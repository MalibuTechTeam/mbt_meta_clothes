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

function Assert.truthy(value, message)
    if not value then fail(message or 'expected truthy value') end
end

function Assert.same(expected, actual, message)
    if expected ~= actual then fail(message or 'expected identical table reference') end
end

local function fullVisual(sex)
    return assert(MBT.Snapshot.VisualFromWearing({ Drawables = {}, Props = {} }, sex))
end

local maleModel
for model, sex in pairs(MBT.GenderModels) do
    if sex == 'male' then maleModel = model break end
end

local cases = {
    {
        name = 'rejects missing managed slot',
        run = function()
            local visual = fullVisual('male')
            visual.Drawables[11] = nil
            local normalized, reason = MBT.Snapshot.Canonicalize(visual, maleModel)
            Assert.equal(nil, normalized)
            Assert.equal('missing_slot', reason)
        end,
    },
    {
        name = 'rejects extra slot and fields',
        run = function()
            local visual = fullVisual('male')
            visual.Drawables[99] = { drawable = 1, texture = 0, palette = 0 }
            Assert.equal('extra_slot', select(2, MBT.Snapshot.Canonicalize(visual, maleModel)))
            visual.Drawables[99] = nil
            visual.Drawables[11].item_name = 'forged'
            Assert.equal('extra_field', select(2, MBT.Snapshot.Canonicalize(visual, maleModel)))
        end,
    },
    {
        name = 'enforces numeric bounds',
        run = function()
            local visual = fullVisual('male')
            visual.Drawables[11].drawable = 4096
            Assert.equal('invalid_drawable', select(2, MBT.Snapshot.Canonicalize(visual, maleModel)))
            visual = fullVisual('male')
            visual.Props[0].drawable = -2
            Assert.equal('invalid_drawable', select(2, MBT.Snapshot.Canonicalize(visual, maleModel)))
            visual = fullVisual('male')
            visual.Drawables[11].texture = 1.5
            Assert.equal('invalid_texture', select(2, MBT.Snapshot.Canonicalize(visual, maleModel)))
        end,
    },
    {
        name = 'fingerprint is deterministic',
        run = function()
            local first = fullVisual('male')
            local second = { Props = {}, Drawables = {} }
            for index, slot in pairs(first.Props) do second.Props[index] = slot end
            for index, slot in pairs(first.Drawables) do second.Drawables[index] = slot end
            Assert.equal(MBT.Snapshot.Fingerprint(first), MBT.Snapshot.Fingerprint(second))
        end,
    },
    {
        name = 'normalizes configured default to absent wearing state',
        run = function()
            local visual = fullVisual('male')
            visual.Drawables[11] = { drawable = 15, texture = 7, palette = 2 }
            local normalized = assert(MBT.Snapshot.Canonicalize(visual, maleModel))
            local nextState = MBT.Snapshot.Reconcile({ Drawables = {}, Props = {} }, normalized, 'male')
            Assert.equal(nil, nextState.Drawables[11])
        end,
    },
    {
        name = 'preserves rich metadata when visual is unchanged',
        run = function()
            local rich = {
                index = 11,
                drawable = 100,
                texture = 2,
                palette = 0,
                item_name = 'jacket',
                last_worn_by = { { identifier = 'char1' } },
            }
            local current = { Drawables = { [11] = rich }, Props = {} }
            local visual = fullVisual('male')
            visual.Drawables[11] = { drawable = 100, texture = 2, palette = 0 }
            local nextState, changes, changed = MBT.Snapshot.Reconcile(current, visual, 'male')
            Assert.same(rich, nextState.Drawables[11])
            Assert.equal(0, #changes)
            Assert.equal(false, changed)
        end,
    },
    {
        name = 'sanitizes external metadata and reports changed slot',
        run = function()
            local visual = fullVisual('male')
            visual.Drawables[11] = { drawable = 101, texture = 3, palette = 1 }
            local normalized = assert(MBT.Snapshot.Canonicalize(visual, maleModel))
            local nextState, changes, changed = MBT.Snapshot.Reconcile({ Drawables = {}, Props = {} }, normalized, 'male')
            Assert.equal(true, changed)
            Assert.equal(1, #changes)
            Assert.equal(11, changes[1].slotIndex)
            Assert.equal('external', nextState.Drawables[11].provenance)
            Assert.equal(nil, nextState.Drawables[11].item_name)
        end,
    },
}

RegisterCommand('mbt_snapshot_selftest', function(source)
    if source ~= 0 then
        print('^1[mbt_meta_clothes] mbt_snapshot_selftest is server-console only.^0')
        return
    end

    local passed = 0
    for _, case in ipairs(cases) do
        local ok, reason = xpcall(case.run, debug.traceback)
        if not ok then
            print(('^1[mbt_meta_clothes][snapshot test] FAIL: %s\n%s^0'):format(case.name, reason))
            return
        end
        passed = passed + 1
    end
    print(('^2[mbt_meta_clothes][snapshot test] PASS: %d/%d cases^0'):format(passed, #cases))
end, true)
