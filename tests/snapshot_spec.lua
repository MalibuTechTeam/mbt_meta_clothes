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

local function snapshotServerFixture()
    local data = {}
    local revisions = {}
    local identifiers = {}
    local liveIdentifiers = {}
    local saves = 0
    local timers = {}
    local store = {
        GetRevision = function(src) return revisions[src] or 0 end,
        GetIdentifier = function(src) return identifiers[src] end,
        IsLoaded = function(src) return data[src] ~= false end,
        GetAll = function(src) return data[src] or { Drawables = {}, Props = {} } end,
        CommitSnapshot = function(src, nextState, changes)
            Assert.truthy(#changes > 0)
            data[src] = nextState
            revisions[src] = (revisions[src] or 0) + 1
            return revisions[src]
        end,
        Save = function() saves = saves + 1 end,
    }
    local coordinator = MBT.SnapshotServer.New({
        PlayerState = store,
        schedule = function(_, callback) timers[#timers + 1] = callback end,
        encode = function(value) return json.encode(value) end,
        saveDelay = 5000,
        newSession = function(generation) return generation end,
        getIdentifier = function(src) return liveIdentifiers[src] end,
    })
    return {
        coordinator = coordinator,
        setIdentifier = function(src, identifier)
            identifiers[src] = identifier
            liveIdentifiers[src] = identifier
        end,
        setLiveIdentifier = function(src, identifier) liveIdentifiers[src] = identifier end,
        timers = timers,
        saveCount = function() return saves end,
    }
end

local function snapshotPayload(context, seq, visual, baseRevision)
    visual = visual or fullVisual('male')
    return {
        session = context.session,
        seq = seq,
        baseRevision = baseRevision == nil and context.revision or baseRevision,
        model = maleModel,
        Drawables = visual.Drawables,
        Props = visual.Props,
    }
end

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
            visual = fullVisual('male')
            visual.Drawables['11'] = visual.Drawables[11]
            Assert.equal('duplicate_slot', select(2, MBT.Snapshot.Canonicalize(visual, maleModel)))
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
    {
        name = 'tracks authoritative revisions and preserves rich metadata',
        run = function()
            local src = -41001
            MBT.PlayerState.Cleanup(src, true)
            MBT.PlayerState.InitPlayer(src)
            Assert.equal(0, MBT.PlayerState.GetRevision(src))
            local rich = {
                index = 11,
                drawable = 100,
                texture = 2,
                palette = 0,
                item_name = 'jacket',
                dna = { sample = 'trusted' },
            }
            MBT.PlayerState.SetSlot(src, 'Drawables', 11, rich)
            Assert.equal(1, MBT.PlayerState.GetRevision(src))
            local changed, revision = MBT.PlayerState.UpdateSlotVisual(src, 'Drawables', 11, {
                drawable = 101,
                texture = 0,
                palette = 0,
            })
            Assert.equal(true, changed)
            Assert.equal(2, revision)
            local updated = MBT.PlayerState.GetSlot(src, 'Drawables', 11)
            Assert.equal('jacket', updated.item_name)
            Assert.same(rich.dna, updated.dna)
            MBT.PlayerState.Cleanup(src, true)
        end,
    },
    {
        name = 'commits a multi-slot snapshot with one revision',
        run = function()
            local src = -41002
            MBT.PlayerState.Cleanup(src, true)
            MBT.PlayerState.InitPlayer(src)
            local visual = fullVisual('male')
            visual.Drawables[11] = { drawable = 101, texture = 0, palette = 0 }
            visual.Props[0] = { drawable = 5, texture = 1, palette = 0 }
            local nextState, changes = MBT.Snapshot.Reconcile(MBT.PlayerState.GetAll(src), visual, 'male')
            Assert.equal(2, #changes)
            Assert.equal(1, MBT.PlayerState.CommitSnapshot(src, nextState, changes))
            Assert.equal(1, MBT.PlayerState.GetRevision(src))
            Assert.equal(1, MBT.PlayerState.CommitSnapshot(src, nextState, {}))
            Assert.equal(1, MBT.PlayerState.GetRevision(src))
            MBT.PlayerState.Cleanup(src, true)
        end,
    },
    {
        name = 'accepts, acknowledges, and deduplicates a snapshot',
        run = function()
            local fixture = snapshotServerFixture()
            local src = 41
            fixture.setIdentifier(src, 'char1:license')
            local context = fixture.coordinator:Activate(src, 'char1:license')
            local visual = fullVisual('male')
            visual.Drawables[11] = { drawable = 101, texture = 0, palette = 0 }
            local payload = snapshotPayload(context, 1, visual)
            local ack = fixture.coordinator:Handle(src, payload)
            Assert.equal(true, ack.ok)
            Assert.equal('accepted', ack.code)
            Assert.equal(1, ack.revision)
            Assert.truthy(type(ack.fingerprint) == 'string')
            Assert.truthy(type(ack.visual) == 'table')
            local duplicate = fixture.coordinator:Handle(src, payload)
            Assert.equal(true, duplicate.ok)
            Assert.equal('duplicate', duplicate.code)
            Assert.equal(1, duplicate.revision)
            Assert.equal(1, #fixture.timers)
            fixture.timers[1]()
            Assert.equal(1, fixture.saveCount())
        end,
    },
    {
        name = 'rejects stale ordering, revision, and wrong character session',
        run = function()
            local fixture = snapshotServerFixture()
            local src = 42
            fixture.setIdentifier(src, 'char1')
            local context = fixture.coordinator:Activate(src, 'char1')
            local visual = fullVisual('male')
            visual.Drawables[11] = { drawable = 101, texture = 0, palette = 0 }
            local stale = fixture.coordinator:Handle(src, snapshotPayload(context, 1, visual, 9))
            Assert.equal(false, stale.ok)
            Assert.equal('stale_revision', stale.code)
            Assert.truthy(type(stale.fingerprint) == 'string')
            Assert.truthy(type(stale.visual) == 'table')
            local acceptedNoOp = fixture.coordinator:Handle(src, snapshotPayload(context, 2, fullVisual('male'), 0))
            Assert.equal(true, acceptedNoOp.ok)
            local lower = fixture.coordinator:Handle(src, snapshotPayload(context, 1, visual, 0))
            Assert.equal('stale_sequence', lower.code)
            local rotated = fixture.coordinator:Activate(src, 'char2')
            fixture.setIdentifier(src, 'char2')
            Assert.truthy(rotated.session ~= context.session)
            local wrong = fixture.coordinator:Handle(src, snapshotPayload(context, 2, visual, 0))
            Assert.equal('wrong_session', wrong.code)
        end,
    },
    {
        name = 'rejects malformed and oversized payloads',
        run = function()
            local fixture = snapshotServerFixture()
            local src = 44
            fixture.setIdentifier(src, 'char1')
            local context = fixture.coordinator:Activate(src, 'char1')
            local malformed = snapshotPayload(context, 1)
            malformed.forged = true
            Assert.equal('malformed', fixture.coordinator:Handle(src, malformed).code)
            local oversized = snapshotPayload(context, 1)
            oversized.Drawables[11].padding = string.rep('x', (MBT.SnapshotMaxPayload or 16384) + 1)
            Assert.equal('oversized', fixture.coordinator:Handle(src, oversized).code)
        end,
    },
    {
        name = 'acknowledges no-op and cancels stale write-behind timers',
        run = function()
            local fixture = snapshotServerFixture()
            local src = 43
            fixture.setIdentifier(src, 'char1')
            local context = fixture.coordinator:Activate(src, 'char1')
            local noChange = fixture.coordinator:Handle(src, snapshotPayload(context, 1))
            Assert.equal(true, noChange.ok)
            Assert.equal('no_change', noChange.code)
            Assert.equal(0, #fixture.timers)

            local changed = fullVisual('male')
            changed.Props[0] = { drawable = 2, texture = 0, palette = 0 }
            fixture.coordinator:Handle(src, snapshotPayload(context, 2, changed))
            Assert.equal(1, #fixture.timers)
            fixture.coordinator:CancelPendingSave(src)
            fixture.timers[1]()
            Assert.equal(0, fixture.saveCount())
        end,
    },
    {
        name = 'invalidates session when the authoritative identifier drifts',
        run = function()
            local fixture = snapshotServerFixture()
            local src = 45
            fixture.setIdentifier(src, 'char1')
            local context = fixture.coordinator:Activate(src, 'char1')
            fixture.setLiveIdentifier(src, 'char2')
            local ack = fixture.coordinator:Handle(src, snapshotPayload(context, 1))
            Assert.equal(false, ack.ok)
            Assert.equal('wrong_session', ack.code)
            Assert.equal(nil, fixture.coordinator:GetContext(src))
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
