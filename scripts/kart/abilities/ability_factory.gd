class_name AbilityFactory
extends RefCounted
## Turns a racer's "ability" JSON object into a KartAbility instance.

## Compiled mod scripts, cached by absolute path so they compile once.
static var _script_cache: Dictionary = {}


static func create(kart: Kart, params: Dictionary, mod_dir: String) -> KartAbility:
	var type := str(params.get("type", "boost"))
	var ability: KartAbility = null
	match type:
		"boost":
			ability = BoostAbility.new()
		"hop":
			ability = HopAbility.new()
		"shockwave":
			ability = ShockwaveAbility.new()
		"shield":
			ability = ShieldAbility.new()
		"script":
			ability = _from_script(mod_dir.path_join(str(params.get("script", ""))))
		"none":
			return null
		_:
			push_warning("Unknown ability type '%s', using boost." % type)
			ability = BoostAbility.new()
	if ability == null:
		ability = BoostAbility.new()
	ability.setup(kart, params)
	return ability


static func clear_cache() -> void:
	_script_cache.clear()


static func _from_script(path: String) -> KartAbility:
	var script: GDScript = _script_cache.get(path)
	if script == null and path.begins_with("res://"):
		# Mods bundled inside the game (browser version) are already compiled.
		script = load(path) as GDScript
		if script == null:
			push_warning("Ability script not found: " + path)
			return null
		_script_cache[path] = script
	if script == null:
		if not FileAccess.file_exists(path):
			push_warning("Ability script not found: " + path)
			return null
		script = GDScript.new()
		script.source_code = FileAccess.get_file_as_string(path)
		var err := script.reload()
		if err != OK:
			push_warning("Ability script failed to compile (%s): %s" % [error_string(err), path])
			return null
		_script_cache[path] = script
	var instance = script.new()
	if not instance is KartAbility:
		push_warning("Ability script must start with 'extends KartAbility': " + path)
		return null
	return instance
