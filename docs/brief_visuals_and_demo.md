# Brief: visual upgrade + first playable (from the owner, Nov 1, 2026)

Read docs/story.md first. Use it for every setting, name, date and detail below.

## Goal
Upgrade the visuals and build the first full playable experience: intro, main menu, the
hub room, and the Tape 1 map. Keep the game at 60 FPS on an RTX 3050 Ti laptop, 16GB RAM.

## 1. Graphics quality
- Grounded realism seen through an old VHS camera: realistic materials and lighting
  underneath, softened by the VHS filter on top.
- Forward+ with: SDFGI or baked lightmaps (pick whichever performs better, explain why),
  volumetric fog, SSAO, glow for light sources, filmic tonemapper.
- LODs, occlusion culling and visibility ranges so the large map stays fast.
- Graphics settings menu with Low / Medium / High presets and an FPS counter toggle.

## 2. Walls, floors and materials
- Free CC0 PBR textures from ambientCG or Poly Haven (albedo, normal, roughness) under
  assets/materials.
- Reusable material library for Indian buildings: weathered painted plaster walls, damp and
  peeling paint, mosaic and Kota stone floors, ceramic tiles, concrete stairs, metal gate
  grills, tube-light-lit corridors, wooden doors.
- Wear and decals: water stains, cracks, wall posters, electric meter boxes, wires.
- Triplanar mapping where it saves UV work.

## 3. Tape 1 map: Shanti Vihar Housing Society
- Gated compound, 4 residential buildings (4 floors each), watchman's cabin with CCTV
  monitor and gate register, central courtyard, parking with scooters and cars, water
  tank, meter room, terrace access.
- Interiors only for flat 4B, corridors, stairs, terrace, meter room; other flats locked.
- Night lighting: sodium street lamps, flickering stairwell tube lights, dark windows with
  a few lit ones.
- Modular kit (wall, floor, stair, window pieces) reused by later tapes.
- Ambient sound: distant dogs, ceiling fans, distant traffic, crickets.

## 4. Hub: Nikhil's room
- Rebuild per the story bible with the new materials: bed, desk with laptop, window to the
  lane, CRT TV and VCR on a steel trunk.
- The between-tape changes from the story bible must be easy to switch on.

## 5. Intro sequence
- VHS tape-loading effect: blue screen, PLAY icon, tracking lines.
- Short first-person scene at a Sunday flea market at dusk: Nikhil walks past stalls, finds
  the cardboard box of unlabeled tapes; a vendor sells it cheap without looking at him.
- Cut to Nikhil arriving home and placing the box beside the VCR; hand control to the
  player in the hub.
- Skippable; autoplays only on first launch.

## 6. Main menu
- VCR on-screen display style: blue background, blocky VHS font, PLAY / REC / STOP motif.
- Background: slow, grainy live shot of the box of tapes in Nikhil's dim room, red REC dot
  blinking somewhere in a dark corner.
- Options: New Game, Continue, Tapes (chapter select; locked tapes are blank cassettes),
  Settings (graphics, audio, controls, subtitles), Quit.
- Sound: VCR button clicks, tape whirring, low room hum.

## How to work
- Show a short plan and build order first.
- One section at a time: build, run, check performance, commit.
- Say exactly what to look at on Play; ask for feedback on the look before moving on.
- Anything that drops below 60 FPS on this hardware: propose a cheaper alternative.
