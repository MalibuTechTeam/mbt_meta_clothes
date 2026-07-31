MBT.PedVisibility = MBT.PedVisibility or {}

MBT.PedVisibility.ResourceRestart = 'resource_restart'

--- Return whether this resource owns the PED hide/reveal transition.
--- Hot recovery preserves alpha chosen by the game/spawn stack; real spawn
--- and character transitions keep the guarded visibility lifecycle.
function MBT.PedVisibility.ShouldObscure(lifecycle)
    return lifecycle ~= MBT.PedVisibility.ResourceRestart
end

function MBT.PedVisibility.New(deps)
    deps = deps or {}
    local schedule = assert(deps.schedule, 'ped visibility scheduler is required')
    local hide = assert(deps.hide, 'ped visibility hide callback is required')
    local reveal = assert(deps.reveal, 'ped visibility reveal callback is required')
    local retryDelay = deps.retryDelay or 250
    local coordinator = {}
    local generation = 0
    local waiting = false
    local pendingReveal

    --- Reveal transactionally. A reveal that could not run — the PED does not
    --- exist yet — must never consume the transition: committing it anyway
    --- burns the watchdog and leaves a hidden PED with no owner left to reveal
    --- it. Keep the generation and retry until the PED exists, a newer Begin
    --- takes over, or the transition is cancelled.
    local function attemptReveal(reason, watchdog, commit)
        pendingReveal = nil
        if reveal(reason, watchdog) then
            if commit then commit() end
            return true
        end

        local ticket = { generation = generation }
        pendingReveal = ticket
        schedule(retryDelay, function()
            if pendingReveal ~= ticket or ticket.generation ~= generation then return end
            attemptReveal(reason, watchdog, commit)
        end)
        return false
    end

    function coordinator:Begin(reason, timeoutMs)
        generation = generation + 1
        pendingReveal = nil
        local current = generation
        waiting = true
        hide(reason)
        schedule(timeoutMs or 5000, function()
            if current ~= generation or not waiting then return end
            attemptReveal(('watchdog:%s'):format(tostring(reason or 'unknown')), true, function()
                waiting = false
            end)
        end)
        return current
    end

    --- @return boolean revealed True only once the PED was actually revealed
    --- @return boolean wasWaiting True when a guarded transition was still open
    function coordinator:Complete(reason)
        local wasWaiting = waiting
        local revealed = attemptReveal(reason or 'complete', false, function()
            generation = generation + 1
            waiting = false
        end)
        return revealed, wasWaiting
    end

    function coordinator:Cancel()
        generation = generation + 1
        waiting = false
        pendingReveal = nil
    end

    return coordinator
end
