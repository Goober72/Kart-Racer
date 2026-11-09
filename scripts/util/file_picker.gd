class_name FilePicker
extends Node
## Lets the player choose files from their device and gives back their bytes.
## Browser (incl. phones): opens the browser's file chooser.
## Desktop: opens a normal file dialog.
##
##   var picker := FilePicker.new()
##   add_child(picker)
##   picker.picked.connect(func(file_name, bytes): ...)       # once per file
##   picker.finished.connect(func(count): ...)                # after the last file
##   picker.status.connect(func(text): ...)                   # progress / errors
##   picker.open(["*.glb"])                 # one file
##   picker.open(["*.png"], true)           # several files
##   picker.open(["*.png"], true, true)     # a whole folder (where supported)

signal picked(file_name: String, bytes: PackedByteArray)
signal finished(count: int)
signal status(text: String)
signal cancelled

var _js_file_cb: JavaScriptObject
var _js_status_cb: JavaScriptObject
var _js_done_cb: JavaScriptObject
var _dialog: FileDialog


func open(filters: PackedStringArray, multiple: bool = false, folder: bool = false) -> void:
	if OS.has_feature("web"):
		_open_web(multiple, folder)
	else:
		_open_desktop(filters, multiple, folder)


func _open_web(multiple: bool, folder: bool) -> void:
	_js_file_cb = JavaScriptBridge.create_callback(_on_web_file)
	_js_status_cb = JavaScriptBridge.create_callback(_on_web_status)
	_js_done_cb = JavaScriptBridge.create_callback(_on_web_done)
	var window := JavaScriptBridge.get_interface("window")
	window.godotFilePicked = _js_file_cb
	window.godotFileStatus = _js_status_cb
	window.godotFilesDone = _js_done_cb
	# Notes for phones:
	# - The <input> is attached to the page; iOS Safari can drop detached inputs
	#   while its picker is open, so the "change" event never arrives.
	# - No "accept" filter: phones don't know the .glb type and may grey files out.
	JavaScriptBridge.eval("""
		(function () {
			var old = document.getElementById('godot-file-input');
			if (old) { old.remove(); }
			var input = document.createElement('input');
			input.id = 'godot-file-input';
			input.type = 'file';
			input.multiple = %s;
			if (%s) { input.webkitdirectory = true; }
			input.style.position = 'fixed';
			input.style.left = '-1000px';
			input.style.opacity = '0';
			document.body.appendChild(input);
			input.addEventListener('change', function () {
				var files = Array.prototype.slice.call(input.files || []);
				if (files.length === 0) { window.godotFileStatus('cancelled'); return; }
				window.godotFileStatus('Reading ' + files.length + ' file(s)...');
				var i = 0;
				function next() {
					if (i >= files.length) { window.godotFilesDone(files.length); input.remove(); return; }
					var file = files[i++];
					var reader = new FileReader();
					reader.onload = function () {
						var data = String(reader.result);
						window.godotFilePicked(file.name, data.substring(data.indexOf(',') + 1));
						setTimeout(next, 0);
					};
					reader.onerror = function () {
						window.godotFileStatus('Could not read ' + file.name + ': ' + reader.error);
						setTimeout(next, 0);
					};
					reader.readAsDataURL(file);
				}
				next();
			});
			input.click();
		})();
	""" % ["true" if multiple or folder else "false", "true" if folder else "false"], true)


func _on_web_file(args: Array) -> void:
	var file_name := str(args[0])
	var bytes := Marshalls.base64_to_raw(str(args[1]))
	if bytes.is_empty():
		status.emit("%s came through empty. Try again, or save the file to your phone first." % file_name)
		return
	picked.emit(file_name, bytes)


func _on_web_status(args: Array) -> void:
	var text := str(args[0])
	if text == "cancelled":
		cancelled.emit()
	else:
		status.emit(text)


func _on_web_done(args: Array) -> void:
	finished.emit(int(args[0]))


func _open_desktop(filters: PackedStringArray, multiple: bool, folder: bool) -> void:
	if _dialog != null:
		_dialog.queue_free()
	_dialog = FileDialog.new()
	_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_dialog.use_native_dialog = true
	_dialog.size = Vector2i(900, 600)
	if folder:
		_dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
		_dialog.dir_selected.connect(_on_desktop_dir.bind(filters))
	elif multiple:
		_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILES
		_dialog.files_selected.connect(_on_desktop_files)
	else:
		_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
		_dialog.file_selected.connect(func(p: String): _on_desktop_files(PackedStringArray([p])))
	_dialog.canceled.connect(func(): cancelled.emit())
	_dialog.filters = filters
	add_child(_dialog)
	_dialog.popup_centered()


func _on_desktop_files(paths: PackedStringArray) -> void:
	for p in paths:
		picked.emit(p.get_file(), FileAccess.get_file_as_bytes(p))
	finished.emit(paths.size())


func _on_desktop_dir(dir: String, filters: PackedStringArray) -> void:
	var exts := Array(filters).map(func(f): return str(f).get_extension().to_lower())
	var paths := PackedStringArray()
	for f in DirAccess.get_files_at(dir):
		if exts.is_empty() or exts.has(f.get_extension().to_lower()):
			paths.append(dir.path_join(f))
	_on_desktop_files(paths)
