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
- [x] Keep connected hot-resource recovery non-obscuring while preserving the
      guarded hide/reveal lifecycle for spawn and character switching.
  - [x] Runtime verified on 2026-07-28: connected resource restart restored the
        authoritative wearing state without changing PED visibility.
- [x] Complete Lua parser checks, `git diff --check`, web lint, and independent
      protocol/lifecycle code review.
- [x] Run `mbt_snapshot_selftest` in an actual Cfx server with `MBT.Debug = true`
      (`36/36` passed on 2026-07-28).
- [x] Verify the primary relog case: logout without jacket and reconnect without
      the jacket being duplicated on the PED and in inventory.
- [ ] Complete the remaining end-to-end verification: six-or-more-slot external
      outfit, rich jacket metadata, rejected toggle rollback, rapid character
      A-to-B switch, abrupt disconnect, and unchanged-player idle period.

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
  - Reserve the operation per logical slot and commit the authoritative wearing
    state before `AddItem`, restoring the exact previous metadata if the adapter
    rejects or throws.
  - Avoid inventory-specific compensating deletes, which cannot reliably identify
    the exact slot created by every supported inventory.
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
  - Require the victim-owned replicated down/surrender observation at both begin
    and completion so a modified thief cannot forge another player's eligibility.
  - Select victim/thief animations and effective durations from a fixed server
    catalog; clients cannot relay arbitrary dictionaries, clips, or durations.
  - Serialize active thief/victim sessions and retain the old event names only as
    non-mutating compatibility tombstones for one release cycle.
- [x] Repair the GitHub release workflow.
  - [x] Install dependencies with Bun and build `web/dist` during the release job.
  - [x] Include `core`, `data`, `locales`, runtime web assets, modules, and manifest files.
  - [x] Validate the archive against every path referenced by `fxmanifest.lua`.
  - [x] Update deprecated GitHub Actions and output syntax.

The authoritative dress, transactional return, persistence guard, and steal
implementations pass both their pure-Lua checks and the running Cfx self-tests:
snapshot `36/36`, inventory return `22/22`, dress authority `8/8`, inventory
adapters `5/5`, client startup `1/1`, steal authority `11/11`, and state save
guard `3/3` (latest runtime verification on 2026-07-29). The intentional
`admin_item` rejection warning confirms that forged item metadata reaches neither
the inventory add operation nor the authoritative state commit.
Equip, undress, relog, and connected resource-restart paths were also verified in
game with both QB Inventory and OX Inventory against commit `d0a9f0e`. End-to-end
inventory-full, partial-batch, and two-player tokenized stealing remain pending.

### Pre-release gameplay backlog

- [ ] Verify tokenized stealing with two connected players before release.
  - Complete one single-item theft and confirm item metadata, victim state, and
    thief inventory are updated exactly once.
  - Cancel an active theft and confirm no item or wearing state changes owner.
  - Exercise multi-select and steal-all with limited thief capacity, confirming
    that only successful transfers commit and failed slots remain on the victim.
  - Retry or replay a completed request and confirm no duplicate item is created.

## P1 - Required for a stable 2.0

- [x] Enforce the existing single-active-inventory invariant.
  - [x] Preserve the current bridge/resource-detection architecture: MBT servers
    run one inventory implementation at a time, independently of the framework.
  - [x] Expose one explicit success/failure result contract from every inventory
    adapter without changing item registration ownership.
  - [x] Fail early with a useful startup error when no supported inventory adapter
    is active and no custom adapter is configured.
- [x] Align optional and required dependencies.
  - [x] Keep `ox_lib` optional with native notification and timed progress fallbacks.
  - [x] Enforce and document the `MBT.CustomInventory(source, itemName, count, metadata)` result contract.
- [x] Fix and enforce the NUI type contract.
  - [x] Add `extraStateUpdate` to the `NUIMessage` union.
  - [x] Add `typecheck` and `check` package scripts.
  - [x] Run lint, type-check, and production build in CI.
- [ ] Complete runtime assets.
  - Add `item_image/bracelet.png`.
  - Add `item_image/jacket.png`, which is referenced by the configured drawable
    slot and the generated QB item definition.
  - Add the missing male backpack layer; it is explicitly disabled until supplied.
  - [x] Explicitly disable missing female mannequin layers instead of requesting broken images.
  - [x] Add an automated check for layer paths declared by the frontend.
- [ ] Verify first-open NUI smoothness in the FiveM CEF runtime.
  - [x] Cap declared clothing layers at 1024px, reducing estimated decoded PNG
    memory from 183.12 MB to 51.12 MB.
  - [x] Decode layer assets sequentially during idle periods instead of starting
    every decode concurrently at resource startup.
  - [x] Replace animated multi-filter chains with a static glow filter and an
    opacity-only overlay animation.
  - [x] Remove permanent large-surface drop shadows during mannequin entrance
    and move hotspot pulses from Framer Motion controls to compositor CSS.
  - [ ] Compare the first and subsequent openings in game and confirm layer
    alignment, image quality, hover glow, active pulse, and pedestal timing.
- [x] Add startup configuration validation.
  - [x] Validate slot defaults, item names, torso-kit mappings, locales, and drip levels.
  - [x] Detect duplicate item names and conflicting clothing-state mappings.
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
- [x] Add a release smoke path that starts from GitHub Actions' clean checkout,
      installs with the frozen Bun lockfile, runs the complete web check, stages
      the runtime resource, validates every manifest path, and verifies the ZIP.
  - [ ] Confirm the workflow on the first 2.0 prerelease tag before release.
- [x] Document installation, dependency order, supported compatibility matrix,
      inventory item definitions, database behavior, build, deploy, and upgrades.
- [ ] Remove obsolete event paths and reduce global functions shared between modules.
  - [x] Move inventory-return, wearable-state, and steal-menu helpers into their
    existing MBT module namespaces instead of resource-wide Lua globals.
  - [ ] Remove the one-release compatibility tombstones after the 2.0 transition.

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
- [ ] Introduce persisted schema versioning only when a planned incompatible data
      change requires a concrete migration; keep it outside the 2.0 scope for now.
- [ ] Accessibility pass for keyboard navigation, focus handling, contrast, reduced
      motion, and screen-size scaling in the NUI.

## Rejected investigations

- Ambient-NPC clothing theft was rejected after runtime probing. Standard GTA
  ambient ped models generally expose baked clothing or alternate dressed
  variations rather than removable components, and their drawable IDs are
  model-specific, so they cannot become faithful freemode-player clothing items.

## Definition of done for 2.0

- No client-triggered path can generate an item without a valid server-owned slot.
- Inventory failure never deletes a worn item or victim state.
- Dress, undress, stealing, reconnect, and multichar scenarios pass on every
  supported framework/inventory combination.
- ESLint, TypeScript, production build, automated tests, and release smoke test pass.
- A release archive produced from a clean tag contains a runnable FiveM resource.
- Installation and upgrade instructions match the shipped artifact.
