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
local femaleModel

local function snapshotServerFixture()
    local data = {}
    local revisions = {}
    local identifiers = {}
    local liveIdentifiers = {}
    local baselines = {}
    local saves = 0
    local timers = {}
    local store = {
        GetRevision = function(src) return revisions[src] or 0 end,
        GetIdentifier = function(src) return identifiers[src] end,
        IsLoaded = function(src) return data[src] ~= false end,
        HasBaseline = function(src) return baselines[src] == true end,
        MarkBaseline = function(src) baselines[src] = true end,
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

local function snapshotClientFixture()
    local fakeNow = 0
    local current = fullVisual('male')
    local currentModel = maleModel
    local sent = {}
    local enforced = {}
    local initialAcknowledgements = {}
    local client = MBT.SnapshotClient.New({
        now = function() return fakeNow end,
        capture = function() return current end,
        model = function() return currentModel end,
        send = function(payload) sent[#sent + 1] = payload end,
        enforce = function(target) enforced[#enforced + 1] = target end,
        onInitialAcknowledged = function(ack)
            initialAcknowledgements[#initialAcknowledgements + 1] = ack
        end,
    })
    return {
        client = client,
        sent = sent,
        enforced = enforced,
        initialAcknowledgements = initialAcknowledgements,
        visual = function() return current end,
        setVisual = function(visual) current = visual end,
        setModel = function(model) currentModel = model end,
        advance = function(ms) fakeNow = fakeNow + ms end,
    }
end

for model, sex in pairs(MBT.GenderModels) do
    if sex == 'male' then maleModel = model break end
end
for model, sex in pairs(MBT.GenderModels) do
    if sex == 'female' then femaleModel = model break end
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
        name = 'canonicalizes absent prop texture sentinel to zero',
        run = function()
            local visual = fullVisual('male')
            visual.Props[1] = { drawable = -1, texture = -1, palette = 0 }
            local normalized, reason = MBT.Snapshot.Canonicalize(visual, maleModel)
            Assert.truthy(normalized, reason)
            Assert.equal(-1, normalized.Props[1].drawable)
            Assert.equal(0, normalized.Props[1].texture)
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
    {
        name = 'reuses context for duplicate readiness and rotates on character change',
        run = function()
            local fixture = snapshotServerFixture()
            local src = 46
            fixture.setIdentifier(src, 'char1')
            local first = fixture.coordinator:Activate(src, 'char1')
            local duplicate = fixture.coordinator:Activate(src, 'char1')
            Assert.equal(first.session, duplicate.session)
            Assert.equal(first.revision, duplicate.revision)
            fixture.setIdentifier(src, 'char2')
            local rotated = fixture.coordinator:Activate(src, 'char2')
            Assert.truthy(rotated.session ~= first.session)
        end,
    },
    {
        name = 'initial snapshots accept complete PED states and initialize only once',
        run = function()
            local bareFixture = snapshotServerFixture()
            local bareSrc = 47
            bareFixture.setIdentifier(bareSrc, 'char1')
            local bareContext = bareFixture.coordinator:Activate(bareSrc, 'char1')
            local barePayload = snapshotPayload(bareContext, 1)
            barePayload.initial = true
            Assert.equal('no_change', bareFixture.coordinator:Handle(bareSrc, barePayload).code)
            Assert.equal(1, #bareFixture.timers,
                'an unchanged initial baseline must still be persisted')
            bareFixture.timers[1]()
            Assert.equal(1, bareFixture.saveCount())

            local repeated = snapshotPayload(bareContext, 2)
            repeated.initial = true
            Assert.equal('initial_not_allowed', bareFixture.coordinator:Handle(bareSrc, repeated).code)

            -- Drawable 0 is a valid GTA component, not evidence that an
            -- appearance script is only partially loaded. This complete PED
            -- state used to be rejected as `partial_initial`.
            local partialFixture = snapshotServerFixture()
            local partialSrc = 48
            partialFixture.setIdentifier(partialSrc, 'char2')
            local partialContext = partialFixture.coordinator:Activate(partialSrc, 'char2')
            local validZeroHeavy = fullVisual('male')
            validZeroHeavy.Drawables[11] = { drawable = 101, texture = 0, palette = 0 }
            validZeroHeavy.Drawables[4] = { drawable = 20, texture = 0, palette = 0 }
            validZeroHeavy.Props[0] = { drawable = 0, texture = 0, palette = 0 }
            validZeroHeavy.Props[1] = { drawable = 0, texture = 0, palette = 0 }
            validZeroHeavy.Props[2] = { drawable = 0, texture = 0, palette = 0 }
            local validPayload = snapshotPayload(partialContext, 1, validZeroHeavy)
            validPayload.initial = true
            Assert.equal('accepted', partialFixture.coordinator:Handle(partialSrc, validPayload).code)
        end,
    },
    {
        name = 'client debounces a stable change and retries the identical request',
        run = function()
            local fixture = snapshotClientFixture()
            local client = fixture.client
            client:SetContext({ session = 7, revision = 3 }, { Drawables = {}, Props = {} })
            client:Resume('startup')
            client:Tick()
            Assert.equal(0, #fixture.sent)

            local changed = fullVisual('male')
            changed.Drawables[11] = { drawable = 101, texture = 2, palette = 0 }
            fixture.setVisual(changed)
            client:Tick()
            fixture.advance(MBT.SnapshotDebounce or 400)
            client:Tick()
            Assert.equal(1, #fixture.sent)
            Assert.equal(1, fixture.sent[1].seq)
            Assert.equal(3, fixture.sent[1].baseRevision)
            Assert.equal(nil, fixture.sent[1].visual)
            Assert.truthy(type(fixture.sent[1].Drawables) == 'table')

            fixture.advance(MBT.SnapshotAckTimeout or 2000)
            client:Tick()
            Assert.equal(2, #fixture.sent)
            Assert.same(fixture.sent[1], fixture.sent[2])
        end,
    },
    {
        name = 'client adopts positive and stale-revision rebase acknowledgements',
        run = function()
            local fixture = snapshotClientFixture()
            local client = fixture.client
            client:SetContext({ session = 8, revision = 2 }, { Drawables = {}, Props = {} })
            client:Resume('startup')
            local changed = fullVisual('male')
            changed.Props[0] = { drawable = 4, texture = 0, palette = 0 }
            fixture.setVisual(changed)
            client:Tick()
            fixture.advance(MBT.SnapshotDebounce or 400)
            client:Tick()
            local fingerprint = MBT.Snapshot.Fingerprint(changed)
            Assert.equal(true, client:HandleAck({
                ok = true,
                code = 'accepted',
                session = 8,
                seq = 1,
                revision = 3,
                fingerprint = fingerprint,
                visual = changed,
            }))
            Assert.equal(3, client:GetContext().revision)
            client:Tick()
            Assert.equal(1, #fixture.sent)

            local newerServer = fullVisual('male')
            newerServer.Drawables[11] = { drawable = 150, texture = 0, palette = 0 }
            fixture.advance(500)
            fixture.setVisual(fullVisual('male'))
            client:Tick()
            fixture.advance(MBT.SnapshotDebounce or 400)
            client:Tick()
            Assert.equal(2, #fixture.sent)
            Assert.equal(false, client:HandleAck({
                ok = false,
                code = 'stale_revision',
                session = 8,
                seq = 2,
                revision = 4,
                fingerprint = MBT.Snapshot.Fingerprint(newerServer),
                visual = newerServer,
            }))
            Assert.equal(4, client:GetContext().revision)
        end,
    },
    {
        name = 'client pause restore internal guards and suppression block false snapshots',
        run = function()
            local fixture = snapshotClientFixture()
            local client = fixture.client
            client:SetContext({ session = 9, revision = 1 }, { Drawables = {}, Props = {} })
            client:Resume('startup')
            local changed = fullVisual('male')
            changed.Props[0] = { drawable = 9, texture = 0, palette = 0 }
            fixture.setVisual(changed)

            client:Pause('character')
            client:Tick()
            fixture.advance(1000)
            client:Tick()
            Assert.equal(0, #fixture.sent)
            client:Resume('character')
            client:SetRestoreProtection(true)
            client:Tick()
            Assert.equal(0, #fixture.sent)
            client:SetRestoreProtection(false)
            local token = client:BeginInternal('dress', 500)
            fixture.advance(600)
            client:Tick()
            fixture.advance(MBT.SnapshotDebounce or 400)
            client:Tick()
            Assert.equal(1, #fixture.sent)
            client:EndInternal(token)

            local suppressedFixture = snapshotClientFixture()
            local suppressed = suppressedFixture.client
            suppressed:SetContext({ session = 10, revision = 1 }, { Drawables = {}, Props = {} })
            suppressed:Resume('startup')
            suppressed:Suppress('Props', 0, { drawable = -1, texture = 0, palette = 0 })
            suppressedFixture.setVisual(changed)
            suppressed:Tick()
            suppressedFixture.advance(1000)
            suppressed:Tick()
            Assert.equal(0, #suppressedFixture.sent)
        end,
    },
    {
        name = 'client ignores an expired restore generation',
        run = function()
            local fixture = snapshotClientFixture()
            local client = fixture.client
            client:SetContext({ session = 11, revision = 1 }, { Drawables = {}, Props = {} })
            client:Resume('startup')
            local oldGeneration = client:SetRestoreProtection(true)
            local currentGeneration = client:SetRestoreProtection(true)
            Assert.truthy(currentGeneration ~= oldGeneration)
            Assert.equal(false, client:SetRestoreProtection(false, nil, oldGeneration))
            client:Tick()
            Assert.equal(0, #fixture.sent)
            client:SetRestoreProtection(false, nil, currentGeneration)
        end,
    },
    {
        name = 'client preserves sequence across duplicate context readiness',
        run = function()
            local fixture = snapshotClientFixture()
            local client = fixture.client
            client:SetContext({ session = 12, revision = 0 }, { Drawables = {}, Props = {} })
            client:Resume('startup')
            local firstVisual = fullVisual('male')
            firstVisual.Drawables[11] = { drawable = 101, texture = 0, palette = 0 }
            fixture.setVisual(firstVisual)
            client:Tick()
            fixture.advance(MBT.SnapshotDebounce or 400)
            client:Tick()
            client:HandleAck({
                ok = true,
                session = 12,
                seq = 1,
                revision = 1,
                visual = firstVisual,
                fingerprint = MBT.Snapshot.Fingerprint(firstVisual),
            })

            client:SetContext({ session = 12, revision = 1 })
            local secondVisual = fullVisual('male')
            secondVisual.Drawables[11] = { drawable = 102, texture = 0, palette = 0 }
            fixture.setVisual(secondVisual)
            fixture.advance(500)
            client:Tick()
            fixture.advance(MBT.SnapshotDebounce or 400)
            client:Tick()
            Assert.equal(2, fixture.sent[#fixture.sent].seq)
        end,
    },
    {
        name = 'client blocks normal submissions until initial scan deadline',
        run = function()
            local fixture = snapshotClientFixture()
            local client = fixture.client
            client:SetContext({ session = 13, revision = 0 })
            client:Resume('startup')
            client:ForceInitialScan(2500)
            local partial = fullVisual('male')
            partial.Drawables[11] = { drawable = 101, texture = 0, palette = 0 }
            fixture.setVisual(partial)
            client:Tick()
            fixture.advance(2499)
            client:Tick()
            Assert.equal(0, #fixture.sent)
            fixture.advance(1)
            client:Tick()
            fixture.advance(MBT.SnapshotDebounce or 400)
            client:Tick()
            Assert.equal(true, fixture.sent[1].initial)
        end,
    },
    {
        name = 'client reports readiness only after initial snapshot acknowledgement',
        run = function()
            local fixture = snapshotClientFixture()
            local client = fixture.client
            client:SetContext({ session = 131, revision = 0 })
            client:Resume('startup')
            client:ForceInitialScan(0)
            client:Tick()
            fixture.advance(MBT.SnapshotDebounce or 400)
            client:Tick()

            Assert.equal(0, #fixture.initialAcknowledgements)
            Assert.equal(true, fixture.sent[1].initial)
            Assert.equal(true, client:HandleAck({
                ok = true,
                code = 'accepted',
                session = 131,
                seq = 1,
                revision = 1,
                visual = fixture.visual(),
            }))
            Assert.equal(1, #fixture.initialAcknowledgements)
            Assert.equal(131, fixture.initialAcknowledgements[1].session)
        end,
    },
    {
        name = 'client compares live PED visuals with authoritative wearing state',
        run = function()
            local fixture = snapshotClientFixture()
            local client = fixture.client
            local wearing = { Drawables = {}, Props = {} }

            Assert.equal(true, client:MatchesWearing(wearing))
            local changed = fullVisual('male')
            changed.Drawables[11] = { drawable = 101, texture = 0, palette = 0 }
            fixture.setVisual(changed)
            local matches, reason = client:MatchesWearing(wearing)
            Assert.equal(false, matches)
            Assert.equal('Drawables:11', reason)

            changed.Props[0] = { drawable = 4, texture = -1, palette = 0 }
            fixture.setVisual(changed)
            matches, reason = client:MatchesWearing(wearing)
            Assert.equal(false, matches)
            Assert.equal('invalid_texture', reason)
        end,
    },
    {
        name = 'resource restart lifecycle preserves current PED visibility',
        run = function()
            Assert.equal(false, MBT.PedVisibility.ShouldObscure('resource_restart'))
        end,
    },
    {
        name = 'spawn lifecycle keeps guarded PED visibility',
        run = function()
            Assert.equal(true, MBT.PedVisibility.ShouldObscure(nil))
        end,
    },
    {
        name = 'new reveal wait invalidates an older visibility watchdog',
        run = function()
            local timers = {}
            local reveals = {}
            local visibility = MBT.PedVisibility.New({
                schedule = function(_, callback) timers[#timers + 1] = callback end,
                hide = function() end,
                reveal = function(reason) reveals[#reveals + 1] = reason return true end,
            })

            visibility:Begin('framework', 5000)
            visibility:Begin('snapshot', 5000)
            timers[1]()
            Assert.equal(0, #reveals)
            timers[2]()
            Assert.equal(1, #reveals)
            Assert.equal('watchdog:snapshot', reveals[1])
        end,
    },
    {
        name = 'successful reveal cancels its pending watchdog',
        run = function()
            local timer
            local reveals = {}
            local visibility = MBT.PedVisibility.New({
                schedule = function(_, callback) timer = callback end,
                hide = function() end,
                reveal = function(reason) reveals[#reveals + 1] = reason return true end,
            })

            visibility:Begin('restore', 5000)
            Assert.equal(true, (visibility:Complete('stable')))
            timer()
            Assert.equal(1, #reveals)
            Assert.equal('stable', reveals[1])
        end,
    },
    {
        name = 'failed reveal keeps the transition open and retries',
        run = function()
            local timers = {}
            local reveals = {}
            local pedExists = false
            local visibility = MBT.PedVisibility.New({
                schedule = function(_, callback) timers[#timers + 1] = callback end,
                hide = function() end,
                reveal = function(reason)
                    if not pedExists then return false end
                    reveals[#reveals + 1] = reason
                    return true
                end,
            })

            local generation = visibility:Begin('restore', 5000)
            Assert.equal(false, (visibility:Complete('stable')))
            Assert.equal(0, #reveals)
            -- The transition must survive: consuming it here would burn the
            -- watchdog and strand a hidden PED with no owner left to reveal it.
            Assert.equal(true, visibility:Pulse(generation))

            pedExists = true
            timers[#timers]()
            Assert.equal(1, #reveals)
            Assert.equal('stable', reveals[1])
            Assert.equal(false, visibility:Pulse(generation))
        end,
    },
    {
        name = 'a newer transition discards a pending reveal retry',
        run = function()
            local timers = {}
            local reveals = {}
            local visibility = MBT.PedVisibility.New({
                schedule = function(_, callback) timers[#timers + 1] = callback end,
                hide = function() end,
                reveal = function(reason)
                    reveals[#reveals + 1] = reason
                    return false
                end,
            })

            visibility:Begin('restore', 5000)
            Assert.equal(false, (visibility:Complete('stable')))
            local retry = timers[#timers]
            visibility:Begin('switch', 5000)
            retry()
            -- Only the original failed attempt ran: the retry belongs to a
            -- transition that a newer character lifecycle already replaced.
            Assert.equal(1, #reveals)
        end,
    },
    {
        name = 'visibility pulse keeps only the current spawn generation hidden',
        run = function()
            local hides = 0
            local visibility = MBT.PedVisibility.New({
                schedule = function() end,
                hide = function() hides = hides + 1 end,
                reveal = function() return true end,
            })

            local oldGeneration = visibility:Begin('framework', 5000)
            local currentGeneration = visibility:Begin('snapshot', 5000)
            Assert.equal(false, visibility:Pulse(oldGeneration))
            Assert.equal(true, visibility:Pulse(currentGeneration))
            Assert.equal(3, hides)
            visibility:Complete('ready')
            Assert.equal(false, visibility:Pulse(currentGeneration))
        end,
    },
    {
        name = 'a forced initial scan sends on the first eligible tick',
        run = function()
            local fixture = snapshotClientFixture()
            local client = fixture.client
            client:SetContext({ session = 41, revision = 0 }, { Drawables = {}, Props = {} })
            client:Resume('startup')
            client:ForceInitialScan(2500)

            -- Prima della finestra non deve partire nulla: se questo tick
            -- inviasse, le asserzioni successive passerebbero a vuoto.
            client:Tick()
            Assert.equal(0, #fixture.sent)

            -- Dentro la finestra si osserva soltanto: nessun invio.
            fixture.advance(1000)
            client:Tick()
            Assert.equal(0, #fixture.sent)
            fixture.advance(1000)
            client:Tick()
            Assert.equal(0, #fixture.sent)

            -- Scaduta la finestra il fingerprint è già stabile da 2000ms, quindi
            -- parte SUBITO. Prima serviva un altro poll solo per registrare un
            -- candidato che non era mai cambiato: ~1s buttato a ogni primo login.
            fixture.advance(1000)
            client:Tick()
            Assert.equal(1, #fixture.sent)
            Assert.equal(true, fixture.sent[1].initial)
        end,
    },
    {
        name = 'new client session clears suppression state',
        run = function()
            local fixture = snapshotClientFixture()
            local client = fixture.client
            client:SetContext({ session = 14, revision = 0 }, { Drawables = {}, Props = {} })
            client:Resume('startup')
            client:Suppress('Props', 0, { drawable = -1, texture = 0, palette = 0 })
            client:SetContext({ session = 15, revision = 0 }, { Drawables = {}, Props = {} })
            local changed = fullVisual('male')
            changed.Props[0] = { drawable = 8, texture = 0, palette = 0 }
            fixture.setVisual(changed)
            client:Tick()
            fixture.advance(MBT.SnapshotDebounce or 400)
            client:Tick()
            Assert.equal(1, #fixture.sent)
        end,
    },
    {
        name = 'restore refreshes defaults after model change and enforces on exit',
        run = function()
            local fakeNow = 0
            local model = maleModel
            local enforced = {}
            local client = MBT.SnapshotClient.New({
                now = function() return fakeNow end,
                model = function() return model end,
                capture = function() return fullVisual(model == femaleModel and 'female' or 'male') end,
                send = function() end,
                enforce = function(target) enforced[#enforced + 1] = target.Drawables[4].drawable end,
            })
            client:SetContext({ session = 16, revision = 0 }, { Drawables = {}, Props = {} })
            client:Resume('startup')
            local generation = client:SetRestoreProtection(true, { Drawables = {}, Props = {} })
            model = femaleModel
            client:Tick()
            Assert.equal(14, enforced[1])
            client:SetRestoreProtection(false, nil, generation)
            Assert.equal(14, enforced[2])
        end,
    },
    {
        name = 'validates only configured persistent toggle transitions',
        run = function()
            local current = {
                index = 11,
                drawable = 29,
                texture = 2,
                palette = 0,
                sex = 'male',
                item_name = 'jacket',
            }
            Assert.equal(true, MBT.Snapshot.IsAllowedToggle(current, 'Drawables', 11, {
                drawable = 30,
                texture = 2,
                palette = 0,
            }))
            Assert.equal(false, MBT.Snapshot.IsAllowedToggle(current, 'Drawables', 11, {
                drawable = 300,
                texture = 2,
                palette = 0,
            }))
            Assert.equal(false, MBT.Snapshot.IsAllowedToggle(current, 'Drawables', 11, {
                drawable = 30,
                texture = 9,
                palette = 0,
            }))
            Assert.equal(false, MBT.Snapshot.IsAllowedToggle(current, 'Drawables', 11, {
                drawable = 30,
                texture = 2,
                palette = 1,
            }))
        end,
    },
    {
        name = 'client applies authoritative toggle revision to its baseline',
        run = function()
            local fixture = snapshotClientFixture()
            local client = fixture.client
            local wearing = {
                Drawables = {
                    [11] = { drawable = 29, texture = 2, palette = 0, sex = 'male', item_name = 'jacket' },
                },
                Props = {},
            }
            client:SetContext({ session = 17, revision = 4 }, wearing)
            client:Resume('startup')
            Assert.equal(true, client:ApplyAuthoritativeVisual({
                session = 17,
                revision = 5,
                slotType = 'Drawables',
                slotIndex = 11,
                visual = { drawable = 30, texture = 2, palette = 0 },
            }))
            Assert.equal(5, client:GetContext().revision)
            Assert.equal(30, wearing.Drawables[11].drawable)
        end,
    },
    {
        name = 'client rolls a rejected toggle back to authoritative visual',
        run = function()
            local fixture = snapshotClientFixture()
            local client = fixture.client
            local wearing = {
                Drawables = {
                    [11] = { drawable = 29, texture = 2, palette = 0, sex = 'male', item_name = 'jacket' },
                },
                Props = {},
            }
            client:SetContext({ session = 18, revision = 4 }, wearing)
            client:Resume('startup')
            local token = client:BeginInternal('toggle', 5000)
            Assert.equal(true, client:ApplyAuthoritativeVisual({
                ok = false,
                code = 'invalid_transition',
                session = 18,
                revision = 4,
                slotType = 'Drawables',
                slotIndex = 11,
                visual = { drawable = 29, texture = 2, palette = 0 },
                token = token,
            }))
            Assert.equal(1, #fixture.enforced)
            Assert.equal(29, fixture.enforced[1].Drawables[11].drawable)
        end,
    },
    {
        name = 'ordinary state mutation rebases client before immediate toggle',
        run = function()
            local fixture = snapshotClientFixture()
            local client = fixture.client
            client:SetContext({ session = 19, revision = 4 }, { Drawables = {}, Props = {} })
            client:Resume('startup')
            Assert.equal(true, client:ApplyAuthoritativeRevision({
                session = 19,
                revision = 5,
            }))
            local context = client:GetContext()
            Assert.equal(19, context.session)
            Assert.equal(5, context.revision)
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
