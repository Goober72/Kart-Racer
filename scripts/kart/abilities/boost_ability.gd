class_name BoostAbility
extends KartAbility
## A burst of extra speed.
## Params: duration (seconds), power (speed multiplier), cooldown.


func on_setup() -> void:
	if not params.has("name"):
		params["name"] = "Turbo"


func activate() -> void:
	kart.add_boost(float(params.get("duration", 1.6)), float(params.get("power", 1.4)))
