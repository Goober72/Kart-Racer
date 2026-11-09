class_name KartVisual
extends Node3D
## Builds what a kart looks like. Uses simple shapes by default; a racer can
## point "model" at a .glb/.gltf file in its mod folder to use a custom model.

var _pivot: Node3D
var _body_root: Node3D
var _wheels: Array[Node3D] = []
var _front_wheels: Array[Node3D] = []
var _sparks: Array[MeshInstance3D] = []
var _flame: MeshInstance3D
var _shield: MeshInstance3D
var _flash_ring: MeshInstance3D
var _flash_time: float = 0.0
var _wheel_spin: float = 0.0
var _spin_angle: float = 0.0


func build(racer: Dictionary) -> void:
	_pivot = Node3D.new()
	add_child(_pivot)
	_body_root = Node3D.new()
	_pivot.add_child(_body_root)

	var custom := _load_custom_model(racer)
	if custom != null:
		_body_root.add_child(custom)
	else:
		_build_default(racer)
	_build_effects()


## Builds a standalone preview (used by the menu turntable).
static func make_preview(racer: Dictionary) -> KartVisual:
	var v := KartVisual.new()
	v.build(racer)
	return v


func reset_pose() -> void:
	if _pivot:
		_pivot.transform = Transform3D.IDENTITY
	_spin_angle = 0.0


func flash(color: Color, radius: float) -> void:
	var mat := _flash_ring.material_override as StandardMaterial3D
	mat.albedo_color = Color(color, 0.6)
	_flash_ring.scale = Vector3.ONE * 0.1
	_flash_ring.set_meta("radius", radius)
	_flash_ring.visible = true
	_flash_time = 0.4


func update_pose(kart: Kart, delta: float) -> void:
	# Lean into turns and tilt with the ground.
	var target_basis := Basis.IDENTITY
	if kart.is_on_floor():
		var n := kart.get_floor_normal()
		var local_n := kart.global_transform.basis.inverse() * n
		target_basis = _align_up(local_n)
	var drift_yaw := -kart.drift_dir * 0.35 if kart.drifting else 0.0
	var lean := -kart.steer_input * 0.06 * clampf(kart.speed / 20.0, 0.0, 1.0)
	if kart.spin_time > 0.0:
		_spin_angle += delta * 14.0
	else:
		_spin_angle = lerp_angle(_spin_angle, 0.0, 1.0 - exp(-10.0 * delta))
	target_basis = target_basis * Basis(Vector3.UP, drift_yaw + _spin_angle) * Basis(Vector3.FORWARD, lean)
	_pivot.basis = _pivot.basis.slerp(target_basis.orthonormalized(), 1.0 - exp(-12.0 * delta)).orthonormalized()

	_wheel_spin += kart.speed * delta / 0.35
	for w in _wheels:
		w.rotation.x = -_wheel_spin
	for w in _front_wheels:
		w.rotation.y = -kart.steer_input * 0.4

	var level := kart.drift_level()
	for s in _sparks:
		s.visible = kart.drifting and level > 0
		if s.visible:
			var mat := s.material_override as StandardMaterial3D
			var c: Color = Kart.DRIFT_COLORS[level - 1]
			mat.albedo_color = c
			mat.emission = c
			s.scale = Vector3.ONE * randf_range(0.7, 1.3)

	_flame.visible = kart.is_boosting()
	if _flame.visible:
		_flame.scale = Vector3(1, 1, randf_range(0.8, 1.4))
	_shield.visible = kart.shield_time > 0.0

	if _flash_time > 0.0:
		_flash_time -= delta
		var t := 1.0 - _flash_time / 0.4
		var r: float = _flash_ring.get_meta("radius", 10.0)
		_flash_ring.scale = Vector3(r, 1, r) * t
		_flash_ring.visible = _flash_time > 0.0


func _process(delta: float) -> void:
	# Only used by the menu preview (no Kart parent).
	if not get_parent() is Kart:
		rotate_y(delta * 0.6)


func _align_up(up: Vector3) -> Basis:
	up = up.normalized()
	var fwd := Vector3.FORWARD
	var right := fwd.cross(up).normalized()
	if right.length() < 0.01:
		return Basis.IDENTITY
	fwd = up.cross(right).normalized()
	return Basis(right, up, -fwd)


func _load_custom_model(racer: Dictionary) -> Node3D:
	var model_file := str(racer.get("model", ""))
	if model_file == "":
		return null
	var path := str(racer.get("_dir", "")).path_join(model_file)
	if not FileAccess.file_exists(path):
		push_warning("Racer model not found: " + path)
		return null
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	var err := doc.append_from_file(path, state)
	if err != OK:
		push_warning("Could not load racer model (%s): %s" % [error_string(err), path])
		return null
	var scene := doc.generate_scene(state) as Node3D
	if scene == null:
		return null
	var s := float(racer.get("model_scale", 1.0))
	scene.scale = Vector3.ONE * s
	scene.rotation.y = deg_to_rad(float(racer.get("model_rotation_y", 0.0)))
	return scene


func _build_default(racer: Dictionary) -> void:
	var body_col := Color.html(str(racer.get("body_color", "#d83a3a")))
	var accent := Color.html(str(racer.get("accent_color", "#ffffff")))
	var skin := Color.html(str(racer.get("driver_color", "#f2c38f")))
	var helmet := Color.html(str(racer.get("helmet_color", "#3a6fd8")))
	var dark := Color(0.12, 0.12, 0.14)

	# Chassis
	_box(Vector3(1.5, 0.35, 2.4), Vector3(0, 0.5, 0), body_col)
	_box(Vector3(1.1, 0.3, 0.8), Vector3(0, 0.55, -1.35), body_col)  # nose
	_box(Vector3(1.6, 0.12, 0.35), Vector3(0, 0.45, -1.75), accent)  # front bumper
	_box(Vector3(1.7, 0.1, 0.45), Vector3(0, 1.05, 1.25), accent)  # spoiler
	_box(Vector3(0.12, 0.4, 0.12), Vector3(-0.6, 0.85, 1.25), dark)
	_box(Vector3(0.12, 0.4, 0.12), Vector3(0.6, 0.85, 1.25), dark)
	_box(Vector3(0.5, 0.3, 0.3), Vector3(0, 0.8, 1.0), dark)  # engine
	_box(Vector3(1.52, 0.08, 1.2), Vector3(0, 0.7, 0.1), accent)  # stripe
	# Steering wheel
	var sw := _cyl(0.18, 0.05, Vector3(0, 0.95, -0.55), dark)
	sw.rotation.x = deg_to_rad(60)

	# Driver
	_capsule(0.32, 0.9, Vector3(0, 1.05, 0.0), accent)
	_sphere(0.34, Vector3(0, 1.75, -0.05), skin)
	var hel := _sphere(0.38, Vector3(0, 1.85, 0.0), helmet)
	hel.scale = Vector3(1, 0.8, 1)
	_box(Vector3(0.5, 0.12, 0.08), Vector3(0, 1.78, -0.36), dark)  # visor

	# Wheels
	for pos in [Vector3(-0.85, 0.38, -1.0), Vector3(0.85, 0.38, -1.0), Vector3(-0.85, 0.42, 0.9), Vector3(0.85, 0.42, 0.9)]:
		var hub := Node3D.new()
		hub.position = pos
		_body_root.add_child(hub)
		var spin := Node3D.new()
		hub.add_child(spin)
		var radius := 0.38 if pos.z < 0 else 0.42
		var wheel := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = radius
		cyl.bottom_radius = radius
		cyl.height = 0.35
		wheel.mesh = cyl
		wheel.rotation.z = PI / 2
		wheel.material_override = _mat(dark)
		spin.add_child(wheel)
		var cap := MeshInstance3D.new()
		var cap_mesh := CylinderMesh.new()
		cap_mesh.top_radius = radius * 0.5
		cap_mesh.bottom_radius = radius * 0.5
		cap_mesh.height = 0.37
		cap.mesh = cap_mesh
		cap.rotation.z = PI / 2
		cap.material_override = _mat(accent)
		spin.add_child(cap)
		_wheels.append(spin)
		if pos.z < 0:
			_front_wheels.append(hub)


func _build_effects() -> void:
	for x in [-0.85, 0.85]:
		var s := MeshInstance3D.new()
		var m := SphereMesh.new()
		m.radius = 0.22
		m.height = 0.44
		s.mesh = m
		var mat := StandardMaterial3D.new()
		mat.emission_enabled = true
		mat.emission_energy_multiplier = 3.0
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		s.material_override = mat
		s.position = Vector3(x, 0.25, 1.2)
		s.visible = false
		_pivot.add_child(s)
		_sparks.append(s)

	_flame = MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.28
	cone.height = 1.2
	_flame.mesh = cone
	_flame.rotation.x = deg_to_rad(90)
	_flame.position = Vector3(0, 0.75, 1.8)
	var fm := StandardMaterial3D.new()
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.albedo_color = Color(1.0, 0.55, 0.1)
	_flame.material_override = fm
	_flame.visible = false
	var flame_parent := Node3D.new()
	_pivot.add_child(flame_parent)
	flame_parent.add_child(_flame)

	_shield = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 1.7
	sm.height = 3.0
	_shield.mesh = sm
	_shield.position = Vector3(0, 0.9, 0)
	var shm := StandardMaterial3D.new()
	shm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shm.albedo_color = Color(0.4, 0.8, 1.0, 0.25)
	shm.cull_mode = BaseMaterial3D.CULL_DISABLED
	_shield.material_override = shm
	_shield.visible = false
	_pivot.add_child(_shield)

	_flash_ring = MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.9
	tm.outer_radius = 1.0
	_flash_ring.mesh = tm
	_flash_ring.position = Vector3(0, 0.5, 0)
	var frm := StandardMaterial3D.new()
	frm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	frm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_flash_ring.material_override = frm
	_flash_ring.visible = false
	add_child(_flash_ring)


func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.6
	return m


func _box(size: Vector3, pos: Vector3, c: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := BoxMesh.new()
	m.size = size
	mi.mesh = m
	mi.position = pos
	mi.material_override = _mat(c)
	_body_root.add_child(mi)
	return mi


func _sphere(r: float, pos: Vector3, c: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	mi.mesh = m
	mi.position = pos
	mi.material_override = _mat(c)
	_body_root.add_child(mi)
	return mi


func _capsule(r: float, h: float, pos: Vector3, c: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := CapsuleMesh.new()
	m.radius = r
	m.height = h
	mi.mesh = m
	mi.position = pos
	mi.material_override = _mat(c)
	_body_root.add_child(mi)
	return mi


func _cyl(r: float, h: float, pos: Vector3, c: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := CylinderMesh.new()
	m.top_radius = r
	m.bottom_radius = r
	m.height = h
	mi.mesh = m
	mi.position = pos
	mi.material_override = _mat(c)
	_body_root.add_child(mi)
	return mi
