# Audio sources and licences

Every sound in the game must be CC0 / royalty-free or our own, and listed here.

**Current state (Nov 2026):** every file below is an original placeholder synthesised by
`tools/gen_placeholder_sfx.py` (stdlib Python, no samples), so it belongs to the project;
nothing third-party is included yet. Ambience/tension beds are loudness-normalised by
`tools/process_audio.py` (ffmpeg loudnorm: ambience -30 LUFS, tension -28 LUFS, voice -16
LUFS, true peak <= -1.5 dBTP).

**Replacing with real CC0 recordings:** the CC0 libraries (Kenney audio packs, freesound.org
CC0 filter, Sonniss is royalty-free but not CC0) block scripted downloads or need an account,
so they must be downloaded by hand. Keep the file names: drop a WAV into
`tools/_build/beds/<ambience|tension>/` for beds (then run tools/process_audio.py), or
overwrite the WAV in `assets/audio/sfx/` (variants: `assets/audio/sfx/variants/<set>_<n>.wav`).
Then add a row here: file, source URL, author, licence, date.

| File | How it was made | Author / licence | Notes |
|---|---|---|---|
| `ambience/crickets.ogg` | Synthesised bed (tools/gen_placeholder_sfx.py) -> tools/process_audio.py (OGG, loudness-normalised) | Original (project) | Replace with a CC0 recording |
| `ambience/electric.ogg` | Synthesised bed (tools/gen_placeholder_sfx.py) -> tools/process_audio.py (OGG, loudness-normalised) | Original (project) | Replace with a CC0 recording |
| `ambience/fridge.ogg` | Synthesised bed (tools/gen_placeholder_sfx.py) -> tools/process_audio.py (OGG, loudness-normalised) | Original (project) | Replace with a CC0 recording |
| `ambience/rain.ogg` | Synthesised bed (tools/gen_placeholder_sfx.py) -> tools/process_audio.py (OGG, loudness-normalised) | Original (project) | Replace with a CC0 recording |
| `ambience/room_tone.ogg` | Synthesised bed (tools/gen_placeholder_sfx.py) -> tools/process_audio.py (OGG, loudness-normalised) | Original (project) | Replace with a CC0 recording |
| `ambience/traffic.ogg` | Synthesised bed (tools/gen_placeholder_sfx.py) -> tools/process_audio.py (OGG, loudness-normalised) | Original (project) | Replace with a CC0 recording |
| `ambience/wind.ogg` | Synthesised bed (tools/gen_placeholder_sfx.py) -> tools/process_audio.py (OGG, loudness-normalised) | Original (project) | Replace with a CC0 recording |
| `sfx/breathing.wav` | Synthesised (tools/gen_placeholder_sfx.py) | Original (project) | Replace with a CC0 recording |
| `sfx/crickets_loop.wav` | Synthesised (tools/gen_placeholder_sfx.py) | Original (project) | Replace with a CC0 recording |
| `sfx/dog_bark.wav` | Synthesised (tools/gen_placeholder_sfx.py) | Original (project) | Replace with a CC0 recording |
| `sfx/door_slam.wav` | Synthesised (tools/gen_placeholder_sfx.py) | Original (project) | Replace with a CC0 recording |
| `sfx/doorbell.wav` | Synthesised (tools/gen_placeholder_sfx.py) | Original (project) | Replace with a CC0 recording |
| `sfx/drawer_slide.wav` | Synthesised (tools/gen_placeholder_sfx.py) | Original (project) | Replace with a CC0 recording |
| `sfx/fan_hum.wav` | Synthesised (tools/gen_placeholder_sfx.py) | Original (project) | Replace with a CC0 recording |
| `sfx/footstep_chappal.wav` | Synthesised (tools/gen_placeholder_sfx.py) | Original (project) | Replace with a CC0 recording |
| `sfx/gate_clang.wav` | Synthesised (tools/gen_placeholder_sfx.py) | Original (project) | Replace with a CC0 recording |
| `sfx/gate_creak.wav` | Synthesised (tools/gen_placeholder_sfx.py) | Original (project) | Replace with a CC0 recording |
| `sfx/horn_far.wav` | Synthesised (tools/gen_placeholder_sfx.py) | Original (project) | Replace with a CC0 recording |
| `sfx/intercom_buzz.wav` | Synthesised (tools/gen_placeholder_sfx.py) | Original (project) | Replace with a CC0 recording |
| `sfx/knock.wav` | Synthesised (tools/gen_placeholder_sfx.py) | Original (project) | Replace with a CC0 recording |
| `sfx/phone_ring.wav` | Synthesised (tools/gen_placeholder_sfx.py) | Original (project) | Replace with a CC0 recording |
| `sfx/power_down.wav` | Synthesised (tools/gen_placeholder_sfx.py) | Original (project) | Replace with a CC0 recording |
| `sfx/room_hum.wav` | Synthesised (tools/gen_placeholder_sfx.py) | Original (project) | Replace with a CC0 recording |
| `sfx/rustle.wav` | Synthesised (tools/gen_placeholder_sfx.py) | Original (project) | Replace with a CC0 recording |
| `sfx/step_concrete.wav` | Synthesised (tools/gen_placeholder_sfx.py) | Original (project) | Replace with a CC0 recording |
| `sfx/step_dirt.wav` | Synthesised (tools/gen_placeholder_sfx.py) | Original (project) | Replace with a CC0 recording |
| `sfx/step_metal.wav` | Synthesised (tools/gen_placeholder_sfx.py) | Original (project) | Replace with a CC0 recording |
| `sfx/step_soft.wav` | Synthesised (tools/gen_placeholder_sfx.py) | Original (project) | Replace with a CC0 recording |
| `sfx/step_tile.wav` | Synthesised (tools/gen_placeholder_sfx.py) | Original (project) | Replace with a CC0 recording |
| `sfx/step_wood.wav` | Synthesised (tools/gen_placeholder_sfx.py) | Original (project) | Replace with a CC0 recording |
| `sfx/sting.wav` | Synthesised (tools/gen_placeholder_sfx.py) | Original (project) | Replace with a CC0 recording |
| `sfx/switch_clack.wav` | Synthesised (tools/gen_placeholder_sfx.py) | Original (project) | Replace with a CC0 recording |
| `sfx/traffic_loop.wav` | Synthesised (tools/gen_placeholder_sfx.py) | Original (project) | Replace with a CC0 recording |
| `sfx/train_far.wav` | Synthesised (tools/gen_placeholder_sfx.py) | Original (project) | Replace with a CC0 recording |
| `sfx/tube_hum.wav` | Synthesised (tools/gen_placeholder_sfx.py) | Original (project) | Replace with a CC0 recording |
| `sfx/tv_static.wav` | Synthesised (tools/gen_placeholder_sfx.py) | Original (project) | Replace with a CC0 recording |
| `sfx/ui_blip.wav` | Synthesised (tools/gen_placeholder_sfx.py) | Original (project) | Replace with a CC0 recording |
| `sfx/ui_select.wav` | Synthesised (tools/gen_placeholder_sfx.py) | Original (project) | Replace with a CC0 recording |
| `sfx/variants/door_creak_1.wav` | Synthesised variant (tools/gen_placeholder_sfx.py, SoundSet in data/sounds/) | Original (project) | Replace with a CC0 recording |
| `sfx/variants/door_creak_2.wav` | Synthesised variant (tools/gen_placeholder_sfx.py, SoundSet in data/sounds/) | Original (project) | Replace with a CC0 recording |
| `sfx/variants/door_creak_3.wav` | Synthesised variant (tools/gen_placeholder_sfx.py, SoundSet in data/sounds/) | Original (project) | Replace with a CC0 recording |
| `sfx/variants/door_creak_4.wav` | Synthesised variant (tools/gen_placeholder_sfx.py, SoundSet in data/sounds/) | Original (project) | Replace with a CC0 recording |
| `sfx/variants/door_creak_5.wav` | Synthesised variant (tools/gen_placeholder_sfx.py, SoundSet in data/sounds/) | Original (project) | Replace with a CC0 recording |
| `sfx/variants/door_latch_1.wav` | Synthesised variant (tools/gen_placeholder_sfx.py, SoundSet in data/sounds/) | Original (project) | Replace with a CC0 recording |
| `sfx/variants/door_latch_2.wav` | Synthesised variant (tools/gen_placeholder_sfx.py, SoundSet in data/sounds/) | Original (project) | Replace with a CC0 recording |
| `sfx/variants/door_latch_3.wav` | Synthesised variant (tools/gen_placeholder_sfx.py, SoundSet in data/sounds/) | Original (project) | Replace with a CC0 recording |
| `sfx/variants/door_latch_4.wav` | Synthesised variant (tools/gen_placeholder_sfx.py, SoundSet in data/sounds/) | Original (project) | Replace with a CC0 recording |
| `sfx/variants/door_latch_5.wav` | Synthesised variant (tools/gen_placeholder_sfx.py, SoundSet in data/sounds/) | Original (project) | Replace with a CC0 recording |
| `sfx/variants/door_rattle_1.wav` | Synthesised variant (tools/gen_placeholder_sfx.py, SoundSet in data/sounds/) | Original (project) | Replace with a CC0 recording |
| `sfx/variants/door_rattle_2.wav` | Synthesised variant (tools/gen_placeholder_sfx.py, SoundSet in data/sounds/) | Original (project) | Replace with a CC0 recording |
| `sfx/variants/door_rattle_3.wav` | Synthesised variant (tools/gen_placeholder_sfx.py, SoundSet in data/sounds/) | Original (project) | Replace with a CC0 recording |
| `sfx/variants/door_rattle_4.wav` | Synthesised variant (tools/gen_placeholder_sfx.py, SoundSet in data/sounds/) | Original (project) | Replace with a CC0 recording |
| `sfx/variants/door_rattle_5.wav` | Synthesised variant (tools/gen_placeholder_sfx.py, SoundSet in data/sounds/) | Original (project) | Replace with a CC0 recording |
| `sfx/variants/interact_tick_1.wav` | Synthesised variant (tools/gen_placeholder_sfx.py, SoundSet in data/sounds/) | Original (project) | Replace with a CC0 recording |
| `sfx/variants/interact_tick_2.wav` | Synthesised variant (tools/gen_placeholder_sfx.py, SoundSet in data/sounds/) | Original (project) | Replace with a CC0 recording |
| `sfx/variants/interact_tick_3.wav` | Synthesised variant (tools/gen_placeholder_sfx.py, SoundSet in data/sounds/) | Original (project) | Replace with a CC0 recording |
| `sfx/variants/interact_tick_4.wav` | Synthesised variant (tools/gen_placeholder_sfx.py, SoundSet in data/sounds/) | Original (project) | Replace with a CC0 recording |
| `sfx/variants/interact_tick_5.wav` | Synthesised variant (tools/gen_placeholder_sfx.py, SoundSet in data/sounds/) | Original (project) | Replace with a CC0 recording |
| `sfx/variants/pickup_1.wav` | Synthesised variant (tools/gen_placeholder_sfx.py, SoundSet in data/sounds/) | Original (project) | Replace with a CC0 recording |
| `sfx/variants/pickup_2.wav` | Synthesised variant (tools/gen_placeholder_sfx.py, SoundSet in data/sounds/) | Original (project) | Replace with a CC0 recording |
| `sfx/variants/pickup_3.wav` | Synthesised variant (tools/gen_placeholder_sfx.py, SoundSet in data/sounds/) | Original (project) | Replace with a CC0 recording |
| `sfx/variants/pickup_4.wav` | Synthesised variant (tools/gen_placeholder_sfx.py, SoundSet in data/sounds/) | Original (project) | Replace with a CC0 recording |
| `sfx/variants/pickup_5.wav` | Synthesised variant (tools/gen_placeholder_sfx.py, SoundSet in data/sounds/) | Original (project) | Replace with a CC0 recording |
| `sfx/variants/step_carpet_1.wav` | Synthesised variant (tools/gen_placeholder_sfx.py, SoundSet in data/sounds/) | Original (project) | Replace with a CC0 recording |
| `sfx/variants/step_carpet_2.wav` | Synthesised variant (tools/gen_placeholder_sfx.py, SoundSet in data/sounds/) | Original (project) | Replace with a CC0 recording |
| `sfx/variants/step_carpet_3.wav` | Synthesised variant (tools/gen_placeholder_sfx.py, SoundSet in data/sounds/) | Original (project) | Replace with a CC0 recording |
| `sfx/variants/step_carpet_4.wav` | Synthesised variant (tools/gen_placeholder_sfx.py, SoundSet in data/sounds/) | Original (project) | Replace with a CC0 recording |
| `sfx/variants/step_carpet_5.wav` | Synthesised variant (tools/gen_placeholder_sfx.py, SoundSet in data/sounds/) | Original (project) | Replace with a CC0 recording |
| `sfx/variants/step_concrete_1.wav` | Synthesised variant (tools/gen_placeholder_sfx.py, SoundSet in data/sounds/) | Original (project) | Replace with a CC0 recording |
| `sfx/variants/step_concrete_2.wav` | Synthesised variant (tools/gen_placeholder_sfx.py, SoundSet in data/sounds/) | Original (project) | Replace with a CC0 recording |
| `sfx/variants/step_concrete_3.wav` | Synthesised variant (tools/gen_placeholder_sfx.py, SoundSet in data/sounds/) | Original (project) | Replace with a CC0 recording |
| `sfx/variants/step_concrete_4.wav` | Synthesised variant (tools/gen_placeholder_sfx.py, SoundSet in data/sounds/) | Original (project) | Replace with a CC0 recording |
| `sfx/variants/step_concrete_5.wav` | Synthesised variant (tools/gen_placeholder_sfx.py, SoundSet in data/sounds/) | Original (project) | Replace with a CC0 recording |
| `sfx/variants/step_grass_1.wav` | Synthesised variant (tools/gen_placeholder_sfx.py, SoundSet in data/sounds/) | Original (project) | Replace with a CC0 recording |
| `sfx/variants/step_grass_2.wav` | Synthesised variant (tools/gen_placeholder_sfx.py, SoundSet in data/sounds/) | Original (project) | Replace with a CC0 recording |
| `sfx/variants/step_grass_3.wav` | Synthesised variant (tools/gen_placeholder_sfx.py, SoundSet in data/sounds/) | Original (project) | Replace with a CC0 recording |
| `sfx/variants/step_grass_4.wav` | Synthesised variant (tools/gen_placeholder_sfx.py, SoundSet in data/sounds/) | Original (project) | Replace with a CC0 recording |
| `sfx/variants/step_grass_5.wav` | Synthesised variant (tools/gen_placeholder_sfx.py, SoundSet in data/sounds/) | Original (project) | Replace with a CC0 recording |
| `sfx/variants/step_gravel_1.wav` | Synthesised variant (tools/gen_placeholder_sfx.py, SoundSet in data/sounds/) | Original (project) | Replace with a CC0 recording |
| `sfx/variants/step_gravel_2.wav` | Synthesised variant (tools/gen_placeholder_sfx.py, SoundSet in data/sounds/) | Original (project) | Replace with a CC0 recording |
| `sfx/variants/step_gravel_3.wav` | Synthesised variant (tools/gen_placeholder_sfx.py, SoundSet in data/sounds/) | Original (project) | Replace with a CC0 recording |
| `sfx/variants/step_gravel_4.wav` | Synthesised variant (tools/gen_placeholder_sfx.py, SoundSet in data/sounds/) | Original (project) | Replace with a CC0 recording |
| `sfx/variants/step_gravel_5.wav` | Synthesised variant (tools/gen_placeholder_sfx.py, SoundSet in data/sounds/) | Original (project) | Replace with a CC0 recording |
| `sfx/variants/step_metal_1.wav` | Synthesised variant (tools/gen_placeholder_sfx.py, SoundSet in data/sounds/) | Original (project) | Replace with a CC0 recording |
| `sfx/variants/step_metal_2.wav` | Synthesised variant (tools/gen_placeholder_sfx.py, SoundSet in data/sounds/) | Original (project) | Replace with a CC0 recording |
| `sfx/variants/step_metal_3.wav` | Synthesised variant (tools/gen_placeholder_sfx.py, SoundSet in data/sounds/) | Original (project) | Replace with a CC0 recording |
| `sfx/variants/step_metal_4.wav` | Synthesised variant (tools/gen_placeholder_sfx.py, SoundSet in data/sounds/) | Original (project) | Replace with a CC0 recording |
| `sfx/variants/step_metal_5.wav` | Synthesised variant (tools/gen_placeholder_sfx.py, SoundSet in data/sounds/) | Original (project) | Replace with a CC0 recording |
| `sfx/variants/step_tile_1.wav` | Synthesised variant (tools/gen_placeholder_sfx.py, SoundSet in data/sounds/) | Original (project) | Replace with a CC0 recording |
| `sfx/variants/step_tile_2.wav` | Synthesised variant (tools/gen_placeholder_sfx.py, SoundSet in data/sounds/) | Original (project) | Replace with a CC0 recording |
| `sfx/variants/step_tile_3.wav` | Synthesised variant (tools/gen_placeholder_sfx.py, SoundSet in data/sounds/) | Original (project) | Replace with a CC0 recording |
| `sfx/variants/step_tile_4.wav` | Synthesised variant (tools/gen_placeholder_sfx.py, SoundSet in data/sounds/) | Original (project) | Replace with a CC0 recording |
| `sfx/variants/step_tile_5.wav` | Synthesised variant (tools/gen_placeholder_sfx.py, SoundSet in data/sounds/) | Original (project) | Replace with a CC0 recording |
| `sfx/variants/step_wood_1.wav` | Synthesised variant (tools/gen_placeholder_sfx.py, SoundSet in data/sounds/) | Original (project) | Replace with a CC0 recording |
| `sfx/variants/step_wood_2.wav` | Synthesised variant (tools/gen_placeholder_sfx.py, SoundSet in data/sounds/) | Original (project) | Replace with a CC0 recording |
| `sfx/variants/step_wood_3.wav` | Synthesised variant (tools/gen_placeholder_sfx.py, SoundSet in data/sounds/) | Original (project) | Replace with a CC0 recording |
| `sfx/variants/step_wood_4.wav` | Synthesised variant (tools/gen_placeholder_sfx.py, SoundSet in data/sounds/) | Original (project) | Replace with a CC0 recording |
| `sfx/variants/step_wood_5.wav` | Synthesised variant (tools/gen_placeholder_sfx.py, SoundSet in data/sounds/) | Original (project) | Replace with a CC0 recording |
| `sfx/variants/switch_click_1.wav` | Synthesised variant (tools/gen_placeholder_sfx.py, SoundSet in data/sounds/) | Original (project) | Replace with a CC0 recording |
| `sfx/variants/switch_click_2.wav` | Synthesised variant (tools/gen_placeholder_sfx.py, SoundSet in data/sounds/) | Original (project) | Replace with a CC0 recording |
| `sfx/variants/switch_click_3.wav` | Synthesised variant (tools/gen_placeholder_sfx.py, SoundSet in data/sounds/) | Original (project) | Replace with a CC0 recording |
| `sfx/variants/switch_click_4.wav` | Synthesised variant (tools/gen_placeholder_sfx.py, SoundSet in data/sounds/) | Original (project) | Replace with a CC0 recording |
| `sfx/variants/switch_click_5.wav` | Synthesised variant (tools/gen_placeholder_sfx.py, SoundSet in data/sounds/) | Original (project) | Replace with a CC0 recording |
| `sfx/vcr_click.wav` | Synthesised (tools/gen_placeholder_sfx.py) | Original (project) | Replace with a CC0 recording |
| `sfx/vcr_insert.wav` | Synthesised (tools/gen_placeholder_sfx.py) | Original (project) | Replace with a CC0 recording |
| `tension/drone_high.ogg` | Synthesised bed (tools/gen_placeholder_sfx.py) -> tools/process_audio.py (OGG, loudness-normalised) | Original (project) | Replace with a CC0 recording |
| `tension/drone_low.ogg` | Synthesised bed (tools/gen_placeholder_sfx.py) -> tools/process_audio.py (OGG, loudness-normalised) | Original (project) | Replace with a CC0 recording |
| `tension/rumble.ogg` | Synthesised bed (tools/gen_placeholder_sfx.py) -> tools/process_audio.py (OGG, loudness-normalised) | Original (project) | Replace with a CC0 recording |
