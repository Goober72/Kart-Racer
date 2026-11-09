extends Node
## Tells the rest of the game which version is running.
##
## DEV build  - for making and testing mods. Has the dev console, debug overlay,
##              track recorder, free camera, hot reload and detailed mod errors.
## PLAY build - the normal game. Mods still load, but all dev tools are gone.
##
## The Dev export preset adds the custom feature tag "dev". Running from the
## Godot editor also counts as dev. You can force either mode with command line
## user arguments:  godot -- --dev   or   godot -- --play

var is_dev: bool = false
var version: String = "0.0.0"


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	is_dev = OS.has_feature("dev") or OS.has_feature("editor")
	if args.has("--dev"):
		is_dev = true
	if args.has("--play"):
		is_dev = false
	version = str(ProjectSettings.get_setting("application/config/version", "0.0.0"))


func build_name() -> String:
	return "DEV" if is_dev else "PLAY"
