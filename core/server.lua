local playerSkins = {}
local legacyEventWarnings = {}

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
MBT.DressRuntime.Initialize()

-- Resource restart recovery for every supported framework. Identifier
-- readiness remains guarded inside PushStateToClient.
AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    SetTimeout(1000, function()
        for _, playerId in ipairs(GetPlayers()) do
            local src = tonumber(playerId)
            if src then
                MBT.PlayerState.PushStateToClient(
                    src,
                    1,
                    false,
                    MBT.PedVisibility.ResourceRestart
                )
            end
        end
    end)
end)

-----------------------------------------------------------
-- Player Ready (load state from DB, send restore to client)
-----------------------------------------------------------

RegisterNetEvent('mbt_meta_clothes:playerReady', function()
    local src = source
    MBT.Debugger('playerReady: client ready', { source = src })
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

-- Compatibility tombstones: retain the old network names for one release
-- cycle so unknown integrations are visible in logs, but never accept their
-- client-provided wearing metadata as authoritative state.
local function ignoreLegacyMutation(src, eventName)
    legacyEventWarnings[src] = legacyEventWarnings[src] or {}
    if legacyEventWarnings[src][eventName] then return end
    legacyEventWarnings[src][eventName] = true
    MBT.Warn('deprecated client mutation event ignored', {
        source = src,
        event = eventName,
    })
end

-----------------------------------------------------------
-- Deprecated client mutation events
-----------------------------------------------------------

-- Keep these names registered for one compatibility cycle. They deliberately
-- do not mutate PlayerState; the warning exposes unknown external callers.
for _, eventName in ipairs({
    'syncInitialWearing',
    'storeWearing',
    'storeWearingKit',
    'externalDress',
    'externalUndress',
    'stealSingleItem',
    'stealBatch',
    'syncStealDress',
    'requestVictimAnim',
}) do
    local legacyName = eventName
    RegisterNetEvent(('mbt_meta_clothes:%s'):format(eventName), function()
        ignoreLegacyMutation(source, legacyName)
    end)
end

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
    legacyEventWarnings[src] = nil

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
    sendUndressResult(src, data.RequestId, "drawable", index, MBT.GiveItems.ReturnDrawable(src, index))
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
    sendUndressResult(src, data.RequestId, "torso", nil, MBT.GiveItems.ReturnTorso(src))
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
    sendUndressResult(src, data.RequestId, "prop", index, MBT.GiveItems.ReturnProp(src, index))
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

local function validateStealContext(thiefSource, targetServerId)
    if thiefSource == targetServerId then return false end
    if not MBT.ServerUtils.IsValidPlayer(targetServerId) then return false end
    if not MBT.ServerUtils.CheckProximity(thiefSource, targetServerId, MBT.StealDistance or 5.0) then return false end
    if MBT.PlayerState.CheckCharacterSwitch(thiefSource) then return false end
    return not MBT.PlayerState.CheckCharacterSwitch(targetServerId)
end

local function validateStealBegin(thiefSource, targetServerId)
    if not MBT.ServerUtils.CheckRateLimit(thiefSource, 'stealBegin') then return false end
    return validateStealContext(thiefSource, targetServerId)
end

local function buildAllStealSelections(targetServerId)
    local wearing = MBT.PlayerState.GetAll(targetServerId)
    if not wearing then return nil end

    local selections, hasTorso = {}, false
    for _, slotIndex in ipairs(MBT.TorsoKitSlots) do
        if wearing.Drawables and wearing.Drawables[slotIndex] then
            hasTorso = true
            break
        end
    end
    if hasTorso then selections[#selections + 1] = { stealType = 'torso' } end

    for slotIndex in pairs(wearing.Drawables or {}) do
        slotIndex = tonumber(slotIndex) or slotIndex
        if not isTorsoSlot(slotIndex) then
            selections[#selections + 1] = { stealType = 'drawable', slotIndex = slotIndex }
        end
    end
    for slotIndex in pairs(wearing.Props or {}) do
        selections[#selections + 1] = {
            stealType = 'prop',
            slotIndex = tonumber(slotIndex) or slotIndex,
        }
    end
    return selections
end

local lowStealSlots = {
    Drawables = { [4] = true, [6] = true },
    Props = {},
}

local stealProfiles = {}
for _, key in ipairs({
    'target_down',
    'standing_low',
    'standing_high',
    'steal_all',
    'steal_all_down',
}) do
    local animation = MBT.StealAnimations and MBT.StealAnimations[key]
    if animation then stealProfiles[key] = { duration = animation.dur } end
end

local stealAuthority = MBT.StealAuthority.New({
    now = GetGameTimer,
    validateBegin = validateStealBegin,
    validateComplete = validateStealContext,
    normalizeSelections = function(selections)
        return MBT.GiveItems.NormalizeStealSelections(selections, {
            validateSlot = MBT.ServerUtils.ValidateSlot,
            torsoSlots = MBT.TorsoKitSlots,
            maxSelections = maxStealSelections(),
        })
    end,
    buildAllSelections = buildAllStealSelections,
    processSelections = processStealSelections,
    isLowSelection = function(selection)
        local slotType = selection.stealType == 'drawable' and 'Drawables'
            or selection.stealType == 'prop' and 'Props'
            or nil
        return slotType and lowStealSlots[slotType][selection.slotIndex] == true or false
    end,
    profiles = stealProfiles,
    singleProgressDuration = MBT.StealDuration or 1500,
    batchProgressDuration = MBT.StealAllDuration or 2500,
    graceDuration = MBT.StealTokenGrace or 10000,
    log = function(message, detail)
        MBT.Error(message, { detail = detail })
    end,
})

RegisterNetEvent('mbt_meta_clothes:beginSteal', function(payload)
    local thiefSource = source
    local result = stealAuthority:Begin(thiefSource, payload)
    if result.ok then
        TriggerClientEvent(
            'mbt_meta_clothes:playVictimAnim',
            result.targetServerId,
            result.victimAnimKey,
            result.victimDuration
        )
    end
    TriggerClientEvent('mbt_meta_clothes:stealBeginResult', thiefSource, result)
end)

RegisterNetEvent('mbt_meta_clothes:completeSteal', function(token)
    local thiefSource = source
    local result = stealAuthority:Complete(thiefSource, token)
    TriggerClientEvent('mbt_meta_clothes:stealCompleteResult', thiefSource, result)
end)

RegisterNetEvent('mbt_meta_clothes:cancelSteal', function(token)
    local targetServerId = stealAuthority:Cancel(source, token)
    if targetServerId then
        TriggerClientEvent('mbt_meta_clothes:stopVictimAnim', targetServerId)
    end
end)

AddEventHandler('playerDropped', function()
    stealAuthority:CleanupSource(source)
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
