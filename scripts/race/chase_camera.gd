class_name ChaseCamera
extends Camera3D
## Follows a kart from behind.

var target: Kart
var distance: float = 6.5
var height: float = 2.6
var base_fov: float = 72.0


func _ready() -> void:
	fov = base_fov
	far = 2000.0


func snap() -> void:
	if target == null:
		return
	global_position = _desired_position()
	look_at(_look_point(), Vector3.UP)


func _physics_process(delta: float) -> void:
	if target == null or not current:
		return
	global_position = global_position.lerp(_desired_position(), 1.0 - exp(-9.0 * delta))
	var look := _look_point()
	if global_position.distance_to(look) > 0.1:
		look_at(look, Vector3.UP)
	var speed_ratio := clampf(target.speed / maxf(target.max_speed, 1.0), 0.0, 1.5)
	var want_fov := base_fov + speed_ratio * 8.0 + (8.0 if target.is_boosting() else 0.0)
	fov = lerpf(fov, want_fov, 1.0 - exp(-4.0 * delta))


func _desired_position() -> Vector3:
	var back := target.global_transform.basis.z
	back.y = 0.0
	back = back.normalized()
	return target.global_position + back * distance + Vector3.UP * height


func _look_point() -> Vector3:
	return target.global_position + Vector3.UP * 1.2 - target.global_transform.basis.z * 4.0
