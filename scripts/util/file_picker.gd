class_name FilePicker
extends Node
## Lets the player choose a file from their device and gives back its bytes.
## Browser (incl. phones): opens the browser's file chooser.
## Desktop: opens a normal file dialog.
##
##   var picker := FilePicker.new()
##   add_child(picker)
##   picker.picked.connect(func(file_name, bytes): ...)
##   picker.open(["*.glb"])

signal picked(file_name: String, bytes: PackedByteArray)
signal cancelled

var _js_callback: JavaScriptObject
var _dialog: FileDialog


func open(filters: PackedStringArray) -> void:
	if OS.has_feature("web"):
		_open_web(filters)
	else:
		_open_desktop(filters)


func _open_web(filters: PackedStringArray) -> void:
	_js_callback = JavaScriptBridge.create_callback(_on_web_file)
	var window := JavaScriptBridge.get_interface("window")
	window.godotFilePicked = _js_callback
	var accept := ",".join(Array(filters).map(func(f): return str(f).trim_prefix("*")))
	JavaScriptBridge.eval("""
		(function () {
			var input = document.createElement('input');
			input.type = 'file';
			input.accept = '%s';
			input.onchange = function () {
				var file = input.files[0];
				if (!file) { return; }
				var reader = new FileReader();
				reader.onload = function () {
					var data = reader.result;
					window.godotFilePicked(file.name, data.substring(data.indexOf(',') + 1));
				};
				reader.readAsDataURL(file);
			};
			input.click();
		})();
	""" % accept, true)


func _on_web_file(args: Array) -> void:
	var file_name := str(args[0])
	var bytes := Marshalls.base64_to_raw(str(args[1]))
	picked.emit(file_name, bytes)


func _open_desktop(filters: PackedStringArray) -> void:
	if _dialog == null:
		_dialog = FileDialog.new()
		_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
		_dialog.access = FileDialog.ACCESS_FILESYSTEM
		_dialog.use_native_dialog = true
		_dialog.size = Vector2i(900, 600)
		_dialog.file_selected.connect(_on_desktop_file)
		_dialog.canceled.connect(func(): cancelled.emit())
		add_child(_dialog)
	_dialog.filters = filters
	_dialog.popup_centered()


func _on_desktop_file(path: String) -> void:
	picked.emit(path.get_file(), FileAccess.get_file_as_bytes(path))
