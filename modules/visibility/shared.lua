MBT.PedVisibility = MBT.PedVisibility or {}

function MBT.PedVisibility.New(deps)
    deps = deps or {}
    local schedule = assert(deps.schedule, 'ped visibility scheduler is required')
    local hide = assert(deps.hide, 'ped visibility hide callback is required')
    local reveal = assert(deps.reveal, 'ped visibility reveal callback is required')
    local coordinator = {}
    local generation = 0
    local waiting = false

    function coordinator:Begin(reason, timeoutMs)
        generation = generation + 1
        local current = generation
        waiting = true
        hide(reason)
        schedule(timeoutMs or 5000, function()
            if current ~= generation or not waiting then return end
            waiting = false
            reveal(('watchdog:%s'):format(tostring(reason or 'unknown')), true)
        end)
        return current
    end

    function coordinator:Complete(reason)
        generation = generation + 1
        local wasWaiting = waiting
        waiting = false
        reveal(reason or 'complete', false)
        return wasWaiting
    end

    function coordinator:Pulse(expectedGeneration)
        if not waiting or expectedGeneration ~= generation then return false end
        hide()
        return true
    end

    function coordinator:Cancel()
        generation = generation + 1
        waiting = false
    end

    return coordinator
end
