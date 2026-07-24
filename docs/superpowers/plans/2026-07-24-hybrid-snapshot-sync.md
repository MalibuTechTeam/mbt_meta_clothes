# Hybrid Snapshot Synchronization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace per-slot external clothing events with an acknowledged full-state snapshot protocol that persists the real managed PED state without losing rich server metadata.

**Architecture:** A pure shared snapshot module canonicalizes, validates, fingerprints, and reconciles visual state. A client coordinator polls the local PED but sends only debounced changes; a server coordinator owns character sessions, sequence idempotency, acknowledgements, and write-behind. `PlayerState` remains the authoritative metadata store and gains atomic snapshot commit plus monotonically increasing state revisions.

**Tech Stack:** FiveM Lua 5.4, Cfx client/server events, GTA PED component/prop natives, oxmysql, existing ESX/QB/OX lifecycle bridges.

## Global Constraints

- Modify only `mbt_meta_clothes`; do not modify `mbt_character` or an appearance resource.
- The complete base skin remains owned by the active appearance resource.
- Snapshots cover exactly the keys configured in `MBT.Drawables` and `MBT.Props`; they do not cover face, hair, tattoos, overlays, or head blend.
- Normal poll interval is 1,000 ms; restore poll interval is 500 ms; stable-change debounce is 400 ms.
- Component drawable bounds are `0..4095`; prop drawable bounds are `-1..4095`; texture bounds are `0..255`; palette bounds are `0..3`; encoded payload maximum is 16 KiB.
- Snapshot write-behind is enabled by default after five seconds of quiet; `0` disables it.
- A configured-default drawable is absent wearing state regardless of its texture or palette.
- Never trust client-supplied `item_name`, DNA, ownership history, labels, descriptions, or arbitrary metadata.
- Preserve existing rich metadata only when server metadata and snapshot have identical drawable, texture, and palette.
- Preserve legacy public event handlers during this change unless a task explicitly replaces only an internal caller.
- Self-tests run only from the server console while `MBT.Debug == true`, use injected stores/schedulers where available, and clean any reserved synthetic source state before returning.

---

## File Map

- Create `modules/snapshot/shared.lua`: pure canonical ordering, validation, fingerprints, and reconciliation.
- Create `modules/snapshot/server.lua`: session/revision protocol, submit/ack flow, idempotency cache, write-behind.
- Create `modules/snapshot/client.lua`: PED capture, polling, debounce, guards, retries, suppression registry.
- Create `tests/snapshot_spec.lua`: deterministic in-resource self-tests exposed through a server-console command when `MBT.Debug` is enabled.
- Modify `fxmanifest.lua`: load shared protocol after config and load coordinators in dependency order.
- Modify `config.lua`: snapshot timing, bounds, payload, and write-behind settings.
- Modify `modules/state/server.lua`: revisions, atomic snapshot commit, identifier/context access, cleanup.
- Modify `modules/utils/client.lua`: remove old per-slot polling behavior and retain compatibility wrappers for existing internal APIs/exports.
- Modify `core/client.lua`: pass lifecycle context to the client coordinator and use guarded restore/new-player capture.
- Modify `core/server.lua`: route batch snapshot and persistent visual toggle operations; retain legacy external handlers.
- Modify `modules/bridge/esx/client.lua`, `modules/bridge/qb/client.lua`, `modules/bridge/ox/client.lua`: pause/resume the coordinator through existing lifecycle hooks.
- Modify `ROADMAP.md`: mark snapshot synchronization work complete only after verification.

---

### Task 1: Pure Snapshot Contract And Self-Test Harness

**Files:**
- Create: `modules/snapshot/shared.lua`
- Create: `tests/snapshot_spec.lua`
- Modify: `config.lua:37-43`
- Modify: `fxmanifest.lua:9-20,25-63`

**Interfaces:**
- Produces: `MBT.Snapshot.Canonicalize(visual, model) -> normalized|nil, reason`
- Produces: `MBT.Snapshot.Fingerprint(visual) -> string`
- Produces: `MBT.Snapshot.VisualFromWearing(wearing, sex) -> visual`
- Produces: `MBT.Snapshot.Reconcile(current, visual, sex) -> nextState, changes, changed`
- Produces: server-console command `mbt_snapshot_selftest` when `MBT.Debug == true`

- [ ] **Step 1: Add failing contract tests**

Create table-driven tests covering full-key enforcement, extra-key rejection, numeric bounds, deterministic ordering, default normalization, metadata preservation, external sanitization, and changed-slot reporting:

```lua
local cases = {
    { name = 'rejects missing slot', run = function()
        local visual = Fixtures.FullVisual('male')
        visual.Drawables[11] = nil
        local normalized, reason = MBT.Snapshot.Canonicalize(visual, Fixtures.MaleModel)
        Assert.equal(nil, normalized)
        Assert.equal('missing_slot', reason)
    end },
    { name = 'normalizes textured default', run = function()
        local visual = Fixtures.FullVisual('male')
        visual.Drawables[11] = { drawable = 15, texture = 7, palette = 2 }
        local normalized = assert(MBT.Snapshot.Canonicalize(visual, Fixtures.MaleModel))
        local nextState = MBT.Snapshot.Reconcile({ Drawables = {}, Props = {} }, normalized, 'male')
        Assert.equal(nil, nextState.Drawables[11])
    end },
    { name = 'preserves rich metadata when visual is unchanged', run = function()
        local rich = { index = 11, drawable = 100, texture = 2, palette = 0, item_name = 'jacket', last_worn_by = {{ identifier = 'char1' }} }
        local current = { Drawables = { [11] = rich }, Props = {} }
        local visual = Fixtures.FullVisual('male')
        visual.Drawables[11] = { drawable = 100, texture = 2, palette = 0 }
        local nextState = MBT.Snapshot.Reconcile(current, visual, 'male')
        Assert.same(rich, nextState.Drawables[11])
    end },
}
```

- [ ] **Step 2: Load the test file and verify the command fails**

Add `tests/snapshot_spec.lua` after production server scripts, restart the resource on the development server, then run:

```text
mbt_snapshot_selftest
```

Expected: failure stating that `MBT.Snapshot.Canonicalize` is missing.

- [ ] **Step 3: Add configuration and pure implementation**

Add exact defaults:

```lua
MBT.SnapshotPollInterval = 1000
MBT.SnapshotRestorePollInterval = 500
MBT.SnapshotDebounce = 400
MBT.SnapshotAckTimeout = 2000
MBT.SnapshotWriteBehind = 5000
MBT.SnapshotMaxPayload = 16384
MBT.SnapshotBounds = {
    componentDrawable = { min = 0, max = 4095 },
    propDrawable = { min = -1, max = 4095 },
    texture = { min = 0, max = 255 },
    palette = { min = 0, max = 3 },
}
```

Implement pure functions with sorted numeric keys and fixed field order. `Reconcile` must copy table structure, retain the original metadata table when visual fields match, and create only this shape for new external values:

```lua
{
    index = slotIndex,
    drawable = slot.drawable,
    texture = slot.texture,
    palette = slot.palette,
    sex = sex,
    type = slotType == 'Props' and 'Prop' or 'Drawable',
    provenance = 'external',
}
```

- [ ] **Step 4: Run contract tests**

Run `mbt_snapshot_selftest` in the development server console.

Expected: all pure contract tests pass, with zero database or player requirements.

- [ ] **Step 5: Commit**

```bash
git add config.lua fxmanifest.lua modules/snapshot/shared.lua tests/snapshot_spec.lua
git commit -m "test(snapshot): define canonical visual contract"
```

---

### Task 2: PlayerState Revisions And Atomic Commit

**Files:**
- Modify: `modules/state/server.lua:8-16,88-174,217-380`
- Modify: `tests/snapshot_spec.lua`

**Interfaces:**
- Consumes: `MBT.Snapshot.Reconcile(current, visual, sex)`
- Produces: `MBT.PlayerState.GetRevision(src) -> integer`
- Produces: `MBT.PlayerState.GetIdentifier(src) -> string|nil`
- Produces: `MBT.PlayerState.CommitSnapshot(src, nextState, changes) -> revision`
- Produces: `MBT.PlayerState.UpdateSlotVisual(src, slotType, slotIndex, visual) -> boolean, revision|reason`
- Produces: server event callback hook `MBT.SnapshotServer.OnRevisionChanged(src, revision)` when available

- [ ] **Step 1: Add failing revision tests**

Add tests asserting:

```lua
Assert.equal(0, MBT.PlayerState.GetRevision(41))
MBT.PlayerState.SetSlot(41, 'Drawables', 11, Fixtures.RichJacket())
Assert.equal(1, MBT.PlayerState.GetRevision(41))
MBT.PlayerState.UpdateSlotVisual(41, 'Drawables', 11, { drawable = 101, texture = 0, palette = 0 })
Assert.equal('jacket', MBT.PlayerState.GetSlot(41, 'Drawables', 11).item_name)
Assert.equal(2, MBT.PlayerState.GetRevision(41))
```

Also assert one `CommitSnapshot` increments once even when several slots change, emits each effective `onClothingChanged`, and a no-op does not increment or dirty state.

- [ ] **Step 2: Run tests and verify failure**

Run `mbt_snapshot_selftest`.

Expected: failure for missing revision APIs.

- [ ] **Step 3: Implement revision ownership**

Add `PlayerRevisions[src]`, reset it to `0` only when a new identifier is loaded, and clear it during `Cleanup`. Route mutations through a private helper:

```lua
local function touchRevision(src)
    PlayerRevisions[src] = (PlayerRevisions[src] or 0) + 1
    local revision = PlayerRevisions[src]
    if MBT.SnapshotServer and MBT.SnapshotServer.OnRevisionChanged then
        MBT.SnapshotServer.OnRevisionChanged(src, revision)
    end
    return revision
end
```

`SetSlot`, effective `ClearSlot`, effective `ClearAllSlots`, and persistent visual updates call it. `CommitSnapshot` swaps the complete table before emitting change events and calls it exactly once.

- [ ] **Step 4: Run tests**

Run `mbt_snapshot_selftest`.

Expected: revision, metadata-preservation, atomic-commit, and no-op tests pass.

- [ ] **Step 5: Commit**

```bash
git add modules/state/server.lua tests/snapshot_spec.lua
git commit -m "feat(state): add authoritative snapshot revisions"
```

---

### Task 3: Server Snapshot Coordinator

**Files:**
- Create: `modules/snapshot/server.lua`
- Modify: `fxmanifest.lua`
- Modify: `core/server.lua:29-124,167-237`
- Modify: `tests/snapshot_spec.lua`

**Interfaces:**
- Consumes: `MBT.PlayerState.GetRevision`, `GetIdentifier`, `GetAll`, `CommitSnapshot`, `Save`
- Produces: `MBT.SnapshotServer.Activate(src, identifier) -> { session, revision }`
- Produces: `MBT.SnapshotServer.GetContext(src) -> { session, revision }|nil`
- Produces: `MBT.SnapshotServer.Handle(src, payload) -> ack`
- Produces: `MBT.SnapshotServer.Cleanup(src)`
- Produces: `MBT.SnapshotServer.New(deps) -> coordinator` for isolated tests
- Produces: client event `mbt_meta_clothes:snapshotAck(ack)`
- Consumes: server event `mbt_meta_clothes:submitSnapshot(payload)`

- [ ] **Step 1: Add failing protocol tests**

Cover accepted change, accepted no-op, duplicate same-sequence retry, lower sequence, wrong session, stale base revision, malformed/oversized payload, character rotation, and write-behind reset/cancellation:

```lua
local coordinator = MBT.SnapshotServer.New(Fixtures.ServerDeps())
local context = coordinator:Activate(41, 'char1:license')
local ack1 = coordinator:Handle(41, Fixtures.Payload(context.session, 1, context.revision))
Assert.equal(true, ack1.ok)
local duplicate = coordinator:Handle(41, Fixtures.Payload(context.session, 1, context.revision))
Assert.equal(ack1.revision, duplicate.revision)
Assert.equal('duplicate', duplicate.code)
```

- [ ] **Step 2: Run tests and verify failure**

Run `mbt_snapshot_selftest`.

Expected: failure for missing `MBT.SnapshotServer`.

- [ ] **Step 3: Implement coordinator and validation**

Implement the production singleton on top of a coordinator constructor whose dependencies provide `PlayerState`, clock, scheduler, event emission, and payload encoding. Tests use fakes and perform no database writes. Maintain per-source state:

```lua
sessions[src] = {
    identifier = identifier,
    generation = generation,
    lastSeq = 0,
    lastRequestFingerprint = nil,
    lastAck = nil,
    saveGeneration = 0,
}
```

Validate the full payload before calling `Reconcile`. Accept `seq == lastSeq` only when its request fingerprint matches the cached request. For a changed visual require `baseRevision == PlayerState.GetRevision(src)`. For a no-op acknowledge the current revision without dirtying state. Schedule write-behind only after a changed commit and guard timers with `saveGeneration`.

- [ ] **Step 4: Integrate server events**

Register one rate-limited submit event:

```lua
RegisterNetEvent('mbt_meta_clothes:submitSnapshot', function(payload)
    local src = source
    if not MBT.ServerUtils.CheckRateLimit(src, 'snapshot') then return end
    TriggerClientEvent('mbt_meta_clothes:snapshotAck', src, MBT.SnapshotServer.Handle(src, payload))
end)
```

Keep `externalDress`, `externalUndress`, `storePlayerSkin`, and `saveSkin` available for compatibility, but the new client must not call per-slot external events.

- [ ] **Step 5: Run protocol tests**

Run `mbt_snapshot_selftest`.

Expected: protocol, stale-ordering, idempotency, and timer tests pass.

- [ ] **Step 6: Commit**

```bash
git add fxmanifest.lua core/server.lua modules/snapshot/server.lua tests/snapshot_spec.lua
git commit -m "feat(snapshot): add acknowledged server protocol"
```

---

### Task 4: Client Snapshot Coordinator

**Files:**
- Create: `modules/snapshot/client.lua`
- Modify: `fxmanifest.lua`
- Modify: `modules/utils/client.lua:301-641`
- Modify: `tests/snapshot_spec.lua`

**Interfaces:**
- Produces: `MBT.SnapshotClient.SetContext(context, wearingState)`
- Produces: `MBT.SnapshotClient.Start()`
- Produces: `MBT.SnapshotClient.Pause(reason)` and `Resume(reason)`
- Produces: `MBT.SnapshotClient.BeginInternal(reason, timeoutMs) -> token`
- Produces: `MBT.SnapshotClient.EndInternal(token, expectedState)`
- Produces: `MBT.SnapshotClient.SetRestoreProtection(active, wearingState)`
- Produces: `MBT.SnapshotClient.Suppress(slotType, slotIndex, canonicalVisual)`
- Produces: `MBT.SnapshotClient.RestoreSuppressed(slotType, slotIndex)`
- Produces: `MBT.SnapshotClient.ForceInitialScan(delayMs)`
- Consumes: `mbt_meta_clothes:snapshotAck`

- [ ] **Step 1: Add failing client state-machine tests**

Use injected clock, capture, and send functions so tests do not require a PED:

```lua
local sent = {}
local client = MBT.SnapshotClient.New({
    now = function() return fakeNow end,
    capture = function() return currentVisual end,
    send = function(payload) sent[#sent + 1] = payload end,
})
client:SetContext({ session = 2, revision = 7 }, currentVisual)
client:Tick()
Assert.equal(0, #sent)
currentVisual = Fixtures.ChangedJacketVisual()
client:Tick()
fakeNow = fakeNow + MBT.SnapshotDebounce
client:Tick()
Assert.equal(1, #sent)
```

Cover unchanged idle, debounce reset, one in-flight request, same-sequence retry, positive ack, stale-revision rejection, pause, restore guard, expiring internal guard, and suppression canonicalization.

- [ ] **Step 2: Run tests and verify failure**

Run `mbt_snapshot_selftest`.

Expected: failure for missing `MBT.SnapshotClient.New`.

- [ ] **Step 3: Implement the testable state machine**

Keep timing and transport injectable. A pending request stores the exact payload and send time; timeout resends it unchanged. A positive ack updates `revision`, acknowledged fingerprint, and clears pending. `wrong_session` clears context and pauses until a new restore payload.

- [ ] **Step 4: Add FiveM runtime adapter**

Capture all configured PED slots in ascending order, substitute canonical values for suppressed slots, and run a single polling thread. Use `MBT.SnapshotPollInterval` normally and `MBT.SnapshotRestorePollInterval` during restore, but never submit while restore is active. If the current PED model is absent from `MBT.GenderModels`, pause snapshot submission and preserve the last valid server state.

Replace the old `processSlotChange` outbound behavior. Preserve public compatibility wrappers:

```lua
function MBT.Utils.PauseHybridDetection()
    MBT.SnapshotClient.Pause('legacy')
end

function MBT.Utils.ResumeHybridDetection(wearingState)
    MBT.SnapshotClient.Resume('legacy', wearingState)
end

function MBT.Utils.ExpectChange(slotType, slotIndex)
    return MBT.SnapshotClient.ExpectInternalSlot(slotType, slotIndex, 3000)
end
```

- [ ] **Step 5: Run state-machine tests**

Run `mbt_snapshot_selftest`.

Expected: all client coordinator tests pass; idle test sends zero events.

- [ ] **Step 6: Commit**

```bash
git add fxmanifest.lua modules/snapshot/client.lua modules/utils/client.lua tests/snapshot_spec.lua
git commit -m "feat(snapshot): batch client hybrid detection"
```

---

### Task 5: Restore, Initial Scan, And Character Lifecycle Integration

**Files:**
- Modify: `modules/state/server.lua:395-486`
- Modify: `core/client.lua:50-221`
- Modify: `modules/bridge/esx/client.lua:7-131`
- Modify: `modules/bridge/qb/client.lua:1-29`
- Modify: `modules/bridge/ox/client.lua:1-32`
- Modify: `modules/bridge/esx/server.lua:65-131`
- Modify: `modules/bridge/qb/server.lua:51-69`
- Modify: `modules/bridge/ox/server.lua:28-45`
- Modify: `tests/snapshot_spec.lua`

**Interfaces:**
- Consumes: `MBT.SnapshotServer.Activate`, `Cleanup`
- Consumes: `MBT.SnapshotClient.SetContext`, `SetRestoreProtection`, `ForceInitialScan`
- Changes payloads: `restoreWearing(wearingState, context)` and `requestPedScan(context)`

- [ ] **Step 1: Add failing lifecycle tests**

Test duplicate readiness reuses context, identifier change rotates session, late old-session snapshot rejects, resource restart issues a fresh context, and cleanup cancels write-behind.

- [ ] **Step 2: Run tests and verify failure**

Run `mbt_snapshot_selftest`.

Expected: failure because readiness payloads do not include context.

- [ ] **Step 3: Attach context to load branches**

After `CheckCharacterSwitch` and `Load`, call:

```lua
local context = MBT.SnapshotServer.Activate(src, MBT.PlayerState.GetIdentifier(src))
TriggerClientEvent('mbt_meta_clothes:restoreWearing', src, wearingState, context)
-- or
TriggerClientEvent('mbt_meta_clothes:requestPedScan', src, context)
```

On drop and detected character switch, save old state first, then rotate/cleanup snapshot context. Duplicate `playerReady` within the current character must not rotate it.

- [ ] **Step 4: Guard restore and migrate initial scan**

The client sets context before applying restore, enables restore guard, applies/reapplies, then rebases and ends the guard. For DB misses, wait the existing 2.5 seconds and submit a full snapshot with `initial = true`. The server applies the existing bare-PED sanity rules before accepting an initial snapshot. Stop using `syncInitialWearing` from the new client, but retain its server handler for compatibility.

- [ ] **Step 5: Wire framework pause/resume**

Existing ESX/QB/OX lifecycle handlers must call coordinator pause/start methods without adding appearance-resource-specific hooks. Graceful logout saves the latest already accepted snapshot and never waits for a final round trip.

- [ ] **Step 6: Run lifecycle tests and resource-restart smoke test**

Run `mbt_snapshot_selftest`, then on the development server:

```text
restart mbt_meta_clothes
```

Expected: connected player restores the same managed visual state, coordinator logs one context activation, and no duplicate inventory item appears.

- [ ] **Step 7: Commit**

```bash
git add modules/state/server.lua core/client.lua modules/bridge/esx/client.lua modules/bridge/qb/client.lua modules/bridge/ox/client.lua modules/bridge/esx/server.lua modules/bridge/qb/server.lua modules/bridge/ox/server.lua tests/snapshot_spec.lua
git commit -m "fix(lifecycle): bind snapshots to character sessions"
```

---

### Task 6: Persistent Toggles And Temporary Suppression

**Files:**
- Modify: `core/client.lua:255-264`
- Modify: `core/server.lua:126-197`
- Modify: `modules/utils/client.lua:598-641,873-995`
- Modify: `modules/state/server.lua:94-174`
- Modify: `tests/snapshot_spec.lua`

**Interfaces:**
- Consumes: `MBT.PlayerState.UpdateSlotVisual`
- Consumes: `MBT.SnapshotClient.BeginInternal`, `EndInternal`, `Suppress`, `RestoreSuppressed`
- Adds: server event `mbt_meta_clothes:updateInternalVisual(slotType, slotIndex, visual)`
- Preserves exports: `expectChange`, `suppressSlot`, `restoreSlot`

- [ ] **Step 1: Add failing toggle/suppression tests**

Assert jacket/visor toggle changes only visual fields and preserves `item_name`/DNA; hair toggle sends no managed snapshot; suppressed prop snapshots retain the original canonical value; expired internal expectations no longer mask future external changes.

- [ ] **Step 2: Run tests and verify failure**

Run `mbt_snapshot_selftest`.

Expected: toggle persistence and suppression canonicalization tests fail.

- [ ] **Step 3: Persist managed toggles**

After the toggle native succeeds, send only validated visual fields through `updateInternalVisual`. Server validation uses configured slot/bounds and `UpdateSlotVisual` preserves rich metadata while incrementing revision. Wrap the client native application in a scoped internal token.

- [ ] **Step 4: Replace permanent expected booleans**

Change `ExpectChange` to an expiring per-slot token. `suppressSlot` captures the canonical pre-suppression value before updating the PED/cache; `restoreSlot` restores and removes it. Do not let either operation create a snapshot of the temporary hidden value.

- [ ] **Step 5: Run tests**

Run `mbt_snapshot_selftest`.

Expected: toggle, rich metadata, expiry, and suppression tests pass.

- [ ] **Step 6: Commit**

```bash
git add core/client.lua core/server.lua modules/utils/client.lua modules/state/server.lua tests/snapshot_spec.lua
git commit -m "fix(snapshot): preserve internal visual variants"
```

---

### Task 7: End-To-End Verification And Roadmap Update

**Files:**
- Modify: `tests/snapshot_spec.lua`
- Modify: `ROADMAP.md:44-61`

**Interfaces:**
- Verifies the complete snapshot protocol; produces no new runtime API.

- [ ] **Step 1: Run static checks**

```powershell
git diff --check
rg -n "TriggerServerEvent\(\"mbt_meta_clothes:external(Dress|Undress)" modules core
rg -n "expectedChanges\[.*\] = true" modules/utils/client.lua
```

Expected: no whitespace errors; no production client call to per-slot external events; no unbounded permanent expected-change assignment.

- [ ] **Step 2: Run the complete deterministic suite**

Run:

```text
mbt_snapshot_selftest
```

Expected: all validation, reconciliation, revision, ordering, retry, guard, suppression, and lifecycle cases pass.

- [ ] **Step 3: Verify external full outfit**

On the development server, apply a saved appearance that changes at least six managed slots. Wait two seconds, relog, and confirm all managed slots match the PED state before relog. Confirm server logs show one accepted snapshot rather than per-slot events.

- [ ] **Step 4: Verify inventory metadata preservation**

Wear a metadata jacket through MBT, record its `item_name` and DNA, apply an unrelated external prop change, then remove the jacket. Confirm the returned item retains its original metadata and no duplicate exists.

- [ ] **Step 5: Verify stale character isolation**

Rapidly relog from character A to B while appearance is loading. Confirm any late A snapshot logs `wrong_session` or `stale_revision` and B retains its own state.

- [ ] **Step 6: Verify abrupt drop and resource restart**

Apply an external change, wait two seconds, disconnect without graceful logout, reconnect, and confirm restore. Then run `restart mbt_meta_clothes` while connected and confirm no visual or inventory duplication.

- [ ] **Step 7: Update roadmap with evidence**

Mark only the completed hybrid synchronization/lifecycle test items and cite the self-test plus manual scenarios in the roadmap notes. Leave framework resolver, inventory transactions, security authorization, and unrelated release work unchecked.

- [ ] **Step 8: Commit**

```bash
git add tests/snapshot_spec.lua ROADMAP.md
git commit -m "test(snapshot): verify relog and appearance sync"
```

---

### Task 8: Post-Implementation Gap Audit

**Files:**
- Modify only if findings require documentation: `ROADMAP.md`

**Interfaces:**
- Produces an evidence-backed list of remaining work; no runtime changes.

- [ ] **Step 1: Audit remaining roadmap areas**

Inspect server event authorization, inventory mutation rollback, framework/inventory resolver, resource restart recovery, database migration/versioning, diagnostics, documentation, and release packaging against current code.

- [ ] **Step 2: Classify findings**

For every remaining item record severity (`P0`, `P1`, `P2`), evidence path/line, affected framework/inventory combinations, and a concrete acceptance test.

- [ ] **Step 3: Update roadmap only with confirmed evidence**

Do not implement unrelated fixes in this task. Keep future work separated into independently plannable features.

- [ ] **Step 4: Commit documentation changes if any**

```bash
git add ROADMAP.md
git commit -m "docs: refresh remaining 2.0 gaps"
```
