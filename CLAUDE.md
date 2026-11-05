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
- Checkpoint = EventBus counts + GameManager flags + inventory (`add_item/has_item`, Pickups add) +
  objectives snapshot + world state + play time + camcorder time. World state = nodes in group
  "persist" with `save_state() -> Dictionary` / `load_state(d)` (Door: open/angle/locked, LightSwitch:
  on), keyed by path from the level root, restored before the player is placed. Anything else that
  must survive a reload is derived from EventBus counts or stored with `GameManager.set_flag()`.
  While objectives rebuild, `EventBus.replaying` is true and EventReactions ignore events.
- Never mid-scare/cutscene: `GameManager.block_saving(source, seconds=0)` / `unblock_saving(source)`;
  `can_save()`. Holders: every EventReaction from its event until it has played (+`save_hold_after`
  2.5 s), DialogueView while open, camcorder tape_cut, the Stalker in FOLLOWING/HUNT/SEARCH/CAUGHT.
  A checkpoint reached while held is queued (`deferred_checkpoint()`) and written when free;
  `save_checkpoint(id, true)` forces (tests). Holds clear on level change. Story-beat autosave =
  `AutosaveReaction` (on_event -> checkpoint_id). Save icon = HUD `SaveIndicator` (2 s, on
  EventBus.checkpoint_saved). Debug overlay shows who holds saving. Test: test_save_system.gd.
- SceneLoader warms shaders behind the loading card (every material drawn once on a 2 cm quad in
  front of the camera, `last_warmup_count`).

## Hub: Nikhil's room (Phase 3)
- `chapters/hub/nikhil_room.tscn` = room + corridor + lane view, generated by `tools/gen_hub.py`
  (also the main-menu backdrop). `chapters/hub/hub.tscn` = room + Hub logic + player + HUD.
- Tapes are unlabeled, in the cardboard box; the box hands out the next unwatched tape.
  Hub stage = tapes watched in order; `apply_stage()` switches the bible's room changes.
  F6 (debug builds) cycles stages. Chores are objectives built in code.
- GI: VoxelGI baked by `tools/bake_voxelgi.gd -- <scene>` into `<scene>_gi.res`; re-run the
  generator afterwards so it references the data. Low preset hides VoxelGI.
- `call_group("hud", "show_note", bbcode, handwritten)` shows paper/screens (NoteView).
- Phone (present day only; the 2009 tape later): `PlayerPhone.attach(player, data_json, stage)` (systems/phone)
  puts a Blender phone (assets/models/phone, tools/blender/build_props.py) under the camera; `carried` /
  `charging` / `desk_anchor`. `phone` action (R, pad D-pad up) raises it; raised = walk only, Interactor off,
  up/down/wheel + E/click + RMB/Backspace (back), touch taps hit the glass (`screen_uv_at`). PhoneScreen
  (SubViewport UI): home, Messages/threads (one-tap `reply` fires its event), Calls log, incoming/in-call
  (answer plays a dialogue JSON), Torch. Data: data/phone/hub.json (contacts, threads, calls, scripted
  `incoming` by `after` seconds, `min_stage`/`max_stage`). Battery = GameManager.remember_value
  ("phone_battery"). Hub: take it from the desk, reply to Maa on it, charger takes/returns it; drained to
  12% on the first return after each tape. Test: test_phone.gd.
- Fonts: every role FontVariation falls back to assets/fonts/dejavu/DejaVuSans-Symbols.ttf (subset: arrows,
  boxes, blocks, shapes, symbols). The web build has no system fonts: test_fonts.gd fails if any script/scene/
  data file prints a symbol the fonts lack.
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
- Main scene = `ui/menus/boot.tscn` (Boot: black -> studio card 3 s + `boot_sting.wav` -> content
  warning, PRESS ANY KEY -> main menu; studio name from `data/credits.json`). Tests load
  `ui/menus/main_menu.tscn` directly. Main menu = diegetic: the VCR-OSD menu UI lives in the
  `Screen` SubViewport (960x720) and is shown on the CRT in `menu_backdrop.tscn` (Nikhil's
  room, tube light off, REC dot) via `assets/shaders/crt_screen.gdshader`. MainMenu._input forwards
  everything to the screen; mouse positions go through `MenuBackdrop.screen_uv_at()` (same
  curvature as the shader). Camera framings IDLE / CLOSE (settings, tapes) / DIVE (start).
  Menu UI paths start with `Screen/UI/`; tests read focus with `menu.focused_control()`.
  CONTINUE / NEW GAME (replays intro) / TAPES (locked = blank cassette; preview = the still
  GameManager saves at each checkpoint (`chapter_thumbnail(id)`, user://.../thumbs), watched +
  runtime, `SPOTTED n/3` from ChapterData `spot_prefix`/`spots_total`) / SETTINGS / CREDITS
  (CreditsRoll reads `data/credits.json`, built by `python tools/gen_credits.py` from
  `data/credits_header.json` + the CREDITS.md files) / QUIT. Menu drone =
  `assets/audio/music/menu_drone.ogg` via AudioManager.play_music (4 s fade in). Version label =
  project.godot `application/config/version`.
- Loading screen = SceneLoader's titled TapeTransition card: ReelIndicator + LOADING % (threaded
  load progress) + a tip from `data/loading_tips.json` (LoadingTips; `{action}` -> key, `where` =
  scene path substring). Pause menu asks (ConfirmDialog) before restart / eject / main menu.
- First launch autoplays `chapters/intro/intro.tscn` (built by `tools/gen_intro.py`, driven by
  `chapters/intro/scripts/intro_director.gd`; hold Space to skip; `intro_seen` in the save).
- Settings screen: six tabs (GRAPHICS, DISPLAY, AUDIO, CONTROLS, GAMEPLAY, ACCESSIBILITY) from
  `ROWS` in settings_menu.gd (`tab_index("NAME")` in tests; "desktop" rows hidden on web), button
  rows (CALIBRATE = BrightnessCalibration overlay, RESET keys), rebind rows from
  `SettingsManager.REBINDABLE` (saved as `key_bindings`; `rebind()` swaps on a conflict,
  `reset_bindings()`). Gamepad map is added at runtime by `InputManager.add_gamepad_map()`
  (look_* actions = right stick, `controller_sensitivity`). `SettingsManager.flash_scale()` (reduce
  flashing) scales VHS glitches, flicker dips, static. `show_objectives` off = Tab only.
  Test: test_settings.gd. Inner monologue: `call_group("subtitles", "think", text, seconds)` (italics,
  no name). Objectives: HUD ObjectivePanel top-left, slide/fade in, `objective_update.wav` (not on
  replays). Subtitles: `call_group("subtitles", "say",
  speaker, text, seconds)` (Subtitles node is in the HUD and the intro).
- Pause menu lives inside `ui/hud/hud.tscn` (Esc). Theme: `ui/themes/vcr_theme.tres`.
- Branding: studio = TIMELESS STUDIOS (data/credits_header.json -> gen_credits.py). Logo =
  the owner's VHS cassette art, `assets/branding/logo_vhs.png` (source), `logo_label.png` (menu
  CRT panel), `icon.png` / `icon.ico` (app + Windows exe). Window title "Unlabeled - Horror" is
  set at runtime (GameManager.WINDOW_TITLE); config/name stays UNLABELED because it names the
  user:// folder (saves). Engine splash = plain black (spec).
- Tests that open the main menu must call `GameManager.mark_intro_seen()` first.

## Scripted sequences + cutscenes (step 7)
- `SequencePlayer` (systems/sequence): a level lists JSON files (`data/sequences/<tape>/*.json`,
  format in data/sequences/README.md and the script header). Trigger event/zone/interact/time/
  objective; steps say/think/message/wait/sound/light/flicker/door/show/hide/walk/set/call/fire/
  dialogue/glitch/shake/tension/silence/look/camera/letterbox/if/parallel... `once` = EventBus
  `seq_<id>`; running = holds saving. `"cutscene": true`: input off, hold E 1.5 s to skip
  (skipping still applies every effect), cinematic camera blends back. `look` turns the
  player's own view (first-person moments). `validate(id)` -> test_sequences.gd.
- Tape 1: the director makes `Story/Sequences` (intercom call, 3:12 look, ending cutscene
  calling `begin_ending` / `show_last_frame` / `finish`).
- `GameManager.complete_chapter()` -> `ChapterComplete` (ui/menus): fade to black + tape
  runout, card (title, END OF TAPE, runtime, sightings), any key -> hub. Tests set
  `GameManager.chapter_complete_wait = 0.3` (closes itself once black).

## Chapter 1 polish (step 8)
- Flicker = `LightFlicker` (systems/events): value noise drop-outs + `light_flicker.wav` at the
  light on every drop (FlickerReaction, sequence `flicker`, TubeLight stutter ticks).
- `CCTVMonitor`: night-gain picture (HDR albedo) + `Glow` OmniLight whose energy follows the
  feed's measured brightness (sampled per switch), blanks on switch, dies with the power.
- `IdleEvents` (systems/story): stand still 20 s -> a far-off sound (no repeats, cooldown,
  not while saving is held or tension > 0.5). Tape 1 (dog, pipe, lathi + whistle, train,
  gate) via gen_tape01.py; hub.tscn (dog, pressure cooker, horn, pipe).
- Floating props: `tools/check_props.gd -- <scene>` (tools/prop_audit.gd); wall/ceiling/
  stacked props pass propkit `mount="wall"|"ceiling"|"on"`. test_polish.gd runs it on
  Tape 1 + the hub.
- Mirrors: none story-relevant yet (the bible's mirror sightings come in later tapes).

## QA / tooling (step 9)
- F1 = `DebugMenu` autoload (core/debug_menu.gd; freed in release builds): chapters, the level's
  checkpoints (GO TO / LOAD SAVED), noclip (`Player.noclip`), SHOW FPS, SHOW TRIGGERS (Area3D
  boxes: red story, green checkpoint, blue hiding), GIVE items (the level's Pickups), AI on/off.
  Test: test_debug_menu.gd.
- `ErrorLog` (core/error_log.gd, a Logger installed by GameManager): errors + warnings with
  timestamps and GDScript backtraces -> user://logs/errors.log (rotates; godot.log keeps all).
- docs/performance.md (tools/profile_level.gd numbers), docs/playtest_checklist.md,
  tests/test_leaks.gd (counts flat across room <-> Tape 1), tests/support.gd `finish()`.
- SceneLoader loads without sub-threads (sub-threads leaked load tokens; same speed).

## Release / Steam (spec 15)
- Export presets: Web (iPad), "Windows Desktop", "Linux" (export_presets.cfg; excludes tools/,
  docs/, build/, tests/*.gd — tests/scenes stays: data/chapter_list.tres references it).
- `python tools/build_release.py patch|minor|major|none [--no-export]`: version bump, CHANGELOG.md,
  export + zip to build/release/. Tag `v<version>` -> .github/workflows/desktop.yml builds both and
  smoke-runs the exported Linux build headless (main scene, menu, Tape 1; any error fails it).
- Walkthrough/trailer footage: `tools/record_walkthrough.gd` (Movie Maker: `--write-movie x.avi
  --fixed-fps 30 --resolution 1920x1080 --script res://tools/record_walkthrough.gd`; usage in the
  header). Drives the real game with a scripted camera, ~2 min; re-record after level changes.
- `Achievements` autoload (core/achievements.gd + data/achievements.json; ids = Steamworks API
  names): EventBus.chapter_completed / spotted / player_caught; stored in the save; GodotSteam's
  `Steam` singleton, when installed, is initialised and mirrored (no other code touches Steam).
  Test: test_achievements.gd (mock backend tests/support_steam_mock.gd). Owner steps: docs/steam.md.

## Graphics / performance (target: 60 FPS at 1080p on the RTX 3050 Ti laptop)
- Graphics settings: `SettingsManager.graphics_quality` LOW/MEDIUM/HIGH fills the detail keys
  (`GRAPHICS_PRESETS`: render_scale, anti_aliasing, shadow/texture/fog/effects_quality); changing a
  detail flips it to CUSTOM (3). First launch picks a preset from the GPU (`detect_quality()`).
  `GraphicsManager.current()` merges its detail tables (SHADOWS/TEXTURES/FOG/EFFECTS/AA) and
  applies them; it only switches level features off, never adds them. Post switches film_grain /
  chromatic_aberration / vignette / tape_blur drive film_grade + vhs shader uniforms.
  FPS counter = SettingsManager.show_fps.
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
- Blender wall kit: `tools/blender/build_wallkit.py` builds the pieces listed in
  `assets/models/wallkit/pieces.json` as OBJ meshes (moulded window frames + shutters, MS grills with an
  arched band, vent lattices, masonry = surround + sill + lintel + chajja, door frames, drain pipes).
  levelkit `window_fill` -> `window_kit()` and `drain_pipe()` place them with `lv.kit(piece, pos, yaw, mat)`
  (local +Z = outside); Level.write() emits one MultiMeshInstance3D per (piece, material) under `Kit`
  (material_override: the wing's own wall paint for masonry). A size nobody built yet is added to
  pieces.json and falls back to boxes: run the generators, then `blender -b --factory-startup --python
  tools/blender/build_wallkit.py`, `--import`, then the generators again. Window glass stays a box.

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

## Tape 2: The Toll Booth (step 10, first pass)
- `chapters/chapter_02/toll_plaza.tscn` + `objectives.tres` from `tools/gen_tape02.py`. Playable
  as the DEBUG chapter `tape_02_wip` (chapters/chapter_02/chapter_wip.tres, F1 menu / chapter
  list debug_chapters); the real `tape_02_tollbooth` keeps an empty scene_path so the demo
  still ends after Tape 1 (DemoEnd). Flip it when the tape is polished.
- Salim's booth 3 on the island at x 0, lane x -2.7 (left-hand traffic towards -Z, right-hand
  drive: the driver stops at the -X window). `TollVehicle` (AnimatableBody3D: drive_up ->
  `arrived`, WAITING, leave -> `gone`); `PlateLog` (flag `t2_log`, the stranger's line after
  van 4); radio = EventOnUse `radio_used` -> data/dialogue/tape02/*.json.
- `tape02_director.gd` `_advance()` derives the next step from EventBus counts/flags
  (`vehicle_served` x3, `van_served_1..4`, `t2_cut_n` tape cuts + checkpoint `booth`), so
  reloads resume. Ending = data/sequences/tape02/ending.json (receipt with Salim's name,
  power_cut, red dot in the back seat). Spots: t2_cctv (lane camera), t2_road, t2_backseat.
- Test: test_tape02.gd. Art is kit boxes + propkit for now (vehicles, people = boxes).

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
  Node extras: `duration` (auto-advance), `audio` (file), `timer` + `timeout` (timed choices, red bar;
  only for tense moments, e.g. the secretary's reveal). `Dialogue.validate()` lists broken links;
  test_dialogue_system.gd validates every file in data/dialogue.
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
- Blender characters: `tools/blender/build_characters.py` (run `blender -b --factory-startup --python
  tools/blender/build_characters.py [-- name]`; cloud: `apt-get install -y blender python3-numpy`, then
  `bash tools/blender/fetch_makehuman.sh` for the CC0 MakeHuman data in tools/_build). MakeHuman base mesh
  + macro targets per character (CHARACTERS table: gender, age_years, weight, height, hair, sleeve,
  colours, garments), reposed from A-pose, skin/face painted as vertex colours then baked by numpy into
  a UV texture (Cycles baking is black headless), clothes = zones + lathe garments, MakeHuman weights
  folded onto 14 game bones named like the pivots. Writes meshes/<name>.glb + .json (pivots, anchors).
  gen_characters.py then builds pivots from the JSON, instances Body/Mesh, adds `Skin` =
  SkinnedBody (systems/characters/skinned_body.gd: pivots -> bones each frame; eyelid pivot scale ->
  lid rotation) and seats accessories via Head/Chest/Pelvis `Fit` frames (old body -> new body).
  Preview without Godot: `tools/blender/preview.py -- <glb> <png> [closeup]`. Test: test_skinned_body.gd.
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
Order: EventBus, SettingsManager, InputManager, AudioManager, UIFeedback, GraphicsManager, SaveManager,
SceneLoader, ObjectiveManager, GameManager, Achievements, DebugMenu (project.godot [autoload]).
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

## Game feel (studio spec step 2)
- Player: walk 2.2 / crouch 1.2 / run 3.8 m/s, `accel_time` 0.2 s / `decel_time` 0.15 s
  (eased), `ChapterData.allow_running`. Head bob follows `Footsteps.phase()` (dip on each
  footfall), scaled by `SettingsManager.motion_scale()` (head_bob_intensity x reduce motion);
  strafe tilt 1.5 deg; dips on landing and stepping down. `sway_allowed()` gates sway/FOV kick.
- Sounds with variants = `SoundSet` resources (data/sounds/*.tres, made by
  gen_placeholder_sfx.py; clips in assets/audio/sfx/variants/): `pick()` never repeats,
  +-5% pitch. Play with `AudioManager.play_set_at()`. Footstep surfaces: wood, carpet, tile,
  concrete, gravel, grass, metal (old dirt/soft map to gravel/carpet).
- Every use makes a sound: `Interactable.use_sounds` or a soft tick (`default_tick`; owners
  with their own sounds turn it off: Door, Drawer, LightSwitch, Pickup). Door: creak /
  creak + latch / locked rattle + camera nudge. Reach 2.0 m; prompt fades 0.15 s;
  `Interactor.used` -> crosshair pulse. Inspect view blurs the world (ui_blur.gdshader).
- Tests: test_game_feel.gd, test_interaction_feel.gd.

## Audio system (studio spec step 3)
- Ambience: `AmbienceSet` (data/ambience/*.tres: looping OGG beds + levels) on an
  `AcousticZone` (`ambience`; innermost zone with one wins). `AudioManager.set_ambience()`
  crossfades over 1.5 s; layers shared by both places keep playing, re-levelled.
- Tension: `AudioManager.set_tension(0..1, source)`; highest source wins; three layers
  (drone_low, rumble from 0.25, drone_high from 0.55) on the Music bus. Tape 1 story levels
  come from EventBus counts (`tape01_director.TENSION_BEATS`), the Stalker adds exposure.
  `hold_silence(seconds)` = deliberate silence before a scare (Tape 1: before the intercom).
- Voice: subtitles/dialogue carry line ids (`t1/vo_<event>`, `t1/opening_N`,
  `<dialogue file>/<node>`); lines without one get `Subtitles.auto_voice_id(text)` =
  "auto/<md5[:12]>". `AudioManager.play_voice(id)` plays assets/audio/voice/<id>.ogg when it
  exists, else subtitles only. Voice script: `python tools/voice_lines.py` -> data/voice/lines.json
  + docs/voice_script.md (cast notes, `speak` text); `--install <dir>` turns `<id with / -> __>.wav|mp3`
  into normalised OGGs (radio/phone filtered). Playthrough tests fail if a spoken line isn't in
  the script (support.gd `unscripted_voice_ids`): re-run the tool after writing new lines.
- Beds: gen_placeholder_sfx.py -> tools/_build/beds/ -> `python tools/process_audio.py`
  (ffmpeg, OGG + loudness) -> `--import` -> `python tools/process_audio.py --imports` (loop).
  Every file + licence: docs/audio_sources.md. `AudioManager.shutdown()` on quit.
- Test: test_audio_system.gd.

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
