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

-- Resource restart recovery for every supported framework. Identifier
-- readiness remains guarded inside PushStateToClient.
AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    SetTimeout(1000, function()
        for _, playerId in ipairs(GetPlayers()) do
            local src = tonumber(playerId)
            if src then MBT.PlayerState.PushStateToClient(src) end
        end
    end)
end)

-----------------------------------------------------------
-- Player Ready (load state from DB, send restore to client)
-----------------------------------------------------------

RegisterNetEvent('mbt_meta_clothes:playerReady', function()
    local src = source
    print(("^5[mbt_meta_clothes][playerReady] src=%s (triggered by client)^0"):format(src))
    -- Logica condivisa con il server bridge esx:playerLoaded — entrambi i flow
    -- (client manda playerReady oppure server riceve esx:playerLoaded direttamente)
    -- chiamano la stessa funzione, debounced per evitare doppio push.
    MBT.PlayerState.PushStateToClient(src)
end)

RegisterNetEvent('mbt_meta_clothes:submitSnapshot', function(payload)
    local src = source
    if not MBT.ServerUtils.CheckRateLimit(src, 'snapshot') then return end
    local ack = MBT.SnapshotServer.Handle(src, payload)
    TriggerClientEvent('mbt_meta_clothes:snapshotAck', src, ack)
end)

-----------------------------------------------------------
-- Sync Initial Wearing (PED scan for NEW players only)
-----------------------------------------------------------

RegisterNetEvent('mbt_meta_clothes:syncInitialWearing', function(wearingData)
    local src = source
    if type(wearingData) ~= "table" then return end
    if not MBT.ServerUtils.CheckRateLimit(src, "syncInitialWearing") then return end

    -- Only process for NEW players (no DB entry)
    if MBT.PlayerState.HasDbEntry(src) then
        MBT.Debugger("syncInitialWearing: EXISTING player, skipping PED scan")
        return
    end

    -- BARE-PED SANITY CHECK (strict — 2026-05-05 fix)
    --
    -- Se il scan cattura uno stato in cui >50% delle slot non-default hanno
    -- drawable=0, significa che è stato eseguito su un PED parzialmente
    -- vestito (illenium-appearance / fivem-appearance non ha ancora finito
    -- di applicare l'outfit, ma ha già applicato qualche slot — tipico nei
    -- char nuovi appena creati dove appearance async load > 2.5s).
    --
    -- Il check precedente accettava la row se almeno 1 slot non-default
    -- aveva drawable > 0 — troppo permissivo. Risultato: row con (es.) solo
    -- pantaloni starter al drawable 35 ma slot 1, 3, 8, 11 a 0 → al
    -- restoreWearing il player è nudo dalla cintola in su.
    --
    -- Nuovo threshold: tipico outfit reale ha 4-8+ slot non-default con
    -- drawable > 0. Bare freemode ha 0-2. Settiamo MIN a 2 con check
    -- aggiuntivo che almeno 50% delle slot scansionate sono non-zero.
    local meaningfulSlotCount = 0
    local zeroSlotCount = 0
    local totalSlotCount = 0
    for _, slots in pairs(wearingData) do
        if type(slots) == "table" then
            for _, metadata in pairs(slots) do
                if type(metadata) == "table" and metadata.drawable then
                    totalSlotCount = totalSlotCount + 1
                    if metadata.drawable > 0 then
                        meaningfulSlotCount = meaningfulSlotCount + 1
                    else
                        zeroSlotCount = zeroSlotCount + 1
                    end
                end
            end
        end
    end

    -- Reject conditions (any one triggers):
    --   1. Empty scan (totalSlotCount == 0) — nothing to save anyway
    --   2. Less than 2 slots have drawable > 0 (canonical bare PED)
    --   3. More than 50% of scanned slots are zero (likely partial apply)
    local MIN_MEANINGFUL = 2
    local rejected, reason = false, nil
    if totalSlotCount == 0 then
        rejected, reason = true, 'empty scan'
    elseif meaningfulSlotCount < MIN_MEANINGFUL then
        rejected, reason = true, ('only %d non-zero slot(s), need ≥%d'):format(meaningfulSlotCount, MIN_MEANINGFUL)
    elseif zeroSlotCount > meaningfulSlotCount then
        rejected, reason = true, ('%d zero vs %d non-zero — likely partial appearance apply'):format(zeroSlotCount, meaningfulSlotCount)
    end

    if rejected then
        print(("^3[mbt_meta_clothes] WARN: syncInitialWearing REJECTED for src=%s — %s. DB row NOT created (avoid storing partial bare-PED state).^0"):format(src, reason))
        return
    end

    MBT.Debugger("syncInitialWearing: NEW player, filling from PED scan")

    if wearingData.Drawables then
        for slotType, slots in pairs(wearingData) do
            if type(slots) == "table" then
                for idx, metadata in pairs(slots) do
                    if type(metadata) == "table" and metadata.drawable then
                        MBT.PlayerState.SetSlot(src, slotType, tonumber(idx) or idx, metadata)
                        MBT.Debugger("  syncInitialWearing: filled", slotType, "slot", idx, "from PED")
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
    if not MBT.ServerUtils.CheckRateLimit(src, "storeWearing") then return end

    -- Validate slot
    local valid, idx = MBT.ServerUtils.ValidateSlot(slotType, metadata.index)
    if not valid then return end
    metadata.index = idx

    -- Inject DNA
    MBT.ServerUtils.InjectDNA(metadata, src)

    MBT.PlayerState.SetSlot(src, slotType, idx, metadata)
    MBT.Debugger(">>> storeWearing:", slotType, "slot", idx)
end)

RegisterNetEvent('mbt_meta_clothes:storeWearingKit', function(kitData)
    local src = source
    if not MBT.ServerUtils.CheckRateLimit(src, "storeWearingKit") then return end
    if type(kitData) ~= "table" then return end
    MBT.Debugger(">>> storeWearingKit received:", json.encode(kitData))

    for slotIndex, slotMetadata in pairs(kitData) do
        if type(slotMetadata) == "table" and slotMetadata.index then
            -- Validate each slot belongs to Drawables
            local valid, idx = MBT.ServerUtils.ValidateSlot("Drawables", slotMetadata.index)
            if valid then
                MBT.Debugger("  kit slot:", slotIndex, "type:", type(slotMetadata), "index:", idx)
                slotMetadata.index = idx
                MBT.ServerUtils.InjectDNA(slotMetadata, src)
                MBT.PlayerState.SetSlot(src, "Drawables", idx, slotMetadata)
            end
        end
    end
end)

-----------------------------------------------------------
-- External Dress/Undress (from appearance scripts via Hybrid Detection)
-----------------------------------------------------------

RegisterNetEvent('mbt_meta_clothes:externalDress', function(slotType, metadata)
    local src = source
    if not metadata or not metadata.index then return end
    if not MBT.ServerUtils.CheckRateLimit(src, "externalDress") then return end

    local valid, idx = MBT.ServerUtils.ValidateSlot(slotType, metadata.index)
    if not valid then return end
    metadata.index = idx

    MBT.Debugger("External dress detected:", slotType, "slot", idx)
    MBT.ServerUtils.InjectDNA(metadata, src)
    MBT.PlayerState.SetSlot(src, slotType, idx, metadata)
end)

RegisterNetEvent('mbt_meta_clothes:externalUndress', function(slotType, slotIndex)
    local src = source
    if not MBT.ServerUtils.CheckRateLimit(src, "externalUndress") then return end

    local valid, idx = MBT.ServerUtils.ValidateSlot(slotType, slotIndex)
    if not valid then return end

    local existingMeta = MBT.PlayerState.GetSlot(src, slotType, idx)
    if existingMeta then
        MBT.PlayerState.ClearSlot(src, slotType, idx)
        MBT.Debugger("External undress:", slotType, "slot", idx)
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

    MBT.Debugger("=== PLAYER DROPPED ===", src)
    local wearingState = MBT.PlayerState.GetAll(src)
    if wearingState then
        MBT.Debugger("Wearing state at disconnect:", json.encode(wearingState))
    end

    MBT.SnapshotServer.Cleanup(src)
    MBT.PlayerState.Cleanup(src)
    MBT.Debugger("PlayerState: Cleaned up", src)
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
    if type(appearance) ~= "table" then return end
    playerSkins[source] = appearance
end)

-----------------------------------------------------------
-- Give items (dress/undress/steal)
-----------------------------------------------------------

RegisterNetEvent('mbt_meta_clothes:giveDress', function(data)
    local src = source
    if not MBT.ServerUtils.CheckRateLimit(src, "giveDress") then return end
    if not data or not data.Index then return end
    if not MBT.Drawables[data.Index] then return end
    MBT.Debugger("<<< giveDress: undressing slot", data.Index)
    giveDress(data)
end)

RegisterNetEvent('mbt_meta_clothes:giveDressKit', function(data)
    local src = source
    if not MBT.ServerUtils.CheckRateLimit(src, "giveDressKit") then return end
    if type(data) ~= "table" then return end
    MBT.Debugger("<<< giveDressKit: undressing top")
    giveDressKit(data)
end)

RegisterNetEvent('mbt_meta_clothes:giveProp', function(data)
    local src = source
    if not MBT.ServerUtils.CheckRateLimit(src, "giveProp") then return end
    if not data or not data.Index then return end
    if not MBT.Props[data.Index] then return end
    MBT.Debugger("<<< giveProp: undressing prop slot", data.Index)
    giveProp(data)
end)

-- S4 FIX: Server-authoritative steal — server reads from PlayerState, not from client
RegisterNetEvent('mbt_meta_clothes:syncStealDress', function(target)
    local src = source
    if not MBT.ServerUtils.CheckRateLimit(src, "steal") then return end
    if not MBT.ServerUtils.IsValidPlayer(target) then return end
    if not MBT.ServerUtils.CheckProximity(src, target, MBT.StealDistance or 5.0) then return end

    -- Server reads victim's state and gives items to thief
    local targetWearing = MBT.PlayerState.GetAll(target)
    if not targetWearing then return end

    -- Verify target actually has worn items before proceeding
    local hasItems = false
    for _ in pairs(targetWearing.Drawables or {}) do hasItems = true break end
    if not hasItems then
        for _ in pairs(targetWearing.Props or {}) do hasItems = true break end
    end
    if not hasItems then return end

    -- Get target sex from metadata (normalize against legacy raw values like 0/"m")
    local targetSex = "male"
    for _, meta in pairs(targetWearing.Drawables or {}) do
        if meta and meta.sex then targetSex = MBT.NormalizeSex(meta.sex) or "male" break end
    end

    -- Give stolen items to thief using server-authoritative state
    giveStolenItemDress(src, targetWearing, targetSex)

    -- Clear all slots for victim
    MBT.PlayerState.ClearAllSlots(target, "Drawables")
    MBT.PlayerState.ClearAllSlots(target, "Props")

    -- Tell victim client to strip PED
    TriggerClientEvent('mbt_meta_clothes:setDefaultDressTarget', target, src)
end)

RegisterNetEvent('mbt_meta_clothes:stealSingleItem', function(targetServerId, stealType, slotIndex)
    local thiefSource = source
    if not MBT.ServerUtils.CheckRateLimit(thiefSource, "steal") then return end
    if not MBT.ServerUtils.IsValidPlayer(targetServerId) then return end
    if not MBT.ServerUtils.CheckProximity(thiefSource, targetServerId, MBT.StealDistance or 5.0) then return end

    -- Validate stealType
    if stealType ~= "torso" and stealType ~= "drawable" and stealType ~= "prop" then return end

    -- Validate slotIndex for non-torso
    if stealType ~= "torso" then
        local slotTypeStr = stealType == "drawable" and "Drawables" or "Props"
        local valid, idx = MBT.ServerUtils.ValidateSlot(slotTypeStr, slotIndex)
        if not valid then return end
        slotIndex = idx
    end

    -- Get target sex from wearing state (normalize against legacy raw values like 0/"m")
    local targetSex = "male"
    local wearing = MBT.PlayerState.GetAll(targetServerId)
    if wearing then
        for _, meta in pairs(wearing.Drawables or {}) do
            if meta and meta.sex then targetSex = MBT.NormalizeSex(meta.sex) or "male" break end
        end
    end

    if stealType == "torso" then
        local kitMeta = {
            description = MBT.Locale["stolen_clothing"] or "Stolen clothing",
            sex = targetSex, type = "DressKit"
        }
        for _, idx in ipairs(MBT.TorsoKitSlots) do
            local meta = MBT.PlayerState.ClearSlot(targetServerId, "Drawables", idx)
            if meta then
                kitMeta[MBT.TorsoSlotNames[idx]] = meta
            else
                -- PlayerState had no entry (slot was at default): always include all three
                -- torso slots so applyKitDress resets them together (prevents arms/shirt mismatch)
                local defaultDrawable = MBT.Drawables[idx]
                    and MBT.Drawables[idx]["Default"]
                    and MBT.Drawables[idx]["Default"][targetSex]
                    and MBT.Drawables[idx]["Default"][targetSex][1]
                if defaultDrawable ~= nil then
                    kitMeta[MBT.TorsoSlotNames[idx]] = {
                        index = idx, drawable = defaultDrawable, texture = 0, palette = 0
                    }
                end
            end
        end
        if addItemToPlayer then
            addItemToPlayer(thiefSource, "topdress", 1, kitMeta)
        end
        TriggerClientEvent('mbt_meta_clothes:stealApplyDefault', targetServerId, "torso")

    elseif stealType == "drawable" then
        local meta = MBT.PlayerState.ClearSlot(targetServerId, "Drawables", slotIndex)
        local slotCfg = MBT.Drawables[slotIndex]
        local itemName = MBT.ResolveItemName(slotCfg, meta)
        if meta and itemName and addItemToPlayer then
            addItemToPlayer(thiefSource, itemName, 1, meta)
        end
        TriggerClientEvent('mbt_meta_clothes:stealApplyDefault', targetServerId, "drawable", slotIndex)

    elseif stealType == "prop" then
        local meta = MBT.PlayerState.ClearSlot(targetServerId, "Props", slotIndex)
        local slotCfg = MBT.Props[slotIndex]
        local itemName = MBT.ResolveItemName(slotCfg, meta)
        if meta and itemName and addItemToPlayer then
            addItemToPlayer(thiefSource, itemName, 1, meta)
        end
        TriggerClientEvent('mbt_meta_clothes:stealApplyDefault', targetServerId, "prop", slotIndex)
    end
end)

-- S3 FIX: Proximity + rate limit on victim anim relay
RegisterNetEvent('mbt_meta_clothes:requestVictimAnim', function(targetServerId, duration, targetDown, dict, clip)
    local src = source
    if not MBT.ServerUtils.CheckRateLimit(src, "victimAnim") then return end
    if not MBT.ServerUtils.IsValidPlayer(targetServerId) then return end
    if not MBT.ServerUtils.CheckProximity(src, targetServerId, MBT.StealDistance or 5.0) then return end
    -- Validate dict/clip are strings (security: prevent arbitrary data injection)
    if type(dict) ~= "string" or type(clip) ~= "string" then return end
    -- Cap duration to prevent grief
    duration = math.min(duration or 3000, MBT.VictimAnimCap or 10000)
    TriggerClientEvent('mbt_meta_clothes:playVictimAnim', targetServerId, duration, targetDown, dict, clip)
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

-- Drip exports removed: use state bags instead
-- Player(src).state.mbt_dripLevel, mbt_dripTitle, mbt_dripXp, mbt_slotsWorn

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
