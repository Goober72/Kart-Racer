class_name ShockwaveAbility
extends KartAbility
## Slows down and bumps every nearby kart.
## Params: radius (meters), slow (0..1, fraction of speed lost), cooldown.


func on_setup() -> void:
	if not params.has("name"):
		params["name"] = "Shockwave"


func activate() -> void:
	var radius := float(params.get("radius", 14.0))
	var slow := clampf(float(params.get("slow", 0.5)), 0.0, 1.0)
	for other in get_other_karts():
		if other.global_position.distance_to(kart.global_position) <= radius:
			if other.shield_time > 0.0:
				continue
			other.speed *= 1.0 - slow
			other.velocity.y = 6.0
			other.spin(0.6)
	kart.flash(Color(0.6, 0.9, 1.0), radius)
