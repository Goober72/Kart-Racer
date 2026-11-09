class_name KartAbility
extends RefCounted
## Base class for racer abilities.
##
## Built-in abilities live next to this file. Mods can add their own by writing
## a .gd file that starts with `extends KartAbility` and pointing a racer's
## ability at it:   "ability": {"type": "script", "script": "scripts/my_ability.gd"}
## Everything else in the "ability" object is available in `params`.
##
## Override any of: on_setup(), activate(), on_tick(delta).

## The Kart this ability belongs to.
var kart: Kart
## The racer's "ability" object from its JSON file.
var params: Dictionary = {}
## Seconds between uses.
var cooldown: float = 8.0
## Seconds left until the ability can be used again.
var cooldown_left: float = 0.0


func setup(owner_kart: Kart, ability_params: Dictionary) -> void:
	kart = owner_kart
	params = ability_params
	cooldown = float(params.get("cooldown", cooldown))
	cooldown_left = cooldown * 0.5
	on_setup()


func is_ready() -> bool:
	return cooldown_left <= 0.0


## 0 = just used, 1 = ready.
func charge_ratio() -> float:
	if cooldown <= 0.0:
		return 1.0
	return clampf(1.0 - cooldown_left / cooldown, 0.0, 1.0)


func try_activate() -> bool:
	if not is_ready():
		return false
	cooldown_left = cooldown
	activate()
	return true


func tick(delta: float) -> void:
	cooldown_left = maxf(cooldown_left - delta, 0.0)
	on_tick(delta)


func get_display_name() -> String:
	return str(params.get("name", "Ability"))


# ---- Override these in your own abilities --------------------------------

## Called once when the kart is created.
func on_setup() -> void:
	pass


## Called when the player (or AI) uses the ability and it is ready.
func activate() -> void:
	pass


## Called every physics frame.
func on_tick(_delta: float) -> void:
	pass


# ---- Helpers for ability scripts ------------------------------------------

## All karts in the race except this one.
func get_other_karts() -> Array[Kart]:
	var out: Array[Kart] = []
	for node in kart.get_tree().get_nodes_in_group("karts"):
		if node != kart and node is Kart:
			out.append(node)
	return out
