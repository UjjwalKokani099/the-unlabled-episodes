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
