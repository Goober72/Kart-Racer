extends Node
## Remembers the race settings picked in the menu and handles switching scenes.
## Also sets up the default controls (keyboard + gamepad).

const MENU_SCENE := "res://scenes/main_menu.tscn"
const RACE_SCENE := "res://scenes/race.tscn"

var racer_id: String = ""
var track_id: String = ""
var laps: int = 3
var ai_count: int = 5
## When non-empty, the race uses this track data instead of looking up track_id.
## The dev track recorder uses it to preview unsaved tracks.
var track_override: Dictionary = {}


func _init() -> void:
	_setup_controls()


func _ready() -> void:
	ModLoader.reloaded.connect(validate_selection)
	validate_selection()


## Makes sure the selected racer/track still exist (mods may have been removed).
func validate_selection() -> void:
	var racer_ids := ModLoader.get_racer_ids()
	if not ModLoader.racers.has(racer_id) and not racer_ids.is_empty():
		racer_id = racer_ids[0]
	var track_ids := ModLoader.get_track_ids(BuildInfo.is_dev)
	if not ModLoader.tracks.has(track_id) and not track_ids.is_empty():
		track_id = track_ids[0]


func start_race() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	get_tree().change_scene_to_file(RACE_SCENE)


func go_to_menu() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	track_override = {}
	get_tree().change_scene_to_file(MENU_SCENE)


func get_track_data() -> Dictionary:
	if not track_override.is_empty():
		return track_override
	return ModLoader.tracks.get(track_id, {})


func _setup_controls() -> void:
	_add_action("accelerate", [KEY_W, KEY_UP], [JOY_BUTTON_A], [[JOY_AXIS_TRIGGER_RIGHT, 1.0]])
	_add_action("brake", [KEY_S, KEY_DOWN], [], [[JOY_AXIS_TRIGGER_LEFT, 1.0]])
	_add_action("steer_left", [KEY_A, KEY_LEFT], [JOY_BUTTON_DPAD_LEFT], [[JOY_AXIS_LEFT_X, -1.0]])
	_add_action("steer_right", [KEY_D, KEY_RIGHT], [JOY_BUTTON_DPAD_RIGHT], [[JOY_AXIS_LEFT_X, 1.0]])
	_add_action("drift", [KEY_SPACE, KEY_SHIFT], [JOY_BUTTON_RIGHT_SHOULDER, JOY_BUTTON_B], [])
	_add_action("ability", [KEY_E, KEY_F], [JOY_BUTTON_X, JOY_BUTTON_LEFT_SHOULDER], [])
	_add_action("respawn", [KEY_R], [JOY_BUTTON_Y], [])
	_add_action("pause", [KEY_ESCAPE, KEY_P], [JOY_BUTTON_START], [])


func _add_action(action: String, keys: Array, buttons: Array, axes: Array) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action, 0.2)
	for key in keys:
		var ev_key := InputEventKey.new()
		ev_key.physical_keycode = key
		InputMap.action_add_event(action, ev_key)
	for button in buttons:
		var ev_button := InputEventJoypadButton.new()
		ev_button.button_index = button
		InputMap.action_add_event(action, ev_button)
	for axis in axes:
		var ev_axis := InputEventJoypadMotion.new()
		ev_axis.axis = axis[0]
		ev_axis.axis_value = axis[1]
		InputMap.action_add_event(action, ev_axis)
