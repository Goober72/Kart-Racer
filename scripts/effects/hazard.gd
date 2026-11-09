class_name Hazard
extends Node3D
## A trap left on the track by a "drop" effect.
## Shapes: "puddle" (default), "spikes", "cloud", "vines", "box".

var owner_kart: Kart
var radius: float = 2.2
var lifetime: float = 25.0
var single_use: bool = true
var hit_data: Dictionary = Effects.DEFAULT_HIT
var _age: float = 0.0
var _recent: Dictionary = {}


func setup(user: Kart, e: Dictionary) -> void:
	owner_kart = user
	radius = float(e.get("radius", 2.2))
	lifetime = float(e.get("lifetime", 25.0))
	single_use = e.get("single_use", true)
	hit_data = e.get("hit", Effects.DEFAULT_HIT)
	var shape := str(e.get("shape", "puddle"))
	var col := Effects._color(e, _default_color(shape))
	_build_visual(shape, col)


func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= lifetime:
		queue_free()
		return
	for k in _recent.keys():
		_recent[k] -= delta
		if _recent[k] <= 0.0:
			_recent.erase(k)
	for node in get_tree().get_nodes_in_group("karts"):
		var k := node as Kart
		if k == owner_kart and _age < 1.0:
			continue
		if _recent.has(k):
			continue
		var d := k.global_position - global_position
		if Vector2(d.x, d.z).length() <= radius + 0.6 and absf(d.y) < 2.5:
			Effects.hit(k, hit_data, owner_kart)
			if single_use:
				queue_free()
				return
			_recent[k] = 1.5


func _default_color(shape: String) -> Color:
	match shape:
		"cloud": return Color(0.5, 0.5, 0.55)
		"vines": return Color(0.25, 0.6, 0.2)
		"spikes": return Color(0.7, 0.7, 0.75)
		"box": return Color(0.9, 0.3, 0.3)
	return Color(0.08, 0.08, 0.1)


func _build_visual(shape: String, col: Color) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	match shape:
		"cloud":
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.albedo_color = Color(col, 0.7)
			for i in 4:
				var s := MeshInstance3D.new()
				var m := SphereMesh.new()
				m.radius = radius * 0.6
				m.height = radius * 1.2
				s.mesh = m
				s.material_override = mat
				s.position = Vector3(cos(i * 1.6) * radius * 0.4, 1.0 + (i % 2) * 0.4, sin(i * 1.6) * radius * 0.4)
				add_child(s)
		"spikes":
			for i in 7:
				var c := MeshInstance3D.new()
				var m := CylinderMesh.new()
				m.top_radius = 0.0
				m.bottom_radius = 0.25
				m.height = 0.6
				c.mesh = m
				c.material_override = mat
				var a := i * TAU / 7.0
				c.position = Vector3(cos(a) * radius * 0.5, 0.3, sin(a) * radius * 0.5)
				add_child(c)
		"vines":
			for i in 3:
				var t := MeshInstance3D.new()
				var m := TorusMesh.new()
				m.inner_radius = radius * (0.3 + i * 0.2)
				m.outer_radius = radius * (0.4 + i * 0.2)
				t.mesh = m
				t.material_override = mat
				t.position.y = 0.1
				add_child(t)
		"box":
			var b := MeshInstance3D.new()
			var m := BoxMesh.new()
			m.size = Vector3.ONE * radius * 0.7
			b.mesh = m
			b.material_override = mat
			b.position.y = radius * 0.35
			add_child(b)
		_:
			mat.metallic = 0.6
			mat.roughness = 0.1
			var p := MeshInstance3D.new()
			var m := CylinderMesh.new()
			m.top_radius = radius
			m.bottom_radius = radius
			m.height = 0.04
			p.mesh = m
			p.material_override = mat
			p.position.y = 0.05
			add_child(p)
