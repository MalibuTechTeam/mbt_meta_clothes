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
    MBT.Utils.MbtDebugger("=== requestPedScan: scanning PED for server ===")
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

    MBT.Utils.MbtDebugger("applyWearingState: sex =", sex)

    for k, v in pairs(MBT.Drawables) do
        local stored = wearingState.Drawables and wearingState.Drawables[tostring(k)]
        if not stored then stored = wearingState.Drawables and wearingState.Drawables[k] end

        local beforeDrawable = GetPedDrawableVariation(ped, k)
        -- No ExpectChange here: during restore protection, the restore guard
        -- handles all changes (including ours). This prevents the flag from being
        -- consumed by an appearance script change, leaving us unprotected.

        if stored and stored.drawable then
            SetPedComponentVariation(ped, k, stored.drawable, stored.texture or 0, stored.palette or 0)
            MBT.Utils.MbtDebugger("  Drawable", k, ":", beforeDrawable, "→", stored.drawable, "(RESTORE)")
        else
            local default = v["Default"][sex]
            if type(default) == "table" then
                SetPedComponentVariation(ped, k, default[1], 0, 0)
                MBT.Utils.MbtDebugger("  Drawable", k, ":", beforeDrawable, "→", default[1], "(DEFAULT)")
            end
        end
    end

    for k, v in pairs(MBT.Props) do
        local stored = wearingState.Props and wearingState.Props[tostring(k)]
        if not stored then stored = wearingState.Props and wearingState.Props[k] end

        local beforeProp = GetPedPropIndex(ped, k)

        if stored and stored.drawable then
            SetPedPropIndex(ped, k, stored.drawable, stored.texture or 0, true)
            MBT.Utils.MbtDebugger("  Prop", k, ":", beforeProp, "→", stored.drawable, "(RESTORE)")
        else
            local default = v["Default"][sex]
            if type(default) == "table" then
                ClearPedProp(ped, k)
                MBT.Utils.MbtDebugger("  Prop", k, ":", beforeProp, "→ -1 (DEFAULT)")
            end
        end
    end

    MBT.Utils.UpdatePlayerClothes()
    MBT.Utils.MbtDebugger("=== applyWearingState DONE ===")
end

RegisterNetEvent('mbt_meta_clothes:restoreWearing')
AddEventHandler('mbt_meta_clothes:restoreWearing', function(wearingState)
    MBT.Utils.MbtDebugger("=== restoreWearing RECEIVED ===")
    if not wearingState then
        MBT.Utils.MbtDebugger("WARNING: wearingState is nil!")
        return
    end
    MBT.Utils.MbtDebugger("Raw data:", json.encode(wearingState))

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
    if data.Index == 8 then MBT.Utils.HandleTorsoUndress() else MBT.Utils.HandleUndress(data.Index) end
    cb(1)
end)

RegisterNUICallback('handleProps', function(data, cb)
    MBT.Utils.HandleProps(data.Index)
    cb(1)
end)

RegisterNUICallback('exitUI', function(data, cb)
    SetNuiFocus(false, false)
    cb(1)
end)

RegisterNetEvent('mbt_meta_clothes:applyDress')
AddEventHandler('mbt_meta_clothes:applyDress', function(data)
    local meta = normalizeMetadata(data)
    MBT.Utils.ExpectChange("Drawables", meta.index)
    SetPedComponentVariation(PlayerPedId(), meta.index, meta.drawable, meta.texture, meta.palette)
    SendNUIMessage({action = "applyDress", indexDress = meta.index})
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
    SendNUIMessage({action = "applyDress", indexDress = 8})
    MBT.Utils.MbtDebugger("applyKitDress: sending kitMetadata:", json.encode(kitMetadata))
    TriggerServerEvent("mbt_meta_clothes:storeWearingKit", kitMetadata)
end)

RegisterNetEvent('mbt_meta_clothes:applyProps')
AddEventHandler('mbt_meta_clothes:applyProps', function(data)
    local meta = normalizeMetadata(data)
    MBT.Utils.ExpectChange("Props", meta.index)
    SetPedPropIndex(PlayerPedId(), meta.index, meta.drawable, meta.texture, true)
    SendNUIMessage({action = "applyProps", indexProp = meta.index})
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
    local targetWearing = {Drawables = {}, Props = {}}

    -- Scatter all non-default clothing as 3D props BEFORE stripping
    MBT.ClothingProps.ScatterAllFromPed(playerPed, playerSex)

    for k, v in pairs(MBT.Drawables) do
        targetWearing["Drawables"][k] = {Drawable = GetPedDrawableVariation(playerPed, k), Texture = GetPedTextureVariation(playerPed, k), Palette = GetPedPaletteVariation(playerPed, k)}
        MBT.Utils.ExpectChange("Drawables", k)
        SetPedComponentVariation(playerPed, k, MBT.Drawables[k]["Default"][playerSex][1], 0, 0)
    end

    for k, v in pairs(MBT.Props) do
        targetWearing["Props"][k] = {Drawable = GetPedPropIndex(playerPed, k), Texture = GetPedPropTextureIndex(playerPed, k), Palette = 0}
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

        SetNuiFocus(true, true)
        SendNUIMessage({action = "ui", status = true, mask = maskState, bag = bagState, armor = armorState, wearableProps = resourceState})
    end
end, false)

RegisterKeyMapping('toggleUndress', MBT.Labels["sett_name"], 'keyboard', MBT.MenuKey)
