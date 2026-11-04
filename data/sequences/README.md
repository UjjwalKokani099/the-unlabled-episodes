# Sequences (scripted events and cutscenes)

One JSON file = one sequence: a trigger and a list of steps, run by a `SequencePlayer`
(systems/sequence/sequence_player.gd, which documents every trigger and step). A level lists
its files; Tape 1's director creates its player with `data/sequences/tape01/*.json`.

- Triggers: `event`, `zone`, `interact`, `time`, `objective`.
- `once` (default true) remembers through the EventBus (`seq_<id>`), so checkpoints keep it.
- A running sequence holds saving. `"cutscene": true` takes the player's input, shows the
  hold-to-skip ring (hold E / A 1.5 s); skipping finishes instantly but still applies every effect.
- `look` turns the player's own view (first person, most moments); `camera` blends a cinematic
  camera in and back over 0.5 s; `letterbox` only where it fits.
- Node paths are relative to the level root. `test_sequences.gd` validates every file.
