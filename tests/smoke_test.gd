extends Node
## Automated smoke test. Runs every track with computer drivers and checks that
## content loads, races can be finished, abilities work and dev tools respond.
##
## Run headless:
##   godot --headless --fixed-fps 60 --path . res://tests/smoke_test.tscn
## Exits with code 0 on success, 1 on failure.

var failures: Array[String] = []


func _ready() -> void:
	# Detach from current_scene so changing scenes doesn't free the test.
	get_tree().current_scene = null
	get_tree().create_timer(900.0).timeout.connect(func():
		print("SMOKE TEST TIMED OUT")
		get_tree().quit(2))
	_run.call_deferred()


func _check(cond: bool, what: String) -> void:
	if cond:
		print("  ok   ", what)
	else:
		print("  FAIL ", what)
		failures.append(what)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _run() -> void:
	print("== Content ==")
	_check(ModLoader.error_count() == 0, "mods load without errors (%d)" % ModLoader.error_count())
	for m in ModLoader.messages:
		if m["level"] != "info":
			print("     ", m["level"], ": ", m["text"])
	_check(ModLoader.racers.size() >= 6, "racers loaded: %d" % ModLoader.racers.size())
	_check(ModLoader.tracks.has("rolling_hills"), "example mod track loaded")
	_check(ModLoader.racers.has("toast"), "example mod racer loaded")
	_check(ModLoader.items.size() >= 9, "items loaded: %d" % ModLoader.items.size())
	_check(ModLoader.items.has("warp_crumb"), "example mod item loaded")

	print("== Imported models ==")
	var rivet := KartVisual.make_preview(ModLoader.racers["rivet"])
	add_child(rivet)
	_check(rivet.found_animations.size() >= 6, "character animations found: %s" % ", ".join(rivet.found_animations))
	_check(rivet._anim_map.get("win", "") == "Cheer" and rivet._anim_map.get("steer_left", "") == "LeanLeft", "animations mapped to slots")
	_check(rivet._model_wheels.size() == 4 and rivet._model_front.size() == 2, "kart model wheels found (4, 2 front)")
	rivet.queue_free()
	var auto := ModelLoader.map_animations(PackedStringArray(["Armature|Idle_Loop", "Armature|Driving", "Turn_Left", "Victory"]), {})
	_check(auto.get("idle") == "Armature|Idle_Loop" and auto.get("drive") == "Armature|Driving" and auto.get("win") == "Victory", "animation names auto-detected")

	for track_id in ModLoader.get_track_ids(false):
		await _race_test(track_id)

	await _dev_test()
	await _creator_test()

	print("")
	if failures.is_empty():
		print("SMOKE TEST PASSED")
		get_tree().quit(0)
	else:
		print("SMOKE TEST FAILED: ", failures)
		get_tree().quit(1)


func _race_test(track_id: String) -> void:
	print("== Race on %s ==" % track_id)
	GameState.track_id = track_id
	GameState.racer_id = "rivet" if track_id == "loop_park" else "toast"
	GameState.ai_count = 5
	GameState.laps = 1
	GameState.start_race()
	await _frames(2)
	var race = get_tree().current_scene
	_check(race != null and race.name == "Race", "race scene loaded")
	if race == null or race.name != "Race":
		return
	race.player.controller = AIController.new(race.track, 1.0, 99)
	_check(race.track.length > 100.0, "track length %.0f m" % race.track.length)

	var used_ability := false
	var used_charged := false
	var item_ids := ModLoader.items.keys()
	var items_used := 0
	var max_frames := 60 * 150
	var f := 0
	while f < max_frames:
		await get_tree().physics_frame
		f += 1
		if race.state == "racing" and race.player.ability != null:
			if not used_ability:
				used_ability = race.player.ability.try_activate(false)
			elif not used_charged and race.player.ability.is_ready():
				used_charged = race.player.ability.try_activate(true)
		# Try every item once, every second, from the player's kart.
		if race.state == "racing" and f % 60 == 0 and items_used < item_ids.size():
			race.player.give_item(ModLoader.items[item_ids[items_used]])
			race.player.use_item()
			items_used += 1
		var all_done := true
		for k in race.karts:
			if not k.finished:
				all_done = false
		if all_done:
			break
	var finished := 0
	for k in race.karts:
		if k.finished:
			finished += 1
	print("     race_time %.1fs, %d/%d finished" % [race.race_time, finished, race.karts.size()])
	for k in race.karts:
		print("     %-10s place %d  dist %.0f  %s" % [k.display_name, k.place, k.distance, ("%.1fs" % k.finish_time) if k.finished else "-"])
	_check(used_ability, "skill tap activated (scripted, from mod)")
	_check(used_charged, "skill charged activated")
	if GameState.racer_id == "toast":
		_check(race.player.ability != null and race.player.ability.get_script() != KartAbility, "mod skill script compiled")
	if track_id == "loop_park":
		_check(race.track.points_from_model, "racing line read from model Path markers")
		var pads: Array = race.track.find_children("*", "BoostPad", true, false)
		_check(pads.size() == 1, "boost pad placed from model marker")
	_check(items_used == item_ids.size(), "all %d items used without errors" % items_used)
	var boxes: Array = race.track.find_children("*", "ItemBox", true, false)
	_check(boxes.size() >= 4 if track_id != "loop_park" else boxes.size() == 6, "item boxes on track: %d" % boxes.size())
	_check(finished >= race.karts.size() - 1, "karts finish the lap")
	_check(race.player.finished, "player kart finished")


func _creator_test() -> void:
	print("== Racer creator ==")
	var menu = get_tree().current_scene
	menu._open_creator()
	await _frames(2)
	var creator: RacerCreator = menu.find_children("*", "RacerCreator", true, false)[0]
	creator._name_edit.text = "Smoke Tester"
	for i in 5:
		creator._change_stat("max_speed", 1)
	_check(creator._points_used() <= RacerCreator.BUDGET, "creator respects points budget (%d)" % creator._points_used())
	_check(creator._save(), "creator saves racer")
	var id := creator._editing_id
	_check(ModLoader.racers.has(id), "created racer '%s' loaded as a mod" % id)
	_check(ModLoader.racers.get(id, {}).get("_mod", "") == "my_racers", "created racer is in my_racers mod")
	creator._delete()
	_check(not ModLoader.racers.has(id), "created racer deleted")
	creator._close()
	await _frames(2)


func _dev_test() -> void:
	print("== Dev tools ==")
	_check(BuildInfo.is_dev, "editor run counts as dev build")
	GameState.track_id = "sandbox"
	GameState.ai_count = 0
	GameState.start_race()
	await _frames(2)
	var race = get_tree().current_scene
	_check(race.is_free_roam(), "sandbox is free roam")
	DevTools._run("track_new smoke_test_track")
	var pts := [Vector3(0, 0, 0), Vector3(60, 0, 0), Vector3(80, 0, 50), Vector3(20, 0, 70), Vector3(-20, 0, 35)]
	for p in pts:
		race.player.respawn(Transform3D(Basis.IDENTITY, p + Vector3.UP * 0.6))
		DevTools._run("track_point")
	_check(DevTools._rec_points.size() == 5, "recorder captured 5 points")
	DevTools._run("track_preview")
	await _frames(5)
	_check(race.track.length > 150.0, "previewed track built (%.0f m)" % race.track.length)
	race.player.controller = AIController.new(race.track, 1.0, 7)
	await _frames(60 * 6)
	_check(race.player.distance > 50.0, "AI drives the previewed track (%.0f m)" % race.player.distance)
	DevTools._run("speed 2")
	_check(is_equal_approx(race.player.speed_multiplier, 2.0), "speed command")
	DevTools._run("mods")
	DevTools._run("help")
	GameState.go_to_menu()
	await _frames(3)
	_check(get_tree().current_scene.name == "MainMenu", "back to main menu")
