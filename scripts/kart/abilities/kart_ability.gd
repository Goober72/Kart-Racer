class_name KartAbility
extends RefCounted
## A racer's skill. Tap the skill button for the quick version, or hold it for
## CHARGE_TIME seconds for the charged version.
##
## Most skills are written as JSON with a list of effects for each version:
##   "ability": {
##     "name": "Root Quake",
##     "cooldown": 8, "charged_cooldown": 12,
##     "tap":     {"name": "Tremor",     "effects": [ {"type": "shockwave", "radius": 10} ]},
##     "charged": {"name": "Root Quake", "effects": [ {"type": "shockwave", "radius": 18},
##                                                    {"type": "drop", "shape": "vines"} ]}
##   }
## See Effects for every effect type. For full control a mod can use
##   "ability": {"type": "script", "script": "scripts/my_skill.gd"}
## where the script extends KartAbility and overrides activate(charged).

const CHARGE_TIME := 1.0

## The Kart this ability belongs to.
var kart: Kart
## The racer's "ability" object from its JSON file.
var params: Dictionary = {}
## Folder of the mod the racer came from (for script effects).
var mod_dir: String = ""
## Seconds before the skill can be used again after a tap / a charged use.
var cooldown: float = 8.0
var charged_cooldown: float = 12.0
## Seconds left until the skill can be used again.
var cooldown_left: float = 0.0
var _last_cooldown: float = 8.0


func setup(owner_kart: Kart, ability_params: Dictionary, dir: String) -> void:
	kart = owner_kart
	params = ability_params
	mod_dir = dir
	cooldown = float(params.get("cooldown", cooldown))
	charged_cooldown = float(params.get("charged_cooldown", cooldown * 1.5))
	_last_cooldown = cooldown
	cooldown_left = cooldown * 0.5
	on_setup()


func is_ready() -> bool:
	return cooldown_left <= 0.0


## 0 = just used, 1 = ready.
func charge_ratio() -> float:
	if _last_cooldown <= 0.0:
		return 1.0
	return clampf(1.0 - cooldown_left / _last_cooldown, 0.0, 1.0)


func try_activate(charged: bool) -> bool:
	if not is_ready():
		return false
	_last_cooldown = charged_cooldown if charged else cooldown
	cooldown_left = _last_cooldown
	activate(charged)
	kart.skill_used.emit(charged)
	return true


func tick(delta: float) -> void:
	cooldown_left = maxf(cooldown_left - delta, 0.0)
	on_tick(delta)


func get_display_name(charged: bool = false) -> String:
	var part: Dictionary = params.get("charged" if charged else "tap", {})
	if part.has("name"):
		return str(part["name"])
	return str(params.get("name", "Skill")) + (" (charged)" if charged else "")


# ---- Override these in script skills -------------------------------------

## Called once when the kart is created.
func on_setup() -> void:
	pass


## Called when the skill is used. `charged` is true if the button was held.
func activate(charged: bool) -> void:
	var part: Dictionary = params.get("charged" if charged else "tap", {})
	Effects.run(kart, part.get("effects", []), mod_dir)


## Called every physics frame.
func on_tick(_delta: float) -> void:
	pass


# ---- Helpers for skill scripts --------------------------------------------

## All karts in the race except this one.
func get_other_karts() -> Array[Kart]:
	return Effects.others(kart)
