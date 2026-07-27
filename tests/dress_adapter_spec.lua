local function fail(message)
    error(message, 3)
end

local Assert = {}

function Assert.equal(expected, actual, message)
    if expected ~= actual then
        fail(message or ('expected %s, got %s'):format(tostring(expected), tostring(actual)))
    end
end

local function authorityFixture(options)
    options = options or {}
    local committed = {}
    return {
        CanUse = function(_, src, itemName, metadata)
            if options.rejectPreflight then return false, options.rejectPreflight end
            return true, nil, {
                src = src,
                itemName = itemName,
                metadata = metadata,
                kind = metadata.type,
            }
        end,
        Commit = function(_, src, itemName, metadata)
            if options.rejectCommit then return { ok = false, reason = options.rejectCommit } end
            committed[#committed + 1] = { src = src, itemName = itemName, metadata = metadata }
            return { ok = true }
        end,
        committed = committed,
    }
end

local cases = {
    {
        name = 'ox preflight rejection cancels inventory use',
        run = function()
            local adapter = MBT.DressAdapters.NewOx({
                authority = authorityFixture({ rejectPreflight = 'slot_occupied' }),
                restoreItem = function() fail('restore must not run before consumption') end,
            })

            local ok, reason = adapter:CanUse(4, 'jacket', { type = 'Drawable' })
            Assert.equal(false, ok)
            Assert.equal('slot_occupied', reason)
        end,
    },
    {
        name = 'ox post-consumption failure restores exact authoritative item',
        run = function()
            local restored
            local metadata = { index = 11, drawable = 29, type = 'Drawable', serial = 'abc' }
            local adapter = MBT.DressAdapters.NewOx({
                authority = authorityFixture({ rejectCommit = 'slot_occupied' }),
                restoreItem = function(src, itemName, count, restoredMetadata)
                    restored = { src, itemName, count, restoredMetadata }
                    return true
                end,
            })

            local result = adapter:CommitUsed(4, 'designer_jacket', 9, metadata)
            Assert.equal(false, result.ok)
            Assert.equal('slot_occupied', result.reason)
            Assert.equal(4, restored[1])
            Assert.equal('designer_jacket', restored[2])
            Assert.equal(1, restored[3])
            Assert.equal('abc', restored[4].serial)
        end,
    },
    {
        name = 'qb completion consumes the exact current slot before commit',
        run = function()
            local now = 1000
            local removed
            local currentItem = {
                name = 'designer_jacket',
                slot = 7,
                info = { index = 11, drawable = 29, type = 'Drawable', serial = 'current' },
            }
            local authority = authorityFixture()
            local adapter = MBT.DressAdapters.NewQb({
                authority = authority,
                now = function() return now end,
                getItemBySlot = function(src, slot)
                    Assert.equal(4, src)
                    Assert.equal(7, slot)
                    return currentItem
                end,
                removeItem = function(src, itemName, count, slot)
                    removed = { src, itemName, count, slot }
                    return true
                end,
                restoreItem = function() fail('successful commit must not restore') end,
            })
            local pending = adapter:Begin(4, currentItem, 1200)
            now = 2200
            local result = adapter:Complete(4, pending.token)

            Assert.equal(true, result.ok, result.reason)
            Assert.equal(4, removed[1])
            Assert.equal('designer_jacket', removed[2])
            Assert.equal(1, removed[3])
            Assert.equal(7, removed[4])
            Assert.equal('current', authority.committed[1].metadata.serial)
        end,
    },
    {
        name = 'qb rejects forged or premature completion without consuming',
        run = function()
            local now = 5000
            local removals = 0
            local item = {
                name = 'hat',
                slot = 2,
                info = { index = 0, drawable = 4, type = 'Prop' },
            }
            local adapter = MBT.DressAdapters.NewQb({
                authority = authorityFixture(),
                now = function() return now end,
                getItemBySlot = function() return item end,
                removeItem = function() removals = removals + 1 return true end,
                restoreItem = function() return true end,
            })
            local pending = adapter:Begin(4, item, 1000)

            local forged = adapter:Complete(4, 'forged')
            local early = adapter:Complete(4, pending.token)
            Assert.equal(false, forged.ok)
            Assert.equal('invalid_request', forged.reason)
            Assert.equal(false, early.ok)
            Assert.equal('not_ready', early.reason)
            Assert.equal(0, removals)
        end,
    },
    {
        name = 'qb cancellation invalidates pending use',
        run = function()
            local now = 9000
            local item = {
                name = 'shoes',
                slot = 5,
                info = { index = 6, drawable = 12, type = 'Drawable' },
            }
            local adapter = MBT.DressAdapters.NewQb({
                authority = authorityFixture(),
                now = function() return now end,
                getItemBySlot = function() return item end,
                removeItem = function() fail('cancelled item must not be removed') end,
                restoreItem = function() return true end,
            })
            local pending = adapter:Begin(4, item, 1000)

            Assert.equal(true, adapter:Cancel(4, pending.token))
            now = 12000
            local result = adapter:Complete(4, pending.token)
            Assert.equal(false, result.ok)
            Assert.equal('invalid_request', result.reason)
        end,
    },
}

local function run()
    local passed = 0
    for _, case in ipairs(cases) do
        local ok, reason = xpcall(case.run, debug.traceback)
        if not ok then error(('FAIL: %s\n%s'):format(case.name, reason), 0) end
        passed = passed + 1
    end
    return passed
end

if RegisterCommand then
    if MBT.Debug then
        RegisterCommand('mbt_dress_adapter_selftest', function(source)
            if source ~= 0 then
                print('^1[mbt_meta_clothes] mbt_dress_adapter_selftest is server-console only.^0')
                return
            end

            local ok, result = xpcall(run, debug.traceback)
            if not ok then
                print(('^1[mbt_meta_clothes][dress adapter test] %s^0'):format(result))
                return
            end
            print(('^2[mbt_meta_clothes][dress adapter test] PASS: %d/%d cases^0'):format(result, #cases))
        end, true)
    end
else
    MBT = MBT or {}
    dofile('modules/bridge/inventory/dress_adapters.lua')
    local passed = run()
    print(('PASS: %d/%d cases'):format(passed, #cases))
end
