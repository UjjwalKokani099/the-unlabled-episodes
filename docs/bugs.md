# Bug log

Severity: **Blocker** (can't continue / crash / data loss), **Major** (broken feature or
obvious defect), **Minor** (small defect, workaround exists), **Polish** (cosmetic).

| ID | Severity | Area | Status | Description |
|---|---|---|---|---|
| B-001 | Minor | Intro / web renderer | Open | Quitting the game *during* the intro on the Compatibility renderer (web build) prints "Texture with GL ID 150/151: leaked 349524 bytes" (two 256x256 mipmapped textures). Not on Forward+, not in any other scene, not caused by the intro's font or sky ambient (both ruled out). Memory is released by the OS on exit; no player-visible effect. Next: bisect intro.tscn nodes. |
| B-002 | Minor | Tests (cloud only) | Open | Under xvfb in the cloud, test_menus "clicking the TV opens SETTINGS" and six test_touch checks fail; they fail identically on `main`. Needs a real window to confirm on the laptop. |
| B-003 | Minor | Tests / loading | Mostly fixed (step 9) | Tests and the game's own quit printed hundreds of "ObjectDB instances were leaked at exit" (hub: 233, test_hub: 494). Cause: SceneLoader's threaded load with sub-threads left internal ResourceLoader load tokens alive. Fixed by loading without sub-threads (same load time). What's left (2-25 per test, 13 after room/Tape 1 cycles) are the engine's own tokens from threaded loading; a direct load leaves none. Counts don't grow across loads (test_leaks.gd). `tests/support.gd` finish() = shared teardown. |
| B-004 | Minor | Tests (cloud only) | Open | Timing-based checks are flaky under software GL (xvfb): test_events (flicker switch-off, door slam delay, flashlight restore) fails 0-2 checks per run on both 4a and 4b; test_player "flashlight toggles" and test_camera shake peak fail now and then (flashlight: the player ignores input while the mouse isn't captured, and an xvfb window doesn't always get the capture; seen failing twice in a row on step 8 with player.gd unchanged). Each passes when run on its own most of the time. Confirm on the laptop. |
| B-005 | Major | Tape 1 / camera | Fixed (step 8) | The covered car in the parking floated 30 cm (placed at y 0.3, its wheels sit at model y 0); the box on the hub almirah floated 17 cm. Found by tools/check_props.gd. |
| B-006 | Minor | Ending card / cutscene UI | Fixed (step 8) | END OF TAPE "PRESS ANY KEY" was off-centre; the hold-to-skip ring overlapped the camcorder date. |
| B-007 | Minor | Performance (web) | Open | Tape 1 on the Compatibility renderer peaks at ~2050 draw calls at the courtyard overview (docs/performance.md). Next: visibility ranges for clutter, check the batcher. |
| B-008 | Minor | Tape 1 CCTV monitor | Fixed (step 8) | The cabin CCTV monitor showed an almost black picture at night; now night gain + a matching screen glow. |
| B-009 | Minor | Quit / audio | Fixed (release setup) | Quitting during Tape 1 sometimes left 8-10 audio resources in use: the level restarted hums after the audio stop, and the audio server frees stopped playbacks on its mixing thread (frames can be ms apart). quit_game now waits for nav bakes, frees the level, stops audio, then waits 0.3 s real time. Found by the exported-build smoke test. |
| B-010 | Polish | Headless | Fixed | keyboard_get_keycode_from_physical errors under the headless display server (CI, smoke test): key names use the physical key there. |
