class_name RaceHUD
extends CanvasLayer
## On-screen race info: lap, position, time, speed, drift charge, ability.

var race: Node
var _lap: Label
var _place: Label
var _time: Label
var _speed: Label
var _ability_name: Label
var _ability_bar: ProgressBar
var _charge_bar: ProgressBar
var _item_box: PanelContainer
var _item_icon: Label
var _item_name: Label
var _drift_bar: ProgressBar
var _center: Label
var _message_time: float = 0.0
var _results: PanelContainer
var _results_list: VBoxContainer


func setup(race_node: Node) -> void:
	race = race_node
	layer = 10

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var top_left := VBoxContainer.new()
	top_left.position = Vector2(24, 16)
	root.add_child(top_left)
	_place = UIKit.label("", 56, UIKit.ACCENT)
	_lap = UIKit.label("", 28)
	top_left.add_child(_place)
	top_left.add_child(_lap)

	_time = UIKit.label("", 30)
	_time.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_time.position = Vector2(-240, 20)
	_time.size = Vector2(220, 40)
	_time.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	root.add_child(_time)

	var bottom_right := VBoxContainer.new()
	bottom_right.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	bottom_right.position = Vector2(-260, -120)
	bottom_right.size = Vector2(236, 100)
	bottom_right.alignment = BoxContainer.ALIGNMENT_END
	root.add_child(bottom_right)
	_speed = UIKit.label("", 40)
	_speed.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	bottom_right.add_child(_speed)
	var drift_title := UIKit.label("DRIFT", 14, Color(1, 1, 1, 0.8))
	drift_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	bottom_right.add_child(drift_title)
	_drift_bar = UIKit.bar(Kart.DRIFT_COLORS[0])
	bottom_right.add_child(_drift_bar)

	var bottom_left := VBoxContainer.new()
	bottom_left.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	bottom_left.position = Vector2(24, -90)
	root.add_child(bottom_left)
	_ability_name = UIKit.label("", 22)
	bottom_left.add_child(_ability_name)
	_ability_bar = UIKit.bar(Color(0.4, 1.0, 0.5))
	bottom_left.add_child(_ability_bar)
	_charge_bar = UIKit.bar(UIKit.ACCENT)
	_charge_bar.visible = false
	bottom_left.add_child(_charge_bar)

	# Held item, top-left next to the position.
	_item_box = UIKit.panel()
	_item_box.position = Vector2(250, 18)
	root.add_child(_item_box)
	var item_row := HBoxContainer.new()
	item_row.add_theme_constant_override("separation", 10)
	_item_box.add_child(item_row)
	_item_icon = UIKit.label("", 34)
	_item_icon.custom_minimum_size = Vector2(56, 56)
	_item_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_item_icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	item_row.add_child(_item_icon)
	_item_name = UIKit.label("", 18)
	item_row.add_child(_item_name)

	_center = UIKit.label("", 96, UIKit.ACCENT)
	_center.set_anchors_preset(Control.PRESET_CENTER)
	_center.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_center.size = Vector2(800, 140)
	_center.position = Vector2(-400, -170)
	root.add_child(_center)

	if BuildInfo.is_dev:
		var tag := UIKit.label("DEV BUILD  -  F1 console  |  F3 debug info", 14, Color(1, 0.5, 0.5))
		tag.set_anchors_preset(Control.PRESET_CENTER_TOP)
		tag.position = Vector2(-170, 6)
		root.add_child(tag)

	_build_results(root)


func flash_message(text: String, duration: float) -> void:
	_center.text = text
	_message_time = duration


func show_results() -> void:
	_results.visible = true
	var first := _results.find_children("*", "Button", true, false)
	if not first.is_empty():
		(first[0] as Button).grab_focus()


func _process(delta: float) -> void:
	var player: Kart = race.player
	if player == null:
		return
	var free: bool = race.is_free_roam()
	var total: int = race.karts.size()

	if free:
		_place.text = "FREE ROAM"
		_lap.text = "R = respawn   Esc = menu"
		_time.text = ""
	else:
		_place.text = "%s / %d" % [UIKit.ordinal(player.place), total]
		_lap.text = "LAP %d / %d" % [race.lap_of(player), race.laps]
		_time.text = UIKit.format_time(player.finish_time if player.finished else race.race_time)

	_speed.text = "%d km/h" % int(absf(player.speed) * 3.6)
	var level := player.drift_level()
	if player.drifting:
		var max_t: float = Kart.DRIFT_LEVEL_TIMES[-1]
		_drift_bar.value = clampf(player.drift_charge / max_t, 0.0, 1.0)
		var fill := _drift_bar.get_theme_stylebox("fill") as StyleBoxFlat
		fill.bg_color = Kart.DRIFT_COLORS[maxi(level - 1, 0)] if level > 0 else Color(0.7, 0.7, 0.7)
	else:
		_drift_bar.value = 0.0

	if player.ability != null:
		var ready := player.ability.is_ready()
		var hint := "  tap / hold" if ready else ""
		_ability_name.text = "%s%s" % [player.ability.get_display_name(false), hint]
		_ability_bar.value = player.ability.charge_ratio()
		var charge := player.skill_charge_ratio()
		_charge_bar.visible = charge > 0.05
		_charge_bar.value = charge
		if charge >= 0.999 or (charge > 0.05 and charge < 1.0):
			_ability_name.text = "Charging %s..." % player.ability.get_display_name(true)
	else:
		_ability_name.text = ""
		_ability_bar.visible = false

	_update_item(player)

	if race.state == "countdown":
		_center.text = str(ceili(race.countdown))
	elif _message_time > 0.0:
		_message_time -= delta
		if _message_time <= 0.0:
			_center.text = ""

	if _results.visible:
		_refresh_results()


func _update_item(player: Kart) -> void:
	if player.item.is_empty():
		_item_icon.text = ""
		_item_name.text = "No item"
		_item_box.modulate = Color(1, 1, 1, 0.5)
		_set_icon_color(Color(0, 0, 0, 0.3))
		return
	_item_box.modulate = Color.WHITE
	_item_icon.text = str(player.item.get("label", "?"))
	var col := str(player.item.get("color", "#ffcc33"))
	_set_icon_color(Color.html(col) if Color.html_is_valid(col) else Color.ORANGE)
	var uses := " x%d" % player.item_uses if player.item_uses > 1 else ""
	_item_name.text = "%s%s\n[Q] use" % [player.item.get("name", "Item"), uses]


func _set_icon_color(c: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = c
	sb.set_corner_radius_all(8)
	_item_icon.add_theme_stylebox_override("normal", sb)


func _build_results(root: Control) -> void:
	_results = UIKit.panel()
	_results.set_anchors_preset(Control.PRESET_CENTER)
	_results.custom_minimum_size = Vector2(460, 0)
	_results.position = Vector2(-230, -200)
	_results.visible = false
	root.add_child(_results)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	_results.add_child(box)
	box.add_child(UIKit.label("RESULTS", 34, UIKit.ACCENT))
	_results_list = VBoxContainer.new()
	box.add_child(_results_list)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	box.add_child(buttons)
	var again := UIKit.button("Race Again", func(): race.restart())
	again.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(again)
	var menu := UIKit.button("Main Menu", func(): GameState.go_to_menu())
	menu.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(menu)


func _refresh_results() -> void:
	var sorted: Array = race.karts.duplicate()
	sorted.sort_custom(func(a: Kart, b: Kart) -> bool: return a.place < b.place)
	while _results_list.get_child_count() < sorted.size():
		_results_list.add_child(UIKit.label("", 22))
	for i in sorted.size():
		var k: Kart = sorted[i]
		var line := _results_list.get_child(i) as Label
		var t := UIKit.format_time(k.finish_time) if k.finished else "racing..."
		line.text = "%-5s %-18s %s" % [UIKit.ordinal(k.place), k.display_name + (" (you)" if k.is_player else ""), t]
		line.add_theme_color_override("font_color", UIKit.ACCENT if k.is_player else Color.WHITE)
