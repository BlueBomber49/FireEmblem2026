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
├─ addons/gut/            # GUT test framework (third-party; don't edit)
├─ core/                  # pure game rules: no Nodes, no scenes, no input/animation
│  ├─ battle/  units/  maps/  items/  ai/  common/
├─ scenes/                # nodes, visuals, input; calls into core/
│  ├─ battle/  units/  maps/  items/  ui/  common/
├─ data/                  # .tres content (Resource instances)
│  ├─ units/  items/
├─ assets/                # art, audio, fonts
│  ├─ art/  audio/  fonts/
├─ docs/                  # design and reference notes
└─ tests/                 # GUT tests; mirrors the path of the code under test
```

| Folder | What goes here |
|---|---|
| `core/` | Game rules as plain scripts, split by feature. `ai/` is only here because enemy logic is pure rules. |
| `scenes/` | Scenes and node scripts that display the game and handle input, split by the same features. `ui/` is only here. |
| `data/` | Content the team edits in the inspector, saved as `.tres` files. A `maps/` folder will be added once we decide how maps are authored. |
| `assets/` | Imported art, audio and fonts. |
| `docs/` | Design and reference notes, such as [`fe7-reference.md`](docs/fe7-reference.md), the source of the FE7 numbers in `data/`. |
| `tests/` | GUT tests. Shared test data lives in `tests/fixtures/`. |
| `common/` | Shared helpers used by more than one feature (in `core/` or `scenes/`). |

## Architecture rule

Keep game rules separate from how the game is shown:

- Code in `core/` never extends `Node` and never references scenes. It can be run and tested without the game running.
- Code in `scenes/` reads from and calls into `core/`. It doesn't hold game rules itself.
- Scripts that define Resource types (for example, a unit definition class) live in `core/<feature>/`. Only the `.tres` instances of those types go in `data/`.

## Data notes

Unit, class and item numbers start from FE7 values (see [`docs/fe7-reference.md`](docs/fe7-reference.md)). Once in a `.tres` file, tune them in the inspector.

- **Character stats are totals.** A character's `starting_stats` holds their full starting stats, the same numbers a character page lists. Generic units (enemies, recruits without personal data) leave `starting_stats` empty and use their class's base stats.
- **Movement comes from the class.** Leave `movement` blank in `starting_stats`. It's ignored.
- **Strength and Magic are separate.** FE7 lists a single Str/Mag number. Put it in `strength` for physical classes or `magic` for magic classes, and leave the other at 0.
- **Items must be their own files.** Add starting items by picking an existing item `.tres`, not with "New WeaponData" inside a unit's file. Items created inside another file can't be saved with the unit, and the data tests flag them.

## Conventions

Follow the [GDScript style guide](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_styleguide.html):

- `snake_case` for files and folders (`unit_data.gd`, `battle_map.tscn`).
- `PascalCase` for `class_name` and node names.
- Typed GDScript: give variables, parameters and return values types.
- Tests are named `test_*.gd` and mirror the path of the code they test. For example, tests for `core/battle/turn_order.gd` go in `tests/core/battle/test_turn_order.gd`, and scene tests go under `tests/scenes/`.

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
