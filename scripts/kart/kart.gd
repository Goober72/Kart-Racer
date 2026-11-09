class_name Kart
extends CharacterBody3D
## An arcade kart. Driven by a controller object (PlayerController or AIController)
## that returns the inputs for this frame.
##
## Driving model: the kart has a scalar `speed` along its facing direction.
## Steering rotates the kart. Holding drift while turning starts a drift; the
## longer you drift, the bigger the boost when you let go (blue, orange, purple).

const GRAVITY := 32.0
const DRIFT_LEVEL_TIMES := [0.9, 1.9, 3.0]
const DRIFT_BOOST_TIMES := [0.6, 1.0, 1.5]
const DRIFT_COLORS := [Color(0.35, 0.75, 1.0), Color(1.0, 0.6, 0.15), Color(0.85, 0.35, 1.0)]

var racer: Dictionary = {}
var display_name: String = ""
var is_player: bool = false
## Object with a `read(kart) -> Dictionary` method.
var controller: Object = null
var controls_enabled: bool = false

# Stats (from racer JSON)
var max_speed: float = 30.0
var acceleration: float = 16.0
var handling: float = 2.2
var drift_power: float = 1.0
## Dev / AI tuning: multiplies top speed.
var speed_multiplier: float = 1.0

# Live state
var speed: float = 0.0
var steer_input: float = 0.0
var drifting: bool = false
var drift_dir: float = 0.0
var drift_charge: float = 0.0
var boost_time: float = 0.0
var boost_power: float = 1.0
var shield_time: float = 0.0
var spin_time: float = 0.0
var ability: KartAbility = null
var respawn_requested: bool = false

# Race progress (managed by the race)
var distance: float = 0.0
var last_offset: float = 0.0
var place: int = 1
var finished: bool = false
var finish_time: float = 0.0

var visual: KartVisual


func setup(racer_data: Dictionary, player: bool) -> void:
	racer = racer_data
	is_player = player
	display_name = str(racer.get("name", "Racer"))
	var stats: Dictionary = racer.get("stats", {})
	max_speed = clampf(float(stats.get("max_speed", 30.0)), 5.0, 120.0)
	acceleration = clampf(float(stats.get("acceleration", 16.0)), 2.0, 100.0)
	handling = clampf(float(stats.get("handling", 2.2)), 0.5, 6.0)
	drift_power = clampf(float(stats.get("drift", 1.0)), 0.2, 3.0)

	add_to_group("karts")
	collision_layer = 2
	collision_mask = 1 | 2
	floor_max_angle = deg_to_rad(50.0)
	floor_snap_length = 0.9
	wall_min_slide_angle = deg_to_rad(5.0)

	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.75
	shape.shape = sphere
	shape.position = Vector3(0, 0.75, 0)
	add_child(shape)

	visual = KartVisual.new()
	add_child(visual)
	visual.build(racer)

	ability = AbilityFactory.create(self, racer.get("ability", {}), str(racer.get("_dir", "")))


func add_boost(duration: float, power: float) -> void:
	if boost_time > 0.0:
		boost_power = maxf(boost_power, power)
	else:
		boost_power = power
	boost_time = maxf(boost_time, duration)


func spin(duration: float) -> void:
	if shield_time > 0.0:
		return
	spin_time = maxf(spin_time, duration)
	_cancel_drift()


func flash(color: Color, radius: float) -> void:
	visual.flash(color, radius)


func respawn(at: Transform3D) -> void:
	global_transform = at
	velocity = Vector3.ZERO
	speed = 0.0
	boost_time = 0.0
	spin_time = 0.0
	_cancel_drift()
	visual.reset_pose()


func is_boosting() -> bool:
	return boost_time > 0.0


## 0 = no drift, 1..3 = drift boost level reached so far.
func drift_level() -> int:
	if not drifting:
		return 0
	var level := 0
	for i in DRIFT_LEVEL_TIMES.size():
		if drift_charge >= DRIFT_LEVEL_TIMES[i]:
			level = i + 1
	return level


func _physics_process(delta: float) -> void:
	var input: Dictionary = {}
	if controls_enabled and controller != null:
		input = controller.read(self)
	var throttle := clampf(float(input.get("throttle", 0.0)), -1.0, 1.0)
	var steer := clampf(float(input.get("steer", 0.0)), -1.0, 1.0)
	var drift_held: bool = input.get("drift", false)
	steer_input = steer
	if input.get("respawn", false):
		respawn_requested = true

	if ability != null:
		ability.tick(delta)
		if input.get("ability", false) and spin_time <= 0.0:
			ability.try_activate()

	boost_time = maxf(boost_time - delta, 0.0)
	shield_time = maxf(shield_time - delta, 0.0)
	if spin_time > 0.0:
		spin_time = maxf(spin_time - delta, 0.0)
		throttle = 0.0
		steer = 0.0
		drift_held = false

	var grounded := is_on_floor()
	var top := max_speed * speed_multiplier

	# --- Speed ---
	if boost_time > 0.0:
		speed = move_toward(speed, top * boost_power, acceleration * 3.0 * delta)
	elif throttle > 0.0:
		if speed < top:
			speed = minf(speed + acceleration * throttle * delta, top)
		else:
			speed = move_toward(speed, top, acceleration * 0.8 * delta)
	elif throttle < 0.0:
		if speed > 0.5:
			speed = maxf(speed - acceleration * 2.2 * -throttle * delta, 0.0)
		else:
			speed = maxf(speed - acceleration * 0.6 * -throttle * delta, -top * 0.35)
	else:
		speed = move_toward(speed, 0.0, acceleration * 0.45 * delta)
	if not grounded:
		speed = move_toward(speed, 0.0, 1.0 * delta)

	# --- Drifting ---
	if drifting:
		if not drift_held or speed < 8.0:
			_release_drift()
		elif grounded:
			var tightness := 0.6 + 0.6 * clampf(steer * drift_dir, 0.0, 1.0)
			drift_charge += delta * tightness * drift_power
	elif drift_held and grounded and absf(steer) > 0.3 and speed > 12.0:
		drifting = true
		drift_dir = signf(steer)
		drift_charge = 0.0
		velocity.y = 3.5

	# --- Steering ---
	var turn := 0.0
	if drifting:
		var relative := steer * drift_dir
		turn = drift_dir * handling * remap(relative, -1.0, 1.0, 0.35, 1.3)
	else:
		var low_speed := clampf(absf(speed) / 6.0, 0.0, 1.0)
		var high_speed := 1.0 - 0.3 * clampf(absf(speed) / maxf(top, 1.0), 0.0, 1.0)
		turn = steer * handling * low_speed * high_speed
		if speed < 0.0:
			turn = -turn
	if not grounded:
		turn *= 0.5
	rotate_y(-turn * delta)

	# --- Movement ---
	var forward := -global_transform.basis.z
	var horizontal := forward * speed
	if drifting:
		horizontal += global_transform.basis.x * -drift_dir * absf(speed) * 0.12
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	if grounded and velocity.y <= 0.0:
		velocity.y = -0.5
	else:
		velocity.y -= GRAVITY * delta
	move_and_slide()

	# Hitting walls costs speed (unless shielded).
	if is_on_wall():
		var actual := get_real_velocity().dot(forward)
		if absf(actual) < absf(speed):
			var keep := 0.85 if shield_time > 0.0 else 0.45
			speed = lerpf(actual, speed, keep)

	visual.update_pose(self, delta)


func _release_drift() -> void:
	var level := drift_level()
	if level > 0:
		add_boost(DRIFT_BOOST_TIMES[level - 1], 1.25 + 0.05 * level)
	_cancel_drift()


func _cancel_drift() -> void:
	drifting = false
	drift_dir = 0.0
	drift_charge = 0.0
