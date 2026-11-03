# Bug log

Severity: **Blocker** (can't continue / crash / data loss), **Major** (broken feature or
obvious defect), **Minor** (small defect, workaround exists), **Polish** (cosmetic).

| ID | Severity | Area | Status | Description |
|---|---|---|---|---|
| B-001 | Minor | Intro / web renderer | Open | Quitting the game *during* the intro on the Compatibility renderer (web build) prints "Texture with GL ID 150/151: leaked 349524 bytes" (two 256x256 mipmapped textures). Not on Forward+, not in any other scene, not caused by the intro's font or sky ambient (both ruled out). Memory is released by the OS on exit; no player-visible effect. Next: bisect intro.tscn nodes. |
| B-002 | Minor | Tests (cloud only) | Open | Under xvfb in the cloud, test_menus "clicking the TV opens SETTINGS" and six test_touch checks fail; they fail identically on `main`. Needs a real window to confirm on the laptop. |
