class_name ShieldAbility
extends KartAbility
## Protects from other abilities and wall slowdowns for a while.
## Params: duration (seconds), cooldown.


func on_setup() -> void:
	if not params.has("name"):
		params["name"] = "Shield"


func activate() -> void:
	kart.shield_time = float(params.get("duration", 3.0))
