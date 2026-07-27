MBT = MBT or {}
MBT.StealAuthority = MBT.StealAuthority or {}

local function validPositiveInteger(value)
    return type(value) == 'number'
        and value == math.floor(value)
        and value > 0
        and value <= 2147483647
end

function MBT.StealAuthority.New(config)
    assert(type(config) == 'table', 'steal authority config is required')
    assert(type(config.now) == 'function', 'steal authority clock is required')
    assert(type(config.validateBegin) == 'function', 'steal begin validator is required')
    assert(type(config.validateComplete) == 'function', 'steal complete validator is required')
    assert(type(config.normalizeSelections) == 'function', 'steal selection normalizer is required')
    assert(type(config.buildAllSelections) == 'function', 'steal all selector is required')
    assert(type(config.processSelections) == 'function', 'steal processor is required')

    local profiles = config.profiles or {}
    local graceDuration = math.max(1000, tonumber(config.graceDuration) or 10000)
    local sessions = {}
    local targetOwners = {}
    local sequence = 0
    local runtime = {}

    local function releaseSession(src)
        local session = sessions[src]
        if not session then return nil end
        sessions[src] = nil
        if targetOwners[session.target] == src then targetOwners[session.target] = nil end
        return session
    end

    local function activeSession(src, now)
        local session = sessions[src]
        if not session then return nil end
        if now - session.startedAt > session.expiresAfter then
            releaseSession(src)
            return nil
        end
        return session
    end

    local function nextToken(src, now)
        sequence = sequence >= 2147483647 and 1 or sequence + 1
        return ('%s:%s:%s'):format(src, now, sequence)
    end

    local function resolveSelections(mode, target, requested)
        local selections = mode == 'all' and config.buildAllSelections(target) or requested
        local normalized = config.normalizeSelections(selections)
        if not normalized or #normalized == 0 then return nil end
        if mode == 'single' and #normalized ~= 1 then return nil end
        return normalized
    end

    local function resolveProfile(mode, stance, selections)
        if stance ~= 'standing' and stance ~= 'down' then return nil end
        local key
        if mode == 'single' then
            if stance == 'down' then
                key = 'target_down'
            elseif config.isLowSelection and config.isLowSelection(selections[1]) then
                key = 'standing_low'
            else
                key = 'standing_high'
            end
        elseif mode == 'batch' or mode == 'all' then
            key = stance == 'down' and 'steal_all_down' or 'steal_all'
        end

        local profile = key and profiles[key]
        if not profile then return nil end
        local animationDuration = tonumber(profile.duration)
        local progressDuration = tonumber(mode == 'single'
            and config.singleProgressDuration
            or config.batchProgressDuration)
        if not animationDuration or animationDuration < 1 or not progressDuration or progressDuration < 1 then
            return nil
        end
        return key, animationDuration, progressDuration
    end

    function runtime:Begin(src, payload)
        if type(payload) ~= 'table' or not validPositiveInteger(payload.requestId) then
            return { ok = false, reason = 'invalid_request' }
        end

        local target = tonumber(payload.targetServerId)
        if not target or target ~= math.floor(target) or target <= 0 or target == src then
            return { ok = false, requestId = payload.requestId, reason = 'invalid_target' }
        end
        if payload.mode ~= 'single' and payload.mode ~= 'batch' and payload.mode ~= 'all' then
            return { ok = false, requestId = payload.requestId, reason = 'invalid_request' }
        end
        if not config.validateBegin(src, target) then
            return { ok = false, requestId = payload.requestId, reason = 'not_allowed' }
        end

        local selections = resolveSelections(payload.mode, target, payload.selections)
        if not selections then
            return { ok = false, requestId = payload.requestId, reason = 'nothing_to_steal' }
        end
        local profileKey, animationDuration, progressDuration = resolveProfile(
            payload.mode,
            payload.stance,
            selections
        )
        if not profileKey then
            return { ok = false, requestId = payload.requestId, reason = 'invalid_request' }
        end

        local now = config.now()
        if activeSession(src, now) then
            return { ok = false, requestId = payload.requestId, reason = 'busy' }
        end
        local targetOwner = targetOwners[target]
        if targetOwner and activeSession(targetOwner, now) then
            return { ok = false, requestId = payload.requestId, reason = 'target_busy' }
        end
        targetOwners[target] = nil

        local minimumDuration = progressDuration + animationDuration
        local token = nextToken(src, now)
        sessions[src] = {
            token = token,
            target = target,
            selections = selections,
            startedAt = now,
            minimumDuration = minimumDuration,
            expiresAfter = minimumDuration + graceDuration,
        }
        targetOwners[target] = src

        return {
            ok = true,
            requestId = payload.requestId,
            token = token,
            targetServerId = target,
            progressDuration = progressDuration,
            animationDuration = animationDuration,
            thiefAnimKey = profileKey,
            victimAnimKey = payload.stance == 'down' and 'victim_down' or 'victim_stand',
            victimDuration = minimumDuration,
        }
    end

    function runtime:Complete(src, token)
        local session = sessions[src]
        if type(token) ~= 'string' or not session or session.token ~= token then
            return { ok = false, reason = 'invalid_token' }
        end

        local elapsed = config.now() - session.startedAt
        if elapsed < session.minimumDuration then
            return { ok = false, reason = 'early_complete' }
        end
        if elapsed > session.expiresAfter then
            releaseSession(src)
            return { ok = false, reason = 'expired_token' }
        end

        -- Consume before any external inventory call so replay and reentrancy
        -- fail closed even if a dependency raises or yields unexpectedly.
        releaseSession(src)
        if not config.validateComplete(src, session.target) then
            return { ok = false, reason = 'not_allowed' }
        end

        local processed, summary = xpcall(function()
            return config.processSelections(src, session.target, session.selections)
        end, debug.traceback)
        if not processed then
            if config.log then config.log('steal transfer exception', summary) end
            return { ok = false, reason = 'internal_error' }
        end
        if not summary or (summary.succeeded or 0) == 0 then
            return { ok = false, reason = summary and summary.lastReason or 'transfer_failed' }
        end
        return { ok = true, summary = summary }
    end

    function runtime:Cancel(src, token)
        local session = sessions[src]
        if type(token) ~= 'string' or not session or session.token ~= token then return nil end
        releaseSession(src)
        return session.target
    end

    function runtime:CleanupSource(src)
        releaseSession(src)
        for thief, session in pairs(sessions) do
            if session.target == src then releaseSession(thief) end
        end
    end

    return runtime
end
