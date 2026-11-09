class_name ItemBox
extends Area3D
## Drive through it to get a random item (if you're not holding one).

const RESPAWN_TIME := 2.5

var _mesh: MeshInstance3D
var _label: Label3D
var _cooldown: float = 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.0, 2.4, 2.0)
	shape.shape = box
	shape.position.y = 1.2
	add_child(shape)
	_mesh = MeshInstance3D.new()
	var m := BoxMesh.new()
	m.size = Vector3.ONE * 1.3
	_mesh.mesh = m
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.4, 0.9, 1.0, 0.75)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(0.2, 0.6, 1.0)
	mat.emission_energy_multiplier = 0.8
	_mesh.material_override = mat
	_mesh.position.y = 1.3
	add_child(_mesh)
	_label = Label3D.new()
	_label.text = "?"
	_label.font_size = 96
	_label.pixel_size = 0.01
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.position.y = 1.3
	_label.outline_size = 16
	add_child(_label)
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	_mesh.rotate_y(delta * 1.5)
	_mesh.rotate_x(delta * 0.7)
	if _cooldown > 0.0:
		_cooldown -= delta
		if _cooldown <= 0.0:
			_mesh.visible = true
			_label.visible = true


func _on_body_entered(body: Node3D) -> void:
	if _cooldown > 0.0 or not body is Kart:
		return
	var k := body as Kart
	_cooldown = RESPAWN_TIME
	_mesh.visible = false
	_label.visible = false
	if k.item.is_empty():
		var total: int = k.get_tree().get_nodes_in_group("karts").size()
		var item := ItemPool.roll(k.place, total)
		if not item.is_empty():
			k.give_item(item)
