class_name AmbienceSet
extends Resource
## The background layers of one place (data/ambience/*.tres): looping beds from
## assets/audio/ambience/ and their levels. An AcousticZone carries one; AudioManager
## crossfades between sets over ~1.5 s, keeping shared layers playing (just re-levelled).

## Looping streams (OGG, loop=true).
@export var layers: Array[AudioStream] = []
## Level of each layer in dB (same order as `layers`; missing = 0 dB).
@export var volumes_db: PackedFloat32Array = PackedFloat32Array()


func volume_of(index: int) -> float:
	return volumes_db[index] if index < volumes_db.size() else 0.0
