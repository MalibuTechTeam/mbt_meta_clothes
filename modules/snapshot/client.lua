local SnapshotClient = {}

local function firstConfiguredModel()
    for model in pairs(MBT.GenderModels or {}) do return model end
end

local function copyVisual(visual)
    local copied = { Drawables = {}, Props = {} }
    for _, slotType in ipairs({ 'Drawables', 'Props' }) do
        for slotIndex, slot in pairs((visual and visual[slotType]) or {}) do
            copied[slotType][slotIndex] = {
                drawable = slot.drawable,
                texture = slot.texture,
                palette = slot.palette or 0,
            }
        end
    end
    return copied
end

function SnapshotClient.New(deps)
    deps = deps or {}
    local now = assert(deps.now, 'snapshot client clock is required')
    local capture = assert(deps.capture, 'snapshot client capture is required')
    local send = assert(deps.send, 'snapshot client transport is required')
    local modelProvider = deps.model or firstConfiguredModel
    local coordinator = {}
    local context
    local nextSeq = 0
    local acknowledgedFingerprint
    local acknowledgedVisual
    local candidateFingerprint
    local candidateSince
    local pending
    local pauses = { startup = true }
    local internalTokens = {}
    local nextToken = 0
    local expectedSlots = {}
    local suppressions = { Drawables = {}, Props = {} }
    local restoreActive = false
    local forceInitialAt
    local retryAfter = 0
    local rejectionCount = 0

    local function slotKey(slotType, slotIndex)
        return slotType .. ':' .. tostring(slotIndex)
    end

    local function cleanupExpiringGuards(at)
        for token, expiresAt in pairs(internalTokens) do
            if expiresAt <= at then internalTokens[token] = nil end
        end
        for key, expiresAt in pairs(expectedSlots) do
            if expiresAt <= at then expectedSlots[key] = nil end
        end
    end

    local function captureCanonical()
        local raw = capture()
        local model = modelProvider()
        if type(raw) == 'table' and raw.visual then
            model = raw.model or model
            raw = raw.visual
        end
        local visual = MBT.Snapshot.Canonicalize(raw, model)
        if not visual then return nil end
        visual = copyVisual(visual)
        for _, slotType in ipairs({ 'Drawables', 'Props' }) do
            for slotIndex, suppressed in pairs(suppressions[slotType]) do
                if visual[slotType][slotIndex] then
                    visual[slotType][slotIndex] = copyVisual({
                        [slotType] = { [slotIndex] = suppressed },
                    })[slotType][slotIndex]
                end
            end
            if acknowledgedVisual then
                for slotIndex in pairs(visual[slotType]) do
                    if expectedSlots[slotKey(slotType, slotIndex)]
                        and acknowledgedVisual[slotType]
                        and acknowledgedVisual[slotType][slotIndex] then
                        visual[slotType][slotIndex] = copyVisual({
                            [slotType] = { [slotIndex] = acknowledgedVisual[slotType][slotIndex] },
                        })[slotType][slotIndex]
                    end
                end
            end
        end
        return visual, model, MBT.Snapshot.Fingerprint(visual)
    end

    local function setBaseline(visual)
        if not visual then return end
        acknowledgedVisual = copyVisual(visual)
        acknowledgedFingerprint = MBT.Snapshot.Fingerprint(acknowledgedVisual)
        candidateFingerprint = nil
        candidateSince = nil
    end

    function coordinator:SetContext(nextContext, wearingState)
        if type(nextContext) ~= 'table' or nextContext.session == nil
            or type(nextContext.revision) ~= 'number' then return false end
        context = { session = nextContext.session, revision = nextContext.revision }
        nextSeq = 0
        pending = nil
        forceInitialAt = nil
        rejectionCount = 0
        pauses.wrong_session = nil

        local raw = capture()
        local model = modelProvider()
        if type(raw) == 'table' and raw.visual then model = raw.model or model end
        local sex = MBT.GenderModels[model]
        if wearingState and sex then
            setBaseline(MBT.Snapshot.VisualFromWearing(wearingState, sex))
        elseif nextContext.visual then
            setBaseline(nextContext.visual)
        else
            local visual = captureCanonical()
            setBaseline(visual)
        end
        return true
    end

    function coordinator:GetContext()
        if not context then return nil end
        return { session = context.session, revision = context.revision }
    end

    function coordinator:Pause(reason)
        pauses[reason or 'manual'] = true
        pending = nil
        candidateFingerprint = nil
        candidateSince = nil
    end

    function coordinator:Resume(reason, wearingState)
        pauses[reason or 'manual'] = nil
        if wearingState and context then
            local raw = capture()
            local model = modelProvider()
            if type(raw) == 'table' and raw.visual then model = raw.model or model end
            local sex = MBT.GenderModels[model]
            if sex then setBaseline(MBT.Snapshot.VisualFromWearing(wearingState, sex)) end
        end
    end

    function coordinator:BeginInternal(_reason, timeoutMs)
        nextToken = nextToken + 1
        internalTokens[nextToken] = now() + (timeoutMs or 3000)
        pending = nil
        candidateFingerprint = nil
        candidateSince = nil
        return nextToken
    end

    function coordinator:EndInternal(token, expectedState)
        internalTokens[token] = nil
        if expectedState then
            local visual = expectedState.Drawables and expectedState.Props and expectedState or nil
            if visual then setBaseline(visual) end
        end
    end

    function coordinator:ExpectInternalSlot(slotType, slotIndex, timeoutMs)
        expectedSlots[slotKey(slotType, slotIndex)] = now() + (timeoutMs or 3000)
    end

    function coordinator:SetRestoreProtection(active, wearingState)
        restoreActive = active == true
        if restoreActive then pending = nil end
        if wearingState and context then
            local raw = capture()
            local model = modelProvider()
            if type(raw) == 'table' and raw.visual then model = raw.model or model end
            local sex = MBT.GenderModels[model]
            if sex then setBaseline(MBT.Snapshot.VisualFromWearing(wearingState, sex)) end
        end
        if not restoreActive then
            candidateFingerprint = nil
            candidateSince = nil
        end
    end

    function coordinator:IsRestoreProtected()
        return restoreActive
    end

    function coordinator:Suppress(slotType, slotIndex, canonicalVisual)
        if suppressions[slotType] and type(canonicalVisual) == 'table' then
            suppressions[slotType][tonumber(slotIndex) or slotIndex] = {
                drawable = canonicalVisual.drawable,
                texture = canonicalVisual.texture or 0,
                palette = canonicalVisual.palette or 0,
            }
        end
    end

    function coordinator:RestoreSuppressed(slotType, slotIndex)
        if suppressions[slotType] then
            suppressions[slotType][tonumber(slotIndex) or slotIndex] = nil
        end
    end

    function coordinator:ForceInitialScan(delayMs)
        forceInitialAt = now() + (delayMs or 0)
        candidateFingerprint = nil
        candidateSince = nil
    end

    function coordinator:HandleAck(ack)
        if type(ack) ~= 'table' or not context or ack.session ~= context.session then return false end
        if not pending or ack.seq ~= pending.payload.seq then return false end
        pending = nil
        candidateFingerprint = nil
        candidateSince = nil
        retryAfter = now() + 500

        if ack.ok then
            context.revision = ack.revision
            if ack.visual then
                setBaseline(ack.visual)
            else
                acknowledgedFingerprint = ack.fingerprint
            end
            forceInitialAt = nil
            rejectionCount = 0
            return true
        end

        rejectionCount = rejectionCount + 1
        if ack.code == 'wrong_session' or ack.code == 'no_session' then
            context = nil
            pauses.wrong_session = true
            return false
        end
        if type(ack.revision) == 'number' then context.revision = ack.revision end
        if ack.visual then setBaseline(ack.visual) end
        return false
    end

    function coordinator:Tick()
        local at = now()
        cleanupExpiringGuards(at)
        if not context or next(pauses) or restoreActive or next(internalTokens) or at < retryAfter then return end
        if pending then
            if at - pending.sentAt >= (MBT.SnapshotAckTimeout or 2000) then
                send(pending.payload)
                pending.sentAt = at
            end
            return
        end

        local visual, model, fingerprint = captureCanonical()
        if not visual then return end
        local forceInitial = forceInitialAt and at >= forceInitialAt
        if not forceInitial and fingerprint == acknowledgedFingerprint then
            candidateFingerprint = nil
            candidateSince = nil
            return
        end
        if candidateFingerprint ~= fingerprint then
            candidateFingerprint = fingerprint
            candidateSince = at
            return
        end
        if not forceInitial and at - candidateSince < (MBT.SnapshotDebounce or 400) then return end
        if forceInitial and candidateSince and at - candidateSince < (MBT.SnapshotDebounce or 400) then return end

        nextSeq = nextSeq + 1
        local payload = {
            session = context.session,
            seq = nextSeq,
            baseRevision = context.revision,
            model = model,
            Drawables = visual.Drawables,
            Props = visual.Props,
        }
        if forceInitial then payload.initial = true end
        pending = { payload = payload, sentAt = at }
        send(payload)
    end

    return coordinator
end

MBT.SnapshotClient = SnapshotClient

if IsDuplicityVersion() then return end

local function capturePed()
    local ped = PlayerPedId()
    if not DoesEntityExist(ped) then return nil end
    local model = GetEntityModel(ped)
    if not MBT.GenderModels[model] then return nil end
    local visual = { Drawables = {}, Props = {} }
    for slotIndex in pairs(MBT.Drawables) do
        visual.Drawables[slotIndex] = {
            drawable = GetPedDrawableVariation(ped, slotIndex),
            texture = GetPedTextureVariation(ped, slotIndex),
            palette = GetPedPaletteVariation(ped, slotIndex),
        }
    end
    for slotIndex in pairs(MBT.Props) do
        visual.Props[slotIndex] = {
            drawable = GetPedPropIndex(ped, slotIndex),
            texture = GetPedPropTextureIndex(ped, slotIndex),
            palette = 0,
        }
    end
    return { model = model, visual = visual }
end

local production = SnapshotClient.New({
    now = GetGameTimer,
    capture = capturePed,
    model = function()
        local ped = PlayerPedId()
        return DoesEntityExist(ped) and GetEntityModel(ped) or nil
    end,
    send = function(payload)
        TriggerServerEvent('mbt_meta_clothes:submitSnapshot', payload)
    end,
})

local running = false

function SnapshotClient.SetContext(context, wearingState) return production:SetContext(context, wearingState) end
function SnapshotClient.GetContext() return production:GetContext() end
function SnapshotClient.Pause(reason) return production:Pause(reason) end
function SnapshotClient.Resume(reason, wearingState) return production:Resume(reason, wearingState) end
function SnapshotClient.BeginInternal(reason, timeoutMs) return production:BeginInternal(reason, timeoutMs) end
function SnapshotClient.EndInternal(token, expectedState) return production:EndInternal(token, expectedState) end
function SnapshotClient.ExpectInternalSlot(slotType, slotIndex, timeoutMs)
    return production:ExpectInternalSlot(slotType, slotIndex, timeoutMs)
end
function SnapshotClient.SetRestoreProtection(active, wearingState)
    return production:SetRestoreProtection(active, wearingState)
end
function SnapshotClient.Suppress(slotType, slotIndex, visual) return production:Suppress(slotType, slotIndex, visual) end
function SnapshotClient.RestoreSuppressed(slotType, slotIndex)
    return production:RestoreSuppressed(slotType, slotIndex)
end
function SnapshotClient.ForceInitialScan(delayMs) return production:ForceInitialScan(delayMs) end

function SnapshotClient.Start()
    if running then return end
    running = true
    production:Resume('startup')
    CreateThread(function()
        while running do
            production:Tick()
            Wait(production:IsRestoreProtected()
                and (MBT.SnapshotRestorePollInterval or 500)
                or (MBT.SnapshotPollInterval or 1000))
        end
    end)
end

RegisterNetEvent('mbt_meta_clothes:snapshotAck', function(ack)
    production:HandleAck(ack)
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then running = false end
end)
