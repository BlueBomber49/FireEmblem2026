# FireEmblem2026

A turn-based tactics game inspired by the Game Boy Advance Fire Emblem games, built in Godot. Class notes and deliverables live in the [project wiki](https://github.com/BlueBomber49/FireEmblem2026/wiki).

## Requirements

- [Godot 4.6.3](https://godotengine.org/download/archive/4.6.3-stable/), **standard** build (not the .NET build). The project uses GDScript only.

## Getting started

1. Clone the repo.
2. Open Godot, choose **Import**, and select `project.godot` in the repo root.
3. The GUT test plugin is included in `addons/gut/` and enabled automatically.

## Folder guide

```
res://
├─ addons/gut/      # GUT test framework (third-party; don't edit)
├─ assets/          # art: battle_pack/ (unit sprite sheets, tiles, UI), tilesets/, portraits/, fonts/
├─ resources/       # game data: classes/ weapons/ consumables/ characters/ terrain_data/ (JSON), levels/ (JSON), terrain/ ui_theme.tres
├─ editor/          # the map editor scene (map_editor.tscn). Run it directly, not as the main scene
├─ gameplay/        # the game: battle.tscn and shared rules/utilities at the root, map/ for the map and unit model, ui/ for menus and panels
├─ docs/            # data-format.md (how to edit the JSON data), fe7-reference.md (the FE7 numbers behind it)
└─ tests/           # GUT tests: tests/gameplay/ mirrors gameplay/ (map/, ui/), tests/editor/ for the map editor, tests/fixtures/ for test data
```

`gameplay/` holds the game. The root has `Battle`, `Combat`, `GameData` and shared helpers (`Enums`, `JsonUtil`, `SaveUtil`, the `WindowControls` autoload); `gameplay/map/` has the map and everything that stands on it; `gameplay/ui/` has the menus and panels:

- **Flow** (`gameplay/flow/`, `gameplay/cutscene/`): `boot.tscn` is the main scene; it starts the `GameFlow` autoload, which plays `resources/campaign.json` in order, swapping between `Cutscene` scenes (lines from `resources/dialogue/`, read by `DialogueData`) and `Battle`. Scenes only signal when they end (`Cutscene.finished`, `Battle.ended`).
- **Battle** (`battle.tscn`) wraps a `Level` with the cursor, menus, forecast and terrain panel. In `gameplay/map/`, `Level`, `LevelUnit`, `LevelState`, `MapData`, `MapLayer`, `Pathfinding` and `TerrainType` load a JSON level from `resources/levels/`, draw it with `resources/terrain/` and place units from `assets/battle_pack/`. `Battle` decides what the keys do; `Level` only draws. `Combat` holds the FE7 combat formulas. The editor in `editor/` builds the levels.
- **Controls:** arrows or mouse hover move the cursor. Z (Enter, Space) confirms: on your unit it selects it and shows its range, on a cell in range it moves there and opens the unit menu, on anything else it opens the map menu. X (Esc, right click) cancels and undoes a move. A opens the unit menu without moving. Attack shows the forecast against enemies the equipped weapon reaches (bows hit from 2 tiles; left / right cycle targets); confirming plays the fight out with real weapons, the weapon triangle, terrain bonuses and FE7 true hit, and units at 0 HP leave the map. Terrain costs movement by class (forest slows units, water blocks all but fliers). End in the map menu refreshes every unit.
- **UI** (`gameplay/ui/`): `ActionMenu` (and `map_menu.tscn`), `CombatForecast` with its `ForecastSide` data, `TerrainPanel` with its `TerrainInfo` data, and the map overlays `MapCursor`, `RangeOverlay` and `PathArrow`. These only draw what `Battle` hands them.
- **Units** (`gameplay/map/`): each unit on the map is a `LevelUnitState` (where it stands, whether it has acted) holding a `Unit` (stats, current and max HP, inventory), built from its placement in the level file (`UnitReference`). `UnitInfo` (`gameplay/ui/`) describes a unit for menus; `Battle.selected_unit_items()`, `use_item()` and `equip_item()` are ready for an Item menu.
- **Data** (`GameData`): classes, weapons, consumables, named characters and terrain rules are JSON files in `resources/`, looked up by id. Edit them in any text editor; see [`docs/data-format.md`](docs/data-format.md).

Add new scripts and scenes to the matching `gameplay/` subfolder, new data files to the matching `resources/` folder, and new art to `assets/`.

## Data notes

- **Data files are JSON** and are checked when they load: a typo'd field, a bad value or an unknown id is reported (with the file name) and that file is skipped. The data tests (`tests/gameplay/test_game_data.gd`) fail if any real file has a problem.
- **Named characters** (`resources/characters/<id>.json`) hold their own **total** stats, the same numbers a character page lists. Maps place them by id. **Generic units** (most enemies) are defined in the map: a class, level, items and optional stat overrides.
- **Movement always comes from the class**, so leave it out of character stats.
- **Strength and Magic are separate.** FE7 lists a single Str/Mag number: put it in `strength` for physical classes or `magic` for magic classes, and the other at 0.
- **Placing units:** in the map editor's Units mode, pick a character (or None and a class), then click a cell. See `docs/data-format.md` for the level file format.

## Conventions

Follow the [GDScript style guide](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_styleguide.html):

- `snake_case` for files and folders (`unit_data.gd`, `battle_map.tscn`).
- `PascalCase` for `class_name` and node names.
- Typed GDScript: give variables, parameters and return values types.
- Tests are named `test_<script>.gd` and go in the `tests/` folder that mirrors the script's (`tests/gameplay/map/`, `tests/gameplay/ui/`, `tests/gameplay/`, `tests/editor/`).

## Running tests

**In the editor:** open the GUT panel at the bottom of the editor and set its directory to `res://tests/` with subdirectories on. Each teammate needs to do this once, because GUT saves panel settings per machine (in `user://`), not in the repo.

**From the command line**, in the repo root. Here `godot` means the path to your Godot 4.6.3 **console** executable. On Windows that's the `_console.exe` in the Godot zip, such as `Godot_v4.6.3-stable_win64_console.exe`, which isn't on your PATH by default. Use the console version: the regular `.exe` detaches from the terminal, so test output and the exit code never reach it.

```sh
# First time on a fresh clone, and again after adding a script with a new class_name:
# build Godot's import cache (headless test runs don't rescan the project)
godot --headless --path . --import

# Run all tests (uses .gutconfig.json)
godot --headless --path . -s addons/gut/gut_cmdln.gd
```

**Check the "Scripts" count in GUT's summary.** If a test file fails to compile (say, it refers to something that was renamed), GUT skips the whole file and can still print "All tests passed!" with exit code 0. The Scripts count should equal the number of `test_*.gd` files.

## Workflow

Branch off `main` for each change and open a pull request to merge it back.
