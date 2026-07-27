# MBT Meta Clothes 2.0 Roadmap

Baseline: `feat/v2.0.0` at commit `627511f`.

This roadmap separates release blockers from product improvements. Items in
the candidate section are not automatically part of the 2.0 release scope.

## Relog and managed-slot snapshot synchronization

- [x] Implement one canonical full snapshot for all configured drawable and prop
      slots, with debounce, one in-flight request, ACK/retry, payload bounds, and
      no database write while the PED is unchanged.
- [x] Bind snapshots to a server-issued character session and authoritative state
      revision so late multichar or pre-inventory snapshots cannot overwrite newer
      state.
- [x] Preserve rich item metadata when the visual state is unchanged, and persist
      only sanitized visual metadata for externally changed slots.
- [x] Protect restore, internal dress/toggle operations, temporary prop suppression,
      PED replacement, resource restart, and duplicate framework readiness events.
- [x] Complete Lua parser checks, `git diff --check`, web lint, and independent
      protocol/lifecycle code review.
- [x] Run `mbt_snapshot_selftest` in an actual Cfx server with `MBT.Debug = true`
      (`33/33` passed on 2026-07-27).
- [x] Verify the primary relog case: logout without jacket and reconnect without
      the jacket being duplicated on the PED and in inventory.
- [ ] Complete the remaining end-to-end verification: six-or-more-slot external
      outfit, rich jacket metadata, rejected toggle rollback, rapid character
      A-to-B switch, abrupt disconnect, unchanged-player idle period, and resource
      restart while connected.

The primary relog defect is now runtime-verified. Snapshot synchronization is not
considered release-verified across all lifecycle paths until the remaining scenario
matrix above passes.

## P0 - Release blockers

- [x] Make dress and undress operations server-authoritative.
  - [x] Never create inventory metadata from untrusted client payloads.
  - [x] Reject an undress request when the corresponding server wearing slot is empty.
  - [x] Build returned-item metadata from the authoritative server wearing state.
  - [x] Correlate item use with the server-side inventory operation.
- [x] Make inventory returns transactional.
  - Add the item before removing a worn slot, using the inventory adapter result
    as the capacity/failure decision.
  - Clear the wearing state only after `AddItem` succeeds.
  - Preserve the previous state when an inventory adapter fails.
  - Return a localized error notification to the player.
- [x] Repair steal single, multiple, and steal-all ownership transfer.
  - Preserve authoritative lowercase visual metadata, DNA, and original metadata
    when an item changes owner.
  - Commit and visually clear only the victim slots whose `AddItem` succeeded.
  - Use one validated, bounded server batch for multi-select and steal-all.
  - Remove the obsolete client `giveStolenItemDress` event path.
- [x] Harden steal and animation events.
  - Use a server-issued, source-bound, expiring, one-use token across begin and
    complete; reject direct, replayed, early, and stale completion attempts.
  - Revalidate target, character context, proximity, and normalized selections
    before the authoritative inventory transfer.
  - Select victim/thief animations and effective durations from a fixed server
    catalog; clients cannot relay arbitrary dictionaries, clips, or durations.
  - Serialize active thief/victim sessions and retain the old event names only as
    non-mutating compatibility tombstones for one release cycle.
- [ ] Repair the GitHub release workflow.
  - Install dependencies and build `web/dist` during the release job.
  - Include `core`, `data`, `locales`, runtime web assets, modules, and manifest files.
  - Validate the archive against every path referenced by `fxmanifest.lua`.
  - Update deprecated GitHub Actions and output syntax.

The authoritative dress, transactional return, and steal implementations pass
their pure-Lua checks: snapshot `33/33`, inventory return `21/21`, dress authority
`8/8`, inventory adapters `5/5`, client startup `1/1`, and steal authority `10/10`.
The snapshot, inventory return (`19/19` before the item-name hardening cases),
dress, and adapter suites also passed in the running Cfx server on 2026-07-27;
the new `21/21` return and `10/10` steal suites still require a resource restart.
Equip, undress, relog, and connected resource-restart paths were also verified in
game with both QB Inventory and OX Inventory against commit `d0a9f0e`. End-to-end
inventory-full, partial-batch, and two-player tokenized stealing remain pending.

## P1 - Required for a stable 2.0

- [ ] Enforce the existing single-active-inventory invariant.
  - [x] Preserve the current bridge/resource-detection architecture: MBT servers
    run one inventory implementation at a time, independently of the framework.
  - [x] Expose one explicit success/failure result contract from every inventory
    adapter without changing item registration ownership.
  - [ ] Fail early with a useful startup error when no supported inventory adapter
    is active and no custom adapter is configured.
- [ ] Align optional and required dependencies.
  - Decide whether `ox_lib` is required or provide notification/progress fallbacks.
  - Fix the `MBT.CustomInventory(source, itemName, count, metadata)` contract.
- [ ] Fix and enforce the NUI type contract.
  - Add `extraStateUpdate` to the `NUIMessage` union.
  - Add `typecheck` and `check` package scripts.
  - Run lint, type-check, and production build in CI.
- [ ] Complete runtime assets.
  - Add `item_image/bracelet.png`.
  - Add the missing male backpack layer.
  - Add or deliberately disable missing female mannequin layers.
  - Add an automated check for layer paths declared by the frontend.
- [ ] Add startup configuration validation.
  - Validate slot defaults, item names, torso-kit mappings, locales, and drip levels.
  - Detect duplicate item names and conflicting clothing-state mappings.
- [x] Reduce production-only diagnostics.
  - Adopt the canonical vendored MalibuTech logger used by `mbt_character` and
    `mbt_malisling`, preserving the historical `MBT.*` aliases.
  - Keep actionable warnings visible, but route verbose lifecycle and multichar
    traces through `MBT.Debug`.

## P2 - Quality and maintainability

- [x] Add automated tests for snapshot helpers, inventory-return transactions,
      steal batch validation, partial failures, and metadata preservation.
- [ ] Add integration scenarios for dress, undress, inventory-full, steal single,
      steal multiple, steal all, reconnect, and rapid multichar switching.
- [ ] Add a release smoke test that starts from a clean checkout.
- [ ] Document installation, dependency order, supported compatibility matrix,
      inventory item definitions, database behavior, build, deploy, and upgrades.
- [ ] Remove obsolete event paths and reduce global functions shared between modules.
- [ ] Add a migration/version field to persisted wearing data.

## Feature candidates after stabilization

- [ ] DNA forensics user flow: permissioned inspection/cleaning command or UI,
      audit logging, and configurable integrations for police resources.
- [ ] Drip administration: permissioned inspect, grant, reset, and migration tools.
- [ ] Optional drip leaderboard and configurable seasonal progression.
- [ ] Exported API/callbacks for appearance resources to pause, resume, and confirm
      an outfit change without relying only on PED polling.
- [ ] Configuration tooling for addon clothing toggle pairs and custom drawables.
- [ ] Explicit custom-ped support policy, with adapters where drawable metadata is
      available and a clear unsupported response otherwise.
- [ ] Accessibility pass for keyboard navigation, focus handling, contrast, reduced
      motion, and screen-size scaling in the NUI.

## Definition of done for 2.0

- No client-triggered path can generate an item without a valid server-owned slot.
- Inventory failure never deletes a worn item or victim state.
- Dress, undress, stealing, reconnect, and multichar scenarios pass on every
  supported framework/inventory combination.
- ESLint, TypeScript, production build, automated tests, and release smoke test pass.
- A release archive produced from a clean tag contains a runnable FiveM resource.
- Installation and upgrade instructions match the shipped artifact.
