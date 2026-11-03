# UNLABELED — project notes

First-person found-footage horror game. Godot 4.7.2, GDScript, Forward+, Jolt physics.
The owner is a React developer new to Godot: all scenes (.tscn), resources (.tres) and
settings are written as text files, not built in the editor.

## Story and current brief
- `docs/story.md` is the story bible: source of truth for names, dates, places, rules.
- `docs/brief_visuals_and_demo.md` is the active brief (visual upgrade + demo).

## Godot binaries
- Editor:  `C:\Users\ujjwa\Tools\Godot\Godot_v4.7.2-stable_win64.exe`
- Console (prints stdout/errors, use for automated runs):
  `C:\Users\ujjwa\Tools\Godot\Godot_v4.7.2-stable_win64_console.exe`

Useful headless commands (run from project root):
- Re-import / validate project: `<console exe> --headless --path . --import`
- Run a scene for N frames and capture errors:
  `<console exe> --path . --quit-after 300 res://tests/scenes/<scene>.tscn`
- Syntax-check a script: `<console exe> --headless --path . --check-only --script res://path.gd`
- Run all automated tests: `bash tests/run_tests.sh` (opens a window per test; mouse capture
  needs a real window). Tests are SceneTree scripts in `tests/test_*.gd` that print PASS/FAIL.
  They must not use class_name types or autoload names at compile time (untyped `var p`):
  `--script` compiles them before autoloads are registered.

## Cloud sessions (Claude Code on the web, from the owner's iPad)
- Detect with `CLAUDE_CODE_REMOTE=true`. The SessionStart hook runs `tools/cloud_setup.sh`:
  Linux Godot 4.7.2 at `$GODOT` (also `godot` on PATH), `git lfs pull`, headless `--import`.
- No GPU, no window: always pass `--headless`. Works: `--check-only`, `--import`, the Python
  generators (`tools/gen_*.py`), logic-only tests (`TESTS=tests/test_x.gd bash tests/run_tests.sh`;
  GODOT_HEADLESS=1 is set). Doesn't work: playtesting, screenshots, benchmarks, VoxelGI bakes,
  tests that need mouse capture/rendering. List anything unverified in the commit/PR text
  so it gets tested on the laptop later.
- Web build for playing on the iPad: `.github/workflows/web.yml` exports preset "Web"
  (`export_presets.cfg`, no threads, ETC2/ASTC textures only: made for iPad Safari) on every push to main / `claude/**`
  and uploads it to itch.io (secret `BUTLER_API_KEY`, variable `ITCH_GAME`); newest push wins.
  Web = Compatibility renderer (no VoxelGI/SSAO/SSIL/volumetric fog): check new levels with
  `--rendering-method gl_compatibility`. No threads on web (NavBaker bakes on the main thread).
- Touch play: `InputManager.touch_mode` (first screen touch; a real mouse switches back) +
  `ui/hud` TouchControls (stick left, drag right to look, buttons send input actions). Grab or
  free the mouse only via `InputManager.capture_mouse(on)` and read `InputManager.mouse_captured()`,
  never `Input.mouse_mode` directly. Touches also emit emulated mouse events
  (device `DEVICE_ID_EMULATION`): look code ignores those. Test: `tests/test_touch.gd`.
- Work on a branch and push it (the owner merges after testing on the laptop). Keep commits
  one-per-system as usual. Re-run generators instead of hand-editing generated scenes.

## Gotchas found so far
- AnimatableBody3D only syncs collision when its *own* transform changes — make the moving
  node the body itself (see `systems/props/door.tscn`), don't rotate a parent of it.
- Physics layers: 1 world, 2 player, 3 interactable (value 4). The Interactor ray masks 1|4.
- HUD messages from anywhere: `get_tree().call_group("hud", "show_message", "text")`.
- Test scripts: `await process_frame` before touching autoloads (their `_ready` hasn't run
  yet in `_initialize`).

## Gameplay wiring (EventBus + ObjectiveManager)
- `EventBus.fire(&"id")` announces anything; Pickups fire their `item_id`, Doors fire
  `opened_event`, completed objectives fire their own `id`.
- A level's objectives are an `ObjectiveSet` .tres (see `tests/scenes/test_objectives.tres`)
  loaded by an `ObjectiveLoader` node. Each objective: `complete_on` event, `required`
  count, `starts_after` objective id.
- Props react to events via exports, e.g. Door `unlock_event = &"find_tape"`.
- Scares = `TriggerZone` (fires `event_id` on player enter; `armed_by` gates it) plus
  `EventReaction` nodes listening to that id with their own `delay`: FlickerReaction,
  SoundReaction, VisibilityReaction, MethodReaction (calls any method, e.g. Door `slam`).
  Example: the `Scares` node in `tests/scenes/test_room.tscn`.
- Flicker lights by `light_energy`, never `visible` (visible = the player's on/off state).
- Placeholder SFX come from `python tools/gen_placeholder_sfx.py`; replace files in place.

## Chapters / saving (GameManager + SaveManager autoloads)
- `data/chapter_list.tres` lists the tapes in order (+ debug chapters, hub scene).
  Each tape has `chapters/<tape>/chapter.tres` (title, scene_path, camcorder start time);
  empty scene_path = not built yet. Test chapter: `tests/scenes/test_chapter.tres`.
- `GameManager.start_chapter(id)`, `load_checkpoint()`, `restart_chapter()`, `complete_chapter()`
  (end a level with a MethodReaction targeting `/root/GameManager`). Save: `user://save.json`.
- A level needs: Player, HUD, Camcorder, ObjectiveLoader, and `Checkpoint` areas (origin on
  the floor, respawn faces -Z; one at the spawn so Continue works immediately).
- Checkpoint = EventBus counts + GameManager flags + camcorder time. Anything that must survive a
  reload is either derived from EventBus counts or stored with `GameManager.set_flag()` (Pickups do).
  While objectives rebuild, `EventBus.replaying` is true and EventReactions ignore events.

## Hub: Nikhil's room (Phase 3)
- `chapters/hub/nikhil_room.tscn` = room + corridor + lane view, generated by `tools/gen_hub.py`
  (also the main-menu backdrop). `chapters/hub/hub.tscn` = room + Hub logic + player + HUD.
- Tapes are unlabeled, in the cardboard box; the box hands out the next unwatched tape.
  Hub stage = tapes watched in order; `apply_stage()` switches the bible's room changes.
  F6 (debug builds) cycles stages. Chores are objectives built in code.
- GI: VoxelGI baked by `tools/bake_voxelgi.gd -- <scene>` into `<scene>_gi.res`; re-run the
  generator afterwards so it references the data. Low preset hides VoxelGI.
- `call_group("hud", "show_note", bbcode, handwritten)` shows paper/screens (NoteView).
- Disabled Interactables leave the physics layer, so they never block the look-ray.
- Footsteps (`player/footsteps.gd`, child of Player): surface = `metadata/surface` on
  the collision shape underfoot (levelkit tags every collider via `surface_of(material)`;
  slabs use their top material) or on the body; sounds `assets/audio/sfx/step_<surface>.wav`.
- `Inspectable` (Model + Interactable children): `call_group("hud", "inspect", item)` opens
  InspectView (HUD, layer 24): a visual-only copy in its own lit world, drag/WASD turns,
  scroll zooms, E takes (if `item_id`) or puts back. `inspected_event` fires once.
- `systems/props/drawer.tscn` (Drawer = the AnimatableBody3D): slides along local +Z; children
  ride along; collision is only the bottom + front so the look-ray reaches what's inside;
  `locked` + `unlock_event`; open state is a GameManager flag.

## Menus + intro (Phases 4-5)
- Main scene = `ui/menus/main_menu.tscn`, diegetic: the VCR-OSD menu UI lives in the
  `Screen` SubViewport (960x720) and is shown on the CRT in `menu_backdrop.tscn` (Nikhil's
  room, tube light off, REC dot) via `assets/shaders/crt_screen.gdshader`. MainMenu._input forwards
  everything to the screen; mouse positions go through `MenuBackdrop.screen_uv_at()` (same
  curvature as the shader). Camera framings IDLE / CLOSE (settings, tapes) / DIVE (start).
  Menu UI paths start with `Screen/UI/`; tests read focus with `menu.focused_control()`.
  CONTINUE / NEW GAME (replays intro) / TAPES (locked = blank cassette) / SETTINGS / QUIT.
- First launch autoplays `chapters/intro/intro.tscn` (built by `tools/gen_intro.py`, driven by
  `chapters/intro/scripts/intro_director.gd`; hold Space to skip; `intro_seen` in the save).
- Settings screen: tabs from `ROWS` in settings_menu.gd; rebind rows from
  `SettingsManager.REBINDABLE` (saved as `key_bindings`). Subtitles: `call_group("subtitles", "say",
  speaker, text, seconds)` (Subtitles node is in the HUD and the intro).
- Pause menu lives inside `ui/hud/hud.tscn` (Esc). Theme: `ui/themes/vcr_theme.tres`.
- Tests that open the main menu must call `GameManager.mark_intro_seen()` first.

## Graphics / performance (target: 60 FPS at 1080p on the RTX 3050 Ti laptop)
- `GraphicsManager` autoload applies Low/Medium/High (`PRESETS`): render scale, FXAA, LOD threshold,
  shadows, SSAO/SSIL/volumetric fog quality, VoxelGI (off on Low). Presets only switch level
  features off, never add them. FPS counter = SettingsManager.show_fps.
- Benchmark: `<console exe> --path . --script res://tools/benchmark.gd -- <scene> [sec]`
  (fullscreen, VSync off, Marker3Ds in group `benchmark_points`). Tape 1 map: Medium ~248 FPS.
- GI = VoxelGI baked by script (`tools/bake_voxelgi.gd`) for interiors; night exteriors use
  local lights + SSIL only. Emissive props that switch off (tube lights) use gi_mode disabled.
- Brightness is a gamma overlay owned by the SettingsManager autoload (canvas layer 5).
- PS1 mode (`SettingsManager.ps1_mode`, off by default): GraphicsManager sets 3D scale <= 0.5, no FXAA, and
  the global shader uniform `ps1_amount` (project.godot [shader_globals]; read it back from
  `GraphicsManager.ps1_amount`, the RenderingServer getter is editor-only). surface.gdshader uses it
  for vertex snapping (POSITION), partial affine warping, 256-texel point sampling. The
  camcorder adds `assets/shaders/ps1_post.gdshader` (480 lines, nearest, 15-bit + Bayer dither)
  under the OSD. Benchmark it with `... benchmark.gd -- <scene> <sec> ps1`.
- Night vision: camcorder `set_night_vision()` / key N: VHS shader `night_vision` (gain,
  green, grain, tunnel vignette) + an IR OmniLight on the camera; drains `osd.battery_level`
  (240 s full), EventBus `battery` (battery pickups) adds 0.5.
- Tests/scratch scripts that change SettingsManager must restore them even on failure paths
  (SettingsManager saves to the player's real settings.cfg).

## Materials and decals (Phase 1)
- `assets/shaders/surfaces/surface.gdshader` = the wall/floor shader: world-space projection (no UVs,
  `tile_size` metres), macro variation, per-storey weathering (rising damp limited by
  `damp_storeys`, leak streaks, top grime), two-tone dado. Storeys are 3 m.
- Library `assets/materials/*.tres` generated from the table in `tools/gen_materials.py`
  (edit table, re-run). Plain StandardMaterial3D files (glass, paint, door) are hand-written.
- Textures: CC0 ambientCG via `tools/fetch_textures.py`. After adding textures: `--import`,
  `python tools/configure_texture_imports.py`, `--import` again.
- Imported normal maps are 2-channel (RG): custom shaders must rebuild Z.
- Decals `assets/decals/<name>.tscn`: put the node ON the surface, +Z out of it.
  Posters: `tools/gen_posters.gd` (Godot renders Devanagari) -> `tools/gen_decals.py`.

## Building kit (Phase 2)
- `tools/levelkit.py` = the modular kit (wall with openings, slab, stair_flight, railing,
  window_fill, residential_wing, sodium_lamp, night_environment, player_rig, benchmark_points).
  Level generators `tools/gen_*.py` import it and write .tscn files — edit the generator and
  re-run, don't hand-edit generated scenes.
- Static geometry under `Static` (StaticBatcher merges at runtime: 6400 boxes -> ~200 meshes);
  collision under one `Collision` body; stairs = visual steps + convex ramp collider.
- In generated .tscn, `script` must be written before that script's exported properties.

## Tape 1: Shanti Vihar (Phase 6)
- `chapters/chapter_01/shanti_vihar.tscn` + `objectives.tres` from `tools/gen_tape01.py`.
  Wings A-D (G+4, stilt parking), cabin (CCTV monitor with live feeds, gate register, 4B key,
  intercom), meter room, water tank, parking, lamps, ambience.
- Full night playable: first round (register -> CCTV -> patrol -> padlocks -> cabin), tape cut
  to 03:10, Deshmukh walks out at 3:12 (NPCWalker), CCTV-only balcony figure, intercom
  breathing, flat 4B, stranger's register entries, secretary call + power cut, meter room,
  last CCTV frame with the red dot -> static -> hub. Beats/dialogue/timing live in
  `chapters/chapter_01/scripts/tape01_director.gd` (`time_scale` speeds it up for
  tests); the director rebuilds its state from EventBus counts in `_restore()`.
- Register times quoted by the stranger's entries = GameManager flags `t1_t_<event>` (camcorder clock).

## Story systems (shared by every tape)
- Tape cut: `call_group("camcorder", "tape_cut", "03:10:40")` (static, black, clock jumps;
  stored in OSD `elapsed`, so checkpoints keep it). OSD: `clock_text()`, `time_of_day()`.
- Spotting the Cameraman: `Spottable` (systems/story) in group "spottable"; the Spot key `spot`
  (Q) is the camcorder's PAUSE (freezes the tree + VHS pause band). Ids like `t1_flat_4b`
  persist in the save (`GameManager.mark_spotted/spotted_count`); 12 total = Ending B. A Spottable
  with `monitor` + `monitor_camera` counts only while that CCTV feed shows.
- Characters: `tools/gen_characters.py` -> `assets/characters/` (deshmukh, raghu, iyer,
  cameraman; primitive stand-ins, -Z forward, head parts under the `Body/Head` pivot). `Cameraman`: `active`, `spot_id`, `vanish_when_unseen`
  (needs real line of sight), `cctv_only`, `steady_dot`. `NPCWalker`: scripted walks.
- CCTV-only things: render layer 20 (`CCTVOnly`); the player camera's cull mask excludes it.
  CCTV markers can set `metadata/fov` for a narrow lens.
- `PowerGrid`: group "mains" nodes switch off (set_power / Light3D / audio) + emissive
  `glow_materials` (restored on exit). Kit sodium lamps + wing tube lights are in "mains".
- `RingingPhone`: phones/intercoms (ring_event, answered_event, use_event, blinking Led).
- Fonts for paper: `[font=res://assets/fonts/hand_raghu.tres]`, `hand_stranger.tres` in BBCode.
- Dialogue: JSON in `data/dialogue/<tape>/*.json` (format in `systems/dialogue/dialogue.gd`: nodes
  with speaker/text/next/choices/branch; `if` = "event:x" / "flag:x" / "!..."; `set` flags
  (stored as GameManager flags `dlg_<name>`), `event` fires). Play: `call_group("hud",
  "start_dialogue", path, start)` -> HUD/DialogueView (await `finished`). Tests: `instant`,
  `advance()`, `choose(i)`, `choice_texts()`. Read flags with `Dialogue.flag("name")`.
- NPC base: `assets/characters/npc.tscn` (CharacterBody3D + Model + Agent + Talk). Put a
  character scene under `<npc>/Model`; head tracking turns `Model/.../Body/Head` (`uncanny`
  = 150 degrees + snap); `walk_to()` -> `arrived` (deferred); `talk()`; `active` toggles all.
  Levels add a `NavBaker` NavigationRegion3D (bakes from `../Collision` at load, on a thread;
  filter_baking_aabb keeps it to the ground). Agent `path_desired_distance` 0.9: the baked
  mesh floats ~0.5 m above the floor and a smaller value never advances.
- Tape 1 people: DeshmukhNPC (first round, asks for the gate at 3:12: flags
  `promised_gate` / `refused_gate` change 3:12 + the secretary), IyerNPC (walks over after
  the CCTV check for her parcel; mentions the red light: `heard_terrace`), secretary call =
  `data/dialogue/tape01/secretary.json`.
- Older input tests (test_camera, test_interaction, test_events, test_player) looked flaky;
  the real cause was the machine running out of memory (OneDrive syncing this folder grew to
  ~35 GB commit). If tests crash with D3D12 0x8007000e, check free RAM/commit first.

## The Cameraman as a threat (Phase 5)
- Design + escalation per tape: `docs/villain_cameraman.md` (story.md wins conflicts).
- `Stalker` (systems/characters/stalker.gd) = child `Brain` of an NPC with the cameraman
  model under `Model`. States ABSENT/WATCHING/FOOTAGE_ONLY/FOLLOWING/PATROL/HUNT/SEARCH/
  CAUGHT/FINAL; level scripts call `start_patrol()` / `follow()` / `stop()`. `exposure` 0..1
  rises while the player is in his shot (45 deg, 16 m, line of sight, not hidden); 1 = CAUGHT
  -> "TRACKING LOST" static -> `GameManager.load_checkpoint()` (`reload_on_catch` off in tests).
  He never runs: the player always outpaces him. Exposure drives VHS glitch + hiss.
- `HidingSpot` (Area3D, systems/story): crouched inside = invisible to him.
- `FootstepsAbove` (Area3D): answers each player step from one floor up (`armed_by`).
- Tape 1: CamWindowD (D balcony, first round, spot `t1_d_balcony`), the stool moves after
  the tape cut, StepsAboveB after the intercom, the courtyard stalk from power cut to meter room.

## Camera / screen
- Every level instances `ui/hud/camcorder.tscn` (OSD on layer 2, VHS shader on layer 3) and
  `ui/hud/hud.tscn` (layer 10, stays crisp above the VHS effect). Debug overlay = layer 20.
- Shake: `call_group("camera_shake", "add_trauma", x)`; glitch: `call_group("camcorder",
  "glitch", amount, seconds)`; or a `CameraReaction` node. CameraShake owns the camera's
  local rotation — don't set Camera3D.rotation elsewhere.
- 3D renders at 75% (`rendering/scaling_3d/scale`) for the lo-fi look and performance.
- Tests: frame rate is uncapped under `--script`; wait real seconds for timing checks, and
  free the level before quit() (sounds still playing at exit report leaks).

## Grounded look, props, characters, sound (Nov 2026 pass)
- Film look: `assets/shaders/film_grade.gdshader` on a GraphicsManager-owned canvas layer 1 (under the
  camcorder OSD/VHS, HUD). `SettingsManager.film_look` 0..1. `GraphicsManager.set_dread(0..1)` darkens /
  desaturates (the Stalker drives it from exposure).
- Real models: `python tools/fetch_models.py` (Poly Haven CC0 glTF, small props 512 px;
  credits in assets/models/CREDITS.md). Place with `tools/propkit.py` `Props(lv).model(name,
  pos, yaw, ...)` (front = -Z after yaw, like every kit prop) under the level's `Props` node
  (not batched). Root script `PropModel` (hide_parts, render_layers, visibility_end);
  `WallClock` turns clock hands to tape time (camcorder OSD) or real time, `stopped_at`.
- Render layer 19 "NotOnCCTV": seen by the player, culled by CCTV feeds
  (`PropModel.CCTV_CULL_MASK`), e.g. CCTV camera bodies.
- propkit also builds primitive clutter (Indian household, 1998 watchman, vehicles),
  `soft()` squashed spheres, `cloth()` hanging fabric (`assets/shaders/cloth.gdshader`: folds,
  sway, stripes; QuadMesh hung from its top edge), `dust_sheet()`.
- Characters (`tools/gen_characters.py`): skeleton pivots Body/Pelvis/HipL|R/KneeL|R,
  Body/Chest/ShoulderL|R/ElbowL|R, Body/Head/EyelidL|R; child `Life` =
  `CharacterLife` (breathing, blinking, walk cycle from the NPC's `walking`).
- One-off moments that must survive leaving a tape: `GameManager.remember(key)` /
  `remembers(key)` (save file). Chapter flags (`set_flag`) are wiped when the hub loads.
- Demo end: playing a tape that isn't built shows `DemoEnd` (ui/menus/demo_end.gd).
- Acoustics: `AcousticZone` Area3D (no physics layer, watches the player) eases the "Space"
  reverb on the SFX bus to its preset; smallest zone wins. Place with levelkit
  `acoustic_zone()`. Tube lights hum while lit (`Hum` child).
- Cloud screenshots: `apt-get install -y mesa-vulkan-drivers` gives lavapipe; then
  `xvfb-run -a $GODOT --path . --rendering-method forward_plus --script <shot script>`
  renders Forward+ (~30 s per shot); `gl_compatibility` works without it. Tests that need
  a window also run under xvfb-run (touch/menu-click tests still fail there, as on main).

## Core autoloads (studio layout, Nov 2026)
Order: EventBus, SettingsManager, InputManager, AudioManager, GraphicsManager, SaveManager,
SceneLoader, ObjectiveManager, GameManager (project.godot [autoload]).
- `EventBus`: `fire(id)` story events + typed signals (chapter_started/completed,
  checkpoint_saved, scene_transition_started/finished, setting_changed,
  input_device_changed, objective_changed, game_paused). Systems talk through it.
- `SaveManager`: user://saves/save_slot.json, `save_version` + `migrate()`, write = temp
  file + rename, previous file kept as .bak (load falls back to it). `data` dict.
  GameManager decides what to save; `GameManager.save_path` forwards to it (tests).
- `SceneLoader.change_scene(path, header, lines, prepare)`: VCR card, threaded load
  (direct load on web), swap, fade in. GameManager re-emits `transition_finished`.
- `AudioManager`: buses Master/Music/SFX/Ambience/Voice/UI; `play_ui`, pooled `play_sfx`
  / `play_at`, `play_music`/`stop_music` with fades, `set_muffled` (pause low-pass).
- `InputManager`: device (keyboard+mouse / gamepad / touch), `capture_mouse()`,
  `mouse_captured()`, `touch_mode`. Never read `Input.mouse_mode` elsewhere.
- `GameManager.quit_game()` stops audio, frees the scene, then quits (window close too):
  no leaks on exit. `chapter_play_time` / `last_chapter_time` for chapter screens.
- Levels write Forward+-only features (SSR, SSIL, volumetric fog) OFF plus
  `metadata/authored_graphics` (levelkit does it); GraphicsManager enables them only on
  Forward+ and when the preset allows (no warnings on the web renderer).
- Bug log: docs/bugs.md.
- Static typing: `python tools/lint_typing.py` must report 0 (CI: .github/workflows/checks.yml).
  Typed vars/params/returns everywhere in game code; tests/ and tools/ are exempt (tests
  reach autoloads untyped). project.godot warns on untyped declarations in the editor.

## Layout
- `scenes/`   hub, menus, test scenes
- `scripts/`  autoload (singletons), player, interaction, objectives, events, ui
- `chapters/` one folder per tape: scene + chapter-specific scripts/data
- `assets/shaders/`  .gdshader files (lo-fi / VHS post-processing)
- `ui/`       themes and HUD scenes
- `assets/`   models, textures, audio, fonts (binary files tracked by Git LFS)

## Conventions
- Systems shared across chapters live in `scripts/` and are reused, never copied into chapters.
- Keep it light (target: RTX 3050 Ti laptop): low-poly, few real-time lights, simple shaders.
- One commit per working system.
