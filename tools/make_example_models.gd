extends Node
## Generates the example .glb models used by mods/example_mod (a robot driver
## with animations, a kart with wheels, and a track with Path/ItemBox markers).
## They also show the structure the game expects from models made in Blender.
##
## Run:  godot --headless --path . res://tools/make_example_models.tscn

const OUT := "res://mods/example_mod/models/"


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_save(_robot(), "robot.glb")
	_save(_kart(), "rocket_kart.glb")
	_save(_track(), "loop_park.glb")
	print("Example models written to ", OUT)
	get_tree().quit()


func _save(root: Node3D, file: String) -> void:
	add_child(root)
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	var err := doc.append_from_scene(root, state)
	if err == OK:
		err = doc.write_to_filesystem(state, ProjectSettings.globalize_path(OUT + file))
	print(file, ": ", error_string(err))
	root.queue_free()


func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	return m


func _box(parent: Node3D, name: String, size: Vector3, pos: Vector3, c: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = name
	var m := BoxMesh.new()
	m.size = size
	m.material = _mat(c)
	mi.mesh = m
	mi.position = pos
	parent.add_child(mi)
	return mi


func _sphere(parent: Node3D, name: String, r: float, pos: Vector3, c: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = name
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2
	m.material = _mat(c)
	mi.mesh = m
	mi.position = pos
	parent.add_child(mi)
	return mi


## A little robot driver. Origin = where it sits. Faces -Z.
func _robot() -> Node3D:
	var root := Node3D.new()
	root.name = "Robot"
	var body := Node3D.new()
	body.name = "Body"
	root.add_child(body)
	_box(body, "Torso", Vector3(0.7, 0.7, 0.5), Vector3(0, 0.45, 0), Color(0.85, 0.85, 0.9))
	var head := Node3D.new()
	head.name = "Head"
	head.position = Vector3(0, 1.05, 0)
	body.add_child(head)
	_box(head, "Skull", Vector3(0.6, 0.45, 0.5), Vector3.ZERO, Color(0.3, 0.75, 0.95))
	_box(head, "Eyes", Vector3(0.45, 0.1, 0.05), Vector3(0, 0.03, -0.26), Color(0.1, 0.1, 0.1))
	_sphere(head, "Antenna", 0.08, Vector3(0, 0.38, 0), Color(1, 0.3, 0.3))
	var arm_l := Node3D.new()
	arm_l.name = "ArmL"
	arm_l.position = Vector3(-0.45, 0.65, 0)
	body.add_child(arm_l)
	_box(arm_l, "ArmLMesh", Vector3(0.15, 0.15, 0.55), Vector3(0, 0, -0.25), Color(0.6, 0.6, 0.65))
	var arm_r := Node3D.new()
	arm_r.name = "ArmR"
	arm_r.position = Vector3(0.45, 0.65, 0)
	body.add_child(arm_r)
	_box(arm_r, "ArmRMesh", Vector3(0.15, 0.15, 0.55), Vector3(0, 0, -0.25), Color(0.6, 0.6, 0.65))

	var ap := AnimationPlayer.new()
	ap.name = "AnimationPlayer"
	root.add_child(ap)
	var lib := AnimationLibrary.new()
	lib.add_animation("Idle", _anim({"Body/Head": [[0.0, Vector3.ZERO], [0.6, Vector3(0, 0, 0.12)], [1.2, Vector3.ZERO]]}, 1.2))
	lib.add_animation("Drive", _anim({"Body": [[0.0, Vector3(-0.08, 0, 0)], [0.25, Vector3(-0.12, 0, 0)], [0.5, Vector3(-0.08, 0, 0)]]}, 0.5))
	lib.add_animation("LeanLeft", _anim({"Body": [[0.0, Vector3(0, 0, 0.25)], [0.5, Vector3(0, 0, 0.25)]]}, 0.5))
	lib.add_animation("LeanRight", _anim({"Body": [[0.0, Vector3(0, 0, -0.25)], [0.5, Vector3(0, 0, -0.25)]]}, 0.5))
	lib.add_animation("Cheer", _anim({"Body/ArmL": [[0.0, Vector3.ZERO], [0.3, Vector3(2.6, 0, 0)], [0.6, Vector3.ZERO]],
		"Body/ArmR": [[0.0, Vector3(2.6, 0, 0)], [0.3, Vector3.ZERO], [0.6, Vector3(2.6, 0, 0)]]}, 0.6))
	lib.add_animation("Hit", _anim({"Body/Head": [[0.0, Vector3.ZERO], [0.2, Vector3(0, 1.5, 0)], [0.4, Vector3(0, 3.0, 0)], [0.6, Vector3(0, 0, 0)]]}, 0.6))
	lib.add_animation("Special", _anim({"Body/ArmR": [[0.0, Vector3.ZERO], [0.2, Vector3(-1.4, 0, 0)], [0.5, Vector3.ZERO]]}, 0.5))
	ap.add_animation_library("", lib)
	return root


## Rotation-only animation: {node_path: [[time, euler], ...]}
func _anim(tracks: Dictionary, length: float) -> Animation:
	var a := Animation.new()
	a.length = length
	for path in tracks.keys():
		var t := a.add_track(Animation.TYPE_ROTATION_3D)
		a.track_set_path(t, NodePath(path))
		for key in tracks[path]:
			a.rotation_track_insert_key(t, key[0], Quaternion.from_euler(key[1]))
	return a


## A rocket-shaped kart. Wheels are named Wheel_FL/FR/RL/RR so the game spins
## them (front ones also steer). The seat is around y = 0.5.
func _kart() -> Node3D:
	var root := Node3D.new()
	root.name = "RocketKart"
	_box(root, "Chassis", Vector3(1.4, 0.35, 2.6), Vector3(0, 0.45, 0), Color(0.95, 0.35, 0.2))
	_box(root, "Nose", Vector3(0.8, 0.3, 0.8), Vector3(0, 0.5, -1.6), Color(0.95, 0.85, 0.2))
	_box(root, "Fin", Vector3(0.1, 0.7, 0.6), Vector3(0, 0.95, 1.1), Color(0.95, 0.85, 0.2))
	_box(root, "Exhaust", Vector3(0.5, 0.5, 0.4), Vector3(0, 0.6, 1.4), Color(0.2, 0.2, 0.25))
	for w in [["Wheel_FL", Vector3(-0.8, 0.35, -1.0)], ["Wheel_FR", Vector3(0.8, 0.35, -1.0)],
			["Wheel_RL", Vector3(-0.8, 0.4, 0.9)], ["Wheel_RR", Vector3(0.8, 0.4, 0.9)]]:
		var wheel := Node3D.new()
		wheel.name = w[0]
		wheel.position = w[1]
		root.add_child(wheel)
		var mi := MeshInstance3D.new()
		mi.name = w[0] + "Mesh"
		var m := CylinderMesh.new()
		m.top_radius = 0.38
		m.bottom_radius = 0.38
		m.height = 0.3
		m.material = _mat(Color(0.12, 0.12, 0.14))
		mi.mesh = m
		mi.rotation.z = PI / 2
		wheel.add_child(mi)
		_box(wheel, w[0] + "Hub", Vector3(0.32, 0.3, 0.1), Vector3.ZERO, Color(0.9, 0.9, 0.9))
	return root


## A stadium-shaped track with its own road, walls and ground, plus markers:
## Path_001.. (racing line, in order), ItemBox_.., BoostPad_.., Start.
func _track() -> Node3D:
	var root := Node3D.new()
	root.name = "LoopPark"
	var pts: Array[Vector3] = []
	for i in 24:
		var a := TAU * i / 24.0
		pts.append(Vector3(cos(a) * 90.0, 0, sin(a) * 50.0))
	var road := SurfaceTool.new()
	road.begin(Mesh.PRIMITIVE_TRIANGLES)
	var walls := SurfaceTool.new()
	walls.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := pts.size()
	for i in n:
		var a := pts[i]
		var b := pts[(i + 1) % n]
		var da := (pts[(i + 1) % n] - pts[(i - 1 + n) % n]).normalized().cross(Vector3.UP)
		var db := (pts[(i + 2) % n] - pts[i]).normalized().cross(Vector3.UP)
		var al := a - da * 8; var ar := a + da * 8
		var bl := b - db * 8; var br := b + db * 8
		for v in [al, bl, br, al, br, ar]:
			road.set_normal(Vector3.UP)
			road.add_vertex(v)
		for edge in [[al, bl], [ar, br]]:
			var p0: Vector3 = edge[0]
			var p1: Vector3 = edge[1]
			for v in [p0, p1, p1 + Vector3.UP * 1.5, p0, p1 + Vector3.UP * 1.5, p0 + Vector3.UP * 1.5]:
				walls.set_normal(Vector3.UP)
				walls.add_vertex(v)
	var road_mi := MeshInstance3D.new()
	road_mi.name = "Road"
	road_mi.mesh = road.commit()
	road_mi.mesh.surface_set_material(0, _mat(Color(0.25, 0.25, 0.3)))
	road_mi.position.y = 0.02
	root.add_child(road_mi)
	var wall_mi := MeshInstance3D.new()
	wall_mi.name = "Walls"
	wall_mi.mesh = walls.commit()
	wall_mi.mesh.surface_set_material(0, _mat(Color(0.95, 0.75, 0.2)))
	root.add_child(wall_mi)
	_box(root, "Grass", Vector3(300, 0.5, 220), Vector3(0, -0.25, 0), Color(0.35, 0.7, 0.4))
	for i in 6:
		_box(root, "Tower%d" % i, Vector3(6, 12 + i * 3, 6), Vector3(-60 + i * 24, 6 + i * 1.5, 0), Color(0.6, 0.5, 0.9))

	# Markers (empty nodes). Start at the right-hand end, racing anti-clockwise.
	for i in n:
		var m := Node3D.new()
		m.name = "Path_%03d" % (i + 1)
		m.position = pts[i]
		root.add_child(m)
	for k in [6, 18]:
		for j in 3:
			var box := Node3D.new()
			box.name = "ItemBox_%d_%d" % [k, j]
			var dir := (pts[(k + 1) % n] - pts[k - 1]).normalized().cross(Vector3.UP)
			box.position = pts[k] + dir * (j - 1) * 4.0
			root.add_child(box)
	var pad := Node3D.new()
	pad.name = "BoostPad_1"
	pad.position = pts[12]
	pad.basis = Basis.looking_at((pts[13] - pts[11]).normalized(), Vector3.UP)
	root.add_child(pad)
	return root
