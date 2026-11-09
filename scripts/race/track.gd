class_name Track
extends Node3D
## Builds a race track from a list of points (from a track JSON file).
##
## The points are joined into a smooth closed loop. The road, curbs, walls,
## start line, boost pads, ground and trees are all generated from that loop,
## so making a track is just a matter of listing points. Optionally a track can
## add a custom 3D model (.glb/.gltf) for extra scenery or even its own collision.

var data: Dictionary = {}
var curve: Curve3D
var length: float = 0.0
var width: float = 14.0
var min_y: float = 0.0
var free_roam: bool = false

const SAMPLE_STEP := 2.0


func build(track_data: Dictionary) -> void:
	data = track_data
	width = clampf(float(data.get("width", 14.0)), 4.0, 60.0)
	free_roam = data.get("free_roam", false)
	var points: Array[Vector3] = []
	for p in data.get("points", []):
		points.append(Vector3(float(p[0]), float(p[1]), float(p[2])))

	if points.size() >= 4:
		_build_curve(points)
		_build_road()
		_build_start_line()
		_build_boost_pads()
	else:
		curve = null
		length = 0.0
		min_y = 0.0
	_build_ground()
	_build_trees()
	_build_custom_model()


## Offset along the loop (0..length) closest to a world position.
func get_offset(world_pos: Vector3) -> float:
	if curve == null:
		return 0.0
	return curve.get_closest_offset(to_local(world_pos))


## World position at an offset along the loop, shifted sideways by `lateral` meters.
func position_at(offset: float, lateral: float = 0.0) -> Vector3:
	var frame := _frame(offset)
	return to_global(frame[0] + frame[2] * lateral)


## A transform at an offset facing the race direction (for spawning karts).
func transform_at(offset: float, lateral: float = 0.0, lift: float = 0.6) -> Transform3D:
	if curve == null:
		return Transform3D(Basis.IDENTITY, Vector3(lateral, 1.0, 0.0))
	var frame := _frame(offset)
	var fwd: Vector3 = frame[1]
	var flat := Vector3(fwd.x, 0.0, fwd.z).normalized()
	var pos: Vector3 = frame[0] + frame[2] * lateral + Vector3.UP * lift
	return global_transform * Transform3D(Basis.looking_at(flat, Vector3.UP), pos)


## Starting grid slot `index` (0 = pole position).
func grid_transform(index: int) -> Transform3D:
	var row := index / 2
	var side := -1.0 if index % 2 == 0 else 1.0
	var offset := length - 7.0 - row * 6.5 - (side + 1.0) * 1.5
	return transform_at(offset, side * width * 0.22)


func get_points() -> Array:
	return data.get("points", [])


# --------------------------------------------------------------------------

## Returns [position, forward, right, up] at an offset.
func _frame(offset: float) -> Array:
	var o := fposmod(offset, length)
	var pos := curve.sample_baked(o, true)
	var ahead := curve.sample_baked(fposmod(o + 1.0, length), true)
	var behind := curve.sample_baked(fposmod(o - 1.0, length), true)
	var fwd := (ahead - behind).normalized()
	var right := fwd.cross(Vector3.UP).normalized()
	var up := right.cross(fwd).normalized()
	return [pos, fwd, right, up]


func _build_curve(points: Array[Vector3]) -> void:
	curve = Curve3D.new()
	curve.bake_interval = 0.5
	var n := points.size()
	for i in n + 1:
		var p := points[i % n]
		var prev := points[(i - 1 + n) % n]
		var next := points[(i + 1) % n]
		var handle := (next - prev) * 0.2
		curve.add_point(p, -handle, handle)
	length = curve.get_baked_length()
	min_y = INF
	for p in points:
		min_y = minf(min_y, p.y)


func _color(key: String) -> Color:
	var value := str(data.get(key, "#ffffff"))
	return Color.html(value) if Color.html_is_valid(value) else Color.MAGENTA


func _build_road() -> void:
	var count := maxi(int(length / SAMPLE_STEP), 8)
	var half := width * 0.5
	var curb := 0.9
	var wall_h := float(data.get("wall_height", 1.4))
	var ground_y := min_y - 0.15

	var road := SurfaceTool.new()
	road.begin(Mesh.PRIMITIVE_TRIANGLES)
	var curbs := SurfaceTool.new()
	curbs.begin(Mesh.PRIMITIVE_TRIANGLES)
	var walls := SurfaceTool.new()
	walls.begin(Mesh.PRIMITIVE_TRIANGLES)
	var faces := PackedVector3Array()

	var road_col := _color("road_color")
	var curb_a := _color("curb_color_a")
	var curb_b := _color("curb_color_b")
	var wall_col := _color("wall_color")

	var frames: Array = []
	for i in count + 1:
		frames.append(_frame(length * i / count))

	for i in count:
		var a: Array = frames[i]
		var b: Array = frames[i + 1]
		var a_pos: Vector3 = a[0]
		var b_pos: Vector3 = b[0]
		var a_r: Vector3 = a[2]
		var b_r: Vector3 = b[2]
		var a_up: Vector3 = a[3]
		var b_up: Vector3 = b[3]
		var al := a_pos - a_r * half
		var ar := a_pos + a_r * half
		var bl := b_pos - b_r * half
		var br := b_pos + b_r * half

		_quad(road, al, ar, br, bl, a_up, road_col)
		faces.append_array([al, ar, br, al, br, bl])

		# Curbs: alternating stripes just inside both edges.
		var stripe := curb_a if (i / 2) % 2 == 0 else curb_b
		var lift := a_up * 0.02
		_quad(curbs, al + lift, al + a_r * curb + lift, bl + b_r * curb + lift, bl + lift, a_up, stripe)
		_quad(curbs, ar - a_r * curb + lift, ar + lift, br + lift, br - b_r * curb + lift, a_up, stripe)

		# Walls / embankments: from the ground up to wall height on both sides.
		for side in [-1.0, 1.0]:
			var p0: Vector3 = (al if side < 0 else ar)
			var p1: Vector3 = (bl if side < 0 else br)
			var top0 := p0 + Vector3.UP * wall_h
			var top1 := p1 + Vector3.UP * wall_h
			var bot0 := Vector3(p0.x, ground_y, p0.z)
			var bot1 := Vector3(p1.x, ground_y, p1.z)
			var n: Vector3 = a_r * -side
			_quad(walls, bot0, bot1, top1, top0, n, wall_col)
			faces.append_array([bot0, bot1, top1, bot0, top1, top0])
			# Flat cap on top of the wall.
			var out0: Vector3 = top0 + a_r * side * 0.5
			var out1: Vector3 = top1 + b_r * side * 0.5
			_quad(walls, top0, top1, out1, out0, Vector3.UP, wall_col.lightened(0.2))

	_add_mesh(road, true)
	_add_mesh(curbs, true)
	_add_mesh(walls, true)

	var body := StaticBody3D.new()
	body.name = "TrackCollision"
	var shape := CollisionShape3D.new()
	var concave := ConcavePolygonShape3D.new()
	concave.backface_collision = true
	concave.set_faces(faces)
	shape.shape = concave
	body.add_child(shape)
	add_child(body)


func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, normal: Vector3, col: Color) -> void:
	for v in [a, b, c, a, c, d]:
		st.set_normal(normal)
		st.set_color(col)
		st.add_vertex(v)


func _add_mesh(st: SurfaceTool, double_sided: bool) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.85
	if double_sided:
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = mat
	add_child(mi)
	return mi


func _build_start_line() -> void:
	var frame := _frame(0.0)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var squares := 10
	var size := width / squares
	var pos: Vector3 = frame[0]
	var fwd: Vector3 = frame[1]
	var right: Vector3 = frame[2]
	var up: Vector3 = frame[3]
	for row in 2:
		for col in squares:
			var c := Color.WHITE if (row + col) % 2 == 0 else Color(0.08, 0.08, 0.08)
			var o := pos - right * width * 0.5 + right * size * col + fwd * size * (row - 1) + up * 0.04
			_quad(st, o, o + right * size, o + right * size + fwd * size, o + fwd * size, up, c)
	_add_mesh(st, true)

	# A simple gantry over the start line.
	var gantry_col := _color("curb_color_a")
	for side in [-1.0, 1.0]:
		var post := MeshInstance3D.new()
		var pm := BoxMesh.new()
		pm.size = Vector3(0.6, 6.0, 0.6)
		post.mesh = pm
		post.material_override = _plain(gantry_col)
		post.position = pos + right * side * (width * 0.5 + 1.0) + Vector3.UP * 3.0
		add_child(post)
	var beam := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(width + 2.6, 1.0, 0.6)
	beam.mesh = bm
	beam.material_override = _plain(Color(0.1, 0.1, 0.1))
	add_child(beam)
	beam.global_transform = Transform3D(Basis.looking_at(Vector3(fwd.x, 0, fwd.z).normalized(), Vector3.UP), pos + Vector3.UP * 6.0)
	var label := Label3D.new()
	label.text = str(data.get("name", "")).to_upper()
	label.font_size = 64
	label.pixel_size = 0.01
	label.modulate = Color.WHITE
	label.double_sided = true
	beam.add_child(label)
	label.position = Vector3(0, 0, 0.32)
	label.rotation.y = PI


func _build_boost_pads() -> void:
	for entry in data.get("boost_pads", []):
		var at := 0.0
		var lateral := 0.0
		if entry is Array and entry.size() >= 1:
			at = float(entry[0])
			if entry.size() >= 2:
				lateral = float(entry[1])
		else:
			at = float(entry)
		var pad := BoostPad.new()
		add_child(pad)
		pad.global_transform = transform_at(at * length, lateral, 0.05)


func _build_ground() -> void:
	var center := Vector3.ZERO
	var extent := 200.0
	if curve != null:
		var aabb := AABB(curve.get_point_position(0), Vector3.ZERO)
		for i in curve.point_count:
			aabb = aabb.expand(curve.get_point_position(i))
		center = aabb.get_center()
		extent = maxf(aabb.size.x, aabb.size.z) + 300.0
	var ground_y := min_y - 0.15
	var mi := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(extent, extent)
	mi.mesh = plane
	mi.material_override = _plain(_color("ground_color"))
	mi.position = Vector3(center.x, ground_y, center.z)
	add_child(mi)

	var body := StaticBody3D.new()
	body.name = "Ground"
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(extent, 2.0, extent)
	shape.shape = box
	body.add_child(shape)
	body.position = Vector3(center.x, ground_y - 1.0, center.z)
	add_child(body)
	set_meta("ground_extent", extent)
	set_meta("ground_center", center)


func _build_trees() -> void:
	var count := int(data.get("tree_count", 90))
	if GameState.is_low_end():
		count = count / 2
	if count <= 0:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(data.get("id", "")))
	var center: Vector3 = get_meta("ground_center", Vector3.ZERO)
	var extent: float = get_meta("ground_extent", 200.0) * 0.45
	var leaf := _plain(_color("tree_color"))
	var trunk := _plain(Color(0.4, 0.27, 0.15))
	var placed := 0
	var tries := 0
	while placed < count and tries < count * 20:
		tries += 1
		var p := center + Vector3(rng.randf_range(-extent, extent), 0, rng.randf_range(-extent, extent))
		p.y = min_y - 0.15
		if curve != null:
			var near := curve.get_closest_point(p)
			if Vector2(near.x - p.x, near.z - p.z).length() < width * 0.5 + 6.0:
				continue
		elif p.length() < 40.0:
			continue
		var s := rng.randf_range(0.8, 1.8)
		var t := MeshInstance3D.new()
		var tm := CylinderMesh.new()
		tm.top_radius = 0.25 * s
		tm.bottom_radius = 0.35 * s
		tm.height = 2.0 * s
		t.mesh = tm
		t.material_override = trunk
		t.position = p + Vector3.UP * s
		add_child(t)
		var l := MeshInstance3D.new()
		var lm := CylinderMesh.new()
		lm.top_radius = 0.0
		lm.bottom_radius = 1.6 * s
		lm.height = 4.0 * s
		l.mesh = lm
		l.material_override = leaf
		l.position = p + Vector3.UP * (2.0 * s + 1.8 * s)
		add_child(l)
		placed += 1


func _build_custom_model() -> void:
	var model_file := str(data.get("model", ""))
	if model_file == "":
		return
	var path := str(data.get("_dir", "")).path_join(model_file)
	if not FileAccess.file_exists(path):
		push_warning("Track model not found: " + path)
		return
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	if doc.append_from_file(path, state) != OK:
		push_warning("Could not load track model: " + path)
		return
	var scene := doc.generate_scene(state) as Node3D
	if scene == null:
		return
	add_child(scene)
	if data.get("model_collision", false):
		for node in scene.find_children("*", "MeshInstance3D", true, false):
			(node as MeshInstance3D).create_trimesh_collision()


func _plain(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.9
	return m
