# MBT Meta Clothes — Server-Authoritative Clothing as Inventory Items

<p align="center">
  <img src="https://img.shields.io/badge/FiveM-Ready-00e676?style=for-the-badge&logo=fivem&logoColor=white" alt="FiveM Ready" />
  <img src="https://img.shields.io/badge/Framework-ESX%20%7C%20QBCore%20%7C%20OX%20Core-blue?style=for-the-badge" alt="Framework" />
  <img src="https://img.shields.io/badge/Version-2.0.0-informational?style=for-the-badge" alt="Version" />
  <img src="https://img.shields.io/badge/Lua-5.4-purple?style=for-the-badge&logo=lua" alt="Lua 5.4" />
  <img src="https://img.shields.io/badge/React-TypeScript-61DAFB?style=for-the-badge&logo=react" alt="React + TS" />
  <img src="https://img.shields.io/badge/License-PolyForm%20Noncommercial%201.0.0-blue?style=for-the-badge" alt="PolyForm Noncommercial 1.0.0" />
</p>

<p align="center">
  <img src=".github/release-assets/hero.png" alt="MBT Meta Clothes" />
</p>

**mbt_meta_clothes** turns equipped GTA clothing components into real inventory items. Players undress through a React NUI, hand clothes over, get robbed of them, and find every garment exactly where they left it after a relog — because the server, not the client, decides what anyone is wearing.

Free and open to hobby servers. Built with the same engineering standards as our paid resources.

---

## Preview

<p align="center">
  <img src=".github/release-assets/v2.0.0-menu.png" alt="Clothing menu" />
</p>

---

## Features

### Core

- **Clothes as inventory items** — every garment you take off becomes a real item with metadata, and putting it back on restores the exact drawable, texture, and palette
- **React + TypeScript NUI** — an interactive mannequin with hotspots, not a list of dropdowns
- **Configurable accent colour** — one hex value in `config.lua` themes the entire interface
- **Torso kits** — tops, undershirts, and torso variations move together as one coherent item instead of leaving players half-dressed
- **Chat commands and keybind** — open the menu with `J` (rebindable) or use per-slot commands

### Server authority and anti-cheat

Every state-changing path is validated server-side. This is the part most clothing resources get wrong.

- **Items are derived from server state, never from the client payload** — a forged event cannot make the server hand out an item the player was not wearing
- **Acknowledged snapshot protocol** — session, revision, and ACK on every mutation; stale or out-of-order client writes are rejected, not merged
- **Per-event rate limiting** on every inbound network event
- **Routing-bucket-aware proximity** — theft validates dimension *and* distance, so players in separate instances cannot reach each other
- **Theft validated twice** — on begin and on complete, with a signed token, a minimum duration, and a grace window
- **Victim consent is replicated** — a thief cannot forge the state bag that marks a target as robbable
- **Inventory metadata is sanitised** — a crafted item can never introduce an arbitrary inventory item, a negative drip value, or a `NaN`
- **Configuration validated at boot** — an invalid config stops the resource with an actionable error instead of running half-broken

### Persistence and compatibility

- **State survives relogs, character switches, and resource restarts**
- **Framework-agnostic lifecycle** — hooks into the standard framework events, so it works with any multicharacter script rather than a hardcoded list
- **Coexists with appearance scripts** — illenium-appearance, skinchanger, qb-clothing and friends apply first; corrections land within a single frame, so players never see a garment they took off
- **Write-behind saves** with periodic flushing of dirty state

### Clothing theft *(optional)*

- Steal a single garment or everything at once
- Requires the target to be down, ragdolled, or with hands up — all configurable
- Progress bars, victim animations, and an anti-grief cap on animation length
- Works with `ox_target`, `qb-target`, or `qtarget` — auto-detected

### Drip Reputation *(optional)*

- Outfits accumulate XP over time based on what the player is wearing
- Per-slot weights and per-drawable values, both configurable
- Named levels with progress, exposed as state bags (`mbt_dripLevel`, `mbt_dripTitle`, `mbt_dripXp`, `mbt_slotsWorn`) for other resources to read

### DNA *(optional)*

- Tracks who wore each garment, FIFO-capped and time-expiring
- Useful for investigative roleplay: a jacket remembers its previous owners

### Localization

- English and Italian included; every UI string comes from the active locale
- Add a language by dropping a file in `locales/`

---

## Requirements

| Requirement | Notes |
| --- | --- |
| **oxmysql** | Required |
| **One framework** | `es_extended`, `qb-core`, or `ox_core` |
| **One inventory** | `ox_inventory`, `qb-inventory`, or a custom adapter |
| **A target script** | Optional — `ox_target`, `qb-target`, or `qtarget` |
| **ox_lib / mbt_visual** | Optional — notifications fall back to the native GTA feed |

Exactly one supported framework and one inventory must be active. Startup validation rejects missing, ambiguous, or incompatible combinations with an explicit error.

---

## Installation

1. Download the latest release and extract it into your `resources` folder.
2. Add the item definitions to your inventory — see [Installation and operations](docs/installation.md).
3. Start the resource **after** your framework and inventory:

```cfg
ensure es_extended      # or qb-core / ox_core
ensure ox_inventory     # or qb-inventory
ensure mbt_meta_clothes
```

4. Open `config.lua` and check `MBT.Drawables` and `MBT.Props` against the clothing pack your server uses.
5. Set `MBT.Debug = false` once you have verified the resource runs correctly.

Full dependency, database, build, and upgrade instructions: [docs/installation.md](docs/installation.md).

---

## Configuration

Everything lives in `config.lua`. The options you will actually touch:

### General

| Option | Default | Description |
| --- | --- | --- |
| `MBT.Debug` | `true` | Debug logging and the lifecycle tracer. **Set to `false` in production.** |
| `MBT.Language` | `'en'` | `'en'`, `'it'`, or your own file in `locales/` |
| `MBT.MenuKey` | `'J'` | Keybind to open the menu |
| `MBT.Theme.Accent` | `'00e676'` | UI accent colour, hex **without** `#` |
| `MBT.ActionCooldown` | `1500` | ms between actions, prevents animation spam |

### Theft

| Option | Default | Description |
| --- | --- | --- |
| `MBT.TargetEnabled` | `true` | Auto-detects the installed target script |
| `MBT.StealDistance` | `5.0` | Max distance in metres |
| `MBT.StealDuration` | `1500` | Progress bar for a single garment |
| `MBT.StealAllDuration` | `2500` | Progress bar for stealing everything |
| `MBT.VictimAnimCap` | `10000` | ms cap on victim animation, anti-grief |
| `MBT.HandsUpAnims` | *(list)* | Which animations mark a player as robbable |

### Drip and DNA

| Option | Default | Description |
| --- | --- | --- |
| `MBT.DripEnabled` | `true` | Enable XP accumulation |
| `MBT.DripInterval` | `300` | Seconds between XP ticks |
| `MBT.DripLevels` | *(list)* | Named levels and their XP thresholds |
| `MBT.DripSlotWeights` | *(table)* | Points per slot — a jacket can outweigh an earring |
| `MBT.DnaEnabled` | `true` | Track who wore each item |
| `MBT.DnaMaxEntries` | `3` | FIFO cap per item |
| `MBT.DnaExpiryHours` | `48` | Hours before DNA expires |

### Integration points

`MBT.ProgressBar` and `MBT.Notification` are plain Lua functions you can replace with your own implementation. Both ship with a guarded fallback chain (`mbt_visual` → `ox_lib` → native), so the resource stays dependency-free out of the box.

---

## Commands

| Command | Description |
| --- | --- |
| `/shirt`, `/jacket` | Toggle the torso kit |
| `/trousers`, `/shoes`, `/chain` | Toggle individual drawables |
| `/hat`, `/glasses`, `/ears`, `/watch` | Toggle props |
| `/hair` | Toggle hair |
| `/tuck <slot>` | Cycle a slot's configured clothing states |
| `/steal` | Open the theft menu on the nearest eligible player |
| `/drip` | Show your current drip level and XP |

---

## FAQ

**Does it work with my multicharacter script?**
It hooks into the standard framework lifecycle events rather than any specific multicharacter resource, so it works with `esx_multicharacter`, `qb_multicharacter`, and anything else that fires them.

**Will it fight with my appearance script?**
No. Appearance scripts apply first and we correct afterwards, within a single frame. If a player logged out without a shirt, they come back without a shirt — and nobody sees a flash of the wrong outfit.

**Can players duplicate clothing?**
The server derives every returned item from its own authoritative state. It never trusts an item name, a slot, or a drawable sent by the client.

**I use a custom inventory.**
Implement `MBT.CustomInventory` in `config.lua`. Startup validation will tell you if the signature is wrong.

---

## Credits

Developed by **Malibu Tech Team**.

Founded with my brother **Gianmarco** *(DarkSideofTheCode)*.

---

## License

This project is licensed under the [PolyForm Noncommercial License 1.0.0](LICENSE.md).

You are free to use and modify this software for **noncommercial purposes only** — personal use, hobby servers, research, and education. Any commercial use, redistribution for profit, or inclusion in paid products is prohibited without written permission from Malibu Tech Team.

---

## Media

- [Showcase](https://www.youtube.com/watch?v=TSCrxiJaWdg)
- [Cfx.re release](https://forum.cfx.re/t/free-esx-qb-ox-mbt-meta-clothes/4961827)

Copyright 2022-2026 MalibuTech.
