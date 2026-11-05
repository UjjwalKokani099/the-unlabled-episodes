# Performance

Target (studio spec 12): steady **60 FPS at 1080p High** on the RTX 3050 Ti laptop (16 GB),
**30+ FPS on Low** on integrated GPUs; the iPad web build (Compatibility renderer) playable.

## How to measure

| What | Command | Valid where |
|---|---|---|
| FPS, 1% low, GPU/CPU ms per preset | `<console exe> --path . --script res://tools/benchmark.gd -- <scene> [sec] [ps1]` | laptop only (needs the real GPU) |
| Draw calls, objects, triangles, node/object/resource counts, memory | `<console exe> --path . [--rendering-method gl_compatibility] --script res://tools/profile_level.gd -- <scene> [quality 0-2] [lod px]` | anywhere: scene/renderer numbers, not GPU numbers |
| Leaks across chapter loads | `tests/test_leaks.gd` (room -> Tape 1 -> room x3) | anywhere |
| Floating props | `tools/check_props.gd -- <scene>` | anywhere |
| In game | F1 debug menu > SHOW FPS; Godot editor Debugger > Profiler / Monitors | laptop |

`profile_level.gd` visits every `benchmark_points` marker (else the spawn) and looks four
ways at each; it reports the average and worst view.

## Results (cloud run, 1920x1080, 4 Nov 2026)

Frame times are **not** in this table: the cloud renders on a software GPU (lavapipe). Laptop
FPS column = last benchmark on the laptop; re-run `benchmark.gd` and fill in the dashes.

| Scene | Renderer | Preset | Draw calls avg / max | Objects drawn max | Triangles avg / max | Nodes | Static mem | Video mem | Laptop FPS |
|---|---|---|---|---|---|---|---|---|---|
| Tape 1 (shanti_vihar) | Forward+ | High | 708 / 1324 | 1697 | 258k / 455k | 3041 | 132 MB | 565 MB | ~248 (Medium, before step 7) |
| Tape 1 | Forward+ | Low | 734 / 1333 | 1705 | 241k / 409k | 3041 | 131 MB | 345 MB | - |
| Tape 1 | Compatibility (web) | High | 1013 / 2049 | 1705 | 261k / 460k | 3041 | 111 MB | 183 MB | - |
| Tape 1 | Compatibility (web) | Low | 1056 / 2045 | 1697 | 243k / 411k | 3041 | 111 MB | 175 MB | - |
| Hub (Nikhil's room) | Forward+ | High | 383 / 479 | 679 | 290k / 362k | 710 | 122 MB | 609 MB | - |
| Hub | Forward+ | Low | 383 / 479 | 679 | 180k / 219k | 710 | 112 MB | 425 MB | - |
| Hub | Compatibility (web) | High | 442 / 577 | 679 | 288k / 350k | 710 | 95 MB | 160 MB | - |
| Hub | Compatibility (web) | Low | 443 / 577 | 679 | 188k / 225k | 710 | 95 MB | 152 MB | - |

Leaks across loads (test_leaks): after the first round warms the caches, objects 3515 ->
3515, nodes 712 -> 712, resources 684 -> 684, static memory +0.27 MB per round.

## Changes made in the QA pass (step 9)

- **Mesh LOD threshold** per texture-quality preset raised: High 1 -> 3 px, Medium 2 -> 4,
  Low 4 -> 8 (`GraphicsManager.TEXTURES`). The Poly Haven props are dense (potted plant soil
  54k triangles, bed frame 50k, broom 19k); Godot's import LODs now kick in sooner. Hub at
  High: 490k -> 362k triangles max, side-by-side screenshots identical at 75% render scale.
- **Scene loading without sub-threads** (`SceneLoader`, `load_threaded_request(..., false)`):
  the sub-threaded load left ~230 internal load tokens alive per hub load (reported as leaked
  RefCounted at exit) and once hung a headless load; Tape 1 loads in 0.65-1.3 s either way.
- Shader warm-up behind the loading card (step 5) and pooled sounds (step 3) were already in.

## Next targets

1. **Tape 1 draw calls on the web renderer** (max ~2050 at the courtyard overview point):
   give small props and kit clutter `visibility_end` ranges (propkit `far`), and check what the
   StaticBatcher leaves unmerged. Goal < 1200 for the iPad.
2. **Dense props**: decimate the heaviest Poly Haven models in Blender (asset-optimization
   skill) to a 5-10k triangle budget; the LOD change only helps at a distance.
3. Fill in the laptop FPS column (benchmark.gd per preset) and add PS1-mode numbers.
