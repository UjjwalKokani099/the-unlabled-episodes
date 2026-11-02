# The Cameraman: threat design

Internal design notes. The game never explains any of this out loud (story bible: "He is
never explained"). This doc keeps the threat consistent across tapes. `docs/story.md` wins
any conflict.

## Who he is (for us, not for the player)

- **Backstory.** No name, no history the player can find. Every tape's subject once bought
  the box; every tape ends with him behind them. The working assumption for writers: he is
  whoever recorded the *first* tape, and every night he records becomes the next tape. The
  rewind ending hints the lens is all that's left of him.
- **Motive.** He doesn't want to hurt anyone. He wants the night *on tape*: the subject,
  framed, unaware, in the last minute before they become footage. Names matter to him (a
  label is a name, and he takes it along with the night), so he learns names early.
- **His rules (never broken).** He never speaks, never runs, never touches anyone. He is
  slow, patient and always framing a shot. His tell is the red REC light. Tracking errors on
  the player's camcorder grow as he gets closer.

## How he stalks: presence before reveal

Escalation in every tape goes from "something's off" to "he is here":

1. **Signs.** Wrong records (the register's stranger entries), calls with nobody there (the
   4B intercom), a moved object (the cabin stool in the doorway after the tape cut),
   footsteps one floor up that walk when you walk and stop when you stop.
2. **Watching.** A figure far away: a terrace, a balcony against a lit window, the end of a
   corridor. Gone once you've really looked, then looked away.
3. **Footage only.** On CCTV, in a feed, in a mirror. Never where the player's own eyes are.
4. **Following.** Behind the player at a distance, only moving while they aren't looking.
5. **The stalk.** He walks towards the player and points his camera. Being held in his shot
   too long is the fail state: the tape loses tracking and rewinds to the last checkpoint.
   The player survives by breaking line of sight and hiding, never by fighting or outrunning.
6. **The last frame.** The tape's ending shot: he is behind the subject, the red dot is the
   last thing on screen. Static.

## AI states (scripts/characters/stalker.gd)

| State | What he does | Exits |
|---|---|---|
| ABSENT | Not in the world. | Level script. |
| WATCHING | Stands at a mark, faces the player; vanishes after being seen. | Seen, then unseen. |
| FOOTAGE_ONLY | Only CCTV cameras can see him (render layer 20). | Level script. |
| FOLLOWING | Keeps 8 to 14 m behind the player; moves only while not looked at. | Level script. |
| PATROL | Walks slow loops between marks, camera up. | Exposure above 0.25: HUNT. |
| HUNT | Walks (never runs) to where he last saw the player. Exposure builds while the player is in his shot. | Exposure 1: CAUGHT. Player unseen 6 s: SEARCH. |
| SEARCH | Checks points near the last sighting, then goes back to PATROL. | Sees player: HUNT. |
| CAUGHT | Tape loses tracking (static, "TRACKING LOST"), reload the checkpoint. | Reload. |
| FINAL | Scripted ending shot (Tape 1: behind Raghu in the meter room). | Tape ends. |

**Exposure ("in his shot")** rises while the player is inside his camera's view (about 45
degrees either side, 16 m), in line of sight, and not hidden. It rises faster the closer
the player is, and falls when out of view. The camcorder shows it as tracking errors (VHS
glitch) and rising hiss. **Hidden** = crouched inside a HidingSpot (behind a parked car, under
the stilt parking, behind the tank pillars).

## Escalation in Tape 1 (The Watchman)

| Time | Beat | State |
|---|---|---|
| 10:40 first round | Figure on D wing's lit 3rd-floor balcony while you patrol | WATCHING |
| 10:40 first round | Mrs. Iyer: "the man on D wing terrace with the red light" | Sign |
| 3:10 after the cut | The cabin stool has moved into the doorway | Sign |
| 3:12 | Deshmukh leaves; on CCTV he's on his balcony; CAM 3 shows the Cameraman on the stairs | FOOTAGE_ONLY |
| ~3:20 | 4B intercom: breathing. In B wing's stairs, footsteps one floor up match yours | Sign |
| ~3:25 | 4B: in the far doorway, gone when you look away | WATCHING (spot 2) |
| ~3:35 | Power cut. Between the cabin and the meter room he walks the courtyard, camera up. Hide behind cars and pillars; get to the meter room unseen | PATROL/HUNT |
| ~3:40 | Main switch. Last CCTV frame: the red dot behind Raghu | FINAL |

## Final confrontation

There is no fight. The confrontation is the stalk across the dark courtyard (he can only
"win" by holding you in frame), then the reveal that he was in the meter room's doorway all
along: the last frame of the tape. Later tapes escalate the stalk (tighter spaces, him in
footage you rely on), and the final tape turns it around: Nikhil films *him*.
