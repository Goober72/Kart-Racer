class_name BoostPad
extends Area3D
## Drive over it for a speed boost.

@export var duration: float = 1.0
@export var power: float = 1.35


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	monitoring = true
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4.0, 2.0, 5.0)
	shape.shape = box
	shape.position = Vector3(0, 1.0, 0)
	add_child(shape)

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var col := Color(0.2, 0.95, 1.0)
	# Three chevrons pointing forward (-Z).
	for i in 3:
		var z := 1.6 - i * 1.4
		var pts := [Vector3(-1.6, 0.03, z), Vector3(0, 0.03, z - 1.0), Vector3(1.6, 0.03, z),
			Vector3(1.6, 0.03, z + 0.5), Vector3(0, 0.03, z - 0.5), Vector3(-1.6, 0.03, z + 0.5)]
		for tri in [[0, 1, 4], [0, 4, 5], [1, 2, 3], [1, 3, 4]]:
			for idx in tri:
				st.set_color(col)
				st.set_normal(Vector3.UP)
				st.add_vertex(pts[idx])
	var base := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(4.0, 0.02, 5.0)
	base.mesh = bm
	var base_mat := StandardMaterial3D.new()
	base_mat.albedo_color = Color(0.05, 0.2, 0.35)
	base.material_override = base_mat
	add_child(base)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = mat
	add_child(mi)
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if body is Kart:
		(body as Kart).add_boost(duration, power)
