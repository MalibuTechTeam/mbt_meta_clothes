--- Normalize metadata from different inventory formats (OX vs QB)
local function normalizeMetadata(data)
    local meta = {}
    meta.index = data.index
    meta.drawable = data.drawable
    meta.texture = data.texture
    meta.palette = data.palette
    meta.sex = MBT.NormalizeSex(data.sex)
    meta.type = data.type
    meta.description = data.description
    -- Store which item was used so give-back uses the exact item name (validate string)
    meta.item_name = type(data.name) == "string" and data.name or nil

    if data.metadata and type(data.metadata) == "table" then
        meta.index = meta.index or data.metadata.index
        meta.drawable = meta.drawable or data.metadata.drawable
        meta.texture = meta.texture or data.metadata.texture
        meta.palette = meta.palette or data.metadata.palette
        meta.sex = meta.sex or MBT.NormalizeSex(data.metadata.sex)
        meta.type = meta.type or data.metadata.type
        meta.description = meta.description or data.metadata.description
        meta.item_name = meta.item_name or (type(data.metadata.item_name) == "string" and data.metadata.item_name or nil)
        for k, v in pairs(data.metadata) do
            if meta[k] == nil then
                meta[k] = v
            end
        end
    end

    return meta
end

-- onResourceStart is handled by the framework bridge (esx/qb/ox client.lua)
-- to avoid duplicate playerReady events

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
            if MBT.Props[k] and MBT.Props[k]["ApplyHairFix"] then
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
    MBT.Utils.EnableRestoreProtection(wearingState, MBT.RestoreProtection or 15000)

    -- Apply immediately — restore guard (100ms polling, 15s) handles late appearance script changes
    applyWearingState(wearingState)

    -- Show PED — state is now correct
    ResetEntityAlpha(PlayerPedId())
end)

RegisterNUICallback('handleDress', function(data, cb)
    -- Delegate to wearable_props if the slot belongs to it and the resource is running
    local wpItemType = MBT.WearablePropsSlots and MBT.WearablePropsSlots[data.Index]
    if wpItemType and MBT.Utils.MbtWearableProps() then
        -- Armor slot: detect which tier is actually worn via statebag
        if data.Index == 9 then
            if LocalPlayer.state.mbt_isWearingHeavyarmor then
                wpItemType = "heavyarmor"
            elseif LocalPlayer.state.mbt_isWearingMedarmor then
                wpItemType = "medarmor"
            else
                wpItemType = "smallarmor"
            end
        end
        exports['mbt_wearable_props']:removeWearable(wpItemType)
        cb(1)
        return
    end
    -- Torso slots are a single kit — always undress together
    if MBT.TorsoKitSlots and MBT.TableContains(MBT.TorsoKitSlots, data.Index) then
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
    if data and data.slotType and data.slotIndex then
        MBT.Utils.ToggleClothingState(data.slotType, tonumber(data.slotIndex))
    end
    cb(1)
end)

RegisterNUICallback('handleHairToggle', function(data, cb)
    local toggled = MBT.Utils.ToggleHair()
    SendNUIMessage({ action = "hairToggleUpdate", hairToggled = toggled })
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
    -- Hat/hair clip fix: hide hair when putting on hat
    if MBT.Props[meta.index] and MBT.Props[meta.index]["ApplyHairFix"] then
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

-----------------------------------------------------------
-- Steal single item: victim resets the stolen slot to default
-----------------------------------------------------------
RegisterNetEvent('mbt_meta_clothes:stealApplyDefault')
AddEventHandler('mbt_meta_clothes:stealApplyDefault', function(stealType, slotIndex)
    local ped = PlayerPedId()
    local sex = MBT.Utils.GetPedSex(ped)
    if sex == "customSkin" then return end

    if stealType == "torso" then
        -- Scatter torso props before resetting
        for _, idx in ipairs(MBT.TorsoKitSlots) do
            MBT.ClothingProps.ScatterFromPed(ped, "Drawables", idx)
            MBT.Utils.ExpectChange("Drawables", idx)
            local default = MBT.Drawables[idx] and MBT.Drawables[idx]["Default"][sex]
            if default then
                SetPedComponentVariation(ped, idx, default[1], 0, 0)
            end
            MBT.Utils.SendSlotUpdate("Drawables", idx, false)
        end
    elseif stealType == "drawable" and slotIndex then
        MBT.ClothingProps.ScatterFromPed(ped, "Drawables", slotIndex)
        MBT.Utils.ExpectChange("Drawables", slotIndex)
        local default = MBT.Drawables[slotIndex] and MBT.Drawables[slotIndex]["Default"][sex]
        if default then
            SetPedComponentVariation(ped, slotIndex, default[1], 0, 0)
        end
        MBT.Utils.SendSlotUpdate("Drawables", slotIndex, false)
    elseif stealType == "prop" and slotIndex then
        MBT.ClothingProps.ScatterFromPed(ped, "Props", slotIndex)
        MBT.Utils.ExpectChange("Props", slotIndex)
        local default = MBT.Props[slotIndex] and MBT.Props[slotIndex]["Default"][sex]
        if default then
            ClearPedProp(ped, slotIndex)
        end
        -- Restore hair if hat was stolen
        if MBT.Props[slotIndex] and MBT.Props[slotIndex]["ApplyHairFix"] then
            MBT.Utils.RestoreHairFromHatFix(ped)
        end
        MBT.Utils.SendSlotUpdate("Props", slotIndex, false)
    end

    MBT.Utils.UpdatePlayerClothes()
end)

-----------------------------------------------------------
-- Victim animation relay (requested by thief via server)
-----------------------------------------------------------
RegisterNetEvent('mbt_meta_clothes:playVictimAnim')
AddEventHandler('mbt_meta_clothes:playVictimAnim', function(duration, targetDown)
    local ped = PlayerPedId()
    local dict = targetDown and "missexile3" or "missmic4"
    local clip = targetDown and "ex03_dingy_search_case_base_michael" or "michael_tux_fidget"
    while not HasAnimDictLoaded(dict) do
        RequestAnimDict(dict)
        Wait(50)
    end
    TaskPlayAnim(ped, dict, clip, 3.0, 3.0, duration, 49, 0, false, false, false)
    Wait(duration)
    ClearPedTasks(ped)
    RemoveAnimDict(dict)
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
                local isDefault = MBT.TableContains(v["Default"][sex], drawable)
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
                local isDefault = MBT.TableContains(v["Default"][sex], prop)
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

        -- Check hair toggleability for NUI
        local hairToggleable = MBT.Utils.IsHairToggleable and MBT.Utils.IsHairToggleable() or false

        -- Request drip data from server for NUI display
        TriggerServerEvent('mbt_meta_clothes:requestDripInfo')

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
            toggleableSlots = toggleableSlots,
            hairToggleable = hairToggleable
        })
    end
end, false)

RegisterKeyMapping('toggleUndress', MBT.Locale["sett_name"] or "Clothes Menu", 'keyboard', MBT.MenuKey)

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
RegisterCommand("hair", function() if canToggle() then MBT.Utils.ToggleHair() end end, false)

-- Steal command (fallback for servers without target scripts)
RegisterCommand("steal", function()
    if not canToggle() then return end
    local myPed = PlayerPedId()
    local myCoords = GetEntityCoords(myPed)
    local maxDist = MBT.StealDistance or 5.0
    local closestPed, closestDist = nil, maxDist

    for _, playerId in ipairs(GetActivePlayers()) do
        if playerId ~= PlayerId() then
            local targetPed = GetPlayerPed(playerId)
            if targetPed and targetPed ~= 0 then
                local dist = #(myCoords - GetEntityCoords(targetPed))
                if dist < closestDist then
                    local canSteal = IsEntityPlayingAnim(targetPed, "missminuteman_1ig_2", "handsup_base", 3)
                        or IsPedDeadOrDying(targetPed, false)
                        or IsPedRagdoll(targetPed)
                    if canSteal then
                        closestPed = targetPed
                        closestDist = dist
                    end
                end
            end
        end
    end

    if closestPed then
        stealPlayerDress({ entity = closestPed })
    else
        MBT.Notification(MBT.Locale["nothing_to_steal"])
    end
end, false)

-----------------------------------------------------------
-- Server → Client notification relay
-----------------------------------------------------------
RegisterNetEvent('mbt_meta_clothes:notify', function(data)
    MBT.Notification(data)
end)

-----------------------------------------------------------
-- wearable_props statebag listeners
-- Keep NUI extraState in sync when mask/bag/armor change
-- outside of the meta_clothes NUI (e.g. via wearable_props UI)
-----------------------------------------------------------
local wpStatebags = {
    { key = 'mbt_isWearingMask',       nuiKey = 'mask'  },
    { key = 'mbt_isWearingBag',        nuiKey = 'bag'   },
    { key = 'mbt_isWearingSmallarmor', nuiKey = 'armor' },
    { key = 'mbt_isWearingMedarmor',   nuiKey = 'armor' },
    { key = 'mbt_isWearingHeavyarmor', nuiKey = 'armor' },
}
for _, sb in ipairs(wpStatebags) do
    local sbKey  = sb.key
    local nuiKey = sb.nuiKey
    AddStateBagChangeHandler(sbKey, nil, function(bagName, _, value)
        -- Only react to own player statebag
        if bagName ~= ('player:%d'):format(GetPlayerServerId(PlayerId())) then return end
        SendNUIMessage({ action = 'extraStateUpdate', [nuiKey] = value == true })
    end)
end

-----------------------------------------------------------
-- Clothing States (Tuck/Untuck)
-- /tuck = auto-detect first toggleable slot
-- /tuck [slot] = toggle specific drawable slot (e.g. /tuck 11)
-----------------------------------------------------------
RegisterCommand("tuck", function(_, args)
    if not canToggle() then return end
    local slotIndex = tonumber(args[1])
    if not slotIndex then
        MBT.Notification(MBT.Locale["tuck_usage"])
        return
    end
    if MBT.Props[slotIndex] then
        MBT.Utils.ToggleClothingState("Props", slotIndex)
    elseif MBT.Drawables[slotIndex] then
        MBT.Utils.ToggleClothingState("Drawables", slotIndex)
    else
        MBT.Notification(MBT.Locale["tuck_invalid_slot"])
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
    TriggerServerEvent('mbt_meta_clothes:requestDripInfo')
end, false)

RegisterNUICallback('requestDripScore', function(data, cb)
    TriggerServerEvent('mbt_meta_clothes:requestDripInfo')
    cb(1)
end)

RegisterNetEvent('mbt_meta_clothes:dripInfo')
AddEventHandler('mbt_meta_clothes:dripInfo', function(data)
    -- Update NUI
    SendNUIMessage({
        action = "dripUpdate",
        xp = data.xp,
        rate = data.rate,
        level = data.level,           -- The name string from server
        levelIndex = data.levelIndex, -- The numeric level from server
        progress = data.progress
    })

    -- Show in chat
    local lvl = data.level or MBT.Locale["drip_unknown"]
    local lvlIdx = data.levelIndex or 1
    local xp = data.xp or 0
    local rate = data.rate or 0
    local msg = MBT.Locale["drip_info"]:format(lvl, lvlIdx, xp, rate)
    TriggerEvent('chat:addMessage', {
        color = { 0, 200, 200 },
        args = { MBT.Locale["drip_label"], msg }
    })
end)
