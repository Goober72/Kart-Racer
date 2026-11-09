extends Node
## Finds and loads all game content: racers, tracks and items.
##
## The base game is itself loaded like a mod (from res://content/base), so
## anything the base game can do, a mod can do too. Mods load after the base
## game; if a mod uses the same id as existing content, it replaces it.
##
## Where mods are looked for:
##   - Running in the Godot editor:  <project folder>/mods/
##   - Exported game:                <folder with the .exe>/mods/
##   - Browser version:              mods bundled into the game (read-only)
##   - Always:                       user://mods/  (the per-user data folder;
##                                   in a browser it's saved in browser storage)
## Each mod is a folder containing a mod.json file. See MODDING.md.

signal reloaded

const BASE_DIR := "res://content/base"

const RACER_DEFAULTS := {
	"name": "Unnamed Racer",
	"description": "",
	"body_color": "#d83a3a",
	"accent_color": "#ffffff",
	"driver_color": "#f2c38f",
	"helmet_color": "#3a6fd8",
	"stats": {
		"max_speed": 30.0,
		"acceleration": 16.0,
		"handling": 2.2,
		"drift": 1.0,
	},
	"ability": {"type": "boost"},
	"model": "",
	"model_scale": 1.0,
	"model_rotation_y": 0.0,
	## {"file": "models/me.glb", "scale": 1, "rotation_y": 0, "offset": [0,0,0], "animations": {...}}
	"character_model": {},
	## {"file": "models/kart.glb", "scale": 1, "rotation_y": 0, "seat": [0,0.55,0], "wheels": [...], "front_wheels": [...]}
	"kart_model": {},
	## 2D racer from images: {"folder": "sprites/me", "covers": "kart", ...} (see SpriteRacer)
	"sprite": {},
}

const ITEM_DEFAULTS := {
	"name": "Item",
	"description": "",
	"label": "?",
	"color": "#ffcc33",
	"uses": 1,
	"weights": [1, 1, 1],
	"effects": [],
}

const TRACK_DEFAULTS := {
	"name": "Unnamed Track",
	"description": "",
	"author": "",
	"points": [],
	"width": 14.0,
	"wall_height": 1.4,
	"laps": 3,
	"boost_pads": [],
	"road_color": "#3b3b42",
	"curb_color_a": "#e84a3c",
	"curb_color_b": "#f4f4f4",
	"wall_color": "#9c7a55",
	"ground_color": "#4f8f3f",
	"sky_top_color": "#2f6fd0",
	"sky_horizon_color": "#c8e6ff",
	"tree_count": 90,
	"tree_color": "#2e6b2a",
	"free_roam": false,
	"dev_only": false,
	"model": "",
	"model_collision": false,
	"model_scale": 1.0,
	## Generated parts of the track. Turn these off when a model provides them.
	"road": true,
	"walls": true,
	"ground": true,
	"start_gantry": true,
	## Item box rows: positions around the lap (0..1). Each row spans the road.
	"item_rows": [0.22, 0.62],
	"items_per_row": 4,
	"sun_angle": 50.0,
}

var racers: Dictionary = {}
var tracks: Dictionary = {}
var items: Dictionary = {}
## One entry per loaded mod: {id, name, version, author, description, dir, is_base, racers, tracks}
var loaded_mods: Array[Dictionary] = []
## Messages produced while loading: {level: "info"|"warn"|"error", text: String}
var messages: Array[Dictionary] = []


func _ready() -> void:
	reload()


func reload() -> void:
	racers.clear()
	tracks.clear()
	items.clear()
	Effects.clear_cache()
	ModelLoader.clear_cache()
	SpriteRacer.clear_cache()
	loaded_mods.clear()
	messages.clear()

	var base_manifest = _read_json(BASE_DIR.path_join("mod.json"))
	if not base_manifest is Dictionary:
		base_manifest = {"id": "base", "name": "Base Game"}
	_load_mod(BASE_DIR, base_manifest, true)

	var manifests: Array[Dictionary] = []
	var seen_ids := {}
	for root in get_mod_roots():
		if not DirAccess.dir_exists_absolute(root):
			continue
		for sub in DirAccess.get_directories_at(root):
			var dir := root.path_join(sub)
			var manifest_path := dir.path_join("mod.json")
			if not FileAccess.file_exists(manifest_path):
				_warn("Folder '%s' has no mod.json, skipped." % dir)
				continue
			var manifest = _read_json(manifest_path)
			if not manifest is Dictionary:
				continue
			if not manifest.has("id"):
				manifest["id"] = sub
			if seen_ids.has(manifest["id"]):
				_warn("Mod id '%s' found twice (%s). Only the first copy is loaded." % [manifest["id"], dir])
				continue
			seen_ids[manifest["id"]] = true
			if not manifest.get("enabled", true):
				_info("Mod '%s' is disabled in its mod.json." % manifest["id"])
				continue
			manifest["_dir"] = dir
			manifests.append(manifest)

	# Lower priority loads first, so higher priority mods win when ids clash.
	manifests.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var pa := float(a.get("priority", 0))
		var pb := float(b.get("priority", 0))
		if pa != pb:
			return pa < pb
		return str(a["id"]) < str(b["id"]))

	for manifest in manifests:
		_load_mod(manifest["_dir"], manifest, false)

	_info("Loaded %d racer(s), %d track(s) and %d item(s) from %d source(s)." % [racers.size(), tracks.size(), items.size(), loaded_mods.size()])
	reloaded.emit()


## Folders that are scanned for mods.
func get_mod_roots() -> PackedStringArray:
	var roots := PackedStringArray()
	if OS.has_feature("web"):
		roots.append("res://mods")
	elif OS.has_feature("editor"):
		roots.append(ProjectSettings.globalize_path("res://mods"))
	else:
		roots.append(OS.get_executable_path().get_base_dir().path_join("mods"))
	roots.append(user_mods_dir())
	return roots


## The per-user mods folder (also where the character creator saves).
func user_mods_dir() -> String:
	if OS.has_feature("web"):
		return "user://mods"
	return ProjectSettings.globalize_path("user://mods")


## The mods folder that tools (like the track recorder) save into.
func get_writable_mod_root() -> String:
	if OS.has_feature("web"):
		return user_mods_dir()
	return get_mod_roots()[0]


func get_racer_ids() -> Array:
	var ids := racers.keys()
	ids.sort_custom(func(a, b): return str(racers[a]["name"]).naturalnocasecmp_to(str(racers[b]["name"])) < 0)
	return ids


func get_track_ids(include_dev_only: bool = false) -> Array:
	var ids := []
	for id in tracks.keys():
		if tracks[id].get("dev_only", false) and not include_dev_only:
			continue
		ids.append(id)
	ids.sort_custom(func(a, b): return str(tracks[a]["name"]).naturalnocasecmp_to(str(tracks[b]["name"])) < 0)
	return ids


func error_count() -> int:
	var n := 0
	for m in messages:
		if m["level"] == "error":
			n += 1
	return n


# --------------------------------------------------------------------------

func _load_mod(dir: String, manifest: Dictionary, is_base: bool) -> void:
	var mod := {
		"id": str(manifest.get("id", dir.get_file())),
		"name": str(manifest.get("name", dir.get_file())),
		"version": str(manifest.get("version", "1.0")),
		"author": str(manifest.get("author", "")),
		"description": str(manifest.get("description", "")),
		"dir": dir,
		"is_base": is_base,
		"racers": 0,
		"tracks": 0,
		"items": 0,
	}

	for file in _json_files(dir.path_join("racers")):
		var data = _read_json(file)
		if not data is Dictionary:
			continue
		var problem := _check_racer(data)
		if problem != "":
			_error("%s: %s" % [_short(file), problem])
			continue
		var racer := _merge(RACER_DEFAULTS, data)
		racer["_mod"] = mod["id"]
		racer["_dir"] = dir
		if racers.has(racer["id"]):
			_info("Mod '%s' replaces racer '%s'." % [mod["id"], racer["id"]])
		racers[racer["id"]] = racer
		mod["racers"] += 1

	for file in _json_files(dir.path_join("tracks")):
		var data = _read_json(file)
		if not data is Dictionary:
			continue
		var problem := _check_track(data)
		if problem != "":
			_error("%s: %s" % [_short(file), problem])
			continue
		var track := _merge(TRACK_DEFAULTS, data)
		track["_mod"] = mod["id"]
		track["_dir"] = dir
		if tracks.has(track["id"]):
			_info("Mod '%s' replaces track '%s'." % [mod["id"], track["id"]])
		tracks[track["id"]] = track
		mod["tracks"] += 1

	for file in _json_files(dir.path_join("items")):
		var data = _read_json(file)
		if not data is Dictionary:
			continue
		var problem := _check_item(data)
		if problem != "":
			_error("%s: %s" % [_short(file), problem])
			continue
		var item := _merge(ITEM_DEFAULTS, data)
		item["_mod"] = mod["id"]
		item["_dir"] = dir
		if items.has(item["id"]):
			_info("Mod '%s' replaces item '%s'." % [mod["id"], item["id"]])
		items[item["id"]] = item
		mod["items"] += 1

	loaded_mods.append(mod)
	if not is_base:
		_info("Loaded mod '%s' v%s (%d racers, %d tracks, %d items)." % [mod["name"], mod["version"], mod["racers"], mod["tracks"], mod["items"]])


func _check_racer(data: Dictionary) -> String:
	if not data.has("id") or str(data["id"]).strip_edges() == "":
		return "racer is missing an \"id\"."
	if data.has("stats") and not data["stats"] is Dictionary:
		return "\"stats\" must be an object like {\"max_speed\": 30}."
	if data.has("ability") and not data["ability"] is Dictionary:
		return "\"ability\" must be an object like {\"type\": \"boost\"}."
	for key in ["body_color", "accent_color", "driver_color", "helmet_color"]:
		if data.has(key) and not Color.html_is_valid(str(data[key])):
			return "\"%s\" is not a valid color (use something like \"#ff8800\")." % key
	return ""


func _check_item(data: Dictionary) -> String:
	if not data.has("id") or str(data["id"]).strip_edges() == "":
		return "item is missing an \"id\"."
	if not data.get("effects", []) is Array or data.get("effects", []).is_empty():
		return "item needs an \"effects\" list, like [{\"type\": \"boost\"}]."
	return ""


func _check_track(data: Dictionary) -> String:
	if not data.has("id") or str(data["id"]).strip_edges() == "":
		return "track is missing an \"id\"."
	var free_roam: bool = data.get("free_roam", false)
	var points = data.get("points", [])
	if not points is Array:
		return "\"points\" must be a list like [[0,0,0], [50,0,0], ...]."
	var has_model := str(data.get("model", "")) != ""
	if not free_roam and not has_model and points.size() < 4:
		return "a track needs at least 4 points (it has %d), or a model with Path markers." % points.size()
	for i in points.size():
		var p = points[i]
		if not p is Array or p.size() < 3:
			return "point #%d must look like [x, y, z]." % (i + 1)
	return ""


func _merge(defaults: Dictionary, data: Dictionary) -> Dictionary:
	var result := defaults.duplicate(true)
	for key in data.keys():
		if result.has(key) and result[key] is Dictionary and data[key] is Dictionary:
			result[key] = _merge(result[key], data[key])
		else:
			result[key] = data[key]
	return result


func _json_files(dir: String) -> PackedStringArray:
	var out := PackedStringArray()
	if not DirAccess.dir_exists_absolute(dir):
		return out
	var files := Array(DirAccess.get_files_at(dir))
	files.sort()
	for f in files:
		if str(f).get_extension().to_lower() == "json":
			out.append(dir.path_join(f))
	return out


func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		_error("%s: file not found." % _short(path))
		return null
	var text := FileAccess.get_file_as_string(path)
	var json := JSON.new()
	var err := json.parse(text)
	if err != OK:
		_error("%s line %d: %s" % [_short(path), json.get_error_line(), json.get_error_message()])
		return null
	return json.data


func _short(path: String) -> String:
	var parts := path.split("/")
	if parts.size() <= 3:
		return path
	return "/".join(parts.slice(parts.size() - 3))


func _info(text: String) -> void:
	messages.append({"level": "info", "text": text})
	print("[mods] ", text)


func _warn(text: String) -> void:
	messages.append({"level": "warn", "text": text})
	push_warning("[mods] " + text)


func _error(text: String) -> void:
	messages.append({"level": "error", "text": text})
	push_warning("[mods] ERROR " + text)
