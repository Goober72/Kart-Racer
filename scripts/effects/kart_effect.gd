class_name KartEffect
extends RefCounted
## Base class for custom effects written in GDScript.
##
## Use from any skill or item:
##   {"type": "script", "script": "scripts/my_effect.gd", "anything": 123}
## Your script:
##   extends KartEffect
##   func apply(user: Kart, params: Dictionary) -> void:
##       user.add_boost(1.0, 1.5)
##
## Helpers: Effects.hit(kart, {"spin": 1}), Effects.others(user),
## Effects.race_of(user) (has .track and .karts), and every other effect via
## Effects.apply(user, {"type": "boost"}).


func apply(_user: Kart, _params: Dictionary) -> void:
	pass
