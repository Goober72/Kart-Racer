extends KartAbility
## Example mod ability: a boost that gets longer the further back you are.
## Everything in the racer's "ability" object is available in `params`.


func activate() -> void:
	var base := float(params.get("base_duration", 0.8))
	var per_place := float(params.get("extra_per_place", 0.35))
	var duration := base + per_place * (kart.place - 1)
	kart.add_boost(duration, 1.4)
	kart.flash(Color(1.0, 0.8, 0.3), 6.0)
