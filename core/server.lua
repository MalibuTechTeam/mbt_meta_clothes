local playerSkins = {}

-----------------------------------------------------------
-- State Bags (drip level, wearing slots count)
-----------------------------------------------------------

function MBT.UpdateStateBags(src)
    local xp = MBT.PlayerState.GetDripXp(src)
    local level, progress = MBT.Drip.GetLevel(xp)
    local wearing = MBT.PlayerState.GetAll(src)
    local slotsWorn = 0
    if wearing then
        for _, _ in pairs(wearing.Drawables or {}) do slotsWorn = slotsWorn + 1 end
        for _, _ in pairs(wearing.Props or {}) do slotsWorn = slotsWorn + 1 end
    end

    Player(src).state:set('mbt_dripLevel', level.index, true)
    Player(src).state:set('mbt_dripTitle', level.name, true)
    Player(src).state:set('mbt_dripXp', xp, true)
    Player(src).state:set('mbt_slotsWorn', slotsWorn, true)
end

-----------------------------------------------------------
-- Player State Init
-----------------------------------------------------------

MBT.PlayerState.Init()

-----------------------------------------------------------
-- Player Ready (load state from DB, send restore to client)
-----------------------------------------------------------

RegisterNetEvent('mbt_meta_clothes:playerReady', function()
    local src = source
    MBT.ServerUtils.MbtDebugger("=== PLAYER READY ===", src)

    MBT.PlayerState.Load(src)

    if MBT.PlayerState.HasDbEntry(src) then
        local wearingState = MBT.PlayerState.GetAll(src)
        MBT.ServerUtils.MbtDebugger("EXISTING player — restoring from DB:", json.encode(wearingState))

        for k, v in pairs(MBT.Drawables) do
            local stored = wearingState.Drawables and (wearingState.Drawables[tostring(k)] or wearingState.Drawables[k])
            if stored and stored.drawable then
                MBT.ServerUtils.MbtDebugger("  Drawable slot", k, "= drawable:", stored.drawable, "texture:", stored.texture)
            else
                MBT.ServerUtils.MbtDebugger("  Drawable slot", k, "= EMPTY (will force default)")
            end
        end
        for k, v in pairs(MBT.Props) do
            local stored = wearingState.Props and (wearingState.Props[tostring(k)] or wearingState.Props[k])
            if stored and stored.drawable then
                MBT.ServerUtils.MbtDebugger("  Prop slot", k, "= drawable:", stored.drawable)
            else
                MBT.ServerUtils.MbtDebugger("  Prop slot", k, "= EMPTY (will force default)")
            end
        end

        TriggerClientEvent('mbt_meta_clothes:restoreWearing', src, wearingState)
    else
        MBT.ServerUtils.MbtDebugger("NEW player — requesting PED scan")
        TriggerClientEvent('mbt_meta_clothes:requestPedScan', src)
    end

    MBT.UpdateStateBags(src)
end)

-----------------------------------------------------------
-- Sync Initial Wearing (PED scan for NEW players only)
-----------------------------------------------------------

RegisterNetEvent('mbt_meta_clothes:syncInitialWearing', function(wearingData)
    local src = source

    -- Only process for NEW players (no DB entry)
    if MBT.PlayerState.HasDbEntry(src) then
        MBT.ServerUtils.MbtDebugger("syncInitialWearing: EXISTING player, skipping PED scan")
        return
    end

    MBT.ServerUtils.MbtDebugger("syncInitialWearing: NEW player, filling from PED scan")

    if wearingData.Drawables then
        for slotType, slots in pairs(wearingData) do
            if type(slots) == "table" then
                for idx, metadata in pairs(slots) do
                    if type(metadata) == "table" and metadata.drawable then
                        MBT.PlayerState.SetSlot(src, slotType, tonumber(idx) or idx, metadata)
                        MBT.ServerUtils.MbtDebugger("  syncInitialWearing: filled", slotType, "slot", idx, "from PED")
                    end
                end
            end
        end
    end
end)

-----------------------------------------------------------
-- Store Wearing (when player uses item to dress)
-----------------------------------------------------------

RegisterNetEvent('mbt_meta_clothes:storeWearing', function(slotType, metadata)
    local src = source
    if not metadata or not metadata.index then return end

    -- Inject DNA
    MBT.ServerUtils.InjectDNA(metadata, src)

    MBT.PlayerState.SetSlot(src, slotType, metadata.index, metadata)
    MBT.ServerUtils.MbtDebugger(">>> storeWearing:", slotType, "slot", metadata.index)
end)

RegisterNetEvent('mbt_meta_clothes:storeWearingKit', function(kitData)
    local src = source
    MBT.ServerUtils.MbtDebugger(">>> storeWearingKit received:", json.encode(kitData))

    for slotIndex, slotMetadata in pairs(kitData) do
        if type(slotMetadata) == "table" and slotMetadata.index then
            MBT.ServerUtils.MbtDebugger("  kit slot:", slotIndex, "type:", type(slotMetadata), "index:", slotMetadata.index)

            -- Inject DNA
            MBT.ServerUtils.InjectDNA(slotMetadata, src)

            MBT.PlayerState.SetSlot(src, "Drawables", slotMetadata.index, slotMetadata)
        end
    end
end)

-----------------------------------------------------------
-- External Dress/Undress (from appearance scripts via Hybrid Detection)
-----------------------------------------------------------

RegisterNetEvent('mbt_meta_clothes:externalDress', function(slotType, metadata)
    local src = source
    if not metadata or not metadata.index then return end

    MBT.ServerUtils.MbtDebugger("External dress detected:", slotType, "slot", metadata.index)

    -- Inject DNA
    MBT.ServerUtils.InjectDNA(metadata, src)

    MBT.PlayerState.SetSlot(src, slotType, metadata.index, metadata)
end)

RegisterNetEvent('mbt_meta_clothes:externalUndress', function(slotType, slotIndex)
    local src = source

    local existingMeta = MBT.PlayerState.GetSlot(src, slotType, slotIndex)

    if existingMeta then
        MBT.PlayerState.ClearSlot(src, slotType, slotIndex)
        MBT.ServerUtils.MbtDebugger("External undress:", slotType, "slot", slotIndex)
    end
end)

-----------------------------------------------------------
-- Player Dropped (save state + cleanup)
-----------------------------------------------------------

AddEventHandler('playerDropped', function(reason)
    local src = source

    if playerSkins[src] then
        TriggerEvent('mbt_meta_clothes:saveSkin', src, playerSkins[src])
        playerSkins[src] = nil
    end

    MBT.ServerUtils.MbtDebugger("=== PLAYER DROPPED ===", src)
    local wearingState = MBT.PlayerState.GetAll(src)
    if wearingState then
        MBT.ServerUtils.MbtDebugger("Wearing state at disconnect:", json.encode(wearingState))
    end

    MBT.PlayerState.Cleanup(src)
    MBT.ServerUtils.MbtDebugger("PlayerState: Cleaned up", src)
end)

-----------------------------------------------------------
-- Resource Stop (save all dirty states)
-----------------------------------------------------------

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    MBT.PlayerState.SaveAllDirty()
end)

-----------------------------------------------------------
-- Skin persistence
-----------------------------------------------------------

RegisterNetEvent('mbt_meta_clothes:storePlayerSkin', function(appearance)
    playerSkins[source] = appearance
end)

-----------------------------------------------------------
-- Give items (dress/undress/steal)
-----------------------------------------------------------

RegisterNetEvent('mbt_meta_clothes:giveDress', function(data)
    MBT.ServerUtils.MbtDebugger("<<< giveDress: undressing slot", data.Index, "item:", data.Item)
    local stateBefore = MBT.PlayerState.GetSlot(source, "Drawables", data.Index)
    MBT.ServerUtils.MbtDebugger("    State before clear:", stateBefore and json.encode(stateBefore) or "NIL")
    giveDress(data)
    local stateAfter = MBT.PlayerState.GetSlot(source, "Drawables", data.Index)
    MBT.ServerUtils.MbtDebugger("    State after clear:", stateAfter and json.encode(stateAfter) or "NIL (correct)")
end)

RegisterNetEvent('mbt_meta_clothes:giveDressKit', function(data)
    MBT.ServerUtils.MbtDebugger("<<< giveDressKit: undressing top")
    giveDressKit(data)
end)

RegisterNetEvent('mbt_meta_clothes:giveProp', function(data)
    MBT.ServerUtils.MbtDebugger("<<< giveProp: undressing prop slot", data.Index)
    giveProp(data)
end)

RegisterNetEvent('mbt_meta_clothes:giveStolenItemDress', function(stealSource, targetWearing, playerSex)
    giveStolenItemDress(stealSource, targetWearing, playerSex)
end)

RegisterNetEvent('mbt_meta_clothes:syncStealDress', function(target)
    -- Clear all slots for the target player
    MBT.PlayerState.ClearAllSlots(target, "Drawables")
    MBT.PlayerState.ClearAllSlots(target, "Props")
    TriggerClientEvent('mbt_meta_clothes:setDefaultDressTarget', target, source)
end)

RegisterNetEvent('mbt_meta_clothes:stealSingleItem', function(targetServerId, stealType, slotIndex)
    local thiefSource = source
    local targetSex = nil

    -- Get target sex from identifier
    if getPlayerIdentifier then
        -- We'll get sex from the wearing state metadata
        local wearing = MBT.PlayerState.GetAll(targetServerId)
        if wearing then
            for _, meta in pairs(wearing.Drawables) do
                if meta and meta.sex then targetSex = meta.sex break end
            end
        end
    end
    if not targetSex then targetSex = "male" end

    if stealType == "torso" then
        local kitData = {
            Item = "topdress",
            Sex = targetSex,
            Kit = {}
        }
        for _, idx in ipairs({3, 8, 11}) do
            local meta = MBT.PlayerState.ClearSlot(targetServerId, "Drawables", idx)
            if meta then
                local slotName = idx == 3 and "Arms" or (idx == 8 and "Tshirt" or "Jacket")
                kitData.Kit[slotName] = meta
            end
        end
        giveDressKit(kitData)
        TriggerClientEvent('mbt_meta_clothes:stealApplyDefault', targetServerId, "torso")
    elseif stealType == "drawable" then
        local meta = MBT.PlayerState.ClearSlot(targetServerId, "Drawables", slotIndex)
        if meta and MBT.Drawables[slotIndex] and MBT.Drawables[slotIndex]["Item"] then
            local player = nil
            if getPlayer then player = getPlayer(thiefSource) end
            local addItem = addItemToPlayer
            if addItem then
                addItem(thiefSource, MBT.Drawables[slotIndex]["Item"], 1, meta)
            end
        end
        TriggerClientEvent('mbt_meta_clothes:stealApplyDefault', targetServerId, "drawable", slotIndex)
    elseif stealType == "prop" then
        local meta = MBT.PlayerState.ClearSlot(targetServerId, "Props", slotIndex)
        if meta and MBT.Props[slotIndex] and MBT.Props[slotIndex]["Item"] then
            local addItem = addItemToPlayer
            if addItem then
                addItem(thiefSource, MBT.Props[slotIndex]["Item"], 1, meta)
            end
        end
        TriggerClientEvent('mbt_meta_clothes:stealApplyDefault', targetServerId, "prop", slotIndex)
    end
end)

RegisterNetEvent('mbt_meta_clothes:requestVictimAnim', function(targetServerId, duration, targetDown)
    TriggerClientEvent('mbt_meta_clothes:playVictimAnim', targetServerId, duration, targetDown)
end)

RegisterNetEvent('mbt_meta_clothes:removeWear', function(itemName)
    -- QB inventory: remove item after use
    if QBCore then
        local Player = QBCore.Functions.GetPlayer(source)
        if Player then
            Player.Functions.RemoveItem(itemName, 1)
        end
    end
end)

-----------------------------------------------------------
-- Drip info request (from /drip command)
-----------------------------------------------------------

RegisterNetEvent('mbt_meta_clothes:requestDripInfo', function()
    local src = source
    local xp = MBT.PlayerState.GetDripXp(src)
    local level, progress = MBT.Drip.GetLevel(xp)
    local rate = MBT.Drip.CalculateRate(src)
    TriggerClientEvent('mbt_meta_clothes:dripInfo', src, {
        title = level.name,
        level = level.index,
        xp = xp,
        rate = rate,
        progress = progress
    })
end)

-----------------------------------------------------------
-- Export API
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

exports('getPlayerDripXp', function(src)
    return MBT.PlayerState.GetDripXp(src)
end)

exports('getPlayerDripLevel', function(src)
    local xp = MBT.PlayerState.GetDripXp(src)
    local level, progress = MBT.Drip.GetLevel(xp)
    return level.name, level.index, progress
end)

exports('getPlayerDripRate', function(src)
    return MBT.Drip.CalculateRate(src)
end)

exports('analyzeClothingDNA', function(src, slotType, slotIndex)
    local meta = MBT.PlayerState.GetSlot(src, slotType, slotIndex)
    if meta and meta.last_worn_by then
        return meta.last_worn_by
    end
    return {}
end)

exports('cleanDNA', function(src, slotType, slotIndex)
    local meta = MBT.PlayerState.GetSlot(src, slotType, slotIndex)
    if meta then
        meta.last_worn_by = nil
        MBT.PlayerState.SetSlot(src, slotType, slotIndex, meta)
    end
end)
