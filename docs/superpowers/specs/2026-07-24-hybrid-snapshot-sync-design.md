# Hybrid Snapshot Synchronization Design

## Status

Approved direction, pending final user review before implementation planning.

## Problem

`mbt_meta_clothes` currently detects changes made by external appearance resources by polling each managed PED slot and emitting one `externalDress` or `externalUndress` event per changed slot. A full outfit can change more slots than the per-event rate limit accepts, while the client updates its cache even when the server rejects later events. The client and `PlayerState` can therefore diverge, and logout persists an incomplete representation of the PED.

The resource must persist the real visual state of its managed PED slots across login, relog, character switching, disconnect, and resource restart without depending on Illenium, fivem-appearance, qb-clothing, or another appearance resource.

## Goals

- Keep appearance-resource compatibility based on native PED state, not named adapters.
- Represent a multi-slot outfit application as one coherent synchronization operation.
- Preserve rich server-owned clothing metadata such as DNA and `item_name`.
- Reject stale snapshots from an earlier character session or an older server state revision.
- Avoid periodic network or database work while the PED is unchanged.
- Preserve the current restore protection and internal dress/undress behavior.
- Keep the implementation scoped to `mbt_meta_clothes`.

## Non-goals

- Saving the full appearance, including face, overlays, tattoos, hair, or head blend.
- Replacing the persistence owned by an appearance resource.
- Modifying `mbt_character` or requiring it to emit new events.
- Supporting arbitrary custom PED models without an entry in `MBT.GenderModels`.
- Making client-observed PED state cheat-proof. The server will minimize trusted fields, but a client can still falsify its own visual state.
- Removing the legacy `storePlayerSkin` / `saveSkin` integration in this change. Its deprecation is a separate compatibility decision.

## Ownership Model

The appearance resource owns the complete base skin. `mbt_meta_clothes` owns the persisted overlay for configured clothing slots.

Framework events provide character lifecycle and the stable character identifier. Hybrid detection provides the most recently observed visual state of the managed slots. Inventory-driven dress and undress operations remain authoritative server operations and continue to carry rich item metadata.

## Managed Visual Snapshot

Each snapshot is a complete visual representation of every configured slot, never a delta:

```lua
{
    session = 4,
    seq = 12,
    baseRevision = 27,
    model = 1885233650,
    Drawables = {
        [3] = { drawable = 15, texture = 0, palette = 0 },
        -- every key configured in MBT.Drawables
    },
    Props = {
        [0] = { drawable = -1, texture = 0 },
        -- every key configured in MBT.Props
    }
}
```

The client must include all configured keys. Missing or extra keys reject the entire snapshot. Default slots remain explicit in the wire snapshot and become absent entries only during server reconciliation.

`session` is a server-issued generation for the active character on that source. It changes when the resolved character identifier changes. Duplicate readiness events for the same identifier reuse the generation. `seq` starts at zero for each client session generation and increases monotonically for every new submitted snapshot. `baseRevision` is the last server-owned state revision acknowledged to the client.

Every authoritative server mutation, including inventory dress/undress, steal, persistent toggle, and an accepted visual-changing snapshot, increments the server revision. The server accepts a visual-changing snapshot only when `baseRevision` equals the current revision. This prevents a snapshot captured before an inventory operation from overwriting the newer authoritative result.

Restore and new-player scan payloads carry the active session generation and server revision to the client. A duplicate readiness push for the same identifier returns the same pair rather than rotating either value.

## Client Detection Flow

1. Poll the local PED every 1,000 ms during normal play and every 500 ms while restore protection is active.
2. Read all configured drawable and prop slots and build a deterministic visual fingerprint without serializing or sending it. Fingerprints use numeric slot order sorted ascending, with fixed field order (`drawable`, `texture`, `palette`) and explicit separators; client and server use the same canonical encoding.
3. If the fingerprint equals the last server-acknowledged fingerprint, do nothing.
4. If it differs while external capture is allowed, start or reset a 400 ms debounce.
5. At debounce expiry, re-read the full snapshot. If it changed again, restart the debounce; otherwise submit one batch event.
6. Keep at most one snapshot in flight. The client promotes its acknowledged fingerprint and server revision only after a positive server acknowledgement.
7. On acknowledgement timeout, retry the identical payload with the same sequence. The server treats this duplicate idempotently and repeats the cached acknowledgement without mutating state.
8. On rejection, discard the pending payload, adopt the returned current session/revision only when it belongs to the active character, and build a fresh snapshot after a bounded delay. Repeated failures produce one actionable warning rather than a hot retry loop.

External capture is disabled while any of these conditions is active:

- hybrid detection is paused for character switching;
- restore protection is active;
- the player model/PED is being replaced;
- an internal dress, undress, toggle, steal, or restore operation is applying components.

Internal mutation guards use scoped counters or expiring tokens, not permanent per-slot booleans. A failed or cancelled internal action cannot suppress an unrelated future appearance change. When the last guard exits, the cache is rebased to the expected server state and normal observation resumes.

Persistent MBT toggles, such as jacket open/closed or visor forward/backward, are authoritative internal visual mutations. They update the visual fields of the existing server metadata while preserving its rich fields and increment the server revision. Hair toggles remain outside snapshot scope because hair is not a managed slot.

Temporary suppression through `suppressSlot`, such as hiding a prop under another wearable, is not a change of clothing ownership. The client keeps the pre-suppression canonical visual value in a suppression registry and substitutes that canonical value when building a snapshot. `restoreSlot` clears the suppression entry after restoring the visual. A suppressed PED value must never replace or clear the underlying rich metadata.

## Server Validation

The server rejects the whole batch unless all of the following hold:

- the source has an active loaded `PlayerState` and character identifier;
- `session` matches the server generation for that identifier;
- `seq` is greater than the last accepted sequence, or equal only for an exact idempotent retry of the cached request;
- `baseRevision` matches the current server revision for a visual-changing request;
- `model` exists in `MBT.GenderModels`;
- `Drawables` and `Props` contain exactly the configured slot keys;
- every field is an integer within the explicit `MBT.SnapshotBounds` limits: component drawable `0..4095`, prop drawable `-1..4095`, texture `0..255`, palette `0..3`, and encoded payload at most 16 KiB;
- props allow `-1` only as the empty drawable;
- payload depth and encoded size remain bounded;
- the snapshot event passes a dedicated low-frequency rate limit.

Only visual fields are accepted. The client cannot submit `item_name`, DNA, ownership history, labels, descriptions, or arbitrary metadata through snapshot synchronization.

## Atomic Reconciliation

After complete validation, the server builds a new wearing table without mutating the live table. A slot is a configured default when its drawable appears in the sex-specific `Default` list; texture and palette are ignored for default classification and normalized away, matching current resource behavior. For each managed slot:

- If the snapshot value is a configured default, the new state has no entry for that slot.
- If an existing server entry has the same drawable, texture, and palette, preserve the complete existing metadata table unchanged.
- If the visual value is new or different, create sanitized metadata containing only `index`, `drawable`, `texture`, `palette` where applicable, normalized `sex`, `type`, and `provenance = "external"`.

If the canonical visual fingerprint equals the current server visual fingerprint, the request is an accepted no-op: advance the accepted sequence and acknowledge the current revision without swapping state, emitting change events, or marking the player dirty. This also handles a fresh sequence built from an already-current PED state.

For a visual-changing request with a matching base revision, the server swaps the complete wearing table in one operation, increments the state revision, marks the player dirty once, stores the accepted sequence and acknowledgement, and emits `mbt_meta_clothes:onClothingChanged` only for slots whose effective state changed. This preserves downstream consumers while preventing observers from seeing a partially reconciled outfit.

A request whose sequence equals the last accepted sequence is an idempotent retry: return the cached acknowledgement without any mutation. The server retains at least the most recently accepted request fingerprint and acknowledgement for the lifetime of the active character session. A lower sequence is rejected. A base-revision mismatch whose canonical fingerprint already equals the current server fingerprint is acknowledged as a no-op at the current revision; any other mismatch is rejected as `stale_revision` and returns the canonical current revision/state needed for rebase.

The server acknowledges the accepted sequence and canonical visual fingerprint. A rejected snapshot receives a negative acknowledgement with a stable reason code and the current session generation. The client never treats a rejected snapshot as synchronized.

## Interaction With Internal Operations

Inventory-based dress, undress, steal, and persistent toggle operations continue to update `PlayerState` immediately through server paths. They do not wait for hybrid polling. Each successful mutation increments the state revision and returns or pushes the new revision to the active client. The client invalidates any pending snapshot based on an older revision, marks the corresponding component application as internal, and rebases its visual cache after the operation.

Restore applies the server state to the PED while external capture is disabled. When restore protection ends, the client performs a fresh baseline scan. A temporary value applied by an appearance resource during restore must be reverted or ignored, never persisted as a new external snapshot.

Server reconciliation must not mint privileged item metadata. Whether an externally sourced visual garment may later become a generic inventory item remains existing product behavior and is not expanded by this change; `provenance` makes a future stricter policy possible.

## Persistence And Lifecycle

Accepted snapshots update memory only when the visual fingerprint changes. They do not query MySQL on every poll.

- Graceful framework logout/relog: pause new capture and persist the latest already accepted state. The base design does not wait for a final client round trip because framework event ordering cannot guarantee that it completes before identity rotation.
- Native `playerDropped`: persist the latest already accepted state; no client round trip is assumed.
- Resource stop: flush dirty states using the existing synchronous save path.
- Periodic save: retain the existing dirty flush as a fallback.
- Write-behind: enabled by default at five seconds. After an accepted visual-changing external snapshot, schedule one per-player save after five seconds of quiet. Further accepted changes reset the timer. A lifecycle save cancels the pending timer after saving. Setting `MBT.SnapshotWriteBehind` to `0` disables it. This bounds loss on process crashes without producing one query per poll or preview change.

The drop guarantee is therefore the last accepted stable snapshot, normally no more than roughly 1.5 seconds behind a sudden disconnect because it includes polling and debounce latency. Internal dress/undress state remains immediate on the server. This bounded lag, rather than an unreliable logout handshake, is the universal compatibility contract.

## Rate Limiting And Performance

Normal polling performs approximately 22 lightweight native reads per second on each player's own client, matching the current order of work. An idle player sends no network event. A changed outfit sends one request and one acknowledgement instead of up to eleven independent events.

The server performs bounded table validation and reconciliation only on actual changes. Database traffic occurs only on lifecycle flush, periodic fallback, or the quiet write-behind timer.

## Failure Handling

- Duplicate sequence: repeat the cached acknowledgement without mutation.
- Stale sequence: reject without mutation and acknowledge `stale_seq`.
- Stale server revision: reject `stale_revision`, return canonical revision/state, and require client rebase.
- Wrong character generation: reject with `wrong_session`; client discards pending state and waits for the active restore/readiness payload.
- Incomplete or invalid snapshot: reject with `invalid_snapshot`; keep the prior server state.
- Lost acknowledgement: retry the identical payload with the same sequence so the operation is idempotent.
- Repeated rejection: stop rapid retry, log once, and request a canonical restore from the server.
- Appearance changes continuously during preview: debounce until stable; do not flood the server.
- Custom PED: skip synchronization and preserve the last valid state unless future configuration maps that model.

## Compatibility

The design remains appearance-resource agnostic for scripts that ultimately apply standard GTA component and prop variations to a configured freemode PED. Framework bridges remain responsible only for identity and lifecycle. No appearance-specific event names or exports are required.

## Verification Scenarios

1. Apply an eleven-slot saved outfit through an external appearance menu; one complete snapshot reaches the server.
2. Change the same outfit repeatedly during preview; only the final stable state is accepted.
3. Dress and undress through MBT items; rich metadata and DNA survive subsequent identical snapshots.
4. Change one external drawable over an existing MBT item; privileged metadata is not copied into the new external entry.
5. Send a snapshot with missing, extra, malformed, or extreme fields; no server state changes.
6. Deliver sequence 12 before sequence 11; sequence 11 is rejected.
7. Switch characters rapidly and deliver a late snapshot from the previous session; it is rejected.
8. Apply an appearance during restore protection; it is reverted or ignored and not persisted.
9. Disconnect abruptly after a stable external change; reconnect restores the last accepted snapshot.
10. Restart `mbt_meta_clothes` with a player online; state saves and restores without duplicate inventory items.
11. Leave the PED unchanged for several minutes; no snapshot network events or snapshot-driven DB writes occur.
12. Capture a snapshot, then complete an inventory dress before it arrives; reject the snapshot by stale server revision.
13. Lose an acknowledgement and retry the same sequence; return the cached acknowledgement without dirtying state twice.
14. Toggle an open jacket and visor; update visual fields while preserving rich item metadata and restore the toggled state after relog.
15. Suppress a prop temporarily through `suppressSlot`; snapshots retain the underlying canonical metadata until `restoreSlot`.
16. Submit a configured-default drawable with nonzero texture or palette; normalize it to an absent wearing entry and the canonical default fingerprint.

## Implementation Boundaries

The implementation should be limited to:

- client hybrid detection and internal mutation guards;
- the snapshot request/acknowledgement events;
- server validation and atomic `PlayerState` reconciliation;
- per-character session and sequence tracking;
- server state revision tracking and idempotent acknowledgement caching;
- focused configuration for debounce, acknowledgement timeout, explicit bounds, and five-second write-behind;
- tests or deterministic test helpers for validation and reconciliation.

Unrelated framework resolver, inventory transaction, UI, roadmap, and appearance-preview work remain separate tasks.
