class_name ScriptLoader
extends RefCounted
## Loads a GDScript from a mod folder (outside the game) or from inside the game.


static func load_script(path: String) -> GDScript:
	if path.begins_with("res://"):
		var s := load(path) as GDScript
		if s == null:
			push_warning("Script not found: " + path)
		return s
	if not FileAccess.file_exists(path):
		push_warning("Script not found: " + path)
		return null
	var script := GDScript.new()
	script.source_code = FileAccess.get_file_as_string(path)
	var err := script.reload()
	if err != OK:
		push_warning("Script failed to compile (%s): %s" % [error_string(err), path])
		return null
	return script
