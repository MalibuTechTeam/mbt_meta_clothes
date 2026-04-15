local playerSex
MBT.playerWearing = { Drawables = {}, Props = {} }
local lastActionTime = 0

MBT.Utils = {}

--- Check cooldown before actions (prevents animation spam)
local function checkCooldown()
    local now = GetGameTimer()
    if now - lastActionTime < (MBT.ActionCooldown or 1500) then
        return false
    end
    lastActionTime = now
    return true
end

function MBT.Utils.UpdatePlayerClothes()
    local playerPed = PlayerPedId()
    for k,v in pairs(MBT.Drawables) do
        MBT.playerWearing["Drawables"][k] = GetPedDrawableVariation(playerPed, k)
    end
    
    for k,v in pairs(MBT.Props) do
        MBT.playerWearing["Props"][k] = GetPedPropIndex(playerPed, k)
    end

    SendNUIMessage({
        action = "checkPlayerClothes", 
        clothes = MBT.playerWearing, 
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
            if not MBT.TableContains(MBT[data.type][v.index]["Default"][data.pedSex], MBT.playerWearing["Drawables"][v.index]) then
                canWear = false
                break
            end
        end
    end

    return canWear
end

---@param data table
function MBT.Utils.HandleProps(propIndex)
    if not checkCooldown() then return end
    local playerSex = MBT.Utils.GetPedSex(PlayerPedId())
    local currentProp = GetPedPropIndex(PlayerPedId(), propIndex)
    local propData = {
        Item = MBT.Props[propIndex] and MBT.GetSlotItemNames(MBT.Props[propIndex])[1] or nil,
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
        MBT.Utils.UpdatePlayerClothes()
        if MBT.Utils.SendWearingToNUI then MBT.Utils.SendWearingToNUI() end
    else
        MBT.Notification(MBT.Locale["nothing_to_unwear"])
    end
end

function MBT.Utils.HandleTorsoUndress()
    if not checkCooldown() then return end
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
        TriggerServerEvent("mbt_meta_clothes:giveDressKit", topDressData)
        MBT.Utils.UpdatePlayerClothes()
        if MBT.Utils.SendWearingToNUI then MBT.Utils.SendWearingToNUI() end
    else
        MBT.Notification(MBT.Locale["nothing_to_unwear"])
    end
end

---@param data table
function MBT.Utils.HandleUndress(dressIndex)
    if not checkCooldown() then return end
    local playerSex = MBT.Utils.GetPedSex(PlayerPedId())
    local currentDrawable = GetPedDrawableVariation(PlayerPedId(), dressIndex)
    local dressData = {
        Item = MBT.Drawables[dressIndex] and MBT.GetSlotItemNames(MBT.Drawables[dressIndex])[1] or nil,
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
        -- Update NUI after animation finishes (SetDefaultVariation is blocking)
        MBT.Utils.UpdatePlayerClothes()
        if MBT.Utils.SendWearingToNUI then MBT.Utils.SendWearingToNUI() end
    else
        MBT.Notification(MBT.Locale["nothing_to_unwear"])
    end
end

---@param data table
function MBT.Utils.IsAbleToUndress(data)
    local isAble = true
    local playerSex = MBT.Utils.GetPedSex(PlayerPedId()) 
    local isWearingDefault = MBT.TableContains(MBT[data.Type][data.Index]["Default"][playerSex], data.Drawable)
    
    if MBT.Utils.IsTable(MBT[data.Type][data.Index]["Default"][playerSex]) then
        if isWearingDefault then
            if data.Index == 8 then
                local currentJacket = {Index = 11, Drawable = GetPedDrawableVariation(PlayerPedId(), 11)}
                if MBT.TableContains(MBT[data.Type][currentJacket.Index]["Default"][playerSex], currentJacket.Drawable) then -- Jacket?
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
    MBT.Utils.ExpectChange("Drawables", data.Index)
    if data.isAnimated then
        local propModel = MBT.ClothingPropsEnabled and MBT.Drawables[data.Index]["PropModel"] or nil
        local propObj = nil

        if propModel and MBT.ClothingProps then
            Citizen.CreateThread(function()
                Wait(300)
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
    MBT.Utils.ExpectChange("Props", data.Index)
    if data.isAnimated then
        local propModel = MBT.ClothingPropsEnabled and MBT.Props[data.Index]["PropModel"] or nil
        local propObj = nil

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
---@return string  Always returns "male", "female", or "customSkin"
function MBT.Utils.GetPedSex(ped)
    local playerModel = ped and GetEntityModel(ped)
    if playerModel and MBT.GenderModels then
        return MBT.GenderModels[playerModel] or "customSkin"
    end
    return "customSkin"
end


---@param x table
function MBT.Utils.IsTable(x)
    return type(x) == "table" 
end

local targetInitialized = false
function MBT.Utils.Target()
    if targetInitialized then return end
    targetInitialized = true
    if MBT.TargetModule and MBT.TargetModule.Setup then
        MBT.TargetModule.Setup()
    end
end

function MBT.Utils.MbtWearableProps()
    local resourceState = GetResourceState("mbt_wearable_props") ~= "missing"
    return resourceState
end

-----------------------------------------------------------
-- Hybrid Detection System (CORE-5)
-- Polls PED drawables/props every 1000ms (100ms during restore)
-- Detects external changes from appearance scripts
-----------------------------------------------------------

local clothingCache = { Drawables = {}, Props = {} }
local expectedChanges = {}
local detectionRunning = false
local restoreProtection = false
local restoreState = nil

--- Flag an expected internal change (prevents false positive in detection)
function MBT.Utils.ExpectChange(slotType, slotIndex)
    expectedChanges[slotType .. "_" .. tostring(slotIndex)] = true
end

--- Initialize clothing cache from current PED state
function MBT.Utils.InitClothingCache()
    local ped = PlayerPedId()
    clothingCache = { Drawables = {}, Props = {} }

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
end

--- Scan current PED and send wearing state to server (for NEW players)
--- This captures what the player is wearing from the appearance script
function MBT.Utils.SyncWearingState()
    local ped = PlayerPedId()
    local sex = MBT.Utils.GetPedSex(ped)
    if not sex or sex == "customSkin" then return end

    local wearingData = { Drawables = {}, Props = {} }

    for k, v in pairs(MBT.Drawables) do
        local current = GetPedDrawableVariation(ped, k)
        if not MBT.TableContains(v["Default"][sex], current) then
            wearingData.Drawables[k] = {
                index = k,
                drawable = current,
                texture = GetPedTextureVariation(ped, k),
                palette = GetPedPaletteVariation(ped, k),
                sex = sex,
                type = "Drawable"
            }
        end
    end

    for k, v in pairs(MBT.Props) do
        local current = GetPedPropIndex(ped, k)
        if not MBT.TableContains(v["Default"][sex], current) then
            wearingData.Props[k] = {
                index = k,
                drawable = current,
                texture = GetPedPropTextureIndex(ped, k),
                sex = sex,
                type = "Prop"
            }
        end
    end

    TriggerServerEvent("mbt_meta_clothes:syncInitialWearing", wearingData)
end

--- Enable restore protection (prevents appearance script from overriding our state)
function MBT.Utils.EnableRestoreProtection(wearingState, durationMs)
    restoreProtection = true
    restoreState = wearingState
    Citizen.SetTimeout(durationMs or 15000, function()
        restoreProtection = false
        restoreState = nil
    end)
end

-- Pre-cache expected change keys (built after config loads to avoid string concat in hot loop)
local expectedChangeKeys = { Drawables = {}, Props = {} }
SetTimeout(0, function()
    for k in pairs(MBT.Drawables or {}) do expectedChangeKeys.Drawables[k] = "Drawables_" .. tostring(k) end
    for k in pairs(MBT.Props or {}) do expectedChangeKeys.Props[k] = "Props_" .. tostring(k) end
end)

--- Process a single slot change in the detection loop
local function processSlotChange(ped, slotType, k, v, sex, currentDrawable, currentTexture, isProps)
    local key = (expectedChangeKeys[slotType] or {})[k] or (slotType .. "_" .. tostring(k))

    if expectedChanges[key] then
        expectedChanges[key] = nil
        clothingCache[slotType][k] = { drawable = currentDrawable, texture = currentTexture }
        if restoreProtection and restoreState and restoreState[slotType] then
            local isDefault = MBT.TableContains(v["Default"][sex], currentDrawable)
            if isDefault then
                restoreState[slotType][tostring(k)] = nil
                restoreState[slotType][k] = nil
            else
                restoreState[slotType][tostring(k)] = { drawable = currentDrawable, texture = currentTexture }
            end
        end
    elseif restoreProtection and restoreState then
        local stored = restoreState[slotType] and (restoreState[slotType][tostring(k)] or restoreState[slotType][k])
        if stored and stored.drawable then
            if isProps then
                SetPedPropIndex(ped, k, stored.drawable, stored.texture or 0, true)
            else
                SetPedComponentVariation(ped, k, stored.drawable, stored.texture or 0, stored.palette or 0)
            end
            clothingCache[slotType][k] = { drawable = stored.drawable, texture = stored.texture or 0 }
        else
            local default = v["Default"][sex]
            if type(default) == "table" then
                if isProps then
                    ClearPedProp(ped, k)
                    clothingCache[slotType][k] = { drawable = -1, texture = 0 }
                else
                    SetPedComponentVariation(ped, k, default[1], 0, 0)
                    clothingCache[slotType][k] = { drawable = default[1], texture = 0 }
                end
            end
        end
    else
        clothingCache[slotType][k] = { drawable = currentDrawable, texture = currentTexture }
        local isDefault = MBT.TableContains(v["Default"][sex], currentDrawable)
        if isDefault then
            if isProps and MBT.Props[k] and MBT.Props[k]["ApplyHairFix"] then MBT.Utils.RestoreHairFromHatFix(ped) end
            TriggerServerEvent("mbt_meta_clothes:externalUndress", slotType, k)
        else
            if isProps and MBT.Props[k] and MBT.Props[k]["ApplyHairFix"] then MBT.Utils.ApplyHatHairFix(ped) end
            TriggerServerEvent("mbt_meta_clothes:externalDress", slotType, {
                index = k,
                drawable = currentDrawable,
                texture = currentTexture,
                sex = sex,
                type = isProps and "Prop" or "Drawable"
            })
        end
    end
end

--- Start the Hybrid Detection polling loop
function MBT.Utils.StartHybridDetection()
    if detectionRunning then return end
    detectionRunning = true

    Citizen.CreateThread(function()
        Wait(500)

        while true do
            local pollInterval = restoreProtection and 500 or 1000
            Wait(pollInterval)

            local ped = PlayerPedId()
            if not DoesEntityExist(ped) then goto continue end

            local sex = MBT.Utils.GetPedSex(ped)
            if not sex or sex == "customSkin" then goto continue end

            -- Check Drawables
            for k, v in pairs(MBT.Drawables) do
                local cached = clothingCache.Drawables[k]
                local currentDrawable = GetPedDrawableVariation(ped, k)
                local currentTexture = GetPedTextureVariation(ped, k)
                if cached and (cached.drawable ~= currentDrawable or cached.texture ~= currentTexture) then
                    processSlotChange(ped, "Drawables", k, v, sex, currentDrawable, currentTexture, false)
                end
            end

            -- Check Props
            for k, v in pairs(MBT.Props) do
                local cached = clothingCache.Props[k]
                local currentDrawable = GetPedPropIndex(ped, k)
                local currentTexture = GetPedPropTextureIndex(ped, k)
                if cached and (cached.drawable ~= currentDrawable or cached.texture ~= currentTexture) then
                    processSlotChange(ped, "Props", k, v, sex, currentDrawable, currentTexture, true)
                end
            end

            ::continue::
        end
    end)
end

-----------------------------------------------------------
-- External API: allow other scripts to mark expected changes
-- and suppress restore protection for specific slots.
-- Used by mbt_wearable_props to hide hat/glasses when wearing mask.
-----------------------------------------------------------
exports('expectChange', function(slotType, slotIndex)
    MBT.Utils.ExpectChange(slotType, slotIndex)
end)

--- Suppress a slot from restore protection and update cache.
--- Calling this tells meta_clothes: "I intentionally cleared this slot, don't restore it."
--- @param slotType string "Drawables" | "Props"
--- @param slotIndex number slot index
--- @param drawable number new drawable value (-1 for cleared props, 0 for default components)
--- @param texture number new texture value
exports('suppressSlot', function(slotType, slotIndex, drawable, texture)
    MBT.Utils.ExpectChange(slotType, slotIndex)
    -- Update cache so detection won't see a diff
    if clothingCache[slotType] then
        clothingCache[slotType][slotIndex] = { drawable = drawable or 0, texture = texture or 0 }
    end
    -- Remove from restore state so restore protection won't revert it
    if restoreProtection and restoreState and restoreState[slotType] then
        restoreState[slotType][tostring(slotIndex)] = nil
        restoreState[slotType][slotIndex] = nil
    end
end)

--- Restore a slot into restore protection tracking and update cache.
--- Called when wearable is removed and the original prop should be tracked again.
--- @param slotType string "Drawables" | "Props"
--- @param slotIndex number slot index
--- @param drawable number restored drawable value
--- @param texture number restored texture value
exports('restoreSlot', function(slotType, slotIndex, drawable, texture)
    MBT.Utils.ExpectChange(slotType, slotIndex)
    if clothingCache[slotType] then
        clothingCache[slotType][slotIndex] = { drawable = drawable or 0, texture = texture or 0 }
    end
    -- Re-add to restore state if protection is active
    if restoreProtection and restoreState and restoreState[slotType] then
        restoreState[slotType][tostring(slotIndex)] = { drawable = drawable, texture = texture or 0 }
    end
end)

--- Register clothing state toggle pairs at runtime.
--- Addon pack makers or other resources can call this export to add their own
--- tuck/untuck / hat visored / jacket-open pairs without editing clothing_states.lua.
---
--- @param slotType string  "Drawables" | "Props" | "Hair"
--- @param slotIndex number Slot index (ignored for "Hair")
--- @param pairs    table   Single pair {sex, from, to} OR array of pairs {{sex,from,to}, ...}
---
--- Example (adds jacket open/closed pair for addon drawable 350):
---   exports.mbt_meta_clothes:registerClothingState("Drawables", 11, {sex="male", from=350, to=351})
exports('registerClothingState', function(slotType, slotIndex, pairs)
    if not MBT.ClothingStates then return end
    if slotType == "Hair" then
        local target = MBT.ClothingStates.Hair
        if type(pairs[1]) == "table" then
            for _, p in ipairs(pairs) do target[#target+1] = p end
        else
            target[#target+1] = pairs
        end
        return
    end
    if not MBT.ClothingStates[slotType] then
        MBT.ClothingStates[slotType] = {}
    end
    if not MBT.ClothingStates[slotType][slotIndex] then
        MBT.ClothingStates[slotType][slotIndex] = {}
    end
    local target = MBT.ClothingStates[slotType][slotIndex]
    if type(pairs[1]) == "table" then
        for _, p in ipairs(pairs) do target[#target+1] = p end
    else
        target[#target+1] = pairs
    end
end)

-----------------------------------------------------------
-- Steal functions
-----------------------------------------------------------

local STEAL_ZONE_LOW = {
    Drawables = { [4] = true, [6] = true },
    Props = {}
}

local function isTargetDown(targetPed)
    return IsPedDeadOrDying(targetPed, false) or IsPedRagdoll(targetPed)
end

local function getStealAnim(targetDown, stealType, slotIndex)
    if targetDown then
        return { dict = "missexile3", clip = "ex03_dingy_search_case_base_michael", flag = 1 }, 2000
    end
    local isLow = false
    if stealType == "drawable" and slotIndex then
        isLow = STEAL_ZONE_LOW.Drawables[slotIndex] == true
    elseif stealType == "prop" and slotIndex then
        isLow = STEAL_ZONE_LOW.Props[slotIndex] == true
    end
    if isLow then
        return { dict = "random@domestic", clip = "pickup_low", flag = 0 }, 2000
    else
        return { dict = "random@shop_robbery", clip = "robbery_action_b", flag = 49 }, 2500
    end
end

local function faceTarget(thiefPed, targetPed)
    local thiefCoords = GetEntityCoords(thiefPed)
    local targetCoords = GetEntityCoords(targetPed)
    local dx = targetCoords.x - thiefCoords.x
    local dy = targetCoords.y - thiefCoords.y
    local targetHeading = math.deg(math.atan(dx, dy))
    if targetHeading < 0 then targetHeading = targetHeading + 360 end
    local currentHeading = GetEntityHeading(thiefPed)
    local diff = math.abs(targetHeading - currentHeading)
    if diff > 180 then diff = 360 - diff end
    if diff > 30 then
        SetEntityHeading(thiefPed, targetHeading)
    end
end

local function requestVictimAnim(targetServerId, duration, targetDown)
    TriggerServerEvent("mbt_meta_clothes:requestVictimAnim", targetServerId, duration, targetDown)
end

local function playStealAnimation(ped, anim, duration)
    local dict = anim.dict
    while not HasAnimDictLoaded(dict) do RequestAnimDict(dict) Wait(50) end
    TaskPlayAnim(ped, dict, anim.clip, 3.0, 3.0, duration, anim.flag or 49, 0, false, false, false)
    Wait(duration)
    ClearPedTasks(ped)
    RemoveAnimDict(dict)
end

function MBT.Utils.StealSingleItem(thiefPed, targetPed, targetServerId, stealType, slotIndex)
    local targetDown = isTargetDown(targetPed)
    local anim, animDuration = getStealAnim(targetDown, stealType, slotIndex)

    faceTarget(thiefPed, targetPed)

    local cancelled = false
    MBT.ProgressBar({
        duration = MBT.StealDuration or 1500,
        label = MBT.Locale["stealing"] or "Stealing...",
    }, function(result)
        if not result then cancelled = true end
    end)

    if cancelled then return end

    requestVictimAnim(targetServerId, animDuration, targetDown)
    playStealAnimation(thiefPed, anim, animDuration)

    TriggerServerEvent("mbt_meta_clothes:stealSingleItem", targetServerId, stealType, slotIndex)
end

function MBT.Utils.StealAllItems(thiefPed, targetPed, targetServerId)
    local targetDown = isTargetDown(targetPed)

    faceTarget(thiefPed, targetPed)

    local cancelled = false
    MBT.ProgressBar({
        duration = MBT.StealAllDuration or 2500,
        label = MBT.Locale["stealing_all"] or "Stripping clothes...",
    }, function(result)
        if not result then cancelled = true end
    end)

    if cancelled then return end

    if targetDown then
        requestVictimAnim(targetServerId, 3000, targetDown)
        playStealAnimation(thiefPed,
            { dict = "missexile3", clip = "ex03_dingy_search_case_base_michael", flag = 1 },
            3000
        )
    else
        requestVictimAnim(targetServerId, 5000, targetDown)
        playStealAnimation(thiefPed,
            { dict = "random@shop_robbery", clip = "robbery_action_b", flag = 49 },
            5000
        )
    end

    TriggerServerEvent('mbt_meta_clothes:syncStealDress', targetServerId)
end

-----------------------------------------------------------
-- Hat/Hair clip fix
-----------------------------------------------------------

local savedHairDrawable = nil
local savedHairTexture = nil

function MBT.Utils.ApplyHatHairFix(ped)
    if not MBT.HatHairFix then return end
    local currentHair = GetPedDrawableVariation(ped, 2)
    if not MBT.HairFixDrawables[currentHair] then return end
    savedHairDrawable = currentHair
    savedHairTexture = GetPedTextureVariation(ped, 2)
    SetPedComponentVariation(ped, 2, 0, 0, 0)
end

function MBT.Utils.RestoreHairFromHatFix(ped)
    if not MBT.HatHairFix then return end
    if savedHairDrawable then
        SetPedComponentVariation(ped, 2, savedHairDrawable, savedHairTexture or 0, 0)
        savedHairDrawable = nil
        savedHairTexture = nil
    end
end

-----------------------------------------------------------
-- Hair toggle (tie up / let down)
-----------------------------------------------------------

local savedHairToggleDrawable = nil

function MBT.Utils.ToggleHair()
    local ped = PlayerPedId()
    local currentHair = GetPedDrawableVariation(ped, 2)
    local sex = MBT.Utils.GetPedSex(ped)
    if not sex or not MBT.ClothingStates or not MBT.ClothingStates.Hair then return false end

    local hairStates = MBT.ClothingStates.Hair
    for _, pair in ipairs(hairStates) do
        if pair.sex == sex then
            local newDrawable = nil
            if currentHair == pair.from then
                newDrawable = pair.to
                savedHairToggleDrawable = currentHair
            elseif currentHair == pair.to then
                newDrawable = pair.from
                savedHairToggleDrawable = nil
            end

            if newDrawable then
                local currentTexture = GetPedTextureVariation(ped, 2)
                MBT.Utils.PlayEmote({
                    Dict = "clothingtie",
                    Anim = "check_out_a",
                    Flag = 51,
                    Dur = 2000
                }, function()
                    SetPedComponentVariation(ped, 2, newDrawable, currentTexture, 0)
                end)
                return true
            end
        end
    end
    return false
end

function MBT.Utils.IsHairToggleable()
    local ped = PlayerPedId()
    local currentHair = GetPedDrawableVariation(ped, 2)
    local sex = MBT.Utils.GetPedSex(ped)
    if not sex or not MBT.ClothingStates or not MBT.ClothingStates.Hair then return false end

    for _, pair in ipairs(MBT.ClothingStates.Hair) do
        if pair.sex == sex and (currentHair == pair.from or currentHair == pair.to) then
            return true
        end
    end
    return false
end

-----------------------------------------------------------
-- Tuck / Untuck toggle
-----------------------------------------------------------

function MBT.Utils.ToggleClothingState(slotType, slotIndex)
    if not checkCooldown() then return false end
    local ped = PlayerPedId()
    local sex = MBT.Utils.GetPedSex(ped)
    if not sex or not MBT.ClothingStates then return false end

    local states = MBT.ClothingStates[slotType] and MBT.ClothingStates[slotType][slotIndex]
    if not states then return false end

    local current
    if slotType == "Drawables" then
        current = GetPedDrawableVariation(ped, slotIndex)
    else
        current = GetPedPropIndex(ped, slotIndex)
    end

    for _, pair in ipairs(states) do
        if pair.sex == sex then
            local newDrawable = nil
            if current == pair.from then
                newDrawable = pair.to
            elseif current == pair.to then
                newDrawable = pair.from
            end

            if newDrawable then
                -- Preserve current texture when toggling state
                local currentTexture
                if slotType == "Drawables" then
                    currentTexture = GetPedTextureVariation(ped, slotIndex)
                else
                    currentTexture = GetPedPropTextureIndex(ped, slotIndex)
                end

                -- Play toggle-specific animation: prefer ToggleAnimation, fallback to Animation
                local slotConfig = slotType == "Drawables" and MBT.Drawables[slotIndex] or MBT.Props[slotIndex]
                local toggleAnim = slotConfig and (slotConfig["ToggleAnimation"] or slotConfig["Animation"])
                if toggleAnim then
                    MBT.Utils.PlayEmote({
                        Dict = toggleAnim["Dict"],
                        Anim = toggleAnim["Anim"],
                        Flag = toggleAnim["Flag"],
                        Dur  = toggleAnim["Duration"]
                    }, function()
                        MBT.Utils.ExpectChange(slotType, slotIndex)
                        if slotType == "Drawables" then
                            SetPedComponentVariation(ped, slotIndex, newDrawable, currentTexture, 0)
                        else
                            SetPedPropIndex(ped, slotIndex, newDrawable, currentTexture, true)
                        end
                    end)
                else
                    MBT.Utils.ExpectChange(slotType, slotIndex)
                    if slotType == "Drawables" then
                        SetPedComponentVariation(ped, slotIndex, newDrawable, currentTexture, 0)
                    else
                        SetPedPropIndex(ped, slotIndex, newDrawable, currentTexture, true)
                    end
                end
                return true
            end
        end
    end
    return false
end

-----------------------------------------------------------
-- Wearable Props check
-----------------------------------------------------------

function MBT.Utils.MbtWearableProps()
    return GetResourceState('mbt_wearable_props') == 'started'
end

--- Send full wearing state to NUI (updates all slot visuals)
function MBT.Utils.SendWearingToNUI()
    local ped = PlayerPedId()
    local sex = MBT.Utils.GetPedSex(ped)
    if not sex or sex == "customSkin" then return end

    local wearing = { Drawables = {}, Props = {} }
    for k, v in pairs(MBT.Drawables) do
        local current = GetPedDrawableVariation(ped, k)
        if not MBT.TableContains(v["Default"][sex], current) then
            wearing.Drawables[tostring(k)] = { drawable = current, texture = GetPedTextureVariation(ped, k) }
        end
    end
    for k, v in pairs(MBT.Props) do
        local current = GetPedPropIndex(ped, k)
        if not MBT.TableContains(v["Default"][sex], current) then
            wearing.Props[tostring(k)] = { drawable = current, texture = GetPedPropTextureIndex(ped, k) }
        end
    end
    SendNUIMessage({ action = "updateWearing", wearing = wearing })
end