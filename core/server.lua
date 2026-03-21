-- Initialize PlayerState system (DB table + periodic save thread)
MBT.PlayerState.Init()

-- Resource stop: save ALL players before script unloads (ensure/stop/restart)
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    MBT.ServerUtils.MbtDebugger("=== RESOURCE STOP — saving all players ===")
    MBT.PlayerState.SaveAllDirty()
end)

-- Player disconnect: save wearing state to DB
AddEventHandler('playerDropped', function(reason)
    local src = source
    local state = MBT.PlayerState.GetAll(src)
    MBT.ServerUtils.MbtDebugger("=== PLAYER DROPPED ===", src)
    if state then
        MBT.ServerUtils.MbtDebugger("Wearing state at disconnect:", json.encode(state))
    else
        MBT.ServerUtils.MbtDebugger("No wearing state found for player", src)
    end
    MBT.PlayerState.Cleanup(src)
end)

-- Player ready: load wearing state from DB, then send to client for PED restore
RegisterNetEvent('mbt_meta_clothes:playerReady', function()
    local src = source
    MBT.ServerUtils.MbtDebugger("=== PLAYER READY ===", src)
    MBT.PlayerState.Load(src)  -- blocking (MySQL.scalar.await)

    -- After Load completes, no more race conditions — we know the DB state.
    if MBT.PlayerState.HasDbEntry(src) then
        -- EXISTING player: restore from DB
        local wearingState = MBT.PlayerState.GetAll(src)
        MBT.ServerUtils.MbtDebugger("EXISTING player — restoring from DB:", json.encode(wearingState))
        for k, _ in pairs(MBT.Drawables) do
            local stored = wearingState.Drawables and wearingState.Drawables[k]
            if stored then
                MBT.ServerUtils.MbtDebugger("  Drawable slot", k, "= drawable:", stored.drawable, "texture:", stored.texture)
            else
                MBT.ServerUtils.MbtDebugger("  Drawable slot", k, "= EMPTY (will force default)")
            end
        end
        for k, _ in pairs(MBT.Props) do
            local stored = wearingState.Props and wearingState.Props[k]
            if stored then
                MBT.ServerUtils.MbtDebugger("  Prop slot", k, "= drawable:", stored.drawable)
            else
                MBT.ServerUtils.MbtDebugger("  Prop slot", k, "= EMPTY (will force default)")
            end
        end
        TriggerClientEvent('mbt_meta_clothes:restoreWearing', src, wearingState)
    else
        -- NEW player: ask client to scan PED (server-initiated, no race condition)
        MBT.ServerUtils.MbtDebugger("NEW player — requesting PED scan from client")
        TriggerClientEvent('mbt_meta_clothes:requestPedScan', src)
    end
end)

-----------------------------------------------------------
-- Dress events: store metadata in PlayerWearing
-----------------------------------------------------------

RegisterNetEvent('mbt_meta_clothes:storeWearing', function(slotType, metadata)
    if not slotType or not metadata or not metadata.index then return end
    MBT.ServerUtils.MbtDebugger(">>> storeWearing:", slotType, "slot", metadata.index, "drawable:", metadata.drawable)
    MBT.PlayerState.SetSlot(source, slotType, metadata.index, metadata)
end)

RegisterNetEvent('mbt_meta_clothes:storeWearingKit', function(kitData)
    MBT.ServerUtils.MbtDebugger(">>> storeWearingKit received:", kitData and json.encode(kitData) or "NIL")
    if not kitData then return end
    for slotIndex, slotMetadata in pairs(kitData) do
        MBT.ServerUtils.MbtDebugger("  kit slot:", slotIndex, "type:", type(slotMetadata), "index:", type(slotMetadata) == "table" and slotMetadata.index or "N/A")
        if type(slotMetadata) == "table" and slotMetadata.index then
            MBT.PlayerState.SetSlot(source, "Drawables", slotMetadata.index, slotMetadata)
        end
    end
end)

-----------------------------------------------------------
-- Hybrid Detection System (CORE-5): server-side handlers
-----------------------------------------------------------

RegisterNetEvent('mbt_meta_clothes:syncInitialWearing', function(wearingData)
    local src = source
    if not wearingData then return end

    -- CRITICAL: Skip PED sync for returning players (those with a DB record).
    -- The DB is authoritative. "Empty slot" means the player intentionally undressed,
    -- NOT "slot was never tracked". Filling from PED scan would corrupt the state.
    -- PED sync is ONLY useful for brand-new players who have never used this script.
    if MBT.PlayerState.HasDbEntry(src) then
        MBT.ServerUtils.MbtDebugger("syncInitialWearing: SKIPPED — player has DB data, DB is authoritative")
        return
    end

    MBT.ServerUtils.MbtDebugger("syncInitialWearing: NEW player, filling from PED scan")

    if not MBT.PlayerState.IsLoaded(src) then
        MBT.PlayerState.InitPlayer(src)
    end

    for _, slotType in ipairs({"Drawables", "Props"}) do
        if wearingData[slotType] then
            for slotIndex, clientMeta in pairs(wearingData[slotType]) do
                local idx = tonumber(slotIndex) or slotIndex
                local existing = MBT.PlayerState.GetSlot(src, slotType, idx)
                if not existing then
                    MBT.PlayerState.SetSlot(src, slotType, idx, clientMeta)
                    MBT.ServerUtils.MbtDebugger("  syncInitialWearing: filled", slotType, "slot", idx, "from PED")
                end
            end
        end
    end
end)

RegisterNetEvent('mbt_meta_clothes:externalDress', function(slotType, metadata)
    local src = source
    if not slotType or not metadata or not metadata.index then return end
    MBT.ServerUtils.MbtDebugger("!!! externalDress:", slotType, "slot", metadata.index, "drawable:", metadata.drawable, "— WHO CHANGED THIS?")

    local existing = MBT.PlayerState.GetSlot(src, slotType, metadata.index)
    if existing then
        existing.drawable = metadata.drawable
        existing.texture = metadata.texture
        existing.palette = metadata.palette or existing.palette
        MBT.PlayerState.SetSlot(src, slotType, metadata.index, existing)
    else
        MBT.PlayerState.SetSlot(src, slotType, metadata.index, metadata)
    end
end)

RegisterNetEvent('mbt_meta_clothes:externalUndress', function(slotType, slotIndex)
    local src = source
    if not slotType or not slotIndex then return end

    local metadata = MBT.PlayerState.ClearSlot(src, slotType, slotIndex)
    if not metadata then return end

    local hasCritical = false
    local criticalFields = {"gsr", "blood", "last_worn_by", "embroidery", "gift_message"}
    for _, field in ipairs(criticalFields) do
        if metadata[field] then
            hasCritical = true
            break
        end
    end

    if hasCritical then
        local itemName
        if slotType == "Drawables" and MBT.Drawables[slotIndex] then
            itemName = MBT.Drawables[slotIndex]["Item"]
        elseif slotType == "Props" and MBT.Props[slotIndex] then
            itemName = MBT.Props[slotIndex]["Item"]
        end

        if itemName and addItemToPlayer then
            addItemToPlayer(src, itemName, 1, metadata)
        end
    end
end)

-----------------------------------------------------------
-- Undress events: use stored metadata to create items
-----------------------------------------------------------

RegisterNetEvent('mbt_meta_clothes:giveDress', function(data)
    MBT.ServerUtils.MbtDebugger("<<< giveDress: undressing slot", data.Index, "item:", data.Item)
    -- Log state BEFORE clearing
    local currentSlot = MBT.PlayerState.GetSlot(source, "Drawables", data.Index)
    MBT.ServerUtils.MbtDebugger("    State before clear:", currentSlot and json.encode(currentSlot) or "NIL")
    giveDress(data)
    -- Log state AFTER clearing
    local afterSlot = MBT.PlayerState.GetSlot(source, "Drawables", data.Index)
    MBT.ServerUtils.MbtDebugger("    State after clear:", afterSlot and json.encode(afterSlot) or "NIL (correct)")
end)

RegisterNetEvent('mbt_meta_clothes:giveDressKit', function(data)
    MBT.ServerUtils.MbtDebugger("<<< giveDressKit: undressing top")
    giveDressKit(data)
end)

RegisterNetEvent('mbt_meta_clothes:giveProp', function(data)
    MBT.ServerUtils.MbtDebugger("<<< giveProp: undressing prop slot", data.Index, "item:", data.Item)
    giveProp(data)
end)

RegisterNetEvent('mbt_meta_clothes:giveStolenItemDress', function(stealSource, targetWearing, playerSex)
    giveStolenItemDress(stealSource, targetWearing, playerSex)
end)

RegisterNetEvent('mbt_meta_clothes:syncStealDress', function(target)
    MBT.PlayerState.ClearAllSlots(target, "Drawables")
    MBT.PlayerState.ClearAllSlots(target, "Props")
    TriggerClientEvent('mbt_meta_clothes:setDefaultDressTarget', target, source)
end)

-----------------------------------------------------------
-- Export API for wearable_props integration
-----------------------------------------------------------

exports('getPlayerWearingState', function(src)
    return MBT.PlayerState.GetAll(src)
end)

exports('getPlayerWearingSlot', function(src, slotType, slotIndex)
    return MBT.PlayerState.GetSlot(src, slotType, slotIndex)
end)

exports('isPlayerWearingSlot', function(src, slotType, slotIndex)
    return MBT.PlayerState.GetSlot(src, slotType, slotIndex) ~= nil
end)
