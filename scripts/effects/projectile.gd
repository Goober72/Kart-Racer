class_name Projectile
extends Node3D
## Something thrown by a "throw" effect. Homing projectiles chase a kart;
## others fly forward along the track.

var owner_kart: Kart
var target: Kart
var track: Track
var hit_data: Dictionary = Effects.DEFAULT_HIT
var speed: float = 50.0
var lifetime: float = 6.0
var _offset: float = 0.0
var _lateral: float = 0.0
var _dir: Vector3 = Vector3.FORWARD
var _age: float = 0.0
var _mesh: MeshInstance3D


func setup(user: Kart, e: Dictionary, homing_target: Kart, race_track: Track, lateral: float) -> void:
	owner_kart = user
	target = homing_target
	track = race_track
	hit_data = e.get("hit", Effects.DEFAULT_HIT)
	speed = float(e.get("speed", 50.0)) + maxf(user.speed, 0.0)
	lifetime = float(e.get("lifetime", 6.0))
	_lateral = lateral
	_dir = -user.global_transform.basis.z
	_offset = user.last_offset + 2.5
	_mesh = MeshInstance3D.new()
	var m := SphereMesh.new()
	var size := float(e.get("size", 0.5))
	m.radius = size
	m.height = size * 2.0
	_mesh.mesh = m
	var mat := StandardMaterial3D.new()
	var col := Effects._color(e, Color(1.0, 0.4, 0.2))
	mat.albedo_color = col
	mat.emission_enabled = true
	mat.emission = col
	mat.emission_energy_multiplier = 2.0
	_mesh.material_override = mat
	add_child(_mesh)


func _ready() -> void:
	global_position = owner_kart.global_position + _dir * 2.5 + Vector3.UP * 0.8


func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= lifetime:
		queue_free()
		return
	if target != null and is_instance_valid(target) and not target.finished:
		var to := target.global_position + Vector3.UP * 0.7 - global_position
		_dir = _dir.lerp(to.normalized(), clampf(delta * 6.0, 0.0, 1.0)).normalized()
		global_position += _dir * speed * delta
	elif track != null and track.length > 0.0:
		_offset += speed * delta
		global_position = global_position.lerp(track.position_at(_offset, _lateral) + Vector3.UP * 0.8, clampf(delta * 12.0, 0.0, 1.0))
	else:
		global_position += _dir * speed * delta
	_mesh.rotate_y(delta * 10.0)

	for node in get_tree().get_nodes_in_group("karts"):
		var k := node as Kart
		if k == owner_kart and _age < 0.5:
			continue
		if k.global_position.distance_to(global_position) < 1.8:
			Effects.hit(k, hit_data, owner_kart)
			queue_free()
			return
