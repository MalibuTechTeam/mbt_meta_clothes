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
      (`28/28` passed on 2026-07-24).
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

- [ ] Make dress and undress operations server-authoritative.
  - Never create inventory metadata from untrusted client payloads.
  - Reject an undress request when the corresponding server wearing slot is empty.
  - Correlate item use with the server-side inventory operation.
- [ ] Make inventory mutations transactional.
  - Check inventory capacity before removing a worn slot.
  - Clear the wearing state only after `AddItem` succeeds.
  - Preserve or restore the previous state when an inventory adapter fails.
  - Return a localized error notification to the player.
- [ ] Repair steal-all metadata.
  - Standardize on `drawable`, `texture`, and `palette` lowercase keys.
  - Preserve DNA and all original metadata when an item changes owner.
  - Remove the obsolete client `giveStolenItemDress` event path.
- [ ] Harden steal and animation events.
  - Validate numeric duration and clamp both minimum and maximum values.
  - Validate target, slot, metadata shape, action state, and proximity server-side.
- [ ] Repair the GitHub release workflow.
  - Install dependencies and build `web/dist` during the release job.
  - Include `core`, `data`, `locales`, runtime web assets, modules, and manifest files.
  - Validate the archive against every path referenced by `fxmanifest.lua`.
  - Update deprecated GitHub Actions and output syntax.

## P1 - Required for a stable 2.0

- [ ] Add a single framework and inventory resolver.
  - Select exactly one framework: ESX, QBCore, or OX Core.
  - Select exactly one inventory adapter and expose a common result contract.
  - Fail early with a useful startup error for unsupported combinations.
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
- [ ] Reduce production-only diagnostics.
  - Keep actionable warnings, but route verbose multichar traces through `MBT.Debug`.

## P2 - Quality and maintainability

- [ ] Add automated tests for pure Lua helpers and metadata normalization.
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
