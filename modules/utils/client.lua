local playerSex
playerWearing = { Drawables = {}, Props = {} }

MBT.Utils = {}

-----------------------------------------------------------
-- Hybrid Detection System (CORE-5)
-- Polls PED natives every 1000ms to detect clothing changes
-- from ANY source (appearance scripts, trainers, mods).
-----------------------------------------------------------

-- Cache of current PED state for change detection
local clothingCache = { Drawables = {}, Props = {} }

-- Expected changes: slots that meta_clothes is about to modify
-- Prevents internal changes from being treated as external
local expectedChanges = {}  -- ["Drawables_4"] = true

-- Whether hybrid detection is running
local detectionRunning = false

-- Restore protection: during initial login, external changes to our managed slots
-- must be REVERTED (appearance script loading late), not tracked as external dress.
-- After the protection window, external changes are tracked normally.
local restoreProtection = false
local restoreState = nil -- the server wearing state to enforce during protection

--- Flag that meta_clothes is about to change a specific slot
--- Must be called BEFORE SetPedComponentVariation/SetPedPropIndex
--- @param slotType string "Drawables" or "Props"
--- @param slotIndex number Component/prop index
function MBT.Utils.ExpectChange(slotType, slotIndex)
    expectedChanges[slotType .. "_" .. tostring(slotIndex)] = true
end

--- Enable restore protection: during this window, Hybrid Detection reverts
--- external changes instead of tracking them. Used after login to prevent
--- the appearance script from overwriting our restored state.
--- @param wearingState table The server wearing state to enforce
--- @param durationMs number How long to protect (ms)
function MBT.Utils.EnableRestoreProtection(wearingState, durationMs)
    restoreProtection = true
    restoreState = wearingState
    MBT.Utils.MbtDebugger("Restore protection ENABLED for", durationMs, "ms")

    Citizen.SetTimeout(durationMs, function()
        restoreProtection = false
        restoreState = nil
        MBT.Utils.MbtDebugger("Restore protection DISABLED — normal detection active")
    end)
end

--- Scan the PED and populate initial wearing state
--- Reads all clothing slots, sends non-default ones to server
--- Initialize the clothing cache from current PED state (no server event)
--- Used by Hybrid Detection to track changes
function MBT.Utils.InitClothingCache()
    local ped = PlayerPedId()
    if not DoesEntityExist(ped) then return end

    for k, _ in pairs(MBT.Drawables) do
        clothingCache.Drawables[k] = {
            drawable = GetPedDrawableVariation(ped, k),
            texture = GetPedTextureVariation(ped, k)
        }
    end

    for k, _ in pairs(MBT.Props) do
        clothingCache.Props[k] = {
            drawable = GetPedPropIndex(ped, k),
            texture = GetPedPropTextureIndex(ped, k)
        }
    end

    MBT.Utils.MbtDebugger("Clothing cache initialized")
end

--- Scan PED and send wearing state to server (new players only)
--- Called by server via requestPedScan AFTER Load completed (no race condition)
function MBT.Utils.SyncWearingState()
    local ped = PlayerPedId()
    if not DoesEntityExist(ped) then return end

    local sex = MBT.Utils.GetPedSex(ped)
    if sex == "customSkin" then return end

    -- Also refresh cache
    MBT.Utils.InitClothingCache()

    local wearingData = { Drawables = {}, Props = {} }

    for k, v in pairs(MBT.Drawables) do
        local drawable = GetPedDrawableVariation(ped, k)
        if not MBT.Utils.TableContainsValue({table = v["Default"][sex], value = drawable}) then
            wearingData.Drawables[k] = {
                index = k,
                drawable = drawable,
                texture = GetPedTextureVariation(ped, k),
                palette = GetPedPaletteVariation(ped, k),
                sex = sex,
                type = "Drawable"
            }
        end
    end

    for k, v in pairs(MBT.Props) do
        local drawable = GetPedPropIndex(ped, k)
        if not MBT.Utils.TableContainsValue({table = v["Default"][sex], value = drawable}) then
            wearingData.Props[k] = {
                index = k,
                drawable = drawable,
                texture = GetPedPropTextureIndex(ped, k),
                sex = sex,
                type = "Prop"
            }
        end
    end

    TriggerServerEvent("mbt_meta_clothes:syncInitialWearing", wearingData)
end

--- Start the hybrid detection polling thread
--- Runs every 1000ms, detects external clothing changes
--- Performance: 20 native calls per tick (12 components + 8 props) = negligible
function MBT.Utils.StartHybridDetection()
    if detectionRunning then return end
    detectionRunning = true

    Citizen.CreateThread(function()
        -- Short wait for SyncWearingState to populate the cache
        Wait(500)

        while true do
            -- During restore protection, poll every 100ms for instant revert (no visible flash)
            -- During normal gameplay, poll every 1000ms (negligible performance)
            Wait(restoreProtection and 100 or 1000)

            local ped = PlayerPedId()
            if not DoesEntityExist(ped) or IsPedDeadOrDying(ped, false) then
                goto continue
            end

            local sex = MBT.Utils.GetPedSex(ped)
            if sex == "customSkin" then goto continue end

            -- Check Drawables (12 component slots)
            for k, v in pairs(MBT.Drawables) do
                local currentDrawable = GetPedDrawableVariation(ped, k)
                local currentTexture = GetPedTextureVariation(ped, k)
                local cached = clothingCache.Drawables[k]

                if cached and (cached.drawable ~= currentDrawable or cached.texture ~= currentTexture) then
                    local key = "Drawables_" .. tostring(k)

                    if expectedChanges[key] then
                        -- Internal change by meta_clothes — consume flag and update cache
                        expectedChanges[key] = nil
                        clothingCache.Drawables[k] = { drawable = currentDrawable, texture = currentTexture }
                        -- CRITICAL: also update restoreState so the guard protects the NEW state
                        -- Without this, undressing during protection would get reverted by the guard
                        if restoreProtection and restoreState and restoreState.Drawables then
                            local isDefault = MBT.Utils.TableContainsValue({table = v["Default"][sex], value = currentDrawable})
                            if isDefault then
                                restoreState.Drawables[tostring(k)] = nil
                                restoreState.Drawables[k] = nil
                            else
                                restoreState.Drawables[tostring(k)] = { drawable = currentDrawable, texture = currentTexture, palette = GetPedPaletteVariation(ped, k) }
                            end
                        end
                    elseif restoreProtection and restoreState then
                        -- RESTORE PROTECTION: appearance script changed a slot during login
                        -- REVERT to server state instead of tracking
                        local stored = restoreState.Drawables and (restoreState.Drawables[tostring(k)] or restoreState.Drawables[k])
                        if stored and stored.drawable then
                            MBT.Utils.MbtDebugger("RESTORE GUARD: reverting Drawable slot", k, "to", stored.drawable, "(appearance script tried", currentDrawable, ")")
                            SetPedComponentVariation(ped, k, stored.drawable, stored.texture or 0, stored.palette or 0)
                            clothingCache.Drawables[k] = { drawable = stored.drawable, texture = stored.texture or 0 }
                        else
                            local default = v["Default"][sex]
                            if type(default) == "table" then
                                MBT.Utils.MbtDebugger("RESTORE GUARD: reverting Drawable slot", k, "to DEFAULT (appearance script tried", currentDrawable, ")")
                                SetPedComponentVariation(ped, k, default[1], 0, 0)
                                clothingCache.Drawables[k] = { drawable = default[1], texture = 0 }
                            end
                        end
                    else
                        -- EXTERNAL change detected (appearance script, trainer, etc.)
                        MBT.Utils.MbtDebugger("Hybrid Detection: External Drawable change slot", k, ":", cached.drawable, "→", currentDrawable)
                        clothingCache.Drawables[k] = { drawable = currentDrawable, texture = currentTexture }

                        local isDefault = MBT.Utils.TableContainsValue({table = v["Default"][sex], value = currentDrawable})

                        if isDefault then
                            TriggerServerEvent("mbt_meta_clothes:externalUndress", "Drawables", k)
                        else
                            TriggerServerEvent("mbt_meta_clothes:externalDress", "Drawables", {
                                index = k,
                                drawable = currentDrawable,
                                texture = currentTexture,
                                palette = GetPedPaletteVariation(ped, k),
                                sex = sex,
                                type = "Drawable"
                            })
                        end
                    end
                end
            end

            -- Check Props (8 prop slots)
            for k, v in pairs(MBT.Props) do
                local currentDrawable = GetPedPropIndex(ped, k)
                local currentTexture = GetPedPropTextureIndex(ped, k)
                local cached = clothingCache.Props[k]

                if cached and (cached.drawable ~= currentDrawable or cached.texture ~= currentTexture) then
                    local key = "Props_" .. tostring(k)

                    if expectedChanges[key] then
                        -- Internal change — consume flag and update cache
                        expectedChanges[key] = nil
                        clothingCache.Props[k] = { drawable = currentDrawable, texture = currentTexture }
                        -- Update restoreState to protect the new intended state
                        if restoreProtection and restoreState and restoreState.Props then
                            local isDefault = MBT.Utils.TableContainsValue({table = v["Default"][sex], value = currentDrawable})
                            if isDefault then
                                restoreState.Props[tostring(k)] = nil
                                restoreState.Props[k] = nil
                            else
                                restoreState.Props[tostring(k)] = { drawable = currentDrawable, texture = currentTexture }
                            end
                        end
                    elseif restoreProtection and restoreState then
                        local stored = restoreState.Props and (restoreState.Props[tostring(k)] or restoreState.Props[k])
                        if stored and stored.drawable then
                            MBT.Utils.MbtDebugger("RESTORE GUARD: reverting Prop slot", k, "to", stored.drawable)
                            SetPedPropIndex(ped, k, stored.drawable, stored.texture or 0, true)
                            clothingCache.Props[k] = { drawable = stored.drawable, texture = stored.texture or 0 }
                        else
                            MBT.Utils.MbtDebugger("RESTORE GUARD: reverting Prop slot", k, "to DEFAULT")
                            ClearPedProp(ped, k)
                            clothingCache.Props[k] = { drawable = -1, texture = 0 }
                        end
                    else
                        MBT.Utils.MbtDebugger("Hybrid Detection: External Prop change slot", k, ":", cached.drawable, "→", currentDrawable)
                        clothingCache.Props[k] = { drawable = currentDrawable, texture = currentTexture }

                        local isDefault = MBT.Utils.TableContainsValue({table = v["Default"][sex], value = currentDrawable})

                        if isDefault then
                            TriggerServerEvent("mbt_meta_clothes:externalUndress", "Props", k)
                        else
                            TriggerServerEvent("mbt_meta_clothes:externalDress", "Props", {
                                index = k,
                                drawable = currentDrawable,
                                texture = currentTexture,
                                sex = sex,
                                type = "Prop"
                            })
                        end
                    end
                end
            end

            ::continue::
        end
    end)
end

-----------------------------------------------------------
-- Existing Utils functions
-----------------------------------------------------------

function MBT.Utils.UpdatePlayerClothes()
    local playerPed = PlayerPedId()
    for k,v in pairs(MBT.Drawables) do
        playerWearing["Drawables"][k] = GetPedDrawableVariation(playerPed, k)
    end

    for k,v in pairs(MBT.Props) do
        playerWearing["Props"][k] = GetPedPropIndex(playerPed, k)
    end

    SendNUIMessage({
        action = "checkPlayerClothes",
        clothes = playerWearing,
        defaultIndexCLothes = MBT.Drawables,
        defaultIndexProps = MBT.Props,
        playerSex = MBT.Utils.GetPedSex(PlayerPedId())
    })
end

---@param data table
---@return boolean
function MBT.Utils.HandleTopDress(data)
    local canWear = true

    for k,v in pairs(data.index) do
        if type(v) == "table" and k ~= "Arms" then
            if not MBT.Utils.TableContainsValue({table = MBT[data.type][v.index]["Default"][data.pedSex], value = playerWearing["Drawables"][v.index]}) then
                canWear = false
                break
            end
        end
    end

    return canWear
end

---@param data table
function MBT.Utils.HandleProps(propIndex)
    local playerSex = MBT.Utils.GetPedSex(PlayerPedId())
    local currentProp = GetPedPropIndex(PlayerPedId(), propIndex)
    local propData = {
        Item = MBT.Props[propIndex]["Item"],
        Index = propIndex,
        Sex = playerSex,
        Drawable = currentProp,
        Texture  = GetPedPropTextureIndex(PlayerPedId(), propIndex)
    }

    if MBT.Utils.IsAbleToUndress({Type = "Props", Index = propIndex, Drawable = currentProp}) then
        MBT.Utils.SetDefaultPropVariation({
            Player = PlayerPedId(),
            Sex = playerSex,
            Index = propIndex,
            isAnimated = true
        })
        TriggerServerEvent("mbt_meta_clothes:giveProp", propData)
    else
        MBT.NotifyHandler(MBT.Labels["nothing_to_unwear"], "error")
    end
    SendNUIMessage({action = "sendUiState", status = false})
end

function MBT.Utils.HandleTorsoUndress()
    local playerSex = MBT.Utils.GetPedSex(PlayerPedId())

    local topDressData = {
        Item = "topdress",
        Sex = playerSex,
        Kit = {
            Arms = {
                Index = 3,
                Drawable = GetPedDrawableVariation(PlayerPedId(), 3),
                Texture  = GetPedTextureVariation(PlayerPedId(), 3),
                Palette =  GetPedPaletteVariation(PlayerPedId(), 3)
            },
            Tshirt = {
                Index = 8,
                Drawable = GetPedDrawableVariation(PlayerPedId(), 8),
                Texture  = GetPedTextureVariation(PlayerPedId(), 8),
                Palette =  GetPedPaletteVariation(PlayerPedId(), 8),
                isAnimated = true
            },
            Jacket = {
                Index = 11,
                Drawable = GetPedDrawableVariation(PlayerPedId(), 11),
                Texture  = GetPedTextureVariation(PlayerPedId(), 11),
                Palette =  GetPedPaletteVariation(PlayerPedId(), 11)
            }
        }
    }

    if MBT.Utils.IsAbleToUndress({Type = "Drawables", Index = topDressData["Kit"]["Tshirt"]["Index"], Drawable = topDressData["Kit"]["Tshirt"]["Drawable"]}) then

        -- Animation first (blocking), then instant changes, then server event
        -- Each SetDefaultVariation calls ExpectChange internally before PED change
        MBT.Utils.SetDefaultVariation({
            isAnimated = true,
            Player = PlayerPedId(),
            Sex = playerSex,
            Index = topDressData["Kit"]["Tshirt"]["Index"]
        })
        MBT.Utils.SetDefaultVariation({
            isAnimated = false,
            Player = PlayerPedId(),
            Sex = playerSex,
            Index = topDressData["Kit"]["Arms"]["Index"]
        })
        MBT.Utils.SetDefaultVariation({
            isAnimated = false,
            Player = PlayerPedId(),
            Sex = playerSex,
            Index = topDressData["Kit"]["Jacket"]["Index"]
        })
        -- Server event AFTER PED changes — ClearSlot happens when PED is already updated
        TriggerServerEvent("mbt_meta_clothes:giveDressKit", topDressData)
    else
        MBT.NotifyHandler(MBT.Labels["nothing_to_unwear"], "error")
    end
    SendNUIMessage({action = "sendUiState", status = false})
end

---@param data table
function MBT.Utils.HandleUndress(dressIndex)
    local playerSex = MBT.Utils.GetPedSex(PlayerPedId())
    local currentDrawable = GetPedDrawableVariation(PlayerPedId(), dressIndex)
    local dressData = {
        Item = MBT.Drawables[dressIndex]["Item"],
        Index = dressIndex,
        Sex = playerSex,
        Drawable = currentDrawable,
        Texture  = GetPedTextureVariation(PlayerPedId(), dressIndex),
        Palette =  GetPedPaletteVariation(PlayerPedId(), dressIndex)
    }

    if MBT.Utils.IsAbleToUndress({Type = "Drawables", Index = dressIndex, Drawable = currentDrawable}) then
        MBT.Utils.SetDefaultVariation({
            Player = PlayerPedId(),
            Sex = playerSex,
            Index = dressIndex,
            isAnimated = true
        })
        TriggerServerEvent("mbt_meta_clothes:giveDress", dressData)
    else
        MBT.NotifyHandler(MBT.Labels["nothing_to_unwear"], "error")
    end
    SendNUIMessage({action = "sendUiState", status = false})
end

---@param data table
function MBT.Utils.IsAbleToUndress(data)
    local isAble = true
    local playerSex = MBT.Utils.GetPedSex(PlayerPedId())
    local isWearingDefault = MBT.Utils.TableContainsValue({table = MBT[data.Type][data.Index]["Default"][playerSex], value = data.Drawable})

    if MBT.Utils.IsTable(MBT[data.Type][data.Index]["Default"][playerSex]) then
        if isWearingDefault then
            if data.Index == 8 then
                local currentJacket = {Index = 11, Drawable = GetPedDrawableVariation(PlayerPedId(), 11)}
                if MBT.Utils.TableContainsValue({table = MBT[data.Type][currentJacket.Index]["Default"][playerSex], value = currentJacket.Drawable}) then
                    isAble = false
                end
            else
                isAble = false
            end
        end
    end
    return isAble
end

---@param data table
function MBT.Utils.SetDefaultVariation(data)
    local drawable = MBT.Drawables[data.Index]["Default"][data.Sex]
    if MBT.Utils.IsTable(MBT.Drawables[data.Index]["Default"][data.Sex]) then
        drawable = MBT.Utils.RandomizeDress(MBT.Drawables[data.Index]["Default"][data.Sex])
    end
    -- Flag expected change BEFORE modifying PED (prevents hybrid detection false positive)
    MBT.Utils.ExpectChange("Drawables", data.Index)
    if data.isAnimated then
        local propModel = MBT.Drawables[data.Index]["PropModel"]
        local propObj = nil

        -- Spawn prop in hand mid-animation (concurrent thread)
        if propModel and MBT.ClothingProps then
            Citizen.CreateThread(function()
                Wait(300) -- let animation start before attaching prop
                propObj = MBT.ClothingProps.AttachToHand(data.Player, propModel)
            end)
        end

        MBT.Utils.PlayEmote({
            Dict = MBT.Drawables[data.Index]["Animation"]["Dict"],
            Anim = MBT.Drawables[data.Index]["Animation"]["Anim"],
            Flag = MBT.Drawables[data.Index]["Animation"]["Flag"],
            Dur = MBT.Drawables[data.Index]["Animation"]["Duration"]
        }, function()
            SetPedComponentVariation(data.Player, data.Index, drawable, 0, 0)
            -- Delete hand prop after drawable changes (item goes to inventory)
            if propObj then
                MBT.ClothingProps.DetachAndDelete(propObj)
            end
        end)
    else
        SetPedComponentVariation(data.Player, data.Index, drawable, 0, 0)
    end
end

---@param data table
function MBT.Utils.SetDefaultPropVariation(data)
    -- Flag expected change BEFORE modifying PED
    MBT.Utils.ExpectChange("Props", data.Index)
    if data.isAnimated then
        local propModel = MBT.Props[data.Index]["PropModel"]
        local propObj = nil

        -- Spawn prop in hand mid-animation (concurrent thread)
        if propModel and MBT.ClothingProps then
            Citizen.CreateThread(function()
                Wait(300)
                propObj = MBT.ClothingProps.AttachToHand(data.Player, propModel)
            end)
        end

        MBT.Utils.PlayEmote({
            Dict = MBT.Props[data.Index]["Animation"]["Dict"],
            Anim = MBT.Props[data.Index]["Animation"]["Anim"],
            Flag = MBT.Props[data.Index]["Animation"]["Flag"],
            Dur = MBT.Props[data.Index]["Animation"]["Duration"]
        }, function()
            ClearPedProp(data.Player, data.Index)
            if propObj then
                MBT.ClothingProps.DetachAndDelete(propObj)
            end
        end)
    else
        ClearPedProp(data.Player, data.Index)
    end
end

-- TODO : FIX THIS
function MBT.Utils.IsDefaultVariation(closestPlayer)
    local playerSex = MBT.Utils.GetPedSex(closestPlayer)

    for k,v in pairs(MBT.Drawables) do
        if not MBT.Utils.TableContainsValue({table = MBT.Drawables[k]["Default"][playerSex], value = GetPedDrawableVariation(closestPlayer, k)}) then
            return false
        end
    end

    for k,v in pairs(MBT.Props) do
        if not MBT.Utils.TableContainsValue({table = MBT.Props[k]["Default"][playerSex], value = GetPedPropIndex(closestPlayer, k)}) then
            return false
        end
    end

    return true
end

---@param data table
---@param cb function
function MBT.Utils.PlayEmote(data, cb)
    while not HasAnimDictLoaded(data.Dict) do RequestAnimDict(data.Dict) Wait(100) end
    if IsPedInAnyVehicle(PlayerPedId()) then data.Flag = 51 end
    TaskPlayAnim(PlayerPedId(), data.Dict, data.Anim, 3.0, 3.0, data.Dur, data.Flag, 0, false, false, false)
    local Pause = data.Dur-500 if Pause < 500 then Pause = 500 end
    Wait(Pause)
    if cb then cb() end
end

---@param t table
function MBT.Utils.RandomizeDress(t)
    math.randomseed(GetGameTimer() * math.random(30123, 90456))
    return t[math.random(1, #t)]
end

---@param ped number
---@return string
function MBT.Utils.GetPedSex(ped)
    local maleModel, femaleModel = `mp_m_freemode_01`, `mp_f_freemode_01`
    local playerModel = GetEntityModel(ped)
    if playerModel then
        if playerModel == maleModel then
            return "male"
        elseif playerModel == femaleModel then
            return "female"
        else
            return "customSkin"
        end
    end
end

---@param data table
function MBT.Utils.TableContainsValue(data)
    for i = 1, #data.table do
        if data.table[i] == data.value then return true end
    end
    return false
end

---@param x table
function MBT.Utils.IsTable(x)
    return type(x) == "table"
end

function MBT.Utils.Target()
    if MBT.Target["Active"] then
        for zId, zFunct in pairs(MBT.Target["Zones"]) do
            zFunct()
        end
    end
end

---@param dictionaries string
---@param clip string
---@param duration number
function MBT.Utils.PlayAnimation(dictionaries, clip, duration)
    local playerPed = PlayerPedId()
    if DoesEntityExist(playerPed) then
        Citizen.CreateThread(function()
            RequestAnimDict(dictionaries)
            while not HasAnimDictLoaded(dictionaries) do
                Citizen.Wait(100)
            end

            if IsEntityPlayingAnim(playerPed, dictionaries, clip, 3) then
                ClearPedSecondaryTask(playerPed)
            else
                TaskPlayAnim(playerPed, dictionaries, clip, 1.0, -1.0, duration, 8, 0, 0, 0, 0)
                RemoveAnimDict(dictionaries)
            end
        end)
    end
end

function MBT.Utils.GetClosestPlayer()
    local players = GetActivePlayers()
    local playerCoords = GetEntityCoords(PlayerPedId())
    local targetDistance, targetId, targetPed

    for i = 1, #players do
        local player = players[i]

        if player ~= PlayerId() then
            local ped = GetPlayerPed(player)
            local distance = #(playerCoords - GetEntityCoords(ped))

            if distance < (targetDistance or 2) then
                targetDistance = distance
                targetId = player
                targetPed = ped
            end
        end
    end

    return targetId, targetPed
end

function MBT.Utils.StealAnim()
    MBT.Utils.PlayAnimation("anim@heists@load_box", "idle", 1000)
    Citizen.Wait(1000)
    MBT.Utils.PlayAnimation("anim@heists@box_carry@", "idle", 500)
    Citizen.Wait(500)
    MBT.Utils.PlayAnimation("missfam5_yoga", "start_pose", 500)
    Citizen.Wait(500)
    MBT.Utils.PlayAnimation("missbigscore2aig_7@driver", "boot_r_loop", 1000)
    Citizen.Wait(1000)
    MBT.Utils.PlayAnimation("mini@yoga", "outro_2", 1000)
    Citizen.Wait(1000)
    MBT.Utils.PlayAnimation("missbigscore2aig_7@driver", "boot_l_loop", 1000)
    Citizen.Wait(1000)
    MBT.Utils.PlayAnimation("mini@yoga", "outro_2", 1000)
    Citizen.Wait(1000)
    ClearPedTasks(PlayerPedId())
end

function MBT.Utils.MbtWearableProps()
    local resourceState = GetResourceState("mbt_wearable_props") ~= "missing"
    return resourceState
end

function MBT.Utils.MbtDebugger(...)
    if MBT.Debug then
        local arg = {...}
        local printResult = "["..GetCurrentResourceName().."] | "
        for _,v in ipairs(arg) do
            printResult = printResult .. tostring(v) .. "\t"
        end
        printResult = printResult .. "\n"
        print(printResult)
    end
end
