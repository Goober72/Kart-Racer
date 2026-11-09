extends Node
## Draws the example 2D racer "Pip" (mods/example_mod/sprites/pip/) as PNGs.
## The file names show the naming the game understands:
##   <animation>_<view>_<frame>.png   e.g. drive_back_2.png, hit_1.png
##
## Run:  godot --headless --path . res://tools/make_example_sprites.tscn

const OUT := "res://mods/example_mod/sprites/pip/"
const W := 48
const H := 48

const OUTLINE := Color(0.08, 0.08, 0.12)
const BLOB := Color(0.35, 0.65, 1.0)
const BLOB_DARK := Color(0.2, 0.45, 0.85)
const CART := Color(0.9, 0.25, 0.25)
const CART_DARK := Color(0.65, 0.12, 0.15)
const TIRE := Color(0.15, 0.15, 0.18)
const SCARF := Color(1.0, 0.85, 0.3)
const FLAME := Color(1.0, 0.6, 0.15)


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	for view in ["back", "front", "side"]:
		for f in 2:
			_save(_frame(view, f, 0, false, false, false), "idle_%s_%d.png" % [view, f + 1], f == 1)
			_save(_frame(view, f, 1, false, false, false), "drive_%s_%d.png" % [view, f + 1])
			_save(_frame(view, f, 1, true, false, false), "boost_%s_%d.png" % [view, f + 1])
	for f in 2:
		_save(_frame("back", f, 1, false, false, false, -2), "left_back_%d.png" % (f + 1))
		_save(_frame("back", f, 1, false, false, false, 2), "right_back_%d.png" % (f + 1))
		_save(_frame("front", f, 0, false, true, false), "hit_%d.png" % (f + 1))
		_save(_frame("front", f, 0, false, false, true), "win_front_%d.png" % (f + 1))
	print("Pip sprites written to ", OUT)
	get_tree().quit()


func _save(img: Image, file: String, bob := false) -> void:
	img.save_png(ProjectSettings.globalize_path(OUT + file))
	# Keep the raw PNG when exporting (the game loads it itself).
	var imp := FileAccess.open(ProjectSettings.globalize_path(OUT + file + ".import"), FileAccess.WRITE)
	imp.store_string('[remap]\n\nimporter="keep"\n')
	imp.close()


## One frame. `step` animates wheels/bobbing, `lean` shifts the blob for steering.
func _frame(view: String, step: int, moving: int, boost: bool, hit: bool, win: bool, lean: int = 0) -> Image:
	var img := Image.create(W, H, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var bob := (step % 2) if moving == 0 else 0
	var shake := (step % 2) * moving
	var cx := 24 + lean
	# Blob (the driver)
	var head_y := 20 - bob + shake
	_circle(img, cx, head_y, 11, OUTLINE)
	_circle(img, cx, head_y, 10, BLOB)
	_circle(img, cx - 3, head_y + 4, 5, BLOB_DARK)
	_circle(img, cx - 4, head_y - 4, 2, Color(1, 1, 1, 0.8))
	if view == "front":
		if hit:
			_x_eye(img, cx - 4, head_y - 1)
			_x_eye(img, cx + 4, head_y - 1)
			for i in 3:
				var a := step * 0.8 + i * TAU / 3.0
				_star(img, cx + int(cos(a) * 13), head_y - 12 + int(sin(a) * 3))
		else:
			_rect(img, cx - 5, head_y - 3, 2, 4, OUTLINE)
			_rect(img, cx + 3, head_y - 3, 2, 4, OUTLINE)
			_rect(img, cx - 2, head_y + 4, 4, 1, OUTLINE)
	elif view == "side":
		_rect(img, cx + 5, head_y - 3, 2, 4, OUTLINE)
	if win:
		var up := 4 if step == 0 else 0
		_rect(img, cx - 15, head_y - 6 - up, 4, 9, BLOB)
		_rect(img, cx + 11, head_y - 6 - up, 4, 9, BLOB)
	# Scarf
	_rect(img, cx - 9, head_y + 8, 18, 3, SCARF)
	if view != "front":
		_rect(img, cx - (12 if view == "side" else 3) + shake, head_y + 9, 4, 5, SCARF)

	# Cart
	if view == "side":
		_rect(img, 6, 30, 36, 9, OUTLINE)
		_rect(img, 7, 31, 34, 7, CART)
		_rect(img, 34, 27, 8, 4, CART_DARK)
		_rect(img, 7, 36, 34, 2, CART_DARK)
		for x in [13, 35]:
			_circle(img, x, 41, 5, OUTLINE)
			_circle(img, x, 41, 4, TIRE)
			var spoke := 2 if (step + moving) % 2 == 0 else -2
			_rect(img, x - 1 + spoke * moving, 40, 2, 2, Color(0.7, 0.7, 0.75))
		if boost:
			_rect(img, 0, 32 + step, 6, 4, FLAME)
	else:
		_rect(img, 8, 30, 32, 10, OUTLINE)
		_rect(img, 9, 31, 30, 8, CART)
		_rect(img, 9, 36, 30, 3, CART_DARK)
		if view == "back":
			_rect(img, 18, 33, 12, 3, Color(0.2, 0.2, 0.25))  # exhaust plate
		else:
			_rect(img, 12, 32, 5, 3, Color(1, 1, 0.7))  # headlights
			_rect(img, 31, 32, 5, 3, Color(1, 1, 0.7))
		for x in [6, 36]:
			_rect(img, x, 36 + (shake if x == 6 else 0), 7, 9, OUTLINE)
			_rect(img, x + 1, 37 + (shake if x == 6 else 0), 5, 7, TIRE)
		if boost and view == "back":
			_circle(img, 24, 43 + step, 4, FLAME)
			_circle(img, 24, 43 + step, 2, Color(1, 0.95, 0.6))
	return img


func _rect(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	img.fill_rect(Rect2i(x, y, w, h).intersection(Rect2i(0, 0, W, H)), c)


func _circle(img: Image, cx: int, cy: int, r: int, c: Color) -> void:
	for y in range(cy - r, cy + r + 1):
		for x in range(cx - r, cx + r + 1):
			if x >= 0 and y >= 0 and x < W and y < H and (x - cx) * (x - cx) + (y - cy) * (y - cy) <= r * r:
				img.set_pixel(x, y, c)


func _x_eye(img: Image, x: int, y: int) -> void:
	for i in range(-2, 3):
		img.set_pixel(x + i, y + i, OUTLINE)
		img.set_pixel(x + i, y - i, OUTLINE)


func _star(img: Image, x: int, y: int) -> void:
	for p in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var q: Vector2i = Vector2i(x, y) + p
		if q.x >= 0 and q.y >= 0 and q.x < W and q.y < H:
			img.set_pixelv(q, Color(1, 0.9, 0.2))
