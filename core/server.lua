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
    if MBT.PlayerState.HasBaseline(src) then
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
    MBT.PlayerState.MarkBaseline(src)
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

RegisterNetEvent('mbt_meta_clothes:updateInternalVisual', function(slotType, slotIndex, visual, requestToken, requestContext)
    local src = source
    -- A framework/multichar resource may rotate the identifier without firing
    -- its lifecycle event. Never validate against A and then let PlayerState
    -- reload and mutate B inside UpdateSlotVisual.
    if MBT.PlayerState.CheckCharacterSwitch(src) then
        MBT.PlayerState.PushStateToClient(src, 1, true)
        return
    end
    local valid, index = MBT.ServerUtils.ValidateSlot(slotType, slotIndex)
    local current = valid and MBT.PlayerState.GetSlot(src, slotType, index) or nil
    local context = MBT.SnapshotServer.GetContext(src)

    local function reply(ok, code, authoritativeVisual, revision)
        if not context or not valid or not authoritativeVisual then return end
        TriggerClientEvent('mbt_meta_clothes:authoritativeVisual', src, {
            ok = ok,
            code = code,
            session = context.session,
            revision = revision or MBT.PlayerState.GetRevision(src),
            slotType = slotType,
            slotIndex = index,
            visual = {
                drawable = authoritativeVisual.drawable,
                texture = authoritativeVisual.texture or 0,
                palette = authoritativeVisual.palette or 0,
            },
            token = type(requestToken) == 'number' and requestToken or nil,
        })
    end

    if not valid or type(visual) ~= 'table' then return end
    if not context or type(requestContext) ~= 'table'
        or requestContext.session ~= context.session then return end
    if not MBT.ServerUtils.CheckRateLimit(src, 'internalVisual') then
        return reply(false, 'rate_limited', current)
    end
    if requestContext.revision ~= MBT.PlayerState.GetRevision(src) then
        return reply(false, 'stale_revision', current)
    end
    if not current then
        local ped = GetPlayerPed(src)
        local model = ped and ped ~= 0 and GetEntityModel(ped) or nil
        local sex = model and MBT.GenderModels[model] or nil
        local authoritative = sex and MBT.Snapshot.VisualFromWearing(MBT.PlayerState.GetAll(src), sex)
        return reply(false, 'missing_metadata', authoritative and authoritative[slotType][index])
    end
    if not MBT.Snapshot.IsAllowedToggle(current, slotType, index, visual) then
        return reply(false, 'invalid_transition', current)
    end
    local changed, revision = MBT.PlayerState.UpdateSlotVisual(src, slotType, index, visual)
    if not changed then
        local code = type(revision) == 'string' and revision or 'no_change'
        local authoritativeRevision = type(revision) == 'number' and revision or nil
        return reply(false, code, current, authoritativeRevision)
    end
    reply(true, nil, visual, revision)
end)

-- Ordinary PlayerState mutations (dress, undress, steal) advance the same
-- revision used by snapshots and toggles. Keep the active client context in
-- sync; snapshot commits and visual toggles already carry their own ACK.
AddEventHandler('mbt_meta_clothes:onClothingChanged', function(src, _, _, _, origin)
    if origin == 'snapshot' or origin == 'internal_visual' then return end
    local context = MBT.SnapshotServer.GetContext(src)
    if not context then return end
    TriggerClientEvent('mbt_meta_clothes:authoritativeRevision', src, {
        session = context.session,
        revision = MBT.PlayerState.GetRevision(src),
    })
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

local function validUndressRequestId(value)
    return type(value) == "number"
        and value == math.floor(value)
        and value > 0
        and value <= 2147483647
end

local function sendUndressResult(src, requestId, kind, index, result)
    MBT.Debugger("undress result", {
        source = src,
        requestId = requestId,
        kind = kind,
        index = index,
        ok = result.ok == true,
        reason = result.reason,
    })
    TriggerClientEvent('mbt_meta_clothes:undressResult', src, {
        requestId = requestId,
        ok = result.ok == true,
        reason = result.reason,
        kind = kind,
        index = index,
    })
end

RegisterNetEvent('mbt_meta_clothes:giveDress', function(data)
    local src = source
    if type(data) ~= "table" or not validUndressRequestId(data.RequestId) then return end
    if not MBT.ServerUtils.CheckRateLimit(src, "giveDress") then
        return sendUndressResult(src, data.RequestId, "drawable", data.Index, { ok = false, reason = "busy" })
    end
    local valid, index = MBT.ServerUtils.ValidateSlot("Drawables", data.Index)
    if not valid or MBT.TableContains(MBT.TorsoKitSlots, index) then
        return sendUndressResult(src, data.RequestId, "drawable", data.Index, { ok = false, reason = "invalid_slot" })
    end
    if MBT.PlayerState.CheckCharacterSwitch(src) then
        return sendUndressResult(src, data.RequestId, "drawable", index, { ok = false, reason = "character_changed" })
    end
    MBT.Debugger("<<< giveDress: undressing slot", index)
    sendUndressResult(src, data.RequestId, "drawable", index, giveDress(src, { Index = index }))
end)

RegisterNetEvent('mbt_meta_clothes:giveDressKit', function(data)
    local src = source
    if type(data) ~= "table" or not validUndressRequestId(data.RequestId) then return end
    if not MBT.ServerUtils.CheckRateLimit(src, "giveDressKit") then
        return sendUndressResult(src, data.RequestId, "torso", nil, { ok = false, reason = "busy" })
    end
    if MBT.PlayerState.CheckCharacterSwitch(src) then
        return sendUndressResult(src, data.RequestId, "torso", nil, { ok = false, reason = "character_changed" })
    end
    MBT.Debugger("<<< giveDressKit: undressing top")
    sendUndressResult(src, data.RequestId, "torso", nil, giveDressKit(src))
end)

RegisterNetEvent('mbt_meta_clothes:giveProp', function(data)
    local src = source
    if type(data) ~= "table" or not validUndressRequestId(data.RequestId) then return end
    if not MBT.ServerUtils.CheckRateLimit(src, "giveProp") then
        return sendUndressResult(src, data.RequestId, "prop", data.Index, { ok = false, reason = "busy" })
    end
    local valid, index = MBT.ServerUtils.ValidateSlot("Props", data.Index)
    if not valid then
        return sendUndressResult(src, data.RequestId, "prop", data.Index, { ok = false, reason = "invalid_slot" })
    end
    if MBT.PlayerState.CheckCharacterSwitch(src) then
        return sendUndressResult(src, data.RequestId, "prop", index, { ok = false, reason = "character_changed" })
    end
    MBT.Debugger("<<< giveProp: undressing prop slot", index)
    sendUndressResult(src, data.RequestId, "prop", index, giveProp(src, { Index = index }))
end)

AddEventHandler('playerDropped', function()
    if MBT.GiveItems.Runtime then
        MBT.GiveItems.Runtime:CleanupSource(source)
    end
end)

-- S4 FIX: Server-authoritative steal — server reads from PlayerState, not from client
local function isTorsoSlot(slotIndex)
    return MBT.TableContains(MBT.TorsoKitSlots, slotIndex)
end

local function maxStealSelections()
    local count = 1
    for slotIndex in pairs(MBT.Drawables) do
        if not isTorsoSlot(slotIndex) then count = count + 1 end
    end
    for _ in pairs(MBT.Props) do count = count + 1 end
    return count
end

local function commitStealItem(thiefSource, targetServerId, selection)
    local runtime = MBT.GiveItems.Runtime
    if not runtime then return { ok = false, reason = "unsupported_inventory" } end

    local result
    if selection.stealType == "torso" then
        result = runtime:TransferTorso(targetServerId, thiefSource)
    else
        local slotType = selection.stealType == "drawable" and "Drawables" or "Props"
        result = runtime:TransferSlot(targetServerId, thiefSource, slotType, selection.slotIndex, {
            preserveDescription = true,
        })
    end

    if result.ok then
        result.committed = {
            stealType = selection.stealType,
            slotIndex = selection.slotIndex,
        }
        TriggerClientEvent(
            'mbt_meta_clothes:stealApplyDefault',
            targetServerId,
            selection.stealType,
            selection.slotIndex
        )
    end
    return result
end

local function notifyStealSummary(thiefSource, summary)
    if summary.succeeded == summary.requested then return end
    local localeKey
    if summary.succeeded > 0 then
        localeKey = "partial_steal"
    elseif summary.lastReason == "inventory_full" then
        localeKey = "inventory_full"
    elseif summary.lastReason == "busy" then
        localeKey = "action_busy"
    else
        localeKey = "inventory_error"
    end
    TriggerClientEvent('mbt_meta_clothes:notify', thiefSource, MBT.Locale[localeKey])
end

local function processStealSelections(thiefSource, targetServerId, selections)
    local normalized = MBT.GiveItems.NormalizeStealSelections(selections, {
        validateSlot = MBT.ServerUtils.ValidateSlot,
        torsoSlots = MBT.TorsoKitSlots,
        maxSelections = maxStealSelections(),
    })
    if not normalized then return nil end

    local summary = MBT.GiveItems.ProcessBatch(normalized, function(selection)
        return commitStealItem(thiefSource, targetServerId, selection)
    end)
    notifyStealSummary(thiefSource, summary)
    return summary
end

local function validateStealAction(thiefSource, targetServerId)
    if not MBT.ServerUtils.CheckRateLimit(thiefSource, "steal") then return false end
    if not MBT.ServerUtils.IsValidPlayer(targetServerId) then return false end
    if not MBT.ServerUtils.CheckProximity(thiefSource, targetServerId, MBT.StealDistance or 5.0) then return false end
    if MBT.PlayerState.CheckCharacterSwitch(thiefSource) then return false end
    return not MBT.PlayerState.CheckCharacterSwitch(targetServerId)
end

RegisterNetEvent('mbt_meta_clothes:stealSingleItem', function(targetServerId, stealType, slotIndex)
    local thiefSource = source
    if not validateStealAction(thiefSource, targetServerId) then return end
    processStealSelections(thiefSource, targetServerId, {
        { stealType = stealType, slotIndex = slotIndex },
    })
end)

RegisterNetEvent('mbt_meta_clothes:stealBatch', function(targetServerId, selections)
    local thiefSource = source
    if not validateStealAction(thiefSource, targetServerId) then return end
    processStealSelections(thiefSource, targetServerId, selections)
end)

RegisterNetEvent('mbt_meta_clothes:syncStealDress', function(targetServerId)
    local thiefSource = source
    if not validateStealAction(thiefSource, targetServerId) then return end

    local wearing = MBT.PlayerState.GetAll(targetServerId)
    if not wearing then return end
    local selections, hasTorso = {}, false

    for _, slotIndex in ipairs(MBT.TorsoKitSlots) do
        if wearing.Drawables and wearing.Drawables[slotIndex] then
            hasTorso = true
            break
        end
    end
    if hasTorso then selections[#selections + 1] = { stealType = "torso" } end

    for slotIndex in pairs(wearing.Drawables or {}) do
        slotIndex = tonumber(slotIndex) or slotIndex
        if not isTorsoSlot(slotIndex) then
            selections[#selections + 1] = { stealType = "drawable", slotIndex = slotIndex }
        end
    end
    for slotIndex in pairs(wearing.Props or {}) do
        selections[#selections + 1] = {
            stealType = "prop",
            slotIndex = tonumber(slotIndex) or slotIndex,
        }
    end

    if #selections == 0 then
        TriggerClientEvent('mbt_meta_clothes:notify', thiefSource, MBT.Locale["nothing_to_steal"])
        return
    end
    processStealSelections(thiefSource, targetServerId, selections)
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
