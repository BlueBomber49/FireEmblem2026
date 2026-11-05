# Data format

The game's classes, weapons, items, characters and terrain rules are JSON files under `resources/`. Edit them in any text editor. Each file holds one thing, and its `id` must match the file name (`resources/classes/knight.json` has `"id": "knight"`). Other files refer to it by that id.

Files are checked when the game loads them. A misspelled field, a wrong type, a bad name or an unknown id is reported with the file name, and that file is skipped. The data tests (`tests/gameplay/test_game_data.gd`) fail if any real file has a problem, so run the tests after editing.

Numbers are whole numbers. Names of weapon types and movement groups are lowercase.

Starting values come from FE7; see [fe7-reference.md](fe7-reference.md) for sources and our intended differences.

## Stat blocks

Used by classes and characters. All stats, in this order:

```json
{ "hp": 17, "strength": 5, "magic": 0, "skill": 2, "speed": 0,
  "luck": 0, "defense": 9, "resistance": 0, "constitution": 13, "movement": 4 }
```

Strength and Magic are separate: physical units use `strength`, magic users use `magic`.

## Classes: `resources/classes/<id>.json`

| Field | Meaning |
|---|---|
| `id`, `name` | Id (matches the file name) and display name |
| `movement_type` | `foot`, `armored`, `mounted`, `flier` or `mage`. Decides terrain movement costs |
| `weapon_types` | Weapon types the class can use: `sword`, `lance`, `axe`, `bow`, `anima`, `light`, `dark`, `staff` |
| `base_stats` | Full stat block: generic units of this class start with these |
| `growths` | Level-up chance per stat, in percent (`constitution` and `movement` may be left out) |
| `caps` | Full stat block: the most each stat can reach |
| `crit_bonus` | Optional, default 0. Added to critical rate |
| `class_power` | Optional, default 3. Used by EXP formulas later |
| `promoted` | Optional, default `false` |
| `tags` | Optional. Traits weapons can be effective against: `flier`, `mounted`, `armored` |
| `sprite` | Sprite sheet path with `{color}` where the faction colour goes (`Blue`, `Red`, `Green`), e.g. `"res://assets/battle_pack/Sprite Sheets/LanceKnight/LanceKnight_{color}.png"` |

## Weapons: `resources/weapons/<id>.json`

| Field | Meaning |
|---|---|
| `id`, `name` | |
| `type` | `sword`, `lance`, `axe`, `bow`, `anima`, `light`, `dark` or `staff` |
| `might`, `hit`, `crit`, `weight` | FE7 weapon stats |
| `min_range`, `max_range` | Distance in tiles it can attack at: 1–1 melee, 2–2 bows, 1–2 javelins and tomes |
| `effective_against` | Optional. Class tags it deals ×2 might against, e.g. `["flier"]` for bows |

## Consumables: `resources/consumables/<id>.json`

| Field | Meaning |
|---|---|
| `id`, `name` | |
| `max_uses` | Uses when new |
| `heal` | HP restored per use, or `"full"` |

## Characters: `resources/characters/<id>.json`

Named units that can appear in more than one map. Maps place them by id.

| Field | Meaning |
|---|---|
| `id`, `name` | |
| `class` | A class id |
| `level` | Optional, default 1 |
| `stats` | The character's **total** starting stats (what a character page lists). `movement` is ignored: it comes from the class |
| `growths` | Optional. Personal growth rates; without them the class's are used |
| `items` | Optional. Item ids in inventory order; the first weapon the class can use is equipped |
| `sprite` | Optional. A sprite template (with `{color}`) overriding the class's |

## Terrain rules: `resources/terrain_data/<id>.json`

| Field | Meaning |
|---|---|
| `id`, `name` | The name is what the terrain panel shows |
| `defense`, `avoid` | Combat bonuses for the unit standing there (fliers don't get them) |
| `heal_percent` | Optional. HP restored per turn (stored for later; no turn phases yet) |
| `move_costs` | Movement points per group: `foot`, `armored`, `mounted`, `flier`, `mage`. `-1` means that group can't enter |
| `tiles` | The drawn tile ids (`resources/terrain/<tile>.tres`) that follow these rules, e.g. `["trees"]` for forest |
| `half_edge_counts` | Optional, default `false`. Whether a map cell counts as this terrain when half of it is drawn as this terrain along one straight edge (see below). `true` for forest |

**Which terrain a map cell is.** Maps are painted by the corners between tiles, so a tile at a terrain's edge can be partly one terrain and partly another. A tile counts as the highest layer that covers 3 or 4 of its corners, or that covers one straight half of it (2 corners side by side) if that terrain has `half_edge_counts`. Otherwise it's whichever layer covers the most corners. A tile with fewer than 3 corners painted at all counts as nothing (impassable). So a half-tree edge tile plays as forest, a tile with just a small tree corner plays as plains, and a mostly-water shore tile blocks movement.

## Units in a level: `resources/levels/<level>.json`

Under `map_data.units`, each unit is keyed by its id in the level. Either a **named character**:

```json
"lyn": { "character": "lyn", "faction": "player", "start_cell": [6, 5], "facing": [1, 0] }
```

or a **generic unit** defined right there:

```json
"bandit": {
	"class": "fighter", "name": "Bandit", "level": 2, "items": ["iron_axe"],
	"stats": { "hp": 24, "strength": 7, "defense": 4 },
	"faction": "enemy", "start_cell": [10, 5]
}
```

- `faction` is `player`, `enemy` or `ally` (green, on the player's side).
- `"commander": true` (optional) marks the enemy commander that `defeat_commander` targets. One per level, enemies only. It's drawn with a crown in play and in the editor.
- A generic unit's `stats` are optional **overrides**: any stat left out uses the class's base stat.
- `sprite_sheet` (optional) is a full sprite path. Without it the unit uses its character's or class's sprite in its faction's colour. The map editor fills it in.
- A unit whose character or class id doesn't exist is kept in the file but skipped in play; the map editor lists it in its status line.

### Objective

Optional `objective` at the top level of the level file: how the level is won or lost.

```json
"objective": {
	"win":  [{ "type": "seize", "cells": [[12, 4]], "name": "the gate" }],
	"lose": [{ "type": "units_fall", "units": ["adelard"] },
	         { "type": "turns_pass", "turns": 10 }]
}
```

- The level is won when **any** `win` condition holds and lost when **any** `lose` condition holds. Losing is checked first, so a lord falling in the same fight as the last enemy is a defeat.
- **Losing every player unit always loses**, whatever `lose` says. It's built in, so `lose` only lists a level's extra conditions (an old file that lists `faction_defeated` for `player` still loads; that entry is dropped as redundant).
- `win` left out is a rout. `lose` left out (or empty) adds nothing beyond the built-in wipe.

| Type | List | Settings | Met when | Shown as |
|---|---|---|---|---|
| `faction_defeated` | win | `faction`: `enemy` | every enemy is defeated | Rout the enemy |
| `defeat_commander` | win | none | the unit marked `"commander": true` is defeated | Defeat the enemy commander |
| `seize` | win | `cells`: list of `[x, y]`; optional `name` | a unit uses the **Seize** command on one of the cells | Seize the gate (or "Seize the marked cell") |
| `survive` | win | `turns` (1+) | that many enemy phases are over | Survive 3 turns |
| `units_fall` | lose | `units`: list of unit ids | any of them is defeated | Adelard falls / Adelard or Rowland falls |
| `turns_pass` | lose | `turns` (1+) | that many enemy phases are over without a win | 10 turns pass |
| *(built in)* | lose | none | every player unit is defeated | Your army is defeated |

- Turns count from 1 (the first player phase) and go up after each enemy phase, so "survive 3" and "3 turns pass" both resolve right after the third enemy phase.
- The older `{"type": "unit_defeated", "unit": "adelard"}` still reads, as `units_fall`.
- An unknown type, a condition in the wrong list (e.g. `seize` under `lose`), or missing settings are warned about ("Objective:") and dropped. Problems that need the level's units (no commander marked for `defeat_commander`, a `seize` with no cells, a `units_fall` id that isn't in the level, more than one commander, a commander that isn't an enemy) are warned about when the level loads, and **the map editor won't save** until they're fixed. A missing commander or unit never counts as defeated.
- **Adding a condition type** (code): a `Condition` subclass in `gameplay/map/objective.gd` plus one `CONDITION_TYPES` entry (its class, editor title, allowed lists and settings). The map editor builds its fields from the settings.

The map editor edits all of it in **Objective** mode: add or remove conditions in each list, set turns, pick units, name a seize point, and click map cells to toggle seize cells (shown in green, as in play). Mark the enemy commander with the **Enemy commander** checkbox in Units mode. In Units mode, pick a character (or None plus a class, level, items and optionally "Override class stats") and click a cell.

## Campaign: `resources/campaign.json`

The order the game plays in. `GameFlow` (an autoload) plays each chapter's intro, its level, then its outro; losing the battle replays it. Scenes don't know what comes after them, so reordering or adding chapters only changes this file.

```json
{ "chapters": [
	{ "id": "prologue", "intro": "prologue_intro", "level": "prologue", "outro": "prologue_outro" }
] }
```

| Field | Meaning |
|---|---|
| `id` | Unique among chapters |
| `intro`, `outro` | Optional. Dialogue ids (`resources/dialogue/<id>.json`); empty or left out means no cutscene |
| `level` | A level id (`resources/levels/<id>.json`) |

A chapter naming a missing dialogue or level file is reported and skipped; `test_campaign.gd` fails on it.

## Dialogue: `resources/dialogue/<id>.json`

One cutscene's conversation.

| Field | Meaning |
|---|---|
| `id` | Must match the file name |
| `background` | Optional. An image id: `assets/cutscenes/<id>.png`. Empty is a plain dark background |
| `lines` | The lines in order (below) |

Each line:

| Field | Meaning |
|---|---|
| `speaker` | A character id, or empty for narration (no name, both portraits dimmed). The portrait is `assets/portraits/<speaker>.png`; without one, the speaker just has no portrait |
| `side` | Optional. `left` (default) or `right`. A portrait stays on its side until another speaker takes it |
| `text` | What they say |

A line with an unknown key, unknown speaker or bad side is reported and dropped; the rest still play.

## Saves

A level save is the level file plus `level_units`: each unit's position, whether it has moved or acted, and its `unit` state (level, EXP, stats, current HP, and items by id with uses left). Loading tolerates hand-edited or damaged saves: missing or wrong values fall back with a "Save data:" warning.

## Exporting the game

Godot 4 imports `.json` files as JSON resources, so they should be included in exported builds without extra setup. This hasn't been checked yet, since the project has no export preset. On the first export, check that units, classes and levels load in the exported game. If any data is missing, add `*.json` to the preset's "Filters to export non-resource files/folders".
