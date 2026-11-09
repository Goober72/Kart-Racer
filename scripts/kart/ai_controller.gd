class_name AIController
extends RefCounted
## Computer driver: follows the track's center line with its own lane offset,
## drifts through sharp corners and uses its ability now and then.

var track: Track
var lane: float = 0.0
var skill: float = 1.0
var _drift_hold: bool = false
var _stuck_time: float = 0.0
var _rng := RandomNumberGenerator.new()


func _init(race_track: Track, ai_skill: float, seed_value: int) -> void:
	track = race_track
	skill = ai_skill
	_rng.seed = seed_value
	lane = _rng.randf_range(-0.25, 0.25) * track.width


func read(kart: Kart) -> Dictionary:
	if track.length <= 0.0:
		return {}
	var offset := track.get_offset(kart.global_position)
	var look := 9.0 + absf(kart.speed) * 0.45
	var target := track.position_at(offset + look, lane)
	var to_target := target - kart.global_position
	to_target.y = 0.0
	var forward := -kart.global_transform.basis.z
	forward.y = 0.0
	var angle := forward.signed_angle_to(to_target, Vector3.UP)

	# Also look further ahead to brake/drift before sharp corners.
	var far := track.position_at(offset + look * 2.2, lane) - kart.global_position
	far.y = 0.0
	var far_angle := absf(forward.signed_angle_to(far, Vector3.UP))

	var steer := clampf(-angle * 2.2, -1.0, 1.0)
	var throttle := 1.0
	if far_angle > 0.9 and kart.speed > kart.max_speed * 0.7:
		throttle = 0.2

	if _drift_hold:
		if absf(angle) < 0.12 or kart.drift_level() >= 2 and absf(angle) < 0.3:
			_drift_hold = false
	elif absf(angle) > 0.3 and kart.speed > 16.0:
		_drift_hold = true

	var use_ability := false
	if kart.ability != null and kart.ability.is_ready() and absf(angle) < 0.15:
		use_ability = _rng.randf() < 0.01

	# Stuck against something? Back up, then respawn.
	if kart.controls_enabled and absf(kart.speed) < 2.0:
		_stuck_time += 1.0 / Engine.physics_ticks_per_second
	else:
		_stuck_time = 0.0
	var respawn := false
	if _stuck_time > 1.2:
		throttle = -1.0
		steer = -steer
	if _stuck_time > 3.0:
		respawn = true
		_stuck_time = 0.0

	return {
		"throttle": throttle,
		"steer": steer,
		"drift": _drift_hold,
		"ability": use_ability,
		"respawn": respawn,
	}
