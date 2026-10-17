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
├─ resources/       # .tres and level data: classes/ weapons/ consumables/ terrain/ levels/ ui_theme.tres
├─ editor/          # the map editor scene (map_editor.tscn). Run it directly, not as the main scene
├─ gameplay/        # every game script and scene, in one flat folder
├─ docs/            # reference notes (FE7 numbers behind resources/)
└─ tests/           # GUT tests: tests/gameplay/ for scripts, tests/data/ for resources, tests/fixtures/ for test data
```

`gameplay/` holds the game and, alongside it, a data model that is not wired in yet:

- **Battle** (`battle.tscn`, the main scene) wraps a `Level` with the cursor, menus, forecast and terrain panel. `Level`, `LevelUnit`, `LevelState`, `MapData`, `MapLayer`, `Pathfinding` and `TerrainType` load a JSON level from `resources/levels/`, draw it with `resources/terrain/` and place units from `assets/battle_pack/`. `Battle` decides what the keys do; `Level` only draws. `Combat` holds the forecast numbers. The editor in `editor/` builds the levels.
- **Controls:** arrows or mouse hover move the cursor. Z (Enter, Space) confirms: on your unit it selects it and shows its range, on a cell in range it moves there and opens the unit menu, on anything else it opens the map menu. X (Esc, right click) cancels and undoes a move. A opens the unit menu without moving. Attack shows the forecast against adjacent enemies (left / right cycle targets); confirming plays the fight out with FE7 true hit and a stand-in Iron Sword, and units at 0 HP leave the map. End in the map menu refreshes every unit.
- **Unit data model** (not yet hooked into Battle): `Stats`, `ClassData`, `UnitData`, `Unit`, `WeaponData`, `Inventory` and the FE7 `.tres` files in `resources/classes/`, `weapons/` and `consumables/`.

Add new scripts and scenes to `gameplay/`, new `.tres` files to the matching `resources/` folder, and new art to `assets/`.

## Conventions

Follow the [GDScript style guide](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_styleguide.html):

- `snake_case` for files and folders (`unit_data.gd`, `battle_map.tscn`).
- `PascalCase` for `class_name` and node names.
- Typed GDScript: give variables, parameters and return values types.
- Tests are named `test_<script>.gd` and go in `tests/gameplay/` (or `tests/data/` for resource checks).

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

## Workflow

Branch off `main` for each change and open a pull request to merge it back.
