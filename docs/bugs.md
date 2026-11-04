# Bug log

Severity: **Blocker** (can't continue / crash / data loss), **Major** (broken feature or
obvious defect), **Minor** (small defect, workaround exists), **Polish** (cosmetic).

| ID | Severity | Area | Status | Description |
|---|---|---|---|---|
| B-001 | Minor | Intro / web renderer | Open | Quitting the game *during* the intro on the Compatibility renderer (web build) prints "Texture with GL ID 150/151: leaked 349524 bytes" (two 256x256 mipmapped textures). Not on Forward+, not in any other scene, not caused by the intro's font or sky ambient (both ruled out). Memory is released by the OS on exit; no player-visible effect. Next: bisect intro.tscn nodes. |
| B-002 | Minor | Tests (cloud only) | Open | Under xvfb in the cloud, test_menus "clicking the TV opens SETTINGS" and six test_touch checks fail; they fail identically on `main`. Needs a real window to confirm on the laptop. |
| B-003 | Minor | Tests | Open | Tests that load a chapter or the hub print "N ObjectDB instances were leaked at exit" (and some "resources still in use"): the test quits a few frames after `queue_free()` of the level while deferred/threaded work still holds references. Same counts on the step-4a commit; the game's own quit path (`GameManager.quit_game`) is clean. Fix with the QA pass (step 9): a shared test teardown that waits for the scene to leave the tree and the NavBaker thread to finish. |
| B-004 | Minor | Tests (cloud only) | Open | Timing-based checks are flaky under software GL (xvfb): test_events (flicker switch-off, door slam delay, flashlight restore) fails 0-2 checks per run on both 4a and 4b; test_player "flashlight toggles" and test_camera shake peak fail now and then (flashlight: the player ignores input while the mouse isn't captured, and an xvfb window doesn't always get the capture; seen failing twice in a row on step 8 with player.gd unchanged). Each passes when run on its own most of the time. Confirm on the laptop. |
