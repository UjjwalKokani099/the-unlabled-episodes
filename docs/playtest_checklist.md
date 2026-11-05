# Playtest checklist

Run this on the laptop (Forward+, 1080p, mouse + keyboard, then a pad) before a chapter is
called done, and once on the iPad web build (touch). Tick each box; anything that fails
goes into `docs/bugs.md` with a severity. Automated coverage is noted in brackets: those
checks run in the cloud, but they don't replace playing it.

Debug menu (debug builds): **F1**. Jump to chapters/checkpoints, noclip, FPS, show triggers,
give items, toggle AI. Text overlay (test rooms): F3.

## Every chapter (studio spec 13)

- [ ] **No softlocks.** Every objective can be finished from every checkpoint; reload each
      checkpoint (pause > Restart from checkpoint) and finish the next objective.
- [ ] **No getting stuck in geometry.** Crouch-walk along every wall, corner, stair, railing and
      parked vehicle; jump-free game, so nothing should need a jump to get out.
- [ ] **Triggers can't be skipped.** With F1 > Show triggers on, walk around each trigger zone's
      edges: every story zone spans its whole path (doorway/stair to wall).
- [ ] **Every interaction works** and makes a sound; prompts match what happens.
- [ ] **Subtitles match the audio** (when voice files exist) and stay on screen long enough.
- [ ] **All paths lead somewhere**: no corridor/door that is open but empty without a reason.
- [ ] Doors you close stay closed; moved things stay moved (reload a checkpoint to check).
- [ ] No floating props, z-fighting decals, light leaking through walls (`tools/check_props.gd`
      catches floating props [test_polish]).
- [ ] Cursor hidden in play, visible in menus, pause and dialogue choices.
- [ ] Stand still 20 s in a few places: an idle sound plays, never the same twice in a row.
- [ ] 60 FPS on High at 1080p (F1 > FPS); note the worst spot in docs/performance.md.
- [ ] Quit from the pause menu mid-chapter: no errors in the console.

## Tape 1: The Watchman (Shanti Vihar, 14 March 1998)

[test_tape01 plays the whole night with teleports; test_demo the loop from the menu;
test_sequences the intercom/3:12/ending data; test_polish the CCTV glow, clocks, props]

First round (mundane, about a third of the tape)
- [ ] Sign in at the gate register: the register shows the date and Raghu's name.
- [ ] Check the CCTV monitor: feeds cycle, readable at night, the screen lights the cabin.
- [ ] Mrs. Iyer walks over for her parcel; give it to her; she mentions the terrace light.
- [ ] Patrol the four wings (4 points): each point fires once, wherever you enter the wing.
- [ ] Padlock the 4 terrace doors; stairs climb cleanly, no snagging on landings.
- [ ] Spot the figure on D balcony (Q = camcorder PAUSE) during the first round.
- [ ] Back at the cabin: the tape cut to 03:10, the stool has moved.

3 AM
- [ ] Write the 3 AM round; Deshmukh calls out near B wing; 3:12 he walks out: the view turns
      to him by itself (no snap), then control returns.
- [ ] Promise / refuse him the gate: the secretary's call changes accordingly.
- [ ] Log his exit; check CCTV: he is on his balcony on the feed, not in the courtyard.
- [ ] Answer the intercom: breathing, the line dies, CAM 4B switches on.
- [ ] Take the spare key; footsteps answer yours one floor up on the B stairs.
- [ ] Flat 4B: stopped clock (3:12), fan, breathing; nothing in the flat blocks the exit.
- [ ] Register: the stranger's entries with your own times.
- [ ] Secretary call: timed choice (red bar) only at the reveal; power cut after.

The dark / the stalk
- [ ] Checkpoint right after the power cut (the cabin); torch on F; message says where to go.
- [ ] The Cameraman patrols the courtyard: the camcorder glitches/hisses as he sees you;
      hiding spots (parked cars) hide you when crouched; he never runs; caught = TRACKING LOST
      and back at the cabin with the power still out.
- [ ] Meter room: the stalk ends; reset the main switch.
- [ ] Ending: lights back, last CCTV frame (Raghu + red dot behind), static, last line;
      hold E skips it (ring above the date, not on a single press).
- [ ] END OF TAPE card after a dark fade and the tape running out: runtime, sightings n/3,
      any key -> Nikhil's room, stage 1 (new thought, the diary).

## Hub: Nikhil's room

- [ ] The box hands out the next tape; the VCR plays it; an unbuilt tape shows the demo card.
- [ ] Phone (R): take it from the desk, reply to Maa, charge it; battery drains after a tape.
- [ ] Clock over the window shows real time; TV static lights the room.
- [ ] Stage changes after each tape (F6 cycles stages in debug builds).

## Menus

- [ ] Boot: black, studio card + sting, content warning, any key -> menu.
- [ ] Menu on the CRT: mouse clicks land where the curved screen shows them.
- [ ] Settings: every row changes something visible/audible; rebinding swaps on conflict;
      Reset restores; settings survive a restart.
- [ ] TAPES: watched tapes show their last checkpoint still, runtime, SPOTTED n/3.
- [ ] Credits roll, Quit quits with no console errors.
