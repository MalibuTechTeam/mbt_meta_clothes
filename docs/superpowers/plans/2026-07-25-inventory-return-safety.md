# Inventory Return Safety Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Prevent undress and steal operations from deleting worn clothing when the destination inventory rejects an item, without changing the existing framework bridges or usable-item registration architecture.

**Architecture:** Extend the existing `MBT.GiveItems` dependency-injection point with a small testable transfer coordinator and per-slot locks. Existing framework bridge files normalize only their own `addItem` result; existing client/server events gain acknowledgements so PED defaults are applied only after the server commits the corresponding state change.

**Tech Stack:** FiveM/Cfx Lua 5.4, ESX, QBCore/qb-inventory, ox_inventory, existing `MBT.PlayerState`, in-resource server-console self-tests.

## Global Constraints

- Do not add a framework or inventory resolver.
- Do not reorganize `modules/bridge` or replace existing OX/QB usable-item registration.
- Assume one inventory resource is active at runtime.
- Build returned items from `MBT.PlayerState`, never from client-supplied clothing metadata.
- Clear worn state only after `AddItem` returns success.
- Preserve rich metadata, DNA, item-name resolution, drawable, texture, and palette.
- Apply the steal rate limit once per selected-multiple or steal-all action.
- Keep the dress/use-item protocol outside this implementation.
- Add no polling, periodic thread, or database write.
- Self-tests are server-console-only and active only with `MBT.Debug == true`.

## File Map

- Modify `modules/bridge/inventory/give_items.lua`: coordinator, locks, authoritative metadata builders.
- Modify `modules/bridge/esx/server.lua`, `qb/server.lua`, `ox/server.lua`: explicit `addItem` results.
- Modify `core/server.lua`: validation, acknowledgements, safe undress and steal batches.
- Modify `modules/utils/client.lua`: defer undress visuals and batch selected steals.
- Modify `core/client.lua`: apply only committed victim defaults and remove obsolete steal path.
- Modify `locales/en.lua` and `locales/it.lua`: stable failure and partial-result notifications.
- Create `tests/inventory_return_spec.lua`: deterministic transaction tests.
- Modify `fxmanifest.lua`: load the new self-test.
- Modify `ROADMAP.md`: record only verified outcomes and the rejected resolver decision.

---

### Task 1: Define the Safe Transfer Contract

**Files:**
- Modify: `modules/bridge/inventory/give_items.lua`
- Create: `tests/inventory_return_spec.lua`
- Modify: `fxmanifest.lua`

**Interfaces:**
- Consumes: `config.addItem(source, itemName, count, metadata) -> boolean, reason?`
- Produces: `MBT.GiveItems.New(config) -> coordinator`
- Produces: `coordinator:Transfer(lockKey, buildPayload, commitState) -> result`
- Produces: `coordinator:CleanupSource(source)`
- Result: `{ ok, reason?, itemName?, committed? }`
- Produces: server-console command `mbt_inventory_return_selftest`

- [ ] **Step 1: Write failing coordinator tests**

Create `tests/inventory_return_spec.lua` using the assertion/command pattern in `tests/snapshot_spec.lua`. Cover add failure, success, re-entrant duplicate, thrown dependency, and lock release:

```lua
local coordinator = MBT.GiveItems.New({
    addItem = function() return false, 'inventory_full' end,
    log = function() end,
})
local cleared = 0
local result = coordinator:Transfer('7:Drawables:11', function()
    return { receiver = 7, itemName = 'jacket', count = 1, metadata = { dna = 'kept' } }
end, function()
    cleared = cleared + 1
    return true
end)
Assert.equal(false, result.ok)
Assert.equal('inventory_full', result.reason)
Assert.equal(0, cleared)
```

The re-entrant case calls `Transfer` with the same key from inside fake `addItem` and must receive `busy`. The exception case must prove a later request can acquire the same key.

- [ ] **Step 2: Load the test and verify failure**

Add `'tests/inventory_return_spec.lua'` after `tests/snapshot_spec.lua` in `fxmanifest.lua`. Restart the resource with debug enabled and run `mbt_inventory_return_selftest`.

Expected: FAIL because `MBT.GiveItems.New` is missing.

- [ ] **Step 3: Implement the minimal coordinator**

Add this shape inside the existing `give_items.lua`; do not create an adapter or resolver:

```lua
function MBT.GiveItems.New(config)
    local locks = {}
    local coordinator = {}

    function coordinator:Transfer(lockKey, buildPayload, commitState)
        if locks[lockKey] then return { ok = false, reason = 'busy' } end
        locks[lockKey] = true
        local protected, result = xpcall(function()
            local payload, reason = buildPayload()
            if not payload then return { ok = false, reason = reason or 'no_item' } end
            local added, addReason = config.addItem(
                payload.receiver, payload.itemName, payload.count or 1, payload.metadata)
            if added ~= true then
                return { ok = false, reason = addReason or 'add_failed', itemName = payload.itemName }
            end
            local committed, committedData = commitState(payload)
            if committed ~= true then
                if config.log then config.log('commit_failed', lockKey, payload.itemName) end
                return { ok = false, reason = 'commit_failed', itemName = payload.itemName }
            end
            return { ok = true, itemName = payload.itemName, committed = committedData }
        end, debug.traceback)
        locks[lockKey] = nil
        if protected then return result end
        if config.log then config.log('exception', lockKey, result) end
        return { ok = false, reason = 'internal_error' }
    end

    function coordinator:CleanupSource(src)
        local prefix = tostring(src) .. ':'
        for key in pairs(locks) do
            if key:sub(1, #prefix) == prefix then locks[key] = nil end
        end
    end

    return coordinator
end
```

- [ ] **Step 4: Run regression tests**

Run `mbt_inventory_return_selftest` and `mbt_snapshot_selftest` in the Cfx console.

Expected: new contract cases pass and snapshot remains `28/28`.

- [ ] **Step 5: Commit**

```bash
git add fxmanifest.lua modules/bridge/inventory/give_items.lua tests/inventory_return_spec.lua
git commit -m "test(inventory): define safe transfer contract"
```

---

### Task 2: Normalize Existing Bridge Add Results

**Files:**
- Modify: `modules/bridge/esx/server.lua`
- Modify: `modules/bridge/qb/server.lua`
- Modify: `modules/bridge/ox/server.lua`
- Modify: `tests/inventory_return_spec.lua`

**Interfaces:**
- Produces: every existing bridge-local `addItem(src, name, count, metadata) -> boolean, reason?`
- Preserves: `MBT.CustomInventory(source, itemName, count, metadata) -> boolean, reason?`

- [ ] **Step 1: Add failing result-normalization cases**

Test `inventory_full`, `invalid_item`, thrown custom callback, non-boolean custom result, and success. Every failure must leave the fake commit counter at zero.

```lua
local function assertRejected(addItem, expectedReason)
    local committed = 0
    local tx = MBT.GiveItems.New({ addItem = addItem, log = function() end })
    local result = tx:Transfer('9:Props:0', function()
        return { receiver = 9, itemName = 'hat', metadata = {} }
    end, function()
        committed = committed + 1
        return true
    end)
    Assert.equal(false, result.ok)
    Assert.equal(expectedReason, result.reason)
    Assert.equal(0, committed)
end
```

- [ ] **Step 2: Normalize OX paths**

Return the documented pair directly in ESX, QB, and OX Core paths:

```lua
local success, response = exports.ox_inventory:AddItem(src, itemName, count, metadata)
return success == true, success and nil or (response or 'add_failed')
```

Do not add `CanCarryItem`; `AddItem` remains the authoritative attempt and reports `invalid_item`, `invalid_inventory`, or `inventory_full`.

- [ ] **Step 3: Normalize QB and custom paths**

Preserve the current QB call but consume its boolean and show ItemBox only on success:

```lua
local success = player.Functions.AddItem(itemName, count, false, metadata)
if success then
    TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[itemName], 'add')
end
return success == true, success and nil or 'inventory_full'
```

Correct custom invocation and fail closed:

```lua
local called, success, reason = pcall(MBT.CustomInventory, src, itemName, count, metadata)
if not called then return false, 'custom_error' end
if success ~= true then return false, reason or 'add_failed' end
return true
```

A missing callback returns `false, 'unsupported_inventory'` after the existing warning.

- [ ] **Step 4: Verify and commit**

Run both self-tests and `git diff --check`. Inspect that no item registration or lifecycle code changed, then commit:

```bash
git add modules/bridge/esx/server.lua modules/bridge/qb/server.lua modules/bridge/ox/server.lua tests/inventory_return_spec.lua
git commit -m "fix(inventory): preserve add item failures"
```

---

### Task 3: Commit Undress Before Changing the PED

**Files:**
- Modify: `modules/bridge/inventory/give_items.lua`
- Modify: `core/server.lua`
- Modify: `modules/utils/client.lua`
- Modify: `locales/en.lua`
- Modify: `locales/it.lua`
- Modify: `tests/inventory_return_spec.lua`

**Interfaces:**
- Changes internal wrappers to `giveDress(src, data)`, `giveDressKit(src, data)`, `giveProp(src, data)`
- Preserves server events `giveDress`, `giveDressKit`, and `giveProp`
- Adds client event `mbt_meta_clothes:undressResult(result)`
- Request: `{ RequestId = integer, Index = integer? }`; torso sends no metadata
- Result: `{ requestId, ok, reason, kind, index? }`

- [ ] **Step 1: Add failing authoritative metadata cases**

Create fake state with rich server metadata:

```lua
local stored = {
    index = 11,
    drawable = 29,
    texture = 2,
    palette = 0,
    sex = 'male',
    item_name = 'designer_jacket',
    last_worn_by = { { identifier = 'char:1' } },
}
```

Assert that a successful return uses `designer_jacket`, preserves DNA, and clears once. Assert an add failure does not clear or mutate the live `stored` table. Add drawable, prop, torso-success, torso-failure, empty-slot, and busy cases.

- [ ] **Step 2: Verify current behavior fails**

Run `mbt_inventory_return_selftest`.

Expected: FAIL because current give functions call `ClearSlot` before `addItem` and accept client fallback metadata.

- [ ] **Step 3: Build authoritative payloads in the existing module**

In `give_items.lua`:

- add a local recursive clone so description/DNA cleanup cannot mutate live state before commit;
- read slots with `PlayerState.GetSlot` and reject missing state as `no_item`;
- resolve names with `MBT.ResolveItemName(slotConfig, clonedMetadata)`;
- run `CleanExpiredDNA` only on the cloned inventory metadata;
- call `ClearSlot` only from the post-add commit callback;
- construct `topdress` from all `MBT.TorsoKitSlots` before adding one item;
- remove `Wait(100)` from the torso flow;
- use `source:slotType:index` and `source:torso` lock keys.

Keep `MBT.GiveItems.Setup(config)` as the runtime wiring point. Its global wrappers accept `src` explicitly instead of reading ambient `source`.

- [ ] **Step 4: Acknowledge existing server events**

Validate `RequestId` as a positive bounded integer and normalize indices with `MBT.ServerUtils.ValidateSlot`. Reject a detected character rotation before building the item. Reply to valid requests:

```lua
local result = giveDress(src, { Index = index })
TriggerClientEvent('mbt_meta_clothes:undressResult', src, {
    requestId = requestId,
    ok = result.ok,
    reason = result.reason,
    kind = 'drawable',
    index = index,
})
```

Call the coordinator cleanup from the existing `playerDropped` lifecycle path.

- [ ] **Step 5: Defer client visual mutation**

Add a monotonic ID and bounded `pendingUndress` table in `modules/utils/client.lua`. The three handlers retain their local UX checks but only enqueue and send a request; they no longer call default variation first.

Add object-format locale entries `inventory_full`, `inventory_error`, and `action_busy` to both locale files. Map stable server reasons to these keys; unknown reasons use `inventory_error`. The result handler must:

```lua
local pending = pendingUndress[result.requestId]
if not pending then return end
pendingUndress[result.requestId] = nil
if not result.ok then
    local key = result.reason == 'inventory_full' and 'inventory_full'
        or result.reason == 'busy' and 'action_busy'
        or 'inventory_error'
    MBT.Notification(MBT.Locale[key])
    return
end
-- Apply the existing drawable, prop, or torso default helper here.
MBT.Utils.UpdatePlayerClothes()
if MBT.Utils.SendWearingToNUI then MBT.Utils.SendWearingToNUI() end
```

Ignore stale/unknown acknowledgements and clear pending operations in the existing multichar pause handler.

- [ ] **Step 6: Verify automated and manual cases**

Run both self-tests. Manually test drawable, prop, torso, full inventory, double click, and relog after success/failure. Expected: the PED changes only after the item appears; failure leaves PED and state unchanged.

- [ ] **Step 7: Commit**

```bash
git add core/server.lua modules/utils/client.lua modules/bridge/inventory/give_items.lua locales/en.lua locales/it.lua tests/inventory_return_spec.lua
git commit -m "fix(clothes): commit undress after inventory add"
```

---

### Task 4: Use the Same Transaction for Every Steal Mode

**Files:**
- Modify: `modules/bridge/inventory/give_items.lua`
- Modify: `core/server.lua`
- Modify: `modules/utils/client.lua`
- Modify: `core/client.lua`
- Modify: `locales/en.lua`
- Modify: `locales/it.lua`
- Modify: `tests/inventory_return_spec.lua`

**Interfaces:**
- Preserves `mbt_meta_clothes:stealSingleItem(target, stealType, slotIndex)`
- Adds `mbt_meta_clothes:stealBatch(target, selections)`
- Selection: `{ stealType = 'torso'|'drawable'|'prop', slotIndex = integer|nil }`
- Preserves `mbt_meta_clothes:stealApplyDefault` but emits it only after commit

- [ ] **Step 1: Add failing conservation tests**

Cover single drawable/prop/torso success, add failure, duplicate slot, selected batch, steal-all, partial capacity, torso deduplication, lowercase metadata, and DNA preservation.

Use this capacity fake for partial results:

```lua
local remaining = 2
local function addItem()
    if remaining == 0 then return false, 'inventory_full' end
    remaining = remaining - 1
    return true
end
```

Assert exactly two state commits and that later rejected victim slots remain present.

- [ ] **Step 2: Verify current steal paths fail**

Run `mbt_inventory_return_selftest`.

Expected: FAIL because single steal clears first and steal-all clears all state after ignoring individual add results.

- [ ] **Step 3: Implement one server-side steal primitive**

Extract a local operation in `core/server.lua`:

```lua
local function commitStealItem(thief, victim, stealType, slotIndex)
    -- Normalize type/index, call the GiveItems coordinator with victim lock,
    -- and emit stealApplyDefault only when result.ok is true.
    return result
end
```

Keep rate limit, valid-player, and proximity checks at event boundaries. Read all item data from victim `PlayerState`; the thief supplies only target/type/index.

- [ ] **Step 4: Send selected-multiple as one bounded batch**

Replace the client loop with:

```lua
TriggerServerEvent('mbt_meta_clothes:stealBatch', targetServerId, items)
```

The server applies rate limit/proximity once, rejects malformed or duplicate logical keys, caps entries to configured logical slots, sorts torso first then drawable/prop indices, and calls `commitStealItem` for each entry. Add `partial_steal` to both locale files and notify once for an empty or partial result.

- [ ] **Step 5: Route steal-all through the batch primitive**

Build selections server-side from victim state. Include torso once when any torso slot is occupied and skip torso indices as individual drawables. Delete unconditional `ClearAllSlots` calls and do not use `setDefaultDressTarget`; emit one default event per committed logical item.

- [ ] **Step 6: Remove obsolete client-authoritative metadata path**

Remove the client flow that builds `targetWearing` and triggers `giveStolenItemDress`. Preserve NUI listing and victim animation. Never accept drawable, texture, palette, DNA, description, or item name from the thief.

- [ ] **Step 7: Verify automated and manual cases**

Run both self-tests. Manually test single drawable/prop/torso, three-item selection, steal-all, full/partial capacity, simultaneous thieves, and victim relog. At most one item may be created per victim slot.

- [ ] **Step 8: Commit**

```bash
git add core/server.lua core/client.lua modules/utils/client.lua modules/bridge/inventory/give_items.lua locales/en.lua locales/it.lua tests/inventory_return_spec.lua
git commit -m "fix(steal): preserve victim state on inventory failure"
```

---

### Task 5: Final Verification and Roadmap Evidence

**Files:**
- Modify: `ROADMAP.md`
- Modify: `tests/inventory_return_spec.lua` only if a regression gap is discovered

**Interfaces:**
- Consumes: `mbt_inventory_return_selftest` and `mbt_snapshot_selftest`
- Produces: evidence-backed roadmap status; no new runtime API

- [ ] **Step 1: Run static checks**

Run `git diff --check`, then inspect all `ClearSlot`, `ClearAllSlots`, `giveStolenItemDress`, and selected `stealSingleItem` loop matches with `rg`. Expected: no return/steal path clears state before add, no unconditional victim clear, and no selected-multiple event loop.

- [ ] **Step 2: Run clean Cfx verification**

With debug enabled, restart the resource and run:

```text
mbt_snapshot_selftest
mbt_inventory_return_selftest
```

Expected: snapshot `28/28` and all inventory-return cases pass.

- [ ] **Step 3: Execute the available smoke matrix**

Test drawable, prop, torso, full inventory, single/multiple/all steal, and relog on every locally available combination:

```text
ESX + ox_inventory
QBCore + qb-inventory
QBCore + ox_inventory
OX Core + ox_inventory
Custom inventory fixture, when available
```

Record unavailable combinations as unverified, never inferred as passing.

- [ ] **Step 4: Update roadmap conservatively**

- Mark transactional add-before-clear complete only with failure-test evidence.
- Mark steal metadata/conservation complete only after partial-capacity tests.
- Leave server-authoritative dress unchecked because item use is outside this plan.
- Leave animation authorization, releases, assets, and unrelated features unchecked.
- Remove or annotate the resolver requirement as rejected by design: one active inventory is an ecosystem invariant and the existing bridge architecture is retained.

- [ ] **Step 5: Review scope and commit evidence**

Inspect `git status`, `git diff --stat`, and the full runtime diff. Expected: no item-registration, lifecycle, snapshot, NUI-build, or unrelated feature changes.

```bash
git add ROADMAP.md tests/inventory_return_spec.lua
git commit -m "test(inventory): verify safe clothing transfers"
```
