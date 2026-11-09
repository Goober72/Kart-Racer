extends KartEffect
## Example custom effect: jump forward along the track.
## Used by items/warp_crumb.json:  {"type": "script", "script": "scripts/warp_effect.gd", "distance": 35}


func apply(user: Kart, params: Dictionary) -> void:
	var race := Effects.race_of(user)
	var track: Track = race.get("track")
	if track == null or track.length <= 0.0:
		return
	var distance := float(params.get("distance", 35.0))
	var keep_speed := user.speed
	user.respawn(track.transform_at(user.last_offset + distance, 0.0, 1.0))
	user.speed = keep_speed
	user.distance += distance
	user.last_offset = track.get_offset(user.global_position)
	user.flash(Color(0.76, 0.48, 1.0), 4.0)
