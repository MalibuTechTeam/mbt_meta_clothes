--- Normalize metadata from different inventory formats (OX vs QB)
local function normalizeMetadata(data)
    local meta = {}
    meta.index = data.index
    meta.drawable = data.drawable
    meta.texture = data.texture
    meta.palette = data.palette
    meta.sex = data.sex
    meta.type = data.type
    meta.description = data.description

    if data.metadata and type(data.metadata) == "table" then
        meta.index = meta.index or data.metadata.index
        meta.drawable = meta.drawable or data.metadata.drawable
        meta.texture = meta.texture or data.metadata.texture
        meta.palette = meta.palette or data.metadata.palette
        meta.sex = meta.sex or data.metadata.sex
        meta.type = meta.type or data.metadata.type
        meta.description = meta.description or data.metadata.description
        for k, v in pairs(data.metadata) do
            if meta[k] == nil then
                meta[k] = v
            end
        end
    end

    return meta
end

AddEventHandler('onResourceStart', function(resourceName)
    if (GetCurrentResourceName() == resourceName) then
        if NetworkIsPlayerActive(PlayerId()) then
            MBT.Utils.UpdatePlayerClothes()
            MBT.Utils.Target()
            SetPedCanLosePropsOnDamage(PlayerPedId(), false, 0)
            TriggerServerEvent("mbt_meta_clothes:playerReady")
            -- SyncWearingState is NOT called here — server decides when to scan
            -- InitClothingCache is called to prepare Hybrid Detection cache
            MBT.Utils.InitClothingCache()
            MBT.Utils.StartHybridDetection()
        end
    end
end)

-- Server requests PED scan (new players only, after Load completed)
RegisterNetEvent('mbt_meta_clothes:requestPedScan')
AddEventHandler('mbt_meta_clothes:requestPedScan', function()
    -- New player: no changes needed, just scan PED and show it
    ResetEntityAlpha(PlayerPedId())
    MBT.Utils.SyncWearingState()
end)

-----------------------------------------------------------
-- Authoritative PED restore from server wearing state
-----------------------------------------------------------

--- Apply the wearing state to the PED
local function applyWearingState(wearingState)
    local ped = PlayerPedId()
    if not DoesEntityExist(ped) then return end

    local sex = MBT.Utils.GetPedSex(ped)
    if sex == "customSkin" then return end

    for k, v in pairs(MBT.Drawables) do
        local stored = wearingState.Drawables and (wearingState.Drawables[tostring(k)] or wearingState.Drawables[k])

        if stored and stored.drawable then
            SetPedComponentVariation(ped, k, stored.drawable, stored.texture or 0, stored.palette or 0)
        else
            local default = v["Default"][sex]
            if type(default) == "table" then
                SetPedComponentVariation(ped, k, default[1], 0, 0)
            end
        end
    end

    for k, v in pairs(MBT.Props) do
        local stored = wearingState.Props and (wearingState.Props[tostring(k)] or wearingState.Props[k])

        if stored and stored.drawable then
            SetPedPropIndex(ped, k, stored.drawable, stored.texture or 0, true)
            -- Hat/hair clip fix: apply on restore if wearing hat
            if k == 0 then
                MBT.Utils.ApplyHatHairFix(ped)
            end
        else
            local default = v["Default"][sex]
            if type(default) == "table" then
                ClearPedProp(ped, k)
            end
        end
    end

    MBT.Utils.UpdatePlayerClothes()
end

RegisterNetEvent('mbt_meta_clothes:restoreWearing')
AddEventHandler('mbt_meta_clothes:restoreWearing', function(wearingState)
    if not wearingState then return end

    -- Normalize JSON string keys to numeric (json.decode creates "3" not 3)
    local normalized = { Drawables = {}, Props = {} }
    for k, v in pairs(wearingState.Drawables or {}) do
        normalized.Drawables[tonumber(k) or k] = v
    end
    for k, v in pairs(wearingState.Props or {}) do
        normalized.Props[tonumber(k) or k] = v
    end
    wearingState = normalized

    -- Enable restore protection: for the next 15 seconds, Hybrid Detection
    -- will REVERT any external changes to our managed slots instead of tracking them.
    -- This prevents the appearance script from overwriting our restored state.
    MBT.Utils.EnableRestoreProtection(wearingState, 15000)

    -- Apply immediately — restore guard (100ms polling, 15s) handles late appearance script changes
    applyWearingState(wearingState)

    -- Show PED — state is now correct
    ResetEntityAlpha(PlayerPedId())
end)

RegisterNUICallback('handleDress', function(data, cb)
    -- Torso slots (3=arms, 8=tshirt, 11=jacket) are a single kit — always undress together
    if data.Index == 3 or data.Index == 8 or data.Index == 11 then
        MBT.Utils.HandleTorsoUndress()
    else
        MBT.Utils.HandleUndress(data.Index)
    end
    cb(1)
end)

RegisterNUICallback('handleProps', function(data, cb)
    MBT.Utils.HandleProps(data.Index)
    cb(1)
end)

RegisterNUICallback('handleToggleState', function(data, cb)
    -- data.slotType = "Drawables" or "Props", data.slotIndex = number
    MBT.Utils.HandleToggleState(data.slotType, data.slotIndex)
    cb(1)
end)

RegisterNUICallback('handleHairToggle', function(data, cb)
    MBT.Utils.HandleToggleState("Drawables", 2)
    cb(1)
end)

RegisterNUICallback('exitUI', function(data, cb)
    SetNuiFocus(false, false)
    cb(1)
end)

--- Send slot update to NUI after any dress/undress action
--- @param slotType string "Drawables" or "Props"
--- @param slotIndex number The slot index
--- @param isWearing boolean Whether the slot is now worn (non-default)
function MBT.Utils.SendSlotUpdate(slotType, slotIndex, isWearing)
    local ped = PlayerPedId()
    local update = {
        action = "updateSlot",
        slotType = slotType,
        slotIndex = slotIndex,
        isWearing = isWearing
    }
    if isWearing then
        if slotType == "Drawables" then
            update.drawable = GetPedDrawableVariation(ped, slotIndex)
            update.texture = GetPedTextureVariation(ped, slotIndex)
        else
            update.drawable = GetPedPropIndex(ped, slotIndex)
            update.texture = GetPedPropTextureIndex(ped, slotIndex)
        end
    end
    SendNUIMessage(update)
end

RegisterNetEvent('mbt_meta_clothes:applyDress')
AddEventHandler('mbt_meta_clothes:applyDress', function(data)
    local meta = normalizeMetadata(data)
    MBT.Utils.ExpectChange("Drawables", meta.index)
    SetPedComponentVariation(PlayerPedId(), meta.index, meta.drawable, meta.texture, meta.palette)
    MBT.Utils.SendSlotUpdate("Drawables", meta.index, true)
    TriggerServerEvent("mbt_meta_clothes:storeWearing", "Drawables", meta)
end)

RegisterNetEvent('mbt_meta_clothes:applyKitDress')
AddEventHandler('mbt_meta_clothes:applyKitDress', function(data)
    local kitMetadata = {}
    for k, v in pairs(data) do
        if type(v) == "table" and v.index then
            MBT.Utils.ExpectChange("Drawables", v.index)
            SetPedComponentVariation(PlayerPedId(), v.index, v.drawable, v.texture, v.palette)
            kitMetadata[v.index] = {
                index = v.index,
                drawable = v.drawable,
                texture = v.texture,
                palette = v.palette,
            }
        end
    end
    MBT.Utils.SendSlotUpdate("Drawables", 3, true)
    MBT.Utils.SendSlotUpdate("Drawables", 8, true)
    MBT.Utils.SendSlotUpdate("Drawables", 11, true)
    TriggerServerEvent("mbt_meta_clothes:storeWearingKit", kitMetadata)
end)

RegisterNetEvent('mbt_meta_clothes:applyProps')
AddEventHandler('mbt_meta_clothes:applyProps', function(data)
    local meta = normalizeMetadata(data)
    MBT.Utils.ExpectChange("Props", meta.index)
    SetPedPropIndex(PlayerPedId(), meta.index, meta.drawable, meta.texture, true)
    -- Hat/hair clip fix: hide hair when putting on hat (prop 0)
    if meta.index == 0 then
        MBT.Utils.ApplyHatHairFix(PlayerPedId())
    end
    MBT.Utils.SendSlotUpdate("Props", meta.index, true)
    TriggerServerEvent("mbt_meta_clothes:storeWearing", "Props", meta)
end)

RegisterNetEvent('mbt_meta_clothes:stealPlayerDress')
AddEventHandler('mbt_meta_clothes:stealPlayerDress', function(data)
    stealPlayerDress(data)
end, false)

RegisterNetEvent('mbt_meta_clothes:setDefaultDressTarget')
AddEventHandler('mbt_meta_clothes:setDefaultDressTarget', function(stealingPlayer)
    local playerPed = PlayerPedId()
    local playerSex = MBT.Utils.GetPedSex(playerPed)
    local targetWearing = { Drawables = {}, Props = {} }

    -- Scatter all non-default clothing as 3D props BEFORE stripping
    MBT.ClothingProps.ScatterAllFromPed(playerPed, playerSex)

    for k, v in pairs(MBT.Drawables) do
        targetWearing["Drawables"][k] = {
            Drawable = GetPedDrawableVariation(playerPed, k),
            Texture =
                GetPedTextureVariation(playerPed, k),
            Palette = GetPedPaletteVariation(playerPed, k)
        }
        MBT.Utils.ExpectChange("Drawables", k)
        SetPedComponentVariation(playerPed, k, MBT.Drawables[k]["Default"][playerSex][1], 0, 0)
    end

    for k, v in pairs(MBT.Props) do
        targetWearing["Props"][k] = {
            Drawable = GetPedPropIndex(playerPed, k),
            Texture = GetPedPropTextureIndex(
                playerPed, k),
            Palette = 0
        }
        MBT.Utils.ExpectChange("Props", k)
        SetPedPropIndex(playerPed, k, MBT.Props[k]["Default"][playerSex][1], 0, 0)
    end

    TriggerServerEvent('mbt_meta_clothes:giveStolenItemDress', stealingPlayer, targetWearing, playerSex)
end)

RegisterCommand("toggleUndress", function()
    if IsPedOnFoot(PlayerPedId()) and not IsPedDeadOrDying(PlayerPedId(), false) and not IsPedCuffed(PlayerPedId()) then
        local bagState = type(checkBagState) == 'function' and checkBagState() or false
        local maskState = type(checkMaskState) == 'function' and checkMaskState() or false
        local armorState = type(checkArmorState) == 'function' and checkArmorState() or false
        local resourceState = MBT.Utils.MbtWearableProps()

        -- Build wearing state for NUI: which slots have non-default drawables
        local ped = PlayerPedId()
        local sex = MBT.Utils.GetPedSex(ped)
        local wearing = { Drawables = {}, Props = {} }

        if sex ~= "customSkin" then
            for k, v in pairs(MBT.Drawables) do
                local drawable = GetPedDrawableVariation(ped, k)
                local isDefault = MBT.Utils.TableContainsValue({ table = v["Default"][sex], value = drawable })
                if not isDefault then
                    wearing.Drawables[tostring(k)] = {
                        index = k,
                        drawable = drawable,
                        texture = GetPedTextureVariation(ped, k)
                    }
                end
            end
            for k, v in pairs(MBT.Props) do
                local prop = GetPedPropIndex(ped, k)
                local isDefault = MBT.Utils.TableContainsValue({ table = v["Default"][sex], value = prop })
                if not isDefault then
                    wearing.Props[tostring(k)] = {
                        index = k,
                        drawable = prop,
                        texture = GetPedPropTextureIndex(ped, k)
                    }
                end
            end
        end

        -- Determine sex as numeric (0=male, 1=female) for NUI mannequin image
        local sexNumeric = (sex == "female") and 1 or 0

        -- Build toggleable slots list: which slots have ClothingStates configured
        local toggleableSlots = { Drawables = {}, Props = {} }
        if MBT.ClothingStates then
            for slotType, slots in pairs(MBT.ClothingStates) do
                for slotIndex, states in pairs(slots) do
                    if #states > 0 then
                        local currentDrawable
                        if slotType == "Drawables" then
                            currentDrawable = GetPedDrawableVariation(ped, slotIndex)
                        else
                            currentDrawable = GetPedPropIndex(ped, slotIndex)
                        end
                        -- Check if current drawable has a toggle state
                        for _, state in ipairs(states) do
                            if state.from == currentDrawable or state.to == currentDrawable then
                                toggleableSlots[slotType][tostring(slotIndex)] = true
                                break
                            end
                        end
                    end
                end
            end
        end

        -- Request drip data from server for NUI display
        TriggerServerEvent('mbt_meta_clothes:requestDripForNui')

        SetNuiFocus(true, true)
        SendNUIMessage({
            action = "ui",
            status = true,
            wearing = wearing,
            sex = sexNumeric,
            mask = maskState,
            bag = bagState,
            armor = armorState,
            wearableProps = resourceState,
            toggleableSlots = toggleableSlots
        })
    end
end, false)

RegisterKeyMapping('toggleUndress', MBT.Labels["sett_name"], 'keyboard', MBT.MenuKey)

-----------------------------------------------------------
-- Slash commands for quick toggle per slot (/shirt, /trousers, etc.)
-- Toggle: if wearing non-default → undress with animation
--         if wearing default → notify nothing to remove
-----------------------------------------------------------

local function canToggle()
    local ped = PlayerPedId()
    return IsPedOnFoot(ped) and not IsPedDeadOrDying(ped, false) and not IsPedCuffed(ped)
end

-- Drawable commands
RegisterCommand("shirt", function() if canToggle() then MBT.Utils.HandleTorsoUndress() end end, false)
RegisterCommand("trousers", function() if canToggle() then MBT.Utils.HandleUndress(4) end end, false)
RegisterCommand("shoes", function() if canToggle() then MBT.Utils.HandleUndress(6) end end, false)
RegisterCommand("chain", function() if canToggle() then MBT.Utils.HandleUndress(7) end end, false)
RegisterCommand("jacket", function() if canToggle() then MBT.Utils.HandleTorsoUndress() end end, false)

-- Prop commands
RegisterCommand("hat", function() if canToggle() then MBT.Utils.HandleProps(0) end end, false)
RegisterCommand("glasses", function() if canToggle() then MBT.Utils.HandleProps(1) end end, false)
RegisterCommand("ears", function() if canToggle() then MBT.Utils.HandleProps(2) end end, false)
RegisterCommand("watch", function() if canToggle() then MBT.Utils.HandleProps(6) end end, false)

-- Hair toggle: tie up / let down
RegisterCommand("hair", function() if canToggle() then MBT.Utils.HandleToggleState("Drawables", 2) end end, false)

-----------------------------------------------------------
-- Clothing States (Tuck/Untuck)
-- /tuck = auto-detect first toggleable slot
-- /tuck [slot] = toggle specific drawable slot (e.g. /tuck 11)
-----------------------------------------------------------
RegisterCommand("tuck", function(_, args)
    if not canToggle() then return end
    if args[1] then
        local slotIndex = tonumber(args[1])
        if slotIndex then
            MBT.Utils.HandleToggleState("Drawables", slotIndex)
        end
    else
        MBT.Utils.HandleToggleState() -- auto-detect
    end
end, false)

-----------------------------------------------------------
-- Drip Reputation — client listener + /drip command
-----------------------------------------------------------

RegisterNetEvent('mbt_meta_clothes:dripUpdate')
AddEventHandler('mbt_meta_clothes:dripUpdate', function(data)
    -- Forward to NUI for display
    SendNUIMessage({
        action = "dripUpdate",
        xp = data.xp,
        rate = data.rate,
        level = data.level,
        levelIndex = data.levelIndex,
        progress = data.progress
    })
end)

RegisterCommand("drip", function()
    TriggerServerEvent('mbt_meta_clothes:requestDrip')
end, false)

RegisterNetEvent('mbt_meta_clothes:dripInfo')
AddEventHandler('mbt_meta_clothes:dripInfo', function(data)
    local msg = ("~t~🔥 Drip: ~w~%s ~t~(Lv.%d) ~w~| ~t~XP: ~w~%d ~t~| Rate: ~w~+%d/tick"):format(
        data.level, data.levelIndex, data.xp, data.rate
    )
    TriggerEvent('chat:addMessage', {
        color = { 0, 200, 200 },
        args = { "Drip", msg }
    })
end)
