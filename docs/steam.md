# Steam release (demo first)

What the code already does, and what only the owner can do on Steam's side.

## In the project
- **Builds:** export presets "Windows Desktop" (`build/windows/Unlabeled.exe`, icon + Timeless
  Studios version info) and "Linux" (`build/linux/Unlabeled.x86_64`). Release builds drop the F1
  debug menu (`OS.is_debug_build()`) and stdout prints (`run/disable_stdout.release`); errors
  still go to `user://logs/errors.log`.
- **One command:** `python tools/build_release.py patch` bumps the version, writes CHANGELOG.md,
  exports and zips both builds into `build/release/`. `git tag v<version>` + push makes
  `.github/workflows/desktop.yml` build them on GitHub and smoke-test the Linux build (boots the
  exported game headless: main scene, menu, Tape 1 must load without errors).
- **Achievements:** `data/achievements.json` (9: one per tape + secret ones). `core/achievements.gd`
  stores unlocks in the save and, when GodotSteam is installed, pushes them to Steam. The ids in
  the JSON are the Steamworks API names.

## Owner checklist (Steamworks, in this order)
1. **Steam Direct**: pay the app fee, create the app for "Unlabeled - Horror" (Timeless Studios).
2. **Demo app**: Steamworks > your app > "Create demo" (demos are separate app ids). Note both ids.
3. **Store page** (main game) — required assets: header capsule 920x430, small capsule 462x174,
   main capsule 1232x706, vertical capsule 748x896, page background, library capsule 600x900,
   library hero 3840x1240 + logo, at least 5 screenshots (1920x1080), short + long description,
   trailer recommended. The VHS logo (`assets/branding/logo_vhs.png`) is the base for these.
4. **Content survey**: violence/horror, flashing lights, mature content disclosure.
5. **Coming Soon**: the page must be public at least 2 weeks before launch; Valve reviews the
   page and the build (allow a week).
6. **Achievements**: Steamworks > Stats & Achievements: create each id from
   `data/achievements.json` (name, description, hidden), upload 64x64 icons, publish.
7. **GodotSteam**: install the GodotSteam GDExtension (Asset Library) into `addons/`, put the
   demo's app id in `steam_appid.txt` in the project root for local testing (never ship it).
   Nothing else changes: `Achievements` finds the `Steam` singleton, calls `steamInitEx`, runs
   callbacks and mirrors unlocks.
8. **Upload**: install the Steamworks SDK (ContentBuilder), copy `tools/steam/*.vdf`, fill in the
   app/depot ids, then `steamcmd +login <account> +run_app_build ../scripts/app_build_demo.vdf +quit`.
   Set the build live on the default branch in Steamworks > SteamPipe > Builds.

## Before the demo goes public (from the readiness review)
- Play the whole demo on the laptop (docs/playtest_checklist.md), fill in docs/performance.md FPS.
- Replace the synthesised placeholder sounds and record/generate the voice lines
  (`data/voice/lines.json`, tools/voice_lines.py).
- Keep Tape 2 out of the demo (it is a debug chapter; the demo ends after Tape 1).
