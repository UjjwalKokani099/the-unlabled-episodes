# UNLABELED — project notes

First-person found-footage horror game. Godot 4.7.2, GDScript, Forward+, Jolt physics.
The owner is a React developer new to Godot: all scenes (.tscn), resources (.tres) and
settings are written as text files, not built in the editor.

## Godot binaries
- Editor:  `C:\Users\ujjwa\Tools\Godot\Godot_v4.7.2-stable_win64.exe`
- Console (prints stdout/errors, use for automated runs):
  `C:\Users\ujjwa\Tools\Godot\Godot_v4.7.2-stable_win64_console.exe`

Useful headless commands (run from project root):
- Re-import / validate project: `<console exe> --headless --path . --import`
- Run a scene for N frames and capture errors:
  `<console exe> --path . --quit-after 300 res://scenes/test/<scene>.tscn`
- Syntax-check a script: `<console exe> --headless --path . --check-only --script res://path.gd`
- Run all automated tests: `bash tests/run_tests.sh` (opens a window per test; mouse capture
  needs a real window). Tests are SceneTree scripts in `tests/test_*.gd` that print PASS/FAIL.
  They must not use class_name types or autoload names at compile time (untyped `var p`):
  `--script` compiles them before autoloads are registered.

## Gotchas found so far
- AnimatableBody3D only syncs collision when its *own* transform changes — make the moving
  node the body itself (see `scenes/props/door.tscn`), don't rotate a parent of it.
- Physics layers: 1 world, 2 player, 3 interactable (value 4). The Interactor ray masks 1|4.
- HUD messages from anywhere: `get_tree().call_group("hud", "show_message", "text")`.

## Layout
- `scenes/`   hub, menus, test scenes
- `scripts/`  autoload (singletons), player, interaction, objectives, events, ui
- `chapters/` one folder per tape: scene + chapter-specific scripts/data
- `shaders/`  .gdshader files (lo-fi / VHS post-processing)
- `ui/`       themes and HUD scenes
- `assets/`   models, textures, audio, fonts (binary files tracked by Git LFS)

## Conventions
- Systems shared across chapters live in `scripts/` and are reused, never copied into chapters.
- Keep it light (target: RTX 3050 Ti laptop): low-poly, few real-time lights, simple shaders.
- One commit per working system.
