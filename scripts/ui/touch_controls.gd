class_name TouchControls
extends CanvasLayer
## On-screen buttons for phones and tablets. Each button presses a normal input
## action, so the kart (and the dev free camera) can't tell it apart from a
## keyboard or gamepad. Supports several fingers at once.

const BUTTONS := [
	# action,        label,   anchor (0..1 of screen), offset from anchor, radius
	["steer_left",  "<",     Vector2(0, 1), Vector2(115, -130), 95.0],
	["steer_right", ">",     Vector2(0, 1), Vector2(330, -130), 95.0],
	["accelerate",  "GO",    Vector2(1, 1), Vector2(-125, -150), 105.0],
	["brake",       "BRAKE", Vector2(1, 1), Vector2(-330, -85), 70.0],
	["drift",       "DRIFT", Vector2(1, 1), Vector2(-305, -270), 75.0],
	["ability",     "SKILL", Vector2(1, 1), Vector2(-120, -365), 68.0],
	["item",        "ITEM",  Vector2(1, 1), Vector2(-300, -440), 62.0],
	["respawn",     "R",     Vector2(0, 0), Vector2(60, 230), 42.0],
	["pause",       "II",    Vector2(1, 0), Vector2(-60, 120), 42.0],
]

var _surface: Control
var _held: Dictionary = {}  # finger index -> action
var _font: Font


## True when the device has a touchscreen (phones, tablets, touch laptops).
static func wanted() -> bool:
	return DisplayServer.is_touchscreen_available() or OS.has_feature("mobile") \
		or OS.has_feature("web_android") or OS.has_feature("web_ios")


func _ready() -> void:
	layer = 15
	_font = ThemeDB.fallback_font
	_surface = Control.new()
	_surface.set_anchors_preset(Control.PRESET_FULL_RECT)
	_surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_surface.draw.connect(_draw_buttons)
	add_child(_surface)


func set_shown(on: bool) -> void:
	visible = on
	if not on:
		_release_all()


func _exit_tree() -> void:
	_release_all()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED:
		_release_all()


func _physics_process(_delta: float) -> void:
	# Browsers can drop held actions (e.g. on a focus change); keep held buttons held.
	for action in _held.values():
		if action != "pause" and not Input.is_action_pressed(action):
			Input.action_press(action)
	if BuildInfo.is_dev and Engine.get_physics_frames() % 60 == 0 and not _held.is_empty():
		var race := get_parent()
		if race != null and race.get("player") != null:
			print("touch held=%s speed=%.1f" % [_held.values(), race.player.speed])


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed:
			var action := _hit(t.position)
			if action != "":
				_press(t.index, action)
		else:
			_release(t.index)
	elif event is InputEventScreenDrag:
		# Sliding a finger between buttons (e.g. left <-> right steering) works.
		var d := event as InputEventScreenDrag
		var action := _hit(d.position)
		var current: String = _held.get(d.index, "")
		if action != current:
			_release(d.index)
			if action != "" and action != "pause":
				_press(d.index, action)


func _press(index: int, action: String) -> void:
	_held[index] = action
	if action == "pause":
		# The pause menu listens for the pause action as an event.
		var ev := InputEventAction.new()
		ev.action = "pause"
		ev.pressed = true
		Input.parse_input_event(ev)
	else:
		Input.action_press(action)
	_surface.queue_redraw()


func _release(index: int) -> void:
	if not _held.has(index):
		return
	var action: String = _held[index]
	_held.erase(index)
	if action != "pause" and not _held.values().has(action):
		Input.action_release(action)
	_surface.queue_redraw()


func _release_all() -> void:
	for action in _held.values():
		if action != "pause":
			Input.action_release(action)
	_held.clear()
	if _surface:
		_surface.queue_redraw()


func _hit(pos: Vector2) -> String:
	var size := _surface.get_viewport_rect().size
	for b in BUTTONS:
		var center: Vector2 = Vector2(b[2]) * size + Vector2(b[3])
		if pos.distance_to(center) <= float(b[4]) * 1.1:
			return b[0]
	return ""


func _draw_buttons() -> void:
	var size := _surface.get_viewport_rect().size
	var pressed := _held.values()
	for b in BUTTONS:
		var center: Vector2 = Vector2(b[2]) * size + Vector2(b[3])
		var r: float = b[4]
		var down: bool = pressed.has(b[0])
		var fill := Color(1, 1, 1, 0.32) if down else Color(0, 0, 0, 0.28)
		if b[0] == "accelerate":
			fill = Color(0.3, 0.9, 0.4, 0.45 if down else 0.25)
		elif b[0] == "drift":
			fill = Color(1.0, 0.7, 0.2, 0.45 if down else 0.22)
		elif b[0] == "ability":
			fill = Color(0.4, 0.7, 1.0, 0.45 if down else 0.22)
		_surface.draw_circle(center, r, fill)
		_surface.draw_arc(center, r, 0, TAU, 48, Color(1, 1, 1, 0.7), 3.0, true)
		var text: String = b[1]
		var font_size := int(clampf(r * 0.42, 18, 44))
		var w := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		_surface.draw_string(_font, center + Vector2(-w * 0.5, font_size * 0.35), text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(1, 1, 1, 0.9))
