class_name PlayerController
extends RefCounted
## Reads keyboard / gamepad input for the player's kart.


func read(_kart: Kart) -> Dictionary:
	return {
		"throttle": Input.get_action_strength("accelerate") - Input.get_action_strength("brake"),
		"steer": Input.get_action_strength("steer_right") - Input.get_action_strength("steer_left"),
		"drift": Input.is_action_pressed("drift"),
		"ability": Input.is_action_pressed("ability"),
		"item": Input.is_action_just_pressed("item"),
		"respawn": Input.is_action_just_pressed("respawn"),
	}
