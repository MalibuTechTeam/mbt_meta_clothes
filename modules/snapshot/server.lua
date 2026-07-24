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

        local encodedOk, encoded = pcall(encode, payload)
        if not encodedOk or type(encoded) ~= 'string' then
            return reject(src, state, payload, 'malformed')
        end
        if #encoded > (MBT.SnapshotMaxPayload or 16384) then
            return reject(src, state, payload, 'oversized')
        end
        for key in pairs(payload) do
            if key ~= 'session' and key ~= 'seq' and key ~= 'baseRevision'
                and key ~= 'model' and key ~= 'visual' and key ~= 'initial' then
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
        local visual, reason = MBT.Snapshot.Canonicalize(payload.visual, payload.model)
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

        local current = playerState.GetAll(src) or { Drawables = {}, Props = {} }
        local nextState, changes, changed = MBT.Snapshot.Reconcile(current, visual, sex)
        local revision = playerState.GetRevision(src)
        if changed and payload.baseRevision ~= revision then
            return remember(state, payload.seq, requestFingerprint,
                reject(src, state, payload, 'stale_revision'))
        end

        if changed then
            revision = playerState.CommitSnapshot(src, nextState, changes)
            scheduleSave(src, state)
        end
        return remember(state, payload.seq, requestFingerprint, {
            ok = true,
            code = changed and 'accepted' or 'no_change',
            session = state.session,
            seq = payload.seq,
            revision = revision,
            changed = changed,
        })
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
})

function SnapshotServer.Activate(src, identifier) return production:Activate(src, identifier) end
function SnapshotServer.GetContext(src) return production:GetContext(src) end
function SnapshotServer.Handle(src, payload) return production:Handle(src, payload) end
function SnapshotServer.Cleanup(src) return production:Cleanup(src) end
function SnapshotServer.OnRevisionChanged(src, revision)
    return production:OnRevisionChanged(src, revision)
end

MBT.SnapshotServer = SnapshotServer
