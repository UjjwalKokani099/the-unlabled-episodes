class_name SoundSet
extends Resource
## A family of interchangeable clips (footsteps on one surface, a door creak...). pick()
## never returns the same clip twice in a row; play through AudioManager.play_set*() which
## also jitters pitch by `pitch_jitter` (default +-5%). Files: data/sounds/*.tres, made by
## tools/gen_placeholder_sfx.py (replace the wavs in assets/audio/sfx/variants/ in place).

@export var streams: Array[AudioStream] = []
@export var volume_db: float = 0.0
## Random pitch range around 1.0 (0.05 = +-5%).
@export_range(0.0, 0.3, 0.01) var pitch_jitter: float = 0.05

var _last: int = -1


## A random clip, never the one returned last time (when there is more than one).
func pick() -> AudioStream:
	if streams.is_empty():
		return null
	if streams.size() == 1:
		return streams[0]
	var i := randi() % streams.size()
	if i == _last:
		i = (i + 1 + randi() % (streams.size() - 1)) % streams.size()
	_last = i
	return streams[i]


func random_pitch() -> float:
	return randf_range(1.0 - pitch_jitter, 1.0 + pitch_jitter)
