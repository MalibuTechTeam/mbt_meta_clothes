MBT = MBT or {}
MBT.DressAdapters = MBT.DressAdapters or {}

local function failed(reason)
    return { ok = false, reason = reason }
end

function MBT.DressAdapters.NewOx(config)
    assert(type(config) == 'table', 'OX dress adapter config is required')
    assert(type(config.authority) == 'table', 'OX dress adapter authority is required')
    assert(type(config.restoreItem) == 'function', 'OX dress adapter restoreItem is required')

    local authority = config.authority
    local restoreItem = config.restoreItem
    local adapter = {}

    function adapter:CanUse(src, itemName, metadata)
        return authority:CanUse(src, itemName, metadata)
    end

    function adapter:CommitUsed(src, itemName, _, metadata)
        local result = authority:Commit(src, itemName, metadata)
        if result.ok then return result end

        local restored = restoreItem(src, itemName, 1, metadata)
        if not restored then
            return failed('rollback_failed')
        end
        return result
    end

    return adapter
end
function MBT.DressAdapters.NewQb(config)
    assert(type(config) == 'table', 'QB dress adapter config is required')
    assert(type(config.authority) == 'table', 'QB dress adapter authority is required')
    assert(type(config.getItemBySlot) == 'function', 'QB dress adapter getItemBySlot is required')
    assert(type(config.removeItem) == 'function', 'QB dress adapter removeItem is required')
    assert(type(config.restoreItem) == 'function', 'QB dress adapter restoreItem is required')

    local authority = config.authority
    local getItemBySlot = config.getItemBySlot
    local removeItem = config.removeItem
    local restoreItem = config.restoreItem
    local now = config.now or GetGameTimer
    local pendingBySource = {}
    local sequence = 0
    local readyTolerance = config.readyTolerance or 100
    local pendingLifetime = config.pendingLifetime or 15000
    local adapter = {}

    local function nextToken(src, timestamp)
        sequence = sequence + 1
        return ('%s:%s:%s'):format(src, timestamp, sequence)
    end

    function adapter:Begin(src, item, duration)
        if pendingBySource[src] then return failed('busy') end
        if type(item) ~= 'table' or type(item.name) ~= 'string' or not tonumber(item.slot) then
            return failed('invalid_item')
        end

        local metadata = item.info
        local allowed, reason, descriptor = authority:CanUse(src, item.name, metadata)
        if not allowed then return failed(reason) end

        local timestamp = now()
        duration = math.max(0, math.min(30000, tonumber(duration) or 0))
        local pending = {
            ok = true,
            token = nextToken(src, timestamp),
            itemName = item.name,
            slot = tonumber(item.slot),
            readyAt = timestamp + math.max(0, duration - readyTolerance),
            expiresAt = timestamp + duration + pendingLifetime,
            descriptor = descriptor,
        }
        pendingBySource[src] = pending
        return pending
    end

    function adapter:Complete(src, token)
        local pending = pendingBySource[src]
        if not pending or pending.token ~= token then return failed('invalid_request') end

        local timestamp = now()
        if timestamp < pending.readyAt then return failed('not_ready') end
        if timestamp > pending.expiresAt then
            pendingBySource[src] = nil
            return failed('expired')
        end

        local item = getItemBySlot(src, pending.slot)
        if type(item) ~= 'table' or item.name ~= pending.itemName then
            pendingBySource[src] = nil
            return failed('item_missing')
        end

        local allowed, reason = authority:CanUse(src, item.name, item.info)
        if not allowed then
            pendingBySource[src] = nil
            return failed(reason)
        end

        if not removeItem(src, item.name, 1, pending.slot) then
            pendingBySource[src] = nil
            return failed('remove_failed')
        end

        pendingBySource[src] = nil
        local result = authority:Commit(src, item.name, item.info)
        if result.ok then return result end

        local restored = restoreItem(src, item.name, 1, item.info, pending.slot)
        if not restored then return failed('rollback_failed') end
        return result
    end

    function adapter:Cancel(src, token)
        local pending = pendingBySource[src]
        if not pending or pending.token ~= token then return false end
        pendingBySource[src] = nil
        return true
    end

    function adapter:Cleanup(src)
        pendingBySource[src] = nil
    end

    return adapter
end
