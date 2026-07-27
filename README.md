<div id="header" align="center">
  <img src="https://dunb17ur4ymx4.cloudfront.net/wysiwyg/1131066/1fe58a9651a48982397fb7d9ec82bfd4aa26d036.png" width="500" alt="MalibuTech" />
</div>

# MBT Meta Clothes

MBT Meta Clothes turns equipped GTA clothing components into metadata-backed
inventory items. Players can undress through the NUI, equip compatible items,
swap clothing, and steal clothing through an optional target interaction.

## Compatibility

| Framework | Inventory | Status |
| --- | --- | --- |
| ESX | ox_inventory | Supported |
| ESX | Custom adapter | Supported with integration work |
| QBCore | qb-inventory | Supported |
| QBCore | ox_inventory | Supported |
| QBCore | Custom adapter | Supported with integration work |
| OX Core | ox_inventory | Supported |

The resource follows the MBT startup convention: start the selected framework
and inventory first, then start `mbt_meta_clothes`. Exactly one supported
framework and one inventory implementation must be active. Startup validation
rejects missing, ambiguous, or incompatible combinations with an actionable
error.

See [Installation and operations](docs/installation.md) for dependencies, item
definitions, database behavior, build, deployment, and upgrade instructions.

## Main features

- Server-authoritative dress, undress, and clothing theft
- Transactional inventory returns with metadata preservation
- Persistent wearing state across reconnects and character switches
- ESX, QBCore, and OX Core bridges
- ox_inventory and qb-inventory item handlers
- Optional DNA history and drip progression
- Optional ox_target, qb-target, or qtarget interaction
- English and Italian locales

## Configuration

Edit `config.lua` before starting the resource. In particular, verify the
freemode defaults in `MBT.Drawables` and `MBT.Props` against the clothing pack
used by the server. Keep `MBT.Debug = false` in production after completing the
runtime verification.

## Media

- [Showcase](https://www.youtube.com/watch?v=TSCrxiJaWdg)
- [Cfx.re release](https://forum.cfx.re/t/free-esx-qb-ox-mbt-meta-clothes/4961827)

Copyright 2022-2026 MalibuTech. All rights reserved.
