extends Node3D
## Runs a race: builds the track, spawns karts, counts laps and positions.

var track: Track
var karts: Array[Kart] = []
var player: Kart
var camera: ChaseCamera
var hud: RaceHUD
var pause_menu: PauseMenu
## "countdown", "racing", "finished" (player done) or "free" (free roam / no laps)
var state: String = "countdown"
var countdown: float = 3.0
var race_time: float = 0.0
var laps: int = 3
var finish_order: Array[Kart] = []

var _environment: WorldEnvironment
var _sun: DirectionalLight3D


func _ready() -> void:
	var data := GameState.get_track_data()
	if data.is_empty():
		push_warning("No track to race on. Returning to menu.")
		GameState.go_to_menu.call_deferred()
		return
	laps = maxi(GameState.laps, 1)

	_build_track(data)
	_spawn_karts()

	camera = ChaseCamera.new()
	add_child(camera)
	camera.target = player
	camera.current = true
	camera.snap()

	hud = RaceHUD.new()
	add_child(hud)
	hud.setup(self)

	pause_menu = PauseMenu.new()
	add_child(pause_menu)

	if track.free_roam or track.length <= 0.0:
		_start_free_roam()

	if BuildInfo.is_dev:
		DevTools.attach_race(self)


func _physics_process(delta: float) -> void:
	match state:
		"countdown":
			countdown -= delta
			if countdown <= 0.0:
				state = "racing"
				for k in karts:
					k.controls_enabled = true
				hud.flash_message("GO!", 1.0)
		"racing", "finished":
			race_time += delta

	for k in karts:
		_track_progress(k)
		_check_respawn(k)
	_update_places()


func is_free_roam() -> bool:
	return state == "free"


func lap_of(k: Kart) -> int:
	if track.length <= 0.0:
		return 1
	return clampi(floori(k.distance / track.length) + 1, 1, laps)


func restart() -> void:
	GameState.start_race()


## Swaps in a different track without leaving the race (used by the dev track recorder).
func rebuild_track(data: Dictionary) -> void:
	if track != null:
		track.free()
	_build_track(data)
	for i in karts.size():
		var k := karts[i]
		k.respawn(_spawn_transform(i))
		_reset_progress(k)
	_start_free_roam()
	camera.snap()


func respawn_kart(k: Kart) -> void:
	var t: Transform3D
	if track.length <= 0.0:
		t = Transform3D(Basis.IDENTITY, Vector3(0, 1, 0))
	else:
		t = track.transform_at(fposmod(k.distance, track.length), 0.0, 1.0)
	k.respawn(t)
	k.last_offset = track.get_offset(k.global_position)
	if k == player:
		camera.snap()


# --------------------------------------------------------------------------

func _build_track(data: Dictionary) -> void:
	if _environment == null:
		_environment = WorldEnvironment.new()
		add_child(_environment)
		_sun = DirectionalLight3D.new()
		_sun.shadow_enabled = true
		_sun.directional_shadow_max_distance = 160.0
		add_child(_sun)
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	var top := _color(data, "sky_top_color", Color(0.18, 0.43, 0.82))
	var horizon := _color(data, "sky_horizon_color", Color(0.78, 0.9, 1.0))
	sky_mat.sky_top_color = top
	sky_mat.sky_horizon_color = horizon
	sky_mat.ground_horizon_color = horizon
	sky_mat.ground_bottom_color = _color(data, "ground_color", Color(0.3, 0.55, 0.25))
	sky.sky_material = sky_mat
	env.sky = sky
	# Flat ambient light (sky-based ambient tints everything with the ground color).
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = top.lerp(horizon, 0.6).lerp(Color.WHITE, 0.5)
	env.ambient_light_energy = 0.55
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	_environment.environment = env
	_sun.light_energy = 1.1
	_sun.rotation_degrees = Vector3(-float(data.get("sun_angle", 50.0)), -35.0, 0.0)

	track = Track.new()
	track.name = "Track"
	add_child(track)
	track.build(data)


func _spawn_karts() -> void:
	var racer_ids := ModLoader.get_racer_ids()
	if racer_ids.is_empty():
		push_error("No racers loaded!")
		return
	var player_id := GameState.racer_id if ModLoader.racers.has(GameState.racer_id) else str(racer_ids[0])
	var free := track.free_roam or track.length <= 0.0
	var ai_count := 0 if free else clampi(GameState.ai_count, 0, 11)

	var opponents: Array = []
	for id in racer_ids:
		if id != player_id:
			opponents.append(id)
	if opponents.is_empty():
		opponents.append(player_id)
	opponents.shuffle()

	var total := ai_count + 1
	for i in total:
		var is_player := i == total - 1  # player starts at the back
		var id: String = player_id if is_player else str(opponents[i % opponents.size()])
		var k := Kart.new()
		k.name = "Player" if is_player else "AI_%d" % i
		add_child(k)
		k.setup(ModLoader.racers[id], is_player)
		k.global_transform = _spawn_transform(i)
		if is_player:
			k.controller = PlayerController.new()
			player = k
		else:
			var skill := remap(float(i), 0.0, maxf(ai_count - 1, 1), 0.97, 0.86)
			k.controller = AIController.new(track, skill, i * 7919 + 1)
			k.speed_multiplier = skill
		_reset_progress(k)
		karts.append(k)


func _spawn_transform(index: int) -> Transform3D:
	if track.length <= 0.0:
		return Transform3D(Basis.IDENTITY, Vector3(index * 4.0, 1.0, 0.0))
	return track.grid_transform(index)


func _reset_progress(k: Kart) -> void:
	k.finished = false
	k.finish_time = 0.0
	if track.length <= 0.0:
		k.distance = 0.0
		k.last_offset = 0.0
		return
	var off := track.get_offset(k.global_position)
	k.last_offset = off
	k.distance = off - track.length if off > track.length * 0.5 else off


func _start_free_roam() -> void:
	state = "free"
	countdown = 0.0
	for k in karts:
		k.controls_enabled = true


func _track_progress(k: Kart) -> void:
	if track.length <= 0.0:
		return
	var off := track.get_offset(k.global_position)
	var d := off - k.last_offset
	if d < -track.length * 0.5:
		d += track.length
	elif d > track.length * 0.5:
		d -= track.length
	if absf(d) < 40.0:
		k.distance += d
	k.last_offset = off

	if state in ["racing", "finished"] and not k.finished and k.distance >= laps * track.length:
		k.finished = true
		k.finish_time = race_time
		finish_order.append(k)
		if k == player:
			_on_player_finished()


func _check_respawn(k: Kart) -> void:
	var fell := k.global_position.y < track.min_y - 20.0
	if k.respawn_requested or fell:
		k.respawn_requested = false
		respawn_kart(k)


func _update_places() -> void:
	var order := karts.duplicate()
	order.sort_custom(func(a: Kart, b: Kart) -> bool:
		if a.finished != b.finished:
			return a.finished
		if a.finished:
			return a.finish_time < b.finish_time
		return a.distance > b.distance)
	for i in order.size():
		(order[i] as Kart).place = i + 1


func _on_player_finished() -> void:
	state = "finished"
	# Let the computer drive the player's kart for a victory lap.
	player.controller = AIController.new(track, 0.8, 4242)
	hud.flash_message("FINISH!", 2.0)
	hud.show_results()


func _color(data: Dictionary, key: String, fallback: Color) -> Color:
	var v := str(data.get(key, ""))
	return Color.html(v) if Color.html_is_valid(v) else fallback
