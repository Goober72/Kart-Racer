extends CanvasLayer
## Dev-build-only tools. In the Play build this node removes itself on startup.
##
##   F1 or `  - console (type "help")
##   F3       - debug overlay (speed, position, track offset...)
##   F5       - track recorder: add a point at your kart / free camera
##   F6       - toggle free camera (WASD/arrows move, Q/E down/up, Shift fast)
##   F9       - reload mods and restart the race
## On touchscreens a "DEV" button gives the same tools without a keyboard.

var race: Node = null

var _console: PanelContainer
var _log: RichTextLabel
var _line: LineEdit
var _overlay: Label
var _touch_panel: Control
var _commands: Dictionary = {}
var _history: Array[String] = []
var _history_pos: int = 0

# Track recorder
var _rec_points: Array[Vector3] = []
var _rec_id: String = "my_track"
var _rec_markers: Node3D

# Free camera
var _freecam: Camera3D
var _freecam_on: bool = false


func _ready() -> void:
	if not BuildInfo.is_dev:
		queue_free()
		return
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	_register_commands()
	ModLoader.reloaded.connect(_report_mods)
	_print("[color=#ffb84d]Kart Racer DEV build v%s[/color] - type [b]help[/b] for commands." % BuildInfo.version)
	_report_mods()


## Called by the race scene when it starts.
func attach_race(race_node: Node) -> void:
	race = race_node
	_freecam = null
	_freecam_on = false
	_rec_markers = null
	_refresh_markers()


func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	var key := (event as InputEventKey).physical_keycode
	match key:
		KEY_F1, KEY_QUOTELEFT:
			_toggle_console()
			get_viewport().set_input_as_handled()
		KEY_F3:
			_overlay.visible = not _overlay.visible
		KEY_F5:
			_run("track_point")
		KEY_F6:
			_run("freecam")
		KEY_F9:
			_run("reload")
		KEY_UP:
			if _console.visible and not _history.is_empty():
				_history_pos = maxi(_history_pos - 1, 0)
				_line.text = _history[_history_pos]
				_line.caret_column = _line.text.length()
				get_viewport().set_input_as_handled()
		KEY_DOWN:
			if _console.visible and not _history.is_empty():
				_history_pos = mini(_history_pos + 1, _history.size())
				_line.text = _history[_history_pos] if _history_pos < _history.size() else ""
				get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if _overlay.visible:
		_update_overlay()
	if _freecam_on and is_instance_valid(_freecam) and not _console.visible:
		_move_freecam(delta)


# ---- UI -------------------------------------------------------------------

func _build_ui() -> void:
	_console = UIKit.panel()
	_console.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_console.custom_minimum_size = Vector2(0, 340)
	_console.visible = false
	add_child(_console)
	var box := VBoxContainer.new()
	_console.add_child(box)
	_log = RichTextLabel.new()
	_log.bbcode_enabled = true
	_log.scroll_following = true
	_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log.selection_enabled = true
	box.add_child(_log)
	_line = LineEdit.new()
	_line.placeholder_text = "type a command (help)"
	_line.text_submitted.connect(_on_submit)
	box.add_child(_line)

	_overlay = UIKit.label("", 15, Color(0.7, 1.0, 0.7))
	_overlay.position = Vector2(10, 360)
	_overlay.visible = false
	add_child(_overlay)

	if TouchControls.wanted():
		_build_touch_toolbar()


## Buttons for phones/tablets, where there are no F-keys.
func _build_touch_toolbar() -> void:
	var toggle := UIKit.button("DEV", func(): _touch_panel.visible = not _touch_panel.visible, 20)
	toggle.set_anchors_preset(Control.PRESET_CENTER_TOP)
	toggle.position = Vector2(-50, 30)
	toggle.custom_minimum_size = Vector2(100, 50)
	toggle.modulate = Color(1, 0.7, 0.7, 0.85)
	add_child(toggle)

	var panel := UIKit.panel()
	panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	panel.position = Vector2(-330, 90)
	panel.visible = false
	add_child(panel)
	_touch_panel = panel
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	panel.add_child(grid)
	var entries := [
		["Console", func(): _toggle_console()],
		["Info", func(): _overlay.visible = not _overlay.visible],
		["Free cam", func(): _run("freecam")],
		["Reload", func(): _run("reload")],
		["Sandbox", func(): _run("sandbox")],
		["New track", func(): _run("track_new my_track")],
		["+ Point", func(): _run("track_point")],
		["Undo point", func(): _run("track_undo")],
		["Preview", func(): _run("track_preview")],
		["Save track", func(): _run("track_save")],
		["Boost", func(): _run("boost")],
		["Menu", func(): _touch_panel.visible = false; _run("menu")],
	]
	for e in entries:
		var b := UIKit.button(e[0], e[1], 18)
		b.custom_minimum_size = Vector2(150, 52)
		b.focus_mode = Control.FOCUS_NONE
		grid.add_child(b)


func _toggle_console() -> void:
	_console.visible = not _console.visible
	if _console.visible:
		_line.grab_focus()
		_line.clear()
	else:
		_line.release_focus()


func _on_submit(text: String) -> void:
	_line.clear()
	text = text.strip_edges()
	if text == "":
		return
	_history.append(text)
	_history_pos = _history.size()
	_print("[color=#888888]> %s[/color]" % text)
	_run(text)


func _print(text: String) -> void:
	_log.append_text(text + "\n")


func _update_overlay() -> void:
	var lines: Array[String] = ["FPS %d" % Engine.get_frames_per_second()]
	if is_instance_valid(race) and race.player != null:
		var k: Kart = race.player
		var p := k.global_position
		lines.append("pos  %.1f, %.1f, %.1f" % [p.x, p.y, p.z])
		lines.append("speed %.1f m/s  (top %.1f)  boost %.2fs" % [k.speed, k.max_speed * k.speed_multiplier, k.boost_time])
		lines.append("drift %s  charge %.2f  level %d" % [k.drifting, k.drift_charge, k.drift_level()])
		if race.track.length > 0.0:
			lines.append("track offset %.1f / %.1f  distance %.1f" % [k.last_offset, race.track.length, k.distance])
		if k.ability != null:
			lines.append("ability %s  cooldown %.1f" % [k.ability.get_display_name(), k.ability.cooldown_left])
	lines.append("recorder '%s': %d points" % [_rec_id, _rec_points.size()])
	if _freecam_on:
		lines.append("FREE CAMERA (F6 to exit)")
	_overlay.text = "\n".join(lines)


# ---- Commands --------------------------------------------------------------

func _register_commands() -> void:
	_add("help", "List commands.", _cmd_help)
	_add("clear", "Clear the console.", func(_a): _log.clear())
	_add("mods", "Show loaded mods and any loading problems.", func(_a): _report_mods(true))
	_add("reload", "Reload all mods (F9). Restarts the current race.", _cmd_reload)
	_add("racers", "List racer ids.", func(_a): _list(ModLoader.racers))
	_add("tracks", "List track ids.", func(_a): _list(ModLoader.tracks))
	_add("race", "race <track_id> [racer_id] [opponents] [laps] - start a race now.", _cmd_race)
	_add("sandbox", "Free roam on an empty field (good for recording tracks).", func(_a): _cmd_race(["sandbox", "", "0"]))
	_add("menu", "Go back to the main menu.", func(_a): GameState.go_to_menu())
	_add("speed", "speed <multiplier> - change your kart's top speed.", _cmd_speed)
	_add("timescale", "timescale <x> - slow motion / fast forward (1 = normal).", _cmd_timescale)
	_add("boost", "boost [seconds] - give yourself a boost.", _cmd_boost)
	_add("charge", "Instantly recharge your ability.", _cmd_charge)
	_add("respawn", "Put your kart back on the track.", func(_a): _with_race(func(): race.respawn_kart(race.player)))
	_add("tp", "tp <offset> - teleport to a distance (meters) along the track.", _cmd_tp)
	_add("finish", "Instantly finish the race (test the results screen).", _cmd_finish)
	_add("pos", "Print your position (copy it into a track's points).", _cmd_pos)
	_add("freecam", "Toggle the free camera (F6).", _cmd_freecam)
	_add("track_new", "track_new <id> - start recording a new track.", _cmd_track_new)
	_add("track_edit", "Copy the current track's points into the recorder.", _cmd_track_edit)
	_add("track_point", "Add a point at your kart / free camera (F5).", _cmd_track_point)
	_add("track_undo", "Remove the last recorded point.", _cmd_track_undo)
	_add("track_preview", "Build the recorded points into a track and drive it.", _cmd_track_preview)
	_add("track_save", "track_save [name] - save recorded track into mods/my_tracks/.", _cmd_track_save)
	_add("quit", "Quit the game.", func(_a): get_tree().quit())


func _add(name: String, help: String, fn: Callable) -> void:
	_commands[name] = {"help": help, "fn": fn}


func _run(line: String) -> void:
	var parts := Array(line.split(" ", false))
	if parts.is_empty():
		return
	var cmd := str(parts.pop_front()).to_lower()
	if not _commands.has(cmd):
		_print("[color=#ff6060]Unknown command '%s'. Type help.[/color]" % cmd)
		return
	_commands[cmd]["fn"].call(parts)


func _cmd_help(_args: Array) -> void:
	var names := _commands.keys()
	names.sort()
	for n in names:
		_print("[b]%s[/b] - %s" % [n, _commands[n]["help"]])
	_print("Keys: F1 console, F3 overlay, F5 add track point, F6 free camera, F9 reload mods.")


func _report_mods(show_all: bool = false) -> void:
	for m in ModLoader.messages:
		if m["level"] == "info" and not show_all:
			continue
		var col: String = {"info": "#aaaaaa", "warn": "#ffcc55", "error": "#ff6060"}[m["level"]]
		_print("[color=%s][mods] %s[/color]" % [col, m["text"]])
	if not show_all:
		_print("[mods] %d racers, %d tracks, %d errors." % [ModLoader.racers.size(), ModLoader.tracks.size(), ModLoader.error_count()])


func _list(dict: Dictionary) -> void:
	var ids := dict.keys()
	ids.sort()
	for id in ids:
		_print("  %s  -  %s  [%s]" % [id, dict[id]["name"], dict[id]["_mod"]])


func _with_race(fn: Callable) -> void:
	if not is_instance_valid(race) or not race.is_inside_tree():
		_print("[color=#ffcc55]Only works during a race.[/color]")
		return
	fn.call()


func _cmd_reload(_args: Array) -> void:
	AbilityFactory.clear_cache()
	ModLoader.reload()
	if is_instance_valid(race) and race.is_inside_tree():
		if not GameState.track_override.is_empty():
			_print("Reloaded mods. (Previewing an unsaved track - not restarting.)")
			return
		race.restart()
	_print("Reloaded mods.")


func _cmd_race(args: Array) -> void:
	if args.size() >= 1:
		if not ModLoader.tracks.has(args[0]):
			_print("[color=#ff6060]No track '%s'. Try: tracks[/color]" % args[0])
			return
		GameState.track_id = args[0]
	if args.size() >= 2 and str(args[1]) != "":
		if not ModLoader.racers.has(args[1]):
			_print("[color=#ff6060]No racer '%s'. Try: racers[/color]" % args[1])
			return
		GameState.racer_id = args[1]
	if args.size() >= 3:
		GameState.ai_count = int(args[2])
	if args.size() >= 4:
		GameState.laps = maxi(int(args[3]), 1)
	GameState.track_override = {}
	GameState.start_race()


func _cmd_speed(args: Array) -> void:
	_with_race(func():
		var m := float(args[0]) if args.size() > 0 else 1.0
		race.player.speed_multiplier = m
		_print("Top speed multiplier = %.2f" % m))


func _cmd_timescale(args: Array) -> void:
	Engine.time_scale = clampf(float(args[0]) if args.size() > 0 else 1.0, 0.05, 4.0)
	_print("Time scale = %.2f" % Engine.time_scale)


func _cmd_boost(args: Array) -> void:
	_with_race(func(): race.player.add_boost(float(args[0]) if args.size() > 0 else 2.0, 1.4))


func _cmd_charge(_args: Array) -> void:
	_with_race(func():
		if race.player.ability != null:
			race.player.ability.cooldown_left = 0.0)


func _cmd_tp(args: Array) -> void:
	_with_race(func():
		if race.track.length <= 0.0:
			return
		var off := float(args[0]) if args.size() > 0 else 0.0
		race.player.respawn(race.track.transform_at(off, 0.0, 1.0))
		race.player.distance = floorf(race.player.distance / race.track.length) * race.track.length + fposmod(off, race.track.length)
		race.player.last_offset = race.track.get_offset(race.player.global_position)
		race.camera.snap())


func _cmd_finish(_args: Array) -> void:
	_with_race(func():
		if race.track.length > 0.0 and race.state == "racing":
			race.player.distance = race.laps * race.track.length + 1.0)


func _cmd_pos(_args: Array) -> void:
	var p := _record_position()
	_print("[%.1f, %.1f, %.1f]" % [p.x, p.y, p.z])


func _cmd_freecam(_args: Array) -> void:
	_with_race(func():
		if _freecam_on:
			_freecam_on = false
			race.camera.current = true
			race.player.controls_enabled = race.state != "countdown"
			_print("Free camera off.")
			return
		if not is_instance_valid(_freecam):
			_freecam = Camera3D.new()
			_freecam.far = 3000.0
			race.add_child(_freecam)
		_freecam.global_transform = race.camera.global_transform
		_freecam.current = true
		_freecam_on = true
		race.player.controls_enabled = false
		_print("Free camera on: WASD/arrows (or GO/BRAKE/steer buttons) move, Q/E or DRIFT/POWER down/up, Shift = fast, F5 or '+ Point' drops a track point, F6 exits."))


func _move_freecam(delta: float) -> void:
	# Uses the normal driving controls so touch buttons and gamepads work too:
	# accelerate/brake = forward/back, steer = turn, ability = up, drift = down.
	var dir := Vector3.ZERO
	dir.z = Input.get_action_strength("brake") - Input.get_action_strength("accelerate")
	var turn := Input.get_action_strength("steer_left") - Input.get_action_strength("steer_right")
	if Input.is_physical_key_pressed(KEY_E) or Input.is_action_pressed("ability"):
		dir.y += 1
	if Input.is_physical_key_pressed(KEY_Q) or (Input.is_action_pressed("drift") and not Input.is_physical_key_pressed(KEY_SHIFT)):
		dir.y -= 1
	var spd := 60.0 if Input.is_physical_key_pressed(KEY_SHIFT) else 20.0
	var real_delta := delta / maxf(Engine.time_scale, 0.01)
	_freecam.rotate_y(turn * 1.6 * real_delta)
	var flat_fwd := -_freecam.global_transform.basis.z
	flat_fwd.y = 0
	flat_fwd = flat_fwd.normalized()
	_freecam.global_position += (flat_fwd * -dir.z + Vector3.UP * dir.y) * spd * real_delta


func _record_position() -> Vector3:
	if _freecam_on and is_instance_valid(_freecam):
		var p := _freecam.global_position
		# Drop the point onto the ground below the camera.
		var space := _freecam.get_world_3d().direct_space_state
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(p, p + Vector3.DOWN * 500.0, 1))
		return hit["position"] if hit.has("position") else Vector3(p.x, 0.0, p.z)
	if is_instance_valid(race) and race.player != null:
		var k: Kart = race.player
		return k.global_position
	return Vector3.ZERO


func _cmd_track_new(args: Array) -> void:
	_rec_id = str(args[0]) if args.size() > 0 else "my_track"
	_rec_points.clear()
	_refresh_markers()
	_print("Recording track '%s'. Drive (or fly with F6) around your route and press F5 at each corner. Go clockwise or counter-clockwise, but keep going one way. Then: track_preview, track_save." % _rec_id)


func _cmd_track_edit(_args: Array) -> void:
	_with_race(func():
		_rec_points.clear()
		for p in race.track.get_points():
			_rec_points.append(Vector3(float(p[0]), float(p[1]), float(p[2])))
		_rec_id = str(race.track.data.get("id", "my_track")) + "_edit"
		_refresh_markers()
		_print("Copied %d points from the current track into the recorder as '%s'." % [_rec_points.size(), _rec_id]))


func _cmd_track_point(_args: Array) -> void:
	var p := _record_position()
	p = Vector3(snappedf(p.x, 0.1), maxf(snappedf(p.y - 0.6, 0.1), 0.0) if not _freecam_on else snappedf(p.y, 0.1), snappedf(p.z, 0.1))
	_rec_points.append(p)
	_refresh_markers()
	_print("Point %d: [%.1f, %.1f, %.1f]" % [_rec_points.size(), p.x, p.y, p.z])


func _cmd_track_undo(_args: Array) -> void:
	if not _rec_points.is_empty():
		_rec_points.pop_back()
	_refresh_markers()
	_print("%d points." % _rec_points.size())


func _recorded_track_data() -> Dictionary:
	var pts: Array = []
	for p in _rec_points:
		pts.append([p.x, p.y, p.z])
	var data := ModLoader.TRACK_DEFAULTS.duplicate(true)
	data["id"] = _rec_id
	data["name"] = _rec_id.capitalize()
	data["points"] = pts
	return data


func _cmd_track_preview(_args: Array) -> void:
	if _rec_points.size() < 4:
		_print("[color=#ffcc55]Need at least 4 points (have %d).[/color]" % _rec_points.size())
		return
	var data := _recorded_track_data()
	data["_dir"] = ""
	data["_mod"] = "recorder"
	GameState.track_override = data
	_with_race(func():
		if _freecam_on:
			_cmd_freecam([])
		race.rebuild_track(data)
		_refresh_markers()
		_print("Previewing '%s' (free roam). Keep adding points or track_save." % _rec_id))


func _cmd_track_save(args: Array) -> void:
	if _rec_points.size() < 4:
		_print("[color=#ffcc55]Need at least 4 points (have %d).[/color]" % _rec_points.size())
		return
	if args.size() > 0:
		_rec_id = str(args[0])
	var mod_dir := ModLoader.get_writable_mod_root().path_join("my_tracks")
	DirAccess.make_dir_recursive_absolute(mod_dir.path_join("tracks"))
	var manifest_path := mod_dir.path_join("mod.json")
	if not FileAccess.file_exists(manifest_path):
		var mf := FileAccess.open(manifest_path, FileAccess.WRITE)
		mf.store_string(JSON.stringify({"id": "my_tracks", "name": "My Tracks", "version": "1.0", "author": "", "description": "Tracks made with the dev track recorder."}, "  "))
		mf.close()
	var data := {
		"id": _rec_id,
		"name": _rec_id.capitalize(),
		"description": "Recorded in the dev build.",
		"width": 14,
		"laps": 3,
		"boost_pads": [],
		"points": _recorded_track_data()["points"],
	}
	var path := mod_dir.path_join("tracks").path_join(_rec_id + ".json")
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		_print("[color=#ff6060]Could not write %s (%s)[/color]" % [path, error_string(FileAccess.get_open_error())])
		return
	f.store_string(JSON.stringify(data, "  "))
	f.close()
	_print("Saved %s. Run [b]reload[/b] to see it in the track list." % path)


func _refresh_markers() -> void:
	if not is_instance_valid(race) or not race.is_inside_tree():
		return
	if not is_instance_valid(_rec_markers):
		_rec_markers = Node3D.new()
		_rec_markers.name = "RecorderMarkers"
		race.add_child(_rec_markers)
	for c in _rec_markers.get_children():
		c.queue_free()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.3, 0.8)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for i in _rec_points.size():
		var m := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.3
		cyl.bottom_radius = 0.3
		cyl.height = 4.0
		m.mesh = cyl
		m.material_override = mat
		m.position = _rec_points[i] + Vector3.UP * 2.0
		_rec_markers.add_child(m)
		var l := Label3D.new()
		l.text = str(i + 1)
		l.font_size = 96
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.no_depth_test = true
		l.position = _rec_points[i] + Vector3.UP * 5.0
		_rec_markers.add_child(l)
