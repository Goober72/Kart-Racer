extends Control
## Title screen: pick racer, track, laps and opponents, then race.

var _racer_ids: Array = []
var _track_ids: Array = []
var _racer_index: int = 0
var _track_index: int = 0

var _racer_value: Label
var _racer_info: Label
var _track_value: Label
var _track_info: Label
var _laps_value: Label
var _ai_value: Label
var _preview_holder: Node3D
var _mods_panel: PanelContainer
var _mods_text: RichTextLabel
var _main_box: Control


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.09, 0.12, 0.2)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	add_child(margin)

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 40)
	margin.add_child(columns)

	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 6)
	left.custom_minimum_size = Vector2(520, 0)
	columns.add_child(left)
	_main_box = left

	left.add_child(UIKit.label("KART RACER", 52, UIKit.ACCENT))
	var sub := "v%s  -  %s BUILD" % [BuildInfo.version, BuildInfo.build_name()]
	left.add_child(UIKit.label(sub, 18, Color(1, 0.5, 0.5) if BuildInfo.is_dev else Color(0.7, 0.8, 1)))

	_racer_value = _add_selector(left, "Racer", func(d): _cycle_racer(d))
	_racer_info = UIKit.label("", 16, Color(0.8, 0.85, 0.95))
	_racer_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left.add_child(_racer_info)
	_track_value = _add_selector(left, "Track", func(d): _cycle_track(d))
	_track_info = UIKit.label("", 16, Color(0.8, 0.85, 0.95))
	_track_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left.add_child(_track_info)
	_laps_value = _add_selector(left, "Laps", func(d): _change_laps(d))
	_ai_value = _add_selector(left, "Opponents", func(d): _change_ai(d))

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 4)
	left.add_child(spacer)
	var start := UIKit.button("RACE!", _start, 30)
	left.add_child(start)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	left.add_child(row)
	var mods_button := UIKit.button("Mods", _toggle_mods)
	mods_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(mods_button)
	if BuildInfo.is_dev:
		var reload := UIKit.button("Reload Mods", _reload_mods)
		reload.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(reload)
	var quit := UIKit.button("Quit", func(): get_tree().quit())
	quit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(quit)

	var help := "Controls: W/S or Up/Down drive  -  A/D steer  -  Space/Shift drift  -  E ability  -  R respawn  -  Esc pause"
	var help_label := UIKit.label(help, 14, Color(0.7, 0.75, 0.85))
	help_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left.add_child(help_label)

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(right)
	right.add_child(_make_preview())

	_mods_panel = UIKit.panel()
	_mods_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_mods_panel.visible = false
	right.add_child(_mods_panel)
	_mods_text = RichTextLabel.new()
	_mods_text.bbcode_enabled = true
	_mods_text.scroll_following = false
	_mods_text.custom_minimum_size = Vector2(0, 260)
	_mods_panel.add_child(_mods_text)

	ModLoader.reloaded.connect(_refresh_lists)
	_refresh_lists()
	start.grab_focus()

	if BuildInfo.is_dev and ModLoader.error_count() > 0:
		_toggle_mods()


func _add_selector(parent: Control, title: String, on_change: Callable) -> Label:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	parent.add_child(row)
	var name_label := UIKit.label(title, 22, Color(0.75, 0.8, 0.95))
	name_label.custom_minimum_size = Vector2(130, 0)
	row.add_child(name_label)
	var prev := UIKit.button(" < ", func(): on_change.call(-1))
	row.add_child(prev)
	var value := UIKit.label("", 24)
	value.custom_minimum_size = Vector2(240, 0)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(value)
	var next := UIKit.button(" > ", func(): on_change.call(1))
	row.add_child(next)
	return value


func _make_preview() -> Control:
	var container := SubViewportContainer.new()
	container.stretch = true
	container.custom_minimum_size = Vector2(480, 340)
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.transparent_bg = true
	container.add_child(vp)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 2.4, 5.2)
	cam.rotation_degrees = Vector3(-16, 0, 0)
	vp.add_child(cam)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, 30, 0)
	vp.add_child(light)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.6, 0.65, 0.8)
	env.environment = e
	vp.add_child(env)
	_preview_holder = Node3D.new()
	vp.add_child(_preview_holder)
	return container


func _refresh_lists() -> void:
	GameState.validate_selection()
	_racer_ids = ModLoader.get_racer_ids()
	_track_ids = ModLoader.get_track_ids(BuildInfo.is_dev)
	_racer_index = maxi(_racer_ids.find(GameState.racer_id), 0)
	_track_index = maxi(_track_ids.find(GameState.track_id), 0)
	_update_racer()
	_update_track()
	_laps_value.text = str(GameState.laps)
	_ai_value.text = str(GameState.ai_count)
	_update_mods_text()


func _cycle_racer(d: int) -> void:
	if _racer_ids.is_empty():
		return
	_racer_index = posmod(_racer_index + d, _racer_ids.size())
	_update_racer()


func _cycle_track(d: int) -> void:
	if _track_ids.is_empty():
		return
	_track_index = posmod(_track_index + d, _track_ids.size())
	_update_track()


func _change_laps(d: int) -> void:
	GameState.laps = clampi(GameState.laps + d, 1, 9)
	_laps_value.text = str(GameState.laps)


func _change_ai(d: int) -> void:
	GameState.ai_count = clampi(GameState.ai_count + d, 0, 11)
	_ai_value.text = str(GameState.ai_count)


func _update_racer() -> void:
	for c in _preview_holder.get_children():
		c.queue_free()
	if _racer_ids.is_empty():
		_racer_value.text = "(none)"
		_racer_info.text = "No racers found. Check the Mods panel for errors."
		return
	GameState.racer_id = _racer_ids[_racer_index]
	var r: Dictionary = ModLoader.racers[GameState.racer_id]
	_racer_value.text = str(r["name"])
	var s: Dictionary = r["stats"]
	var ability: Dictionary = r.get("ability", {})
	var ability_name := str(ability.get("name", str(ability.get("type", "boost")).capitalize()))
	var from_mod := "" if r["_mod"] == "base" else "   [mod: %s]" % r["_mod"]
	_racer_info.text = "%s\nSpeed %s   Accel %s   Handling %s   Drift %s\nAbility: %s%s" % [
		r.get("description", ""), _stars(s["max_speed"], 22, 40), _stars(s["acceleration"], 10, 26),
		_stars(s["handling"], 1.5, 3.2), _stars(s["drift"], 0.6, 1.6), ability_name, from_mod]
	_preview_holder.add_child(KartVisual.make_preview(r))


func _update_track() -> void:
	if _track_ids.is_empty():
		_track_value.text = "(none)"
		_track_info.text = ""
		return
	GameState.track_id = _track_ids[_track_index]
	var t: Dictionary = ModLoader.tracks[GameState.track_id]
	_track_value.text = str(t["name"])
	var extra := ""
	if t.get("dev_only", false):
		extra += "   [dev only]"
	if t["_mod"] != "base":
		extra += "   [mod: %s]" % t["_mod"]
	_track_info.text = str(t.get("description", "")) + extra


func _stars(v: float, lo: float, hi: float) -> String:
	var n := clampi(roundi(remap(float(v), lo, hi, 1.0, 5.0)), 1, 5)
	return "*".repeat(n) + ".".repeat(5 - n)


func _start() -> void:
	if _racer_ids.is_empty() or _track_ids.is_empty():
		_toggle_mods()
		return
	GameState.track_override = {}
	GameState.start_race()


func _reload_mods() -> void:
	AbilityFactory.clear_cache()
	ModLoader.reload()
	_mods_panel.visible = true


func _toggle_mods() -> void:
	_mods_panel.visible = not _mods_panel.visible
	_update_mods_text()


func _update_mods_text() -> void:
	if _mods_text == null:
		return
	var lines: Array[String] = []
	lines.append("[b]Loaded content[/b]")
	for m in ModLoader.loaded_mods:
		var label := "Base game" if m["is_base"] else "%s v%s" % [m["name"], m["version"]]
		var by := "" if str(m["author"]) == "" else " by " + str(m["author"])
		lines.append("  - %s%s  (%d racers, %d tracks)" % [label, by, m["racers"], m["tracks"]])
	lines.append("")
	lines.append("[b]Mod folders[/b]")
	for root in ModLoader.get_mod_roots():
		lines.append("  " + root)
	var problems := ModLoader.messages.filter(func(m): return m["level"] != "info")
	if not problems.is_empty():
		lines.append("")
		lines.append("[b]Problems[/b]")
		for m in problems:
			var col := "#ff6060" if m["level"] == "error" else "#ffcc55"
			lines.append("  [color=%s]%s[/color]" % [col, m["text"]])
	_mods_text.text = "\n".join(lines)
