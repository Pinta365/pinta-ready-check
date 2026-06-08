# Pinta Ready Check

A lightweight WoW addon that shows each group member's consumable and gear status during a **ready check**, so you can spot who's missing a flask, food, rune, enchants, or gems before the pull.

When a ready check starts, a small movable window pops up listing everyone with a colored square per category. It hides itself a couple of seconds after the ready check ends (configurable) and instantly clears when you enter combat.

## Download

* [Wago Addons](https://addons.wago.io/addons/pintareadycheck)
* [CurseForge](https://www.curseforge.com/wow/addons/pintareadycheck)

## What it checks

| Category | How it's detected | Where it works |
|---|---|---|
| **Flask** | aura scan (`C_UnitAuras`) | any group, incl. raid |
| **Food** | aura scan | any group, incl. raid |
| **Rune** | aura scan (augment rune) | any group, incl. raid |
| **Ench** | gear inspect (all armor + a ring/weapon enchant) | party / solo only |
| **Gem** | gear inspect (neck + both rings) | party / solo only |

Enchant and gem checks require inspecting other players, which is only reliable in a 5-man where everyone is in range — so those two columns are **party-only** (think M+). In a raid the window shows just Flask / Food / Rune. Your own gear is always read directly.

### Square colors

- 🟩 **Green** – has it
- 🟥 **Red** – missing it
- 🟨 **Yellow `?`** – inspect still pending (party members; flips to green/red once their gear loads, or stays yellow if they're out of range)

Names are shown in class color.

## Commands

| Command | Action |
|---|---|
| `/prc` | Show command list |
| `/prc test` | Force a scan and show the window now |
| `/prc slackers` | Toggle "only show players with missing buffs" |
| `/prc debug` | Toggle debug output |
| `/prc reset` | Reset settings to defaults (with confirmation, reloads UI) |

## Options

**Settings → AddOns → Pinta Ready Check** (or `/prc` for the quick toggles):

- **Only show players with missing buffs** – hide everyone who's fully set up.
- **Hide delay after ready check ends** – seconds before the window fades (0–30, default **2**).
- **Show debug messages** – verbose logging via `PRC.Debug(...)`.
