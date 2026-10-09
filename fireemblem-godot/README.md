# FireEmblem2026

A turn-based tactics game inspired by the Game Boy Advance Fire Emblem games, built in Godot. Class notes and deliverables live in the [project wiki](https://github.com/BlueBomber49/FireEmblem2026/wiki).

## Requirements

- [Godot 4.5.x](https://godotengine.org/download), **standard** build (not the .NET build). The project uses GDScript only.

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
└─ tests/                 # GUT tests; mirrors the path of the code under test
```

| Folder | What goes here |
|---|---|
| `core/` | Game rules as plain scripts, split by feature. `ai/` is only here because enemy logic is pure rules. |
| `scenes/` | Scenes and node scripts that display the game and handle input, split by the same features. `ui/` is only here. |
| `data/` | Content the team edits in the inspector, saved as `.tres` files. A `maps/` folder will be added once we decide how maps are authored. |
| `assets/` | Imported art, audio and fonts. |
| `tests/` | GUT tests. |
| `common/` | Shared helpers used by more than one feature (in `core/` or `scenes/`). |

## Architecture rule

Keep game rules separate from how the game is shown:

- Code in `core/` never extends `Node` and never references scenes. It can be run and tested without the game running.
- Code in `scenes/` reads from and calls into `core/`. It doesn't hold game rules itself.
- Scripts that define Resource types (for example, a unit definition class) live in `core/<feature>/`. Only the `.tres` instances of those types go in `data/`.

## Conventions

Follow the [GDScript style guide](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_styleguide.html):

- `snake_case` for files and folders (`unit_data.gd`, `battle_map.tscn`).
- `PascalCase` for `class_name` and node names.
- Typed GDScript: give variables, parameters and return values types.
- Tests are named `test_*.gd` and mirror the path of the code they test. For example, tests for `core/battle/turn_order.gd` go in `tests/core/battle/test_turn_order.gd`, and scene tests go under `tests/scenes/`.

## Running tests

**In the editor:** open the GUT panel at the bottom of the editor and set its directory to `res://tests/` with subdirectories on. Each teammate needs to do this once, because GUT saves panel settings per machine (in `user://`), not in the repo.

**From the command line**, in the repo root. Here `godot` means the path to your Godot 4.5 executable. On Windows that's usually something like `Godot_v4.5-stable_win64.exe`, which isn't on your PATH by default.

```sh
# First time on a fresh clone: build Godot's import cache
godot --headless --path . --import

# Run all tests (uses .gutconfig.json)
godot --headless --path . -s addons/gut/gut_cmdln.gd
```

## Workflow

Branch off `main` for each change and open a pull request to merge it back.
