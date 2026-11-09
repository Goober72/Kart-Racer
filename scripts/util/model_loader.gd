class_name ModelLoader
extends RefCounted
## Loads .glb / .gltf 3D models at runtime (from mod folders or browser storage)
## and helps find their animations and wheels.

## Animation slots the game uses, and words that auto-match animation names.
const ANIM_SLOTS := {
	"idle": ["idle", "stand", "wait"],
	"drive": ["drive", "driving", "ride", "run", "move"],
	"steer_left": ["left"],
	"steer_right": ["right"],
	"boost": ["boost", "turbo", "fast", "dash"],
	"skill": ["skill", "special", "cast", "attack", "ability", "throw"],
	"hit": ["hit", "hurt", "damage", "spin", "fall"],
	"win": ["win", "victory", "cheer", "celebrate", "dance", "happy"],
	"lose": ["lose", "sad", "defeat", "cry"],
}
const LOOPING := ["idle", "drive", "steer_left", "steer_right", "boost", "win", "lose"]

static var _states: Dictionary = {}


static func clear_cache() -> void:
	_states.clear()


## Builds a new scene from a model file. Returns null (with a warning) on failure.
static func load_scene(path: String) -> Node3D:
	var state: GLTFState = _states.get(path)
	var doc := GLTFDocument.new()
	if state == null:
		if not FileAccess.file_exists(path):
			push_warning("Model not found: " + path)
			return null
		state = GLTFState.new()
		var err := doc.append_from_file(path, state)
		if err != OK:
			push_warning("Could not load model (%s): %s" % [error_string(err), path])
			return null
		_states[path] = state
	return doc.generate_scene(state) as Node3D


## Checks that bytes are a loadable model before saving them. Returns "" if OK.
static func validate_bytes(bytes: PackedByteArray) -> String:
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	var err := doc.append_from_buffer(bytes, "", state)
	if err != OK:
		return "That file isn't a model the game can read (%s). Export a .glb (glTF Binary) from Blender." % error_string(err)
	var scene := doc.generate_scene(state)
	if scene == null:
		return "The model file is empty."
	scene.free()
	return ""


static func find_animation_player(root: Node) -> AnimationPlayer:
	if root is AnimationPlayer:
		return root
	var found := root.find_children("*", "AnimationPlayer", true, false)
	return found[0] if not found.is_empty() else null


static func list_animations(root: Node) -> PackedStringArray:
	var ap := find_animation_player(root)
	if ap == null:
		return PackedStringArray()
	var names := ap.get_animation_list()
	names.sort()
	return names


## Maps game slots ("idle", "drive", ...) to animation names in the model.
## Explicit names in `overrides` win; the rest are guessed from the names.
static func map_animations(available: PackedStringArray, overrides: Dictionary) -> Dictionary:
	var out := {}
	for slot in ANIM_SLOTS.keys():
		var wanted := str(overrides.get(slot, ""))
		if wanted != "" and available.has(wanted):
			out[slot] = wanted
			continue
		for anim in available:
			var lower := anim.to_lower()
			for word in ANIM_SLOTS[slot]:
				if lower.contains(word):
					out[slot] = anim
					break
			if out.has(slot):
				break
	if not out.has("drive") and out.has("idle"):
		out["drive"] = out["idle"]
	if not out.has("idle") and out.has("drive"):
		out["idle"] = out["drive"]
	if not out.has("idle") and not available.is_empty():
		out["idle"] = available[0]
		out["drive"] = available[0]
	return out


## Nodes whose names contain "wheel" (unless listed explicitly).
static func find_wheels(root: Node, names: Array) -> Array[Node3D]:
	var out: Array[Node3D] = []
	if not names.is_empty():
		for n in names:
			var node := root.find_child(str(n), true, false)
			if node is Node3D:
				out.append(node)
		return out
	for node in root.find_children("*", "Node3D", true, false):
		if not str(node.name).to_lower().contains("wheel"):
			continue
		# Skip parts inside a wheel we already have (e.g. Wheel_FL/Wheel_FLMesh).
		var inside := false
		for w in out:
			if w.is_ancestor_of(node):
				inside = true
				break
		if not inside:
			out.append(node)
	return out


static func is_front_wheel(node: Node3D) -> bool:
	var n := str(node.name).to_lower()
	return n.contains("front") or n.contains("_f") or n.ends_with("fl") or n.ends_with("fr") or n.contains(".f")


static func vec3(v: Variant, fallback: Vector3) -> Vector3:
	if v is Array and v.size() >= 3:
		return Vector3(float(v[0]), float(v[1]), float(v[2]))
	return fallback
