class_name SpriteRacer
extends Node3D
## A 2D racer drawn with PNG images (like retro kart games).
##
## Racer JSON:
##   "sprite": {
##     "folder": "sprites/pip",      <- images live here (inside the mod)
##     "covers": "kart",             <- "kart" = the picture is kart + driver,
##                                      "driver" = just the driver, sitting in a 3D kart
##     "height": 2.2,                <- meters tall in game
##     "fps": 8,                     <- animation speed
##     "pixel_art": true,            <- keep pixels sharp
##     "frames": { "idle": { "back": ["idle_back_1.png", "idle_back_2.png"] } }   <- optional
##   }
## Without "frames", images in the folder are sorted by their file names:
##   <animation>[_<view>][_<number>].png
## animation: idle, drive, left, right, boost, skill, hit, win, lose (only idle is needed)
## view (optional): back, front, side  (side is mirrored for the other side)
## e.g.  idle.png, drive_1.png, drive_2.png, drive_back_1.png, hit_side_2.png

const SLOTS := ["idle", "drive", "steer_left", "steer_right", "boost", "skill", "hit", "win", "lose"]
const VIEWS := ["back", "front", "side"]
const IMAGE_EXTS := ["png", "webp", "jpg", "jpeg"]

static var _texture_cache: Dictionary = {}

## frames[slot][view] = Array[Texture2D]; view is "back", "front", "side" or "any"
var frames: Dictionary = {}
var fps: float = 8.0
var _sprite: Sprite3D
var _slot: String = "idle"
var _time: float = 0.0
var _height: float = 2.2


static func clear_cache() -> void:
	_texture_cache.clear()


## Turns file names into {slot: {view: [file, ...]}}. Unrecognised files go in "unsorted".
static func sort_files(files: PackedStringArray) -> Dictionary:
	var out := {}
	var numbered := {}
	for f in files:
		if not IMAGE_EXTS.has(f.get_extension().to_lower()):
			continue
		var info := parse_name(f)
		var slot: String = info["slot"]
		var view: String = info["view"]
		if not numbered.has(slot):
			numbered[slot] = {}
		if not numbered[slot].has(view):
			numbered[slot][view] = []
		numbered[slot][view].append([info["number"], f])
	for slot in numbered:
		out[slot] = {}
		for view in numbered[slot]:
			var list: Array = numbered[slot][view]
			list.sort_custom(func(a, b): return a[0] < b[0] if a[0] != b[0] else str(a[1]) < str(b[1]))
			out[slot][view] = list.map(func(x): return x[1])
	return out


## {slot, view, number} from a file name like "drive_back_2.png".
static func parse_name(file_name: String) -> Dictionary:
	var base := file_name.get_basename().to_lower()
	var tokens := base.replace("-", "_").replace(" ", "_").replace(".", "_").split("_", false)
	var slot := "unsorted"
	var view := "any"
	var number := 0
	for t in tokens:
		if VIEWS.has(t):
			view = t
	for t in tokens:
		if t.is_valid_int():
			number = int(t)
		elif t.length() > 1 and t.right(1).is_valid_int() and t.left(-1).length() > 0:
			# e.g. "drive2"
			var digits := ""
			var word := t
			while word.length() > 0 and word.right(1).is_valid_int():
				digits = word.right(1) + digits
				word = word.left(-1)
			number = int(digits)
	var text := " ".join(tokens)
	for s in SLOTS:
		var words: Array = ModelLoader.ANIM_SLOTS.get(s, [s])
		if s == "steer_left":
			words = ["left", "steerleft"]
		elif s == "steer_right":
			words = ["right", "steerright"]
		for w in words:
			if text.contains(w):
				slot = s
				break
		if slot != "unsorted":
			break
	return {"slot": slot, "view": view, "number": number}


static func load_texture(path: String, pixel_art: bool = true) -> Texture2D:
	if _texture_cache.has(path):
		return _texture_cache[path]
	if not FileAccess.file_exists(path):
		push_warning("Sprite image not found: " + path)
		return null
	var bytes := FileAccess.get_file_as_bytes(path)
	var img := Image.new()
	var err := ERR_FILE_UNRECOGNIZED
	match path.get_extension().to_lower():
		"png": err = img.load_png_from_buffer(bytes)
		"webp": err = img.load_webp_from_buffer(bytes)
		"jpg", "jpeg": err = img.load_jpg_from_buffer(bytes)
	if err != OK:
		push_warning("Could not read image (%s): %s" % [error_string(err), path])
		return null
	var tex := ImageTexture.create_from_image(img)
	_texture_cache[path] = tex
	return tex


func setup(cfg: Dictionary, mod_dir: String) -> void:
	var folder := mod_dir.path_join(str(cfg.get("folder", "")))
	fps = maxf(float(cfg.get("fps", 8.0)), 0.5)
	_height = clampf(float(cfg.get("height", 2.2)), 0.2, 20.0)
	var pixel_art: bool = cfg.get("pixel_art", true)
	var listing: Dictionary = cfg.get("frames", {})
	if listing.is_empty() and DirAccess.dir_exists_absolute(folder):
		listing = sort_files(DirAccess.get_files_at(folder))
		if listing.has("unsorted") and not listing.has("idle"):
			listing["idle"] = listing["unsorted"]
	for slot in listing.keys():
		if not listing[slot] is Dictionary:
			continue
		frames[slot] = {}
		for view in listing[slot].keys():
			var texs: Array[Texture2D] = []
			for f in listing[slot][view]:
				var t := load_texture(folder.path_join(str(f)), pixel_art)
				if t != null:
					texs.append(t)
			if not texs.is_empty():
				frames[slot][view] = texs

	_sprite = Sprite3D.new()
	_sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	_sprite.shaded = false
	_sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST if pixel_art else BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(_sprite)
	_apply(_pick("idle", "back"), false)


func has_frames() -> bool:
	return not frames.is_empty()


func set_slot(slot: String) -> void:
	if slot != _slot:
		_slot = slot
		_time = 0.0


func _process(delta: float) -> void:
	if _sprite == null:
		return
	_time += delta
	var view := _camera_view()
	var flip := false
	var list: Array = []
	var slot := _slot if frames.has(_slot) else ("drive" if frames.has("drive") and _slot != "idle" else "idle")
	if not frames.has(slot):
		slot = frames.keys()[0] if not frames.is_empty() else ""
	if slot == "":
		return
	var want: String = view[0]
	flip = view[1]
	list = _pick(slot, want)
	_apply(list, flip)


func _apply(list: Array, flip: bool) -> void:
	if list.is_empty():
		return
	var tex: Texture2D = list[int(_time * fps) % list.size()]
	if _sprite.texture != tex:
		_sprite.texture = tex
		_sprite.pixel_size = _height / maxf(tex.get_height(), 1.0)
		_sprite.position.y = _height * 0.5
	_sprite.flip_h = flip


## Frames for a slot from a view, falling back to other views.
func _pick(slot: String, view: String) -> Array:
	if not frames.has(slot):
		return []
	var views: Dictionary = frames[slot]
	for v in [view, "any", "back", "side", "front"]:
		if views.has(v):
			return views[v]
	return views.values()[0]


## Which side of the racer the camera sees: [view, mirror?]
func _camera_view() -> Array:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return ["back", false]
	var fwd := -global_transform.basis.z
	fwd.y = 0.0
	var to_cam := cam.global_position - global_position
	to_cam.y = 0.0
	if fwd.length() < 0.01 or to_cam.length() < 0.01:
		return ["back", false]
	fwd = fwd.normalized()
	to_cam = to_cam.normalized()
	var d := fwd.dot(to_cam)
	if d < -0.5:
		return ["back", false]
	if d > 0.5:
		return ["front", false]
	# Side view. Images are drawn facing right; mirror when the kart faces left on screen.
	var right := global_transform.basis.x
	return ["side", right.dot(to_cam) < 0.0]
