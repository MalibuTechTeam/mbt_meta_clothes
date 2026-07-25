# Inventory Return Safety Design

## Status

Approved direction, pending final user review before implementation planning.

## Problem

`mbt_meta_clothes` currently clears a worn slot from `MBT.PlayerState` before it knows whether the inventory accepted the corresponding item. The framework-specific `addItem` functions also discard the result returned by the inventory.

If an inventory is full, an item is missing from its definitions, or an inventory export fails, the PED may already have been undressed and the authoritative worn state may already have been cleared. The clothing item can therefore be lost. The same ordering exists in single-item stealing and torso-kit stealing.

This change must fix that failure mode without introducing an inventory resolver, reorganizing the bridge folders, or replacing the current usable-item registration.

## Goals

- Preserve the current ESX, QB and OX bridge structure.
- Preserve the current OX and QB item-registration paths.
- Make returning a worn drawable, prop, or torso kit to inventory all-or-nothing from the resource's point of view.
- Make single-item and steal-all operations use the same safe ordering.
- Preserve complete server-owned metadata, including DNA and resolved `item_name` information.
- Prevent duplicate requests against the same player slot while an operation is in progress.
- Report inventory failures to the requesting client without changing the PED or `PlayerState`.

## Non-goals

- Adding an inventory or framework resolver.
- Supporting two simultaneously active inventory resources.
- Moving the existing bridge or item-registration files.
- Replacing `MBT.OxItems.RegisterItems`, `MBT.QbItems.RegisterItems`, or `MBT.QbUseable.RegisterItems`.
- Making the existing dress/use-item flow fully server-authoritative in this change. That requires a separate protocol design because OX and QB currently consume and expose usable items differently.
- Adding new gameplay features or changing the clothing metadata schema.

## Existing Architecture Preserved

Each active framework bridge continues to call `MBT.GiveItems.Setup` with its framework-specific player helpers and `addItem` implementation. The shared `modules/bridge/inventory/give_items.lua` remains the coordinator for returning worn clothing to an inventory.

The only bridge contract change is that `config.addItem` must return an explicit result:

```lua
true, nil
false, "inventory_full"
```

Inventory-specific raw return values are normalized locally inside the existing ESX, QB, and OX bridge files. This is not a new global inventory adapter.

The custom inventory callback keeps its existing configuration surface but receives the correct arguments (`source`, `itemName`, `count`, `metadata`) and must return a boolean. A missing or invalid result is treated as failure, not success.

## Operation Lock

The shared give-items module keeps a small in-memory lock keyed by the state owner and affected logical slot:

```text
<source>:Drawables:<index>
<source>:Props:<index>
<source>:torso
```

The lock is acquired before reading authoritative metadata and released on every success or failure path. A duplicate request while locked is rejected as `busy`. Locks are also discarded when the player drops or the resource stops.

For stealing, the lock belongs to the victim's slot, not the thief, because the victim's `PlayerState` is the conserved source. Steal-all acquires and releases these logical locks through the same operation primitive rather than maintaining a separate mutation path.

## Safe Undress Flow

The client no longer permanently applies the default variation before the server confirms the inventory operation.

1. The client requests an undress using only the logical slot/type required by the existing action.
2. The server validates the slot and acquires its operation lock.
3. The server reads the metadata with `MBT.PlayerState.GetSlot`; it does not clear the slot.
4. The server builds the returned item from that authoritative metadata and resolves its configured item name.
5. The active bridge attempts `addItem` and returns a normalized success result.
6. On failure, the server releases the lock and tells the client to keep or restore the current visual state.
7. On success, the server clears the same slot from `PlayerState`, releases the lock, and tells the client to apply the configured default.

Because the slot is locked and checked immediately before `addItem`, `ClearSlot` is deterministic after a successful add. If the expected metadata is unexpectedly absent at commit time, the operation emits an error diagnostic and does not issue another client visual mutation.

## Torso Kit Flow

The torso kit is one logical operation covering every index in `MBT.TorsoKitSlots`.

1. Acquire the single torso lock.
2. Read all torso metadata without clearing any slot.
3. Build one `topdress` metadata object, preserving stored rich metadata for every occupied torso slot and using configured defaults only where the existing behavior requires them.
4. Add the single `topdress` item.
5. Only after success, clear all participating torso slots and instruct the client to apply their defaults.

The operation cannot return a partial torso kit or clear only part of the torso state.

## Safe Steal Flow

Single drawable, prop, and torso stealing follow the same order:

1. Keep the existing rate-limit, player validity, proximity, type, and slot validation.
2. Acquire a lock on the victim's affected slot or torso group.
3. Read the victim's authoritative metadata without clearing it.
4. Attempt to add the resulting item to the thief.
5. If the inventory rejects it, leave the victim state and PED unchanged.
6. If it succeeds, clear the victim state and emit `stealApplyDefault`.

The server never clears the victim first. A failed steal therefore cannot destroy clothing.

Steal-all reuses this primitive for every logical item in deterministic slot order. It is not presented as one inventory-wide atomic transaction because the supported inventories do not share a reliable batch-add and rollback API. Instead:

- every successfully added logical item clears only its corresponding victim slot or torso group;
- every rejected item remains worn and present in the victim's `PlayerState`;
- the server returns the exact set of committed slots;
- the victim client applies defaults only to that committed set;
- the thief receives a summary notification when the result is partial or empty.

This permits a capacity-limited partial steal while preserving the conservation invariant for every individual clothing item. It never clears all victim slots unconditionally after attempting multiple additions.

## Client Acknowledgement

Undress requests receive one bounded acknowledgement containing:

```lua
{
    ok = true | false,
    reason = "inventory_full" | "busy" | "invalid_slot" | "no_item" | nil
}
```

Only a successful acknowledgement allows the client to finalize the default PED variation. Failure produces the existing notification style and refreshes the local clothing cache from the unchanged PED.

Steal operations notify the thief on failure and mutate the victim PED only after server success.

## Failure Handling

- Inventory full or overweight: retain state and PED; return `inventory_full`.
- Unknown inventory item: retain state and PED; return `add_failed` and log the item name.
- Duplicate request: retain state and PED; return `busy`.
- Slot already empty: return `no_item` without touching inventory.
- Player or character changes during the request: reject before commit and retain the original character state.
- Custom inventory callback missing or returning a non-boolean result: fail closed and emit one actionable warning.

## Diagnostics

Diagnostics use the existing MBT logging style and include operation, source, target when present, slot type/index, item name, and stable failure reason. Successful normal operations remain silent unless debug logging is enabled.

No inventory polling, periodic task, or additional database write is introduced.

## Verification Scenarios

1. Undress a drawable with free inventory capacity; receive one item with complete metadata and clear the worn slot.
2. Undress a prop with a full inventory; keep the prop on the PED and in `PlayerState`, with no item created.
3. Undress a torso kit; create exactly one `topdress` and clear all torso slots only after success.
4. Submit two rapid requests for the same slot; at most one item is created.
5. Steal one drawable successfully; create one thief item, then clear and visually reset the victim slot.
6. Attempt a steal while the thief inventory is full; preserve the victim state and PED.
7. Attempt two simultaneous steals against the same victim slot; at most one succeeds.
8. Use steal-all with enough capacity; transfer every logical item and reset exactly the committed victim slots.
9. Use steal-all with capacity for only part of the outfit; retain every rejected item on the victim and clear only successful slots.
10. Use rich metadata containing DNA, description, texture, palette, and resolved item name; preserve it in the returned item.
11. Make the custom inventory callback fail or return no value; retain state and report a controlled failure.
12. Relog after a successful, partial, or failed operation; restore the last authoritative result without duplication.

## Implementation Boundaries

Implementation is limited to:

- normalized `addItem` returns in the existing framework bridge files;
- the existing shared give-items module;
- the existing undress request/client completion flow;
- the existing steal handlers;
- focused operation-lock and transaction tests.

Item registration, framework lifecycle, snapshot synchronization, roadmap features, and the dress/use-item protocol remain unchanged.
