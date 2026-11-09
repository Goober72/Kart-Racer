class_name PauseMenu
extends CanvasLayer
## Esc / Start during a race.

var _panel: Control


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.5)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	_panel = dim

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.add_child(center)
	var p := UIKit.panel()
	p.custom_minimum_size = Vector2(320, 0)
	center.add_child(p)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	p.add_child(box)
	box.add_child(UIKit.label("PAUSED", 36, UIKit.ACCENT))
	box.add_child(UIKit.button("Resume", _resume))
	box.add_child(UIKit.button("Restart", func(): get_parent().restart()))
	box.add_child(UIKit.button("Main Menu", func(): GameState.go_to_menu()))
	dim.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if _panel.visible:
			_resume()
		else:
			_pause()
		get_viewport().set_input_as_handled()


func _pause() -> void:
	_panel.visible = true
	get_tree().paused = true
	var buttons := _panel.find_children("*", "Button", true, false)
	if not buttons.is_empty():
		(buttons[0] as Button).grab_focus()


func _resume() -> void:
	_panel.visible = false
	get_tree().paused = false
