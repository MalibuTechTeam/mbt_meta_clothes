if not MBT.Debug then return end

local function fail(message)
    error(message, 3)
end

local Assert = {}

function Assert.equal(expected, actual, message)
    if expected ~= actual then
        fail(message or ('expected %s, got %s'):format(tostring(expected), tostring(actual)))
    end
end

local function payload(receiver, item_name, metadata)
    return {
        receiver = receiver,
        itemName = item_name,
        count = 1,
        metadata = metadata or {},
    }
end

local cases = {
    {
        name = 'add failure never commits authoritative state',
        run = function()
            local committed = 0
            local coordinator = MBT.GiveItems.New({
                addItem = function() return false, 'inventory_full' end,
                log = function() end,
            })
            local result = coordinator:Transfer('7:Drawables:11', function()
                return payload(7, 'jacket', { dna = 'kept' })
            end, function()
                committed = committed + 1
                return true
            end)

            Assert.equal(false, result.ok)
            Assert.equal('inventory_full', result.reason)
            Assert.equal(0, committed)
        end,
    },
    {
        name = 'successful add commits exactly once',
        run = function()
            local added, committed = 0, 0
            local coordinator = MBT.GiveItems.New({
                addItem = function(_, item_name, count, metadata)
                    added = added + 1
                    Assert.equal('jacket', item_name)
                    Assert.equal(1, count)
                    Assert.equal('kept', metadata.dna)
                    return true
                end,
                log = function() end,
            })
            local result = coordinator:Transfer('7:Drawables:11', function()
                return payload(7, 'jacket', { dna = 'kept' })
            end, function()
                committed = committed + 1
                return true, { slotType = 'Drawables', slotIndex = 11 }
            end)

            Assert.equal(true, result.ok)
            Assert.equal(1, added)
            Assert.equal(1, committed)
            Assert.equal(11, result.committed.slotIndex)
        end,
    },
    {
        name = 'same lock rejects a reentrant transfer',
        run = function()
            local coordinator
            local nested
            coordinator = MBT.GiveItems.New({
                addItem = function()
                    nested = coordinator:Transfer('8:Props:0', function()
                        return payload(8, 'hat')
                    end, function()
                        return true
                    end)
                    return true
                end,
                log = function() end,
            })

            local result = coordinator:Transfer('8:Props:0', function()
                return payload(8, 'hat')
            end, function()
                return true
            end)

            Assert.equal(true, result.ok)
            Assert.equal(false, nested.ok)
            Assert.equal('busy', nested.reason)
        end,
    },
    {
        name = 'dependency exception releases the lock',
        run = function()
            local should_throw = true
            local coordinator = MBT.GiveItems.New({
                addItem = function()
                    if should_throw then error('inventory exploded') end
                    return true
                end,
                log = function() end,
            })
            local function build()
                return payload(9, 'watch')
            end

            local failed = coordinator:Transfer('9:Props:6', build, function() return true end)
            should_throw = false
            local retried = coordinator:Transfer('9:Props:6', build, function() return true end)

            Assert.equal(false, failed.ok)
            Assert.equal('internal_error', failed.reason)
            Assert.equal(true, retried.ok)
        end,
    },
    {
        name = 'cleanup releases every lock owned by a source',
        run = function()
            local coordinator
            local nested
            coordinator = MBT.GiveItems.New({
                addItem = function()
                    coordinator:CleanupSource(10)
                    nested = coordinator:Transfer('10:Drawables:4', function()
                        return payload(10, 'trousers')
                    end, function()
                        return true
                    end)
                    return true
                end,
                log = function() end,
            })

            coordinator:Transfer('10:Drawables:4', function()
                return payload(10, 'trousers')
            end, function()
                return true
            end)

            Assert.equal(true, nested.ok)
        end,
    },
    {
        name = 'normalizes inventory add results',
        run = function()
            local ok, reason = MBT.GiveItems.NormalizeAddResult(false, 'invalid_item')
            Assert.equal(false, ok)
            Assert.equal('invalid_item', reason)

            ok, reason = MBT.GiveItems.NormalizeAddResult(nil, nil)
            Assert.equal(false, ok)
            Assert.equal('add_failed', reason)

            ok, reason = MBT.GiveItems.NormalizeAddResult(true, { slot = 4 })
            Assert.equal(true, ok)
            Assert.equal(nil, reason)
        end,
    },
    {
        name = 'custom inventory callback fails closed',
        run = function()
            local ok, reason = MBT.GiveItems.CallCustom(nil, 12, 'hat', 1, {})
            Assert.equal(false, ok)
            Assert.equal('unsupported_inventory', reason)

            ok, reason = MBT.GiveItems.CallCustom(function()
                error('custom exploded')
            end, 12, 'hat', 1, {})
            Assert.equal(false, ok)
            Assert.equal('custom_error', reason)

            ok, reason = MBT.GiveItems.CallCustom(function()
                return nil
            end, 12, 'hat', 1, {})
            Assert.equal(false, ok)
            Assert.equal('add_failed', reason)

            ok, reason = MBT.GiveItems.CallCustom(function(src, name, count, metadata)
                Assert.equal(12, src)
                Assert.equal('hat', name)
                Assert.equal(1, count)
                Assert.equal('male', metadata.sex)
                return true
            end, 12, 'hat', 1, { sex = 'male' })
            Assert.equal(true, ok)
            Assert.equal(nil, reason)
        end,
    },
}

RegisterCommand('mbt_inventory_return_selftest', function(source)
    if source ~= 0 then
        print('^1[mbt_meta_clothes] mbt_inventory_return_selftest is server-console only.^0')
        return
    end

    local passed = 0
    for _, case in ipairs(cases) do
        local ok, reason = xpcall(case.run, debug.traceback)
        if not ok then
            print(('^1[mbt_meta_clothes][inventory return test] FAIL: %s\n%s^0'):format(case.name, reason))
            return
        end
        passed = passed + 1
    end
    print(('^2[mbt_meta_clothes][inventory return test] PASS: %d/%d cases^0'):format(passed, #cases))
end, true)
