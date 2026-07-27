# Installation and operations

## Requirements

Required:

- FiveM server artifact 6116 or newer
- OneSync
- `oxmysql`
- one supported framework: `es_extended`, `qb-core`, or `ox_core`
- one supported inventory for that framework

Optional:

- `ox_lib` for notifications and progress UI; native/timed fallbacks are built in
- `ox_target`, `qb-target`, or `qtarget` for clothing theft interactions
- `mbt_wearable_props` for the mask, bag, and armor slots configured in
  `MBT.WearablePropsSlots`

## Compatibility matrix

| Framework | ox_inventory | qb-inventory | MBT.CustomInventory |
| --- | --- | --- | --- |
| ESX | Yes | No | Yes |
| QBCore | Yes | Yes | Yes |
| OX Core | Yes | No | No |

Only one framework and one inventory implementation may be active. A custom
inventory callback is considered the inventory implementation when neither
`ox_inventory` nor `qb-inventory` is running.

`MBT.CustomInventory` handles the authoritative addition of clothing returned
from the PED. A custom inventory must also provide its own usable-item integration
that invokes the Meta Clothes dress flow; that registration cannot be inferred
from the add-item callback alone.

## Start order

Follow the standard MBT resource lifecycle: dependencies first, MBT resources
afterward. Examples:

```cfg
ensure oxmysql
ensure es_extended
ensure ox_inventory
ensure mbt_meta_clothes
```

```cfg
ensure oxmysql
ensure qb-core
ensure qb-inventory
ensure mbt_meta_clothes
```

If the framework or inventory is restarted, restart `mbt_meta_clothes`
afterward so its bridge, hooks, and usable-item handlers are registered against
the current dependency instance.

## Configuration

Copy the resource without renaming its folder, then review `config.lua`.

At minimum:

1. Select `MBT.Language` and the menu key.
2. Verify the male and female defaults under `MBT.Drawables` and `MBT.Props`.
3. Enable only the target and optional integrations installed on the server.
4. Review snapshot, rate-limit, stealing, DNA, and drip settings.
5. Set `MBT.Debug = false` after installation and runtime verification.

Startup validation checks numeric bounds, slot defaults, item names, torso-kit
mappings, locales, drip levels, callback types, framework state, and inventory
state. Invalid configuration stops the resource before gameplay handlers load.

## Inventory items

Item names are derived from `MBT.Drawables[*].Item` and `MBT.Props[*].Item`.
`topdress` is always registered as the torso-kit item. With the default config,
the complete set is:

| Item | Purpose |
| --- | --- |
| `topdress` | Torso kit (arms, undershirt, and top) |
| `trousers` | Drawable slot 4 |
| `shoes` | Drawable slot 6 |
| `chain` | Drawable slot 7 |
| `jacket` | Drawable slot 11 registration |
| `hat` | Prop slot 0 |
| `glasses` | Prop slot 1 |
| `earaccess` | Prop slot 2 |
| `watch` | Prop slot 6 |
| `bracelet` | Prop slot 7 |

### ox_inventory

Define every configured item in `ox_inventory/data/items.lua`. The client export
must match its item name:

```lua
['trousers'] = {
    label = 'Trousers',
    weight = 100,
    stack = false,
    close = true,
    client = {
        export = 'mbt_meta_clothes.trousers'
    }
},
```

Repeat the definition for every name in the table above, changing both the key
and export suffix. Clothing items should not stack because each instance carries
unique drawable, texture, sex, provenance, and optional DNA metadata. Copy the
matching PNG files from `item_image` into the inventory image directory. Do not
change an item name in the inventory without changing the corresponding config
entry.

### qb-inventory

When the QBCore and qb-inventory bridges start, Meta Clothes derives the configured
items and registers them through QBCore. It also registers each item as usable.
Copy the supplied PNG files from `item_image` into the qb-inventory image
directory and provide images for any configured items that are not bundled. In
the current 2.0 roadmap, `bracelet.png` and `jacket.png` are still pending. If a
server build does not allow runtime shared-item registration, mirror the same
names in that server's QBCore shared items file.

## Custom inventory callback

ESX and QBCore servers may provide an add-item adapter in `config.lua`:

```lua
MBT.CustomInventory = function(source, itemName, count, metadata)
    local success = YourInventoryAddItem(source, itemName, count, metadata)
    return success == true, success and nil or 'add_failed'
end
```

The callback must preserve `metadata` unchanged and return `true` only after the
item has been added. On failure it must return `false` and a stable reason such as
`inventory_full` or `add_failed`. Missing, thrown, or non-boolean results fail
closed and leave the authoritative wearing state unchanged.

## Database behavior

No manual SQL import is required. On startup, Meta Clothes creates
`mbt_player_wearing` through oxmysql and ensures the `drip_xp` column exists.

The table stores:

- the framework character identifier as the primary key;
- serialized authoritative drawable and prop metadata in `wearing_data`;
- cumulative drip XP in `drip_xp`;
- the last update timestamp.

Dirty state is saved periodically, on relevant lifecycle transitions, and during
resource shutdown. Back up this table before downgrading, changing character
identifier strategy, or making large slot/configuration changes.

## Build and checks

The NUI uses Bun 1.3.13. From the resource root:

```powershell
Set-Location -LiteralPath .\web
bun install --frozen-lockfile
bun run check
```

`bun run check` runs ESLint, TypeScript validation, declared-asset validation,
and the production Vite build. The resulting runtime bundle is written to
`web/dist` and is referenced by `fxmanifest.lua`.

## Deployment

On Windows, the repository includes a deployment helper:

```powershell
.\deploy-to-server.ps1 -Dest 'C:\FXServer\server-data\resources\[mbt]\mbt_meta_clothes'
```

The default path inside the script is a development-machine convenience; pass
`-Dest` on other machines. The helper builds the NUI by default, mirrors runtime
files with robocopy, and treats robocopy exit codes 0 through 7 as success. Use
`-DryRun` to inspect the sync and `-SkipBuild` only for Lua-only changes when
`web/dist` is already current.

After deployment:

```text
restart mbt_meta_clothes
```

## Upgrade procedure

1. Back up `config.lua`, custom locales, item definitions, images, and the
   `mbt_player_wearing` table.
2. Install the new resource files from a release archive or clean checkout.
3. Reapply configuration changes manually instead of replacing a new config with
   an old copy.
4. Compare configured item names and defaults with the inventory definitions.
5. Build `web/dist` when deploying from source.
6. Start dependencies first, then restart `mbt_meta_clothes`.
7. Inspect startup validation and run the release gameplay checklist before
   enabling the update in production.

Downgrades are not guaranteed to understand data written by a newer release;
restore the matching database and configuration backup if a rollback is needed.
