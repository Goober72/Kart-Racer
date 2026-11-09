class_name RacerCreator
extends Control
## In-game racer maker (Dev build). Pick a name, colors, stats and an ability;
## the racer is saved as a normal mod file in  <user mods>/my_racers/racers/,
## so it works exactly like a hand-written mod and can be shared.

signal closed

const MOD_ID := "my_racers"
const KART_COLORS := ["#d83a3a", "#f08a24", "#f2c14e", "#3f8f3a", "#3ac0c0", "#2f7de1",
	"#5b3fd1", "#9b2fd1", "#e05aa8", "#f5f5f5", "#8a8a95", "#1d1d24", "#8a5a2b", "#7fd16b"]
const SKIN_COLORS := ["#ffe0c4", "#f2c38f", "#e0a878", "#c98b5a", "#a86d43", "#8d5a3b",
	"#6b4228", "#4a2e1d", "#9fd18b", "#8fb8ff", "#c7a4ff", "#ff9f9f"]
const STATS := [
	["max_speed", "Speed", 28.0, 34.0],
	["acceleration", "Acceleration", 13.0, 22.0],
	["handling", "Handling", 1.9, 2.9],
	["drift", "Drift charge", 0.9, 1.25],
]
const ABILITIES := ["boost", "hop", "shockwave", "shield"]
const ABILITY_INFO := {
	"boost": ["Turbo", "A burst of speed."],
	"hop": ["Super Hop", "A big jump. Skip corners!"],
	"shockwave": ["Shockwave", "Slows down karts near you."],
	"shield": ["Shield", "Blocks shockwaves and softens wall hits."],
}
## Stat levels (1-5 each) plus ability power (1-3) must fit in this budget.
const BUDGET := 15

var _levels := {"max_speed": 3, "acceleration": 3, "handling": 3, "drift": 3}
var _ability_type := "boost"
var _ability_level := 2
var _colors := {"body_color": "#2f7de1", "accent_color": "#f5f5f5", "helmet_color": "#f2c14e", "driver_color": "#f2c38f"}
var _editing_id := ""  # empty = new racer

var _name_edit: LineEdit
var _desc_edit: LineEdit
var _ability_name_edit: LineEdit
var _stat_values := {}
var _points_label: Label
var _ability_label: Label
var _ability_desc: Label
var _ability_power: HBoxContainer
var _editing_label: Label
var _status: Label
var _preview_holder: Node3D
var _swatch_rows := {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := Panel.new()
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.07, 0.09, 0.15)
	bg.add_theme_stylebox_override("panel", bg_style)
	add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var margin := MarginContainer.new()
	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 20)
	margin.add_child(columns)

	# ---- Left: options (scrolls on small screens) ----
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(700, 0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	columns.add_child(scroll)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 8)
	scroll.add_child(left)

	left.add_child(UIKit.label("CREATE A RACER", 40, UIKit.ACCENT))
	var edit_row := HBoxContainer.new()
	edit_row.add_theme_constant_override("separation", 8)
	left.add_child(edit_row)
	edit_row.add_child(UIKit.button(" < ", func(): _cycle_existing(-1)))
	_editing_label = UIKit.label("", 20)
	_editing_label.custom_minimum_size = Vector2(300, 0)
	_editing_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	edit_row.add_child(_editing_label)
	edit_row.add_child(UIKit.button(" > ", func(): _cycle_existing(1)))
	edit_row.add_child(UIKit.button("New", _new_racer, 20))

	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 8)
	left.add_child(name_row)
	name_row.add_child(_caption("Name"))
	_name_edit = _line_edit("Racer name", 20)
	name_row.add_child(_name_edit)
	name_row.add_child(UIKit.button("Random", _random_name, 20))

	var desc_row := HBoxContainer.new()
	desc_row.add_theme_constant_override("separation", 8)
	left.add_child(desc_row)
	desc_row.add_child(_caption("Bio"))
	_desc_edit = _line_edit("A short description (optional)", 80)
	desc_row.add_child(_desc_edit)

	left.add_child(UIKit.label("Colors", 24, Color(0.75, 0.8, 0.95)))
	_add_swatches(left, "body_color", "Kart", KART_COLORS)
	_add_swatches(left, "accent_color", "Trim", KART_COLORS)
	_add_swatches(left, "helmet_color", "Helmet", KART_COLORS)
	_add_swatches(left, "driver_color", "Skin", SKIN_COLORS)

	var stats_title := HBoxContainer.new()
	left.add_child(stats_title)
	stats_title.add_child(UIKit.label("Stats", 24, Color(0.75, 0.8, 0.95)))
	_points_label = UIKit.label("", 20, UIKit.ACCENT)
	_points_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_points_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	stats_title.add_child(_points_label)
	for s in STATS:
		var key: String = s[0]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		left.add_child(row)
		row.add_child(_caption(s[1]))
		row.add_child(UIKit.button(" - ", func(): _change_stat(key, -1)))
		var pips := _make_pips(5)
		row.add_child(pips)
		row.add_child(UIKit.button(" + ", func(): _change_stat(key, 1)))
		_stat_values[key] = pips

	left.add_child(UIKit.label("Ability", 24, Color(0.75, 0.8, 0.95)))
	var ab_row := HBoxContainer.new()
	ab_row.add_theme_constant_override("separation", 8)
	left.add_child(ab_row)
	ab_row.add_child(_caption("Type"))
	ab_row.add_child(UIKit.button(" < ", func(): _cycle_ability(-1)))
	_ability_label = UIKit.label("", 22)
	_ability_label.custom_minimum_size = Vector2(170, 0)
	_ability_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ab_row.add_child(_ability_label)
	ab_row.add_child(UIKit.button(" > ", func(): _cycle_ability(1)))
	_ability_desc = UIKit.label("", 16, Color(0.8, 0.85, 0.95))
	left.add_child(_ability_desc)
	var pw_row := HBoxContainer.new()
	pw_row.add_theme_constant_override("separation", 8)
	left.add_child(pw_row)
	pw_row.add_child(_caption("Power"))
	pw_row.add_child(UIKit.button(" - ", func(): _change_ability_level(-1)))
	_ability_power = _make_pips(3)
	pw_row.add_child(_ability_power)
	pw_row.add_child(UIKit.button(" + ", func(): _change_ability_level(1)))
	var an_row := HBoxContainer.new()
	an_row.add_theme_constant_override("separation", 8)
	left.add_child(an_row)
	an_row.add_child(_caption("Name it"))
	_ability_name_edit = _line_edit("Ability name (optional)", 24)
	an_row.add_child(_ability_name_edit)

	# ---- Right: preview + actions ----
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 8)
	columns.add_child(right)
	right.add_child(_make_preview())
	for entry in [["Save", _save], ["Save + Test Drive", _test_drive], ["Share file", _share], ["Delete", _delete], ["Back", _close]]:
		var b := UIKit.button(entry[0], entry[1], 22)
		right.add_child(b)
	_status = UIKit.label("", 16, Color(0.7, 1.0, 0.7))
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size = Vector2(300, 0)
	right.add_child(_status)

	_name_edit.text_changed.connect(func(_t): _refresh())

	# Start by editing the racer selected in the menu if it's one of ours.
	var selected: Dictionary = ModLoader.racers.get(GameState.racer_id, {})
	if selected.get("_mod", "") == MOD_ID:
		_load_racer(selected)
	else:
		_new_racer()


# ---- Building blocks ---------------------------------------------------------

func _caption(text: String) -> Label:
	var l := UIKit.label(text, 20, Color(0.75, 0.8, 0.95))
	l.custom_minimum_size = Vector2(140, 0)
	return l


func _line_edit(placeholder: String, max_len: int) -> LineEdit:
	var e := LineEdit.new()
	e.placeholder_text = placeholder
	e.max_length = max_len
	e.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	e.custom_minimum_size = Vector2(0, 46)
	e.add_theme_font_size_override("font_size", 22)
	e.virtual_keyboard_enabled = true
	return e


## A row of little bars showing a 1..n level (no special font characters needed).
func _make_pips(count: int) -> HBoxContainer:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	box.custom_minimum_size = Vector2(170, 0)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	for i in count:
		var pip := ColorRect.new()
		pip.custom_minimum_size = Vector2(28, 26)
		box.add_child(pip)
	return box


func _set_pips(box: HBoxContainer, level: int) -> void:
	for i in box.get_child_count():
		(box.get_child(i) as ColorRect).color = UIKit.ACCENT if i < level else Color(1, 1, 1, 0.15)


func _add_swatches(parent: Control, key: String, title: String, palette: Array) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	parent.add_child(row)
	row.add_child(_caption(title))
	var buttons: Array[Button] = []
	for hex in palette:
		var b := Button.new()
		b.custom_minimum_size = Vector2(36, 40)
		b.focus_mode = Control.FOCUS_NONE
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color.html(hex)
		sb.set_corner_radius_all(6)
		b.add_theme_stylebox_override("normal", sb)
		b.add_theme_stylebox_override("hover", sb)
		b.add_theme_stylebox_override("pressed", sb)
		b.set_meta("hex", hex)
		b.pressed.connect(func():
			_colors[key] = hex
			_refresh())
		row.add_child(b)
		buttons.append(b)
	_swatch_rows[key] = buttons


func _make_preview() -> Control:
	var container := SubViewportContainer.new()
	container.stretch = true
	container.custom_minimum_size = Vector2(380, 280)
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


# ---- Editing -------------------------------------------------------------------

func _points_used() -> int:
	var total := _ability_level
	for k in _levels:
		total += _levels[k]
	return total


func _change_stat(key: String, d: int) -> void:
	var v: int = _levels[key] + d
	if v < 1 or v > 5:
		return
	if d > 0 and _points_used() >= BUDGET:
		_status.text = "Out of points! Lower another stat first."
		return
	_levels[key] = v
	_refresh()


func _change_ability_level(d: int) -> void:
	var v := _ability_level + d
	if v < 1 or v > 3:
		return
	if d > 0 and _points_used() >= BUDGET:
		_status.text = "Out of points! Lower a stat first."
		return
	_ability_level = v
	_refresh()


func _cycle_ability(d: int) -> void:
	_ability_type = ABILITIES[posmod(ABILITIES.find(_ability_type) + d, ABILITIES.size())]
	_refresh()


func _random_name() -> void:
	var first := ["Turbo", "Captain", "Little", "Big", "Sir", "Rocket", "Lucky", "Dusty", "Neon", "Sunny", "Pickle", "Mega"]
	var second := ["Biscuit", "Comet", "Noodle", "Sprocket", "Pebble", "Muffin", "Blaze", "Waffle", "Bolt", "Gizmo", "Taco", "Spark"]
	_name_edit.text = "%s %s" % [first.pick_random(), second.pick_random()]
	_refresh()


func _my_racer_ids() -> Array:
	var ids := []
	for id in ModLoader.get_racer_ids():
		if ModLoader.racers[id].get("_mod", "") == MOD_ID:
			ids.append(id)
	return ids


func _cycle_existing(d: int) -> void:
	var ids := _my_racer_ids()
	if ids.is_empty():
		_status.text = "You haven't saved any racers yet."
		return
	var i := ids.find(_editing_id)
	i = posmod(i + d, ids.size()) if i >= 0 else (0 if d > 0 else ids.size() - 1)
	_load_racer(ModLoader.racers[ids[i]])


func _new_racer() -> void:
	_editing_id = ""
	_levels = {"max_speed": 3, "acceleration": 3, "handling": 3, "drift": 3}
	_ability_type = ABILITIES.pick_random()
	_ability_level = 2
	_colors = {"body_color": KART_COLORS.pick_random(), "accent_color": "#f5f5f5",
		"helmet_color": KART_COLORS.pick_random(), "driver_color": SKIN_COLORS.pick_random()}
	_name_edit.text = ""
	_desc_edit.text = ""
	_ability_name_edit.text = ""
	_random_name()
	_status.text = "New racer. You have %d points to spend on stats and ability power." % BUDGET


func _load_racer(r: Dictionary) -> void:
	_editing_id = str(r["id"])
	_name_edit.text = str(r.get("name", ""))
	_desc_edit.text = str(r.get("description", ""))
	for k in _colors.keys():
		_colors[k] = str(r.get(k, _colors[k]))
	var stats: Dictionary = r.get("stats", {})
	for s in STATS:
		var v := float(stats.get(s[0], (s[2] + s[3]) * 0.5))
		_levels[s[0]] = clampi(roundi(remap(v, s[2], s[3], 1.0, 5.0)), 1, 5)
	var ab: Dictionary = r.get("ability", {})
	_ability_type = str(ab.get("type", "boost")) if ABILITIES.has(str(ab.get("type", ""))) else "boost"
	_ability_level = clampi(int(ab.get("level", 2)), 1, 3)
	_ability_name_edit.text = str(ab.get("name", ""))
	_status.text = "Editing %s." % _name_edit.text
	_refresh()


func _refresh() -> void:
	var used := _points_used()
	_points_label.text = "Points left: %d / %d" % [BUDGET - used, BUDGET]
	for s in STATS:
		_set_pips(_stat_values[s[0]], _levels[s[0]])
	var info: Array = ABILITY_INFO[_ability_type]
	_ability_label.text = info[0]
	_ability_desc.text = info[1]
	_set_pips(_ability_power, _ability_level)
	_editing_label.text = "Editing: " + (_name_edit.text if _editing_id != "" else "new racer")
	for key in _swatch_rows:
		for b in _swatch_rows[key]:
			var selected: bool = str(b.get_meta("hex")).to_lower() == str(_colors[key]).to_lower()
			var sb := StyleBoxFlat.new()
			sb.bg_color = Color.html(b.get_meta("hex"))
			sb.set_corner_radius_all(6)
			if selected:
				sb.set_border_width_all(4)
				sb.border_color = UIKit.ACCENT
			for state in ["normal", "hover", "pressed"]:
				b.add_theme_stylebox_override(state, sb)
	for c in _preview_holder.get_children():
		c.queue_free()
	_preview_holder.add_child(KartVisual.make_preview(_build_data()))


# ---- Output --------------------------------------------------------------------

func _ability_params() -> Dictionary:
	var lv := float(_ability_level)
	var p := {"type": _ability_type, "level": _ability_level}
	match _ability_type:
		"boost":
			p.merge({"duration": 1.1 + 0.3 * lv, "power": 1.3 + 0.05 * lv, "cooldown": 10.0 - lv})
		"hop":
			p.merge({"height": 10.0 + 2.0 * lv, "push": 4.0 + 2.0 * lv, "cooldown": 8.0 - lv})
		"shockwave":
			p.merge({"radius": 10.0 + 3.0 * lv, "slow": 0.35 + 0.1 * lv, "cooldown": 12.0 - lv})
		"shield":
			p.merge({"duration": 2.0 + lv, "cooldown": 11.0 - lv})
	var custom := _ability_name_edit.text.strip_edges()
	p["name"] = custom if custom != "" else ABILITY_INFO[_ability_type][0]
	return p


func _build_data() -> Dictionary:
	var stats := {}
	for s in STATS:
		stats[s[0]] = snappedf(remap(float(_levels[s[0]]), 1.0, 5.0, s[2], s[3]), 0.01)
	var racer_name := _name_edit.text.strip_edges()
	if racer_name == "":
		racer_name = "Mystery Racer"
	var data := {
		"id": _editing_id if _editing_id != "" else _make_id(racer_name),
		"name": racer_name,
		"description": _desc_edit.text.strip_edges(),
		"stats": stats,
		"ability": _ability_params(),
	}
	data.merge(_colors)
	return data


func _make_id(racer_name: String) -> String:
	var slug := ""
	for ch in racer_name.to_lower():
		if (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9"):
			slug += ch
		elif slug != "" and not slug.ends_with("_"):
			slug += "_"
	slug = "my_" + slug.trim_suffix("_")
	var id := slug
	var n := 2
	while ModLoader.racers.has(id):
		id = "%s_%d" % [slug, n]
		n += 1
	return id


func _mod_dir() -> String:
	return ModLoader.user_mods_dir().path_join(MOD_ID)


func _save() -> bool:
	var data := _build_data()
	var dir := _mod_dir().path_join("racers")
	DirAccess.make_dir_recursive_absolute(dir)
	var manifest := _mod_dir().path_join("mod.json")
	if not FileAccess.file_exists(manifest):
		var mf := FileAccess.open(manifest, FileAccess.WRITE)
		if mf != null:
			mf.store_string(JSON.stringify({"id": MOD_ID, "name": "My Racers", "version": "1.0",
				"description": "Racers made with the in-game creator."}, "  "))
			mf.close()
	var path := dir.path_join(str(data["id"]) + ".json")
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		_status.text = "Couldn't save (%s)." % error_string(FileAccess.get_open_error())
		return false
	f.store_string(JSON.stringify(data, "  "))
	f.close()
	_editing_id = str(data["id"])
	ModLoader.reload()
	GameState.racer_id = _editing_id
	_status.text = "Saved %s! They're in the racer list now." % data["name"]
	_refresh()
	return true


func _test_drive() -> void:
	if not _save():
		return
	var tracks := ModLoader.get_track_ids(false)
	if tracks.is_empty():
		return
	GameState.track_id = "meadow_ring" if tracks.has("meadow_ring") else str(tracks[0])
	GameState.ai_count = 3
	GameState.laps = 1
	GameState.track_override = {}
	GameState.start_race()


func _share() -> void:
	var data := _build_data()
	var text := JSON.stringify(data, "  ")
	var file_name := str(data["id"]) + ".json"
	if OS.has_feature("web"):
		JavaScriptBridge.download_buffer(text.to_utf8_buffer(), file_name, "application/json")
		_status.text = "Downloaded %s. To share it, a friend puts it in mods/my_racers/racers/ (with a mod.json; see MODDING.md)." % file_name
	else:
		DisplayServer.clipboard_set(text)
		_status.text = "Copied to clipboard. The file is in:\n" + _mod_dir().path_join("racers").path_join(file_name)


func _delete() -> void:
	if _editing_id == "":
		_status.text = "This racer isn't saved yet."
		return
	var path := _mod_dir().path_join("racers").path_join(_editing_id + ".json")
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	var gone := _name_edit.text
	ModLoader.reload()
	_new_racer()
	_status.text = "Deleted %s." % gone


func _close() -> void:
	closed.emit()
	queue_free()
