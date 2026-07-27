local SnapshotServer = {}

local function integerAtLeast(value, minimum)
    return type(value) == 'number' and value == value and value % 1 == 0 and value >= minimum
end

local function copyAck(ack, code)
    local copied = {}
    for key, value in pairs(ack or {}) do copied[key] = value end
    if code then copied.code = code end
    return copied
end

local function boundedPayload(value, maxStringBytes)
    local seen = {}
    local nodes = 0
    local stringBytes = 0
    local failure = 'malformed'
    local function walk(current, depth)
        nodes = nodes + 1
        if nodes > 256 or depth > 6 then return false end
        local currentType = type(current)
        if currentType == 'table' then
            if seen[current] then return false end
            seen[current] = true
            for key, nested in pairs(current) do
                local keyType = type(key)
                if keyType ~= 'string' and keyType ~= 'number' then return false end
                if keyType == 'string' then
                    stringBytes = stringBytes + #key
                    if stringBytes > maxStringBytes then
                        failure = 'oversized'
                        return false
                    end
                end
                if not walk(nested, depth + 1) then return false end
            end
            seen[current] = nil
            return true
        end
        if currentType == 'string' then
            stringBytes = stringBytes + #current
            if stringBytes > maxStringBytes then failure = 'oversized' end
            return stringBytes <= maxStringBytes
        end
        return currentType == 'number' or currentType == 'boolean' or currentType == 'nil'
    end
    local valid = walk(value, 1)
    if valid then return true end
    return false, failure
end

function SnapshotServer.New(deps)
    assert(type(deps) == 'table', 'snapshot server dependencies are required')
    local playerState = assert(deps.PlayerState, 'PlayerState dependency is required')
    local schedule = assert(deps.schedule, 'schedule dependency is required')
    local encode = assert(deps.encode, 'encode dependency is required')
    local saveDelay = deps.saveDelay
    if saveDelay == nil then saveDelay = MBT.SnapshotWriteBehind or 5000 end
    local sessions = {}
    local generation = 0

    local coordinator = {}

    local function contextFor(src, state)
        if not state then return nil end
        return {
            session = state.session,
            revision = playerState.GetRevision(src),
        }
    end

    local function reject(src, state, payload, code)
        return {
            ok = false,
            code = code,
            session = state and state.session or nil,
            seq = type(payload) == 'table' and payload.seq or nil,
            revision = playerState.GetRevision(src),
        }
    end

    local function canonicalState(src, sex)
        local visual = MBT.Snapshot.VisualFromWearing(playerState.GetAll(src), sex)
        return visual, visual and MBT.Snapshot.Fingerprint(visual) or nil
    end

    local function remember(state, seq, fingerprint, ack)
        state.lastSeq = seq
        state.lastRequestFingerprint = fingerprint
        state.lastAck = copyAck(ack)
        return ack
    end

    local function scheduleSave(src, state)
        if saveDelay <= 0 then return end
        state.saveGeneration = state.saveGeneration + 1
        local expectedGeneration = state.saveGeneration
        local expectedSession = state.session
        schedule(saveDelay, function()
            local current = sessions[src]
            if not current or current.session ~= expectedSession
                or current.saveGeneration ~= expectedGeneration then return end
            playerState.Save(src)
        end)
    end

    function coordinator:Activate(src, identifier)
        if not identifier then return nil end
        local current = sessions[src]
        if current and current.identifier == identifier then
            return contextFor(src, current)
        end
        if current then current.saveGeneration = current.saveGeneration + 1 end

        generation = generation + 1
        local session = deps.newSession and deps.newSession(generation, src, identifier)
            or generation
        sessions[src] = {
            identifier = identifier,
            session = session,
            generation = generation,
            lastSeq = 0,
            lastRequestFingerprint = nil,
            lastAck = nil,
            saveGeneration = 0,
        }
        return contextFor(src, sessions[src])
    end

    function coordinator:GetContext(src)
        return contextFor(src, sessions[src])
    end

    function coordinator:Handle(src, payload)
        local state = sessions[src]
        if not state then return reject(src, nil, payload, 'no_session') end
        if type(payload) ~= 'table' then return reject(src, state, payload, 'malformed') end

        local identifier = playerState.GetIdentifier(src)
        local liveIdentifier = deps.getIdentifier and deps.getIdentifier(src) or nil
        local loaded = not playerState.IsLoaded or playerState.IsLoaded(src)
        if not loaded or not identifier or identifier ~= state.identifier
            or not liveIdentifier or liveIdentifier ~= state.identifier then
            state.saveGeneration = state.saveGeneration + 1
            sessions[src] = nil
            return reject(src, state, payload, 'wrong_session')
        end
        local payloadBounded, payloadReason = boundedPayload(payload, MBT.SnapshotMaxPayload or 16384)
        if not payloadBounded then
            return reject(src, state, payload, payloadReason)
        end

        local encodedOk, encoded = pcall(encode, payload)
        if not encodedOk or type(encoded) ~= 'string' then
            return reject(src, state, payload, 'malformed')
        end
        if #encoded > (MBT.SnapshotMaxPayload or 16384) then
            return reject(src, state, payload, 'oversized')
        end
        for key in pairs(payload) do
            if key ~= 'session' and key ~= 'seq' and key ~= 'baseRevision'
                and key ~= 'model' and key ~= 'Drawables' and key ~= 'Props'
                and key ~= 'initial' then
                return reject(src, state, payload, 'malformed')
            end
        end
        if payload.session ~= state.session then
            return reject(src, state, payload, 'wrong_session')
        end
        if not integerAtLeast(payload.seq, 1) or not integerAtLeast(payload.baseRevision, 0) then
            return reject(src, state, payload, 'malformed')
        end
        if payload.initial ~= nil and type(payload.initial) ~= 'boolean' then
            return reject(src, state, payload, 'malformed')
        end

        local sex = MBT.GenderModels[payload.model]
        if not sex then return reject(src, state, payload, 'unsupported_model') end
        local visual, reason = MBT.Snapshot.Canonicalize({
            Drawables = payload.Drawables,
            Props = payload.Props,
        }, payload.model)
        if not visual then return reject(src, state, payload, reason) end
        local requestFingerprint = table.concat({
            tostring(payload.session),
            tostring(payload.seq),
            tostring(payload.baseRevision),
            tostring(payload.model),
            payload.initial and '1' or '0',
            MBT.Snapshot.Fingerprint(visual),
        }, '#')

        if payload.seq < state.lastSeq then
            return reject(src, state, payload, 'stale_sequence')
        end
        if payload.seq == state.lastSeq then
            if requestFingerprint == state.lastRequestFingerprint and state.lastAck then
                return copyAck(state.lastAck, 'duplicate')
            end
            return reject(src, state, payload, 'sequence_conflict')
        end

        if payload.initial then
            if playerState.HasBaseline and playerState.HasBaseline(src) then
                return remember(state, payload.seq, requestFingerprint,
                    reject(src, state, payload, 'initial_not_allowed'))
            end
        end

        local current = playerState.GetAll(src) or { Drawables = {}, Props = {} }
        local nextState, changes, changed = MBT.Snapshot.Reconcile(current, visual, sex)
        local revision = playerState.GetRevision(src)
        if changed and payload.baseRevision ~= revision then
            local rebaseVisual, rebaseFingerprint = canonicalState(src, sex)
            local ack = reject(src, state, payload, 'stale_revision')
            ack.visual = rebaseVisual
            ack.fingerprint = rebaseFingerprint
            return remember(state, payload.seq, requestFingerprint, ack)
        end

        if changed then
            revision = playerState.CommitSnapshot(src, nextState, changes)
        end
        if changed or payload.initial then
            -- An initial snapshot is also the durable baseline when it matches
            -- an empty/default state. Persist it even when reconciliation is a
            -- no-op, otherwise a legitimate bare character is a DB miss again
            -- after every resource/server restart.
            scheduleSave(src, state)
        end
        if payload.initial and playerState.MarkBaseline then playerState.MarkBaseline(src) end
        local canonicalVisual, canonicalFingerprint = canonicalState(src, sex)
        return remember(state, payload.seq, requestFingerprint, {
            ok = true,
            code = changed and 'accepted' or 'no_change',
            session = state.session,
            seq = payload.seq,
            revision = revision,
            changed = changed,
            fingerprint = canonicalFingerprint,
            visual = canonicalVisual,
        })
    end

    function coordinator:CancelPendingSave(src)
        local state = sessions[src]
        if state then state.saveGeneration = state.saveGeneration + 1 end
    end

    function coordinator:Cleanup(src)
        local state = sessions[src]
        if state then state.saveGeneration = state.saveGeneration + 1 end
        sessions[src] = nil
    end

    function coordinator:OnRevisionChanged(_src, _revision)
        -- Context revisions are read directly from PlayerState. This hook exists
        -- so external mutations and snapshots share one authoritative clock.
    end

    return coordinator
end

local production = SnapshotServer.New({
    PlayerState = MBT.PlayerState,
    schedule = function(delay, callback) SetTimeout(delay, callback) end,
    encode = function(value) return json.encode(value) end,
    saveDelay = MBT.SnapshotWriteBehind,
    newSession = function(currentGeneration)
        return ('%d:%d:%d'):format(os.time(), GetGameTimer(), currentGeneration)
    end,
    getIdentifier = function(src)
        return getPlayerIdentifier and getPlayerIdentifier(src) or nil
    end,
})

function SnapshotServer.Activate(src, identifier) return production:Activate(src, identifier) end
function SnapshotServer.GetContext(src) return production:GetContext(src) end
function SnapshotServer.Handle(src, payload) return production:Handle(src, payload) end
function SnapshotServer.CancelPendingSave(src) return production:CancelPendingSave(src) end
function SnapshotServer.Cleanup(src) return production:Cleanup(src) end
function SnapshotServer.OnRevisionChanged(src, revision)
    return production:OnRevisionChanged(src, revision)
end

MBT.SnapshotServer = SnapshotServer
