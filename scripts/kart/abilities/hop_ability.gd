class_name HopAbility
extends KartAbility
## A big jump with a little forward push. Great for cutting corners.
## Params: height (jump speed), push (extra forward speed), cooldown.


func on_setup() -> void:
	if not params.has("name"):
		params["name"] = "Super Hop"


func activate() -> void:
	kart.velocity.y = float(params.get("height", 12.0))
	kart.speed += float(params.get("push", 6.0))
	kart.add_boost(0.4, 1.15)
