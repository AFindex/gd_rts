@tool
extends VBoxContainer

const SOURCE_FILTERS: PackedStringArray = [
	"*.png ; PNG",
	"*.jpg ; JPG",
	"*.jpeg ; JPEG",
	"*.webp ; WEBP",
	"*.bmp ; BMP",
	"*.tga ; TGA",
	"*.svg ; SVG"
]

const OUTPUT_FILTERS: PackedStringArray = [
	"*.png ; PNG",
	"*.jpg ; JPG",
	"*.jpeg ; JPEG",
	"*.webp ; WEBP"
]

var _editor_plugin: EditorPlugin = null

var _source_edit: LineEdit
var _output_edit: LineEdit
var _width_spin: SpinBox
var _height_spin: SpinBox
var _keep_ratio_check: CheckBox
var _interpolation_option: OptionButton
var _overwrite_check: CheckBox
var _quality_spin: SpinBox
var _resize_button: Button
var _status_label: Label

var _source_dialog: EditorFileDialog
var _output_dialog: EditorFileDialog

func setup(editor_plugin: EditorPlugin) -> void:
	_editor_plugin = editor_plugin

func _ready() -> void:
	_build_ui()
	_build_file_dialogs()

func _build_ui() -> void:
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	custom_minimum_size = Vector2(320.0, 0.0)

	var title: Label = Label.new()
	title.text = "Image Resizer"
	title.add_theme_font_size_override("font_size", 16)
	add_child(title)

	var hint: Label = Label.new()
	hint.text = "Source 支持 SVG，输出支持 PNG/JPG/WEBP。"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(hint)

	add_child(_make_separator())

	var source_row: HBoxContainer = HBoxContainer.new()
	add_child(source_row)

	var source_label: Label = Label.new()
	source_label.text = "Source"
	source_label.custom_minimum_size = Vector2(72.0, 0.0)
	source_row.add_child(source_label)

	_source_edit = LineEdit.new()
	_source_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_source_edit.placeholder_text = "res://icon.svg"
	source_row.add_child(_source_edit)

	var source_browse: Button = Button.new()
	source_browse.text = "Browse"
	source_browse.pressed.connect(_on_source_browse_pressed)
	source_row.add_child(source_browse)

	var output_row: HBoxContainer = HBoxContainer.new()
	add_child(output_row)

	var output_label: Label = Label.new()
	output_label.text = "Output"
	output_label.custom_minimum_size = Vector2(72.0, 0.0)
	output_row.add_child(output_label)

	_output_edit = LineEdit.new()
	_output_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_output_edit.placeholder_text = "res://assets/raw/icon_128.png (留空自动命名)"
	output_row.add_child(_output_edit)

	var output_browse: Button = Button.new()
	output_browse.text = "Browse"
	output_browse.pressed.connect(_on_output_browse_pressed)
	output_row.add_child(output_browse)

	var size_row: HBoxContainer = HBoxContainer.new()
	add_child(size_row)

	var width_label: Label = Label.new()
	width_label.text = "W"
	size_row.add_child(width_label)

	_width_spin = SpinBox.new()
	_width_spin.min_value = 1.0
	_width_spin.max_value = 8192.0
	_width_spin.step = 1.0
	_width_spin.value = 128.0
	size_row.add_child(_width_spin)

	var height_label: Label = Label.new()
	height_label.text = "H"
	size_row.add_child(height_label)

	_height_spin = SpinBox.new()
	_height_spin.min_value = 1.0
	_height_spin.max_value = 8192.0
	_height_spin.step = 1.0
	_height_spin.value = 128.0
	size_row.add_child(_height_spin)

	_keep_ratio_check = CheckBox.new()
	_keep_ratio_check.text = "Keep Aspect"
	_keep_ratio_check.button_pressed = true
	size_row.add_child(_keep_ratio_check)

	var interpolation_row: HBoxContainer = HBoxContainer.new()
	add_child(interpolation_row)

	var interpolation_label: Label = Label.new()
	interpolation_label.text = "Filter"
	interpolation_label.custom_minimum_size = Vector2(72.0, 0.0)
	interpolation_row.add_child(interpolation_label)

	_interpolation_option = OptionButton.new()
	_interpolation_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_interpolation_option.add_item("Nearest", 0)
	_interpolation_option.add_item("Bilinear", 1)
	_interpolation_option.add_item("Cubic", 2)
	_interpolation_option.add_item("Trilinear", 3)
	_interpolation_option.add_item("Lanczos", 4)
	_interpolation_option.select(1)
	interpolation_row.add_child(_interpolation_option)

	var quality_row: HBoxContainer = HBoxContainer.new()
	add_child(quality_row)

	var quality_label: Label = Label.new()
	quality_label.text = "Quality"
	quality_label.custom_minimum_size = Vector2(72.0, 0.0)
	quality_row.add_child(quality_label)

	_quality_spin = SpinBox.new()
	_quality_spin.min_value = 0.0
	_quality_spin.max_value = 1.0
	_quality_spin.step = 0.01
	_quality_spin.value = 0.9
	_quality_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	quality_row.add_child(_quality_spin)

	_overwrite_check = CheckBox.new()
	_overwrite_check.text = "Overwrite source (when possible)"
	quality_row.add_child(_overwrite_check)

	add_child(_make_separator())

	var actions_row: HBoxContainer = HBoxContainer.new()
	add_child(actions_row)

	_resize_button = Button.new()
	_resize_button.text = "Resize"
	_resize_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_resize_button.pressed.connect(_on_resize_pressed)
	actions_row.add_child(_resize_button)

	var clear_button: Button = Button.new()
	clear_button.text = "Clear"
	clear_button.pressed.connect(_on_clear_pressed)
	actions_row.add_child(clear_button)

	_status_label = Label.new()
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.text = "Ready."
	add_child(_status_label)

func _build_file_dialogs() -> void:
	_source_dialog = EditorFileDialog.new()
	_source_dialog.title = "Select Source Image"
	_source_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
	_source_dialog.access = EditorFileDialog.ACCESS_RESOURCES
	for filter in SOURCE_FILTERS:
		_source_dialog.add_filter(filter)
	_source_dialog.file_selected.connect(_on_source_file_selected)
	add_child(_source_dialog)

	_output_dialog = EditorFileDialog.new()
	_output_dialog.title = "Select Output Path"
	_output_dialog.file_mode = EditorFileDialog.FILE_MODE_SAVE_FILE
	_output_dialog.access = EditorFileDialog.ACCESS_RESOURCES
	for filter in OUTPUT_FILTERS:
		_output_dialog.add_filter(filter)
	_output_dialog.file_selected.connect(_on_output_file_selected)
	add_child(_output_dialog)

func _on_source_browse_pressed() -> void:
	_source_dialog.popup_centered_ratio(0.75)

func _on_output_browse_pressed() -> void:
	_output_dialog.popup_centered_ratio(0.75)

func _on_source_file_selected(path: String) -> void:
	_source_edit.text = path
	if _output_edit.text.strip_edges().is_empty():
		_output_edit.text = _default_output_path(path)

func _on_output_file_selected(path: String) -> void:
	_output_edit.text = path

func _on_clear_pressed() -> void:
	_source_edit.text = ""
	_output_edit.text = ""
	_width_spin.value = 128.0
	_height_spin.value = 128.0
	_keep_ratio_check.button_pressed = true
	_interpolation_option.select(1)
	_overwrite_check.button_pressed = false
	_quality_spin.value = 0.9
	_set_status("Ready.")

func _on_resize_pressed() -> void:
	var src: String = _normalize_path(_source_edit.text)
	if src.is_empty():
		_set_error("source path 不能为空。")
		return

	_resize_button.disabled = true

	var image: Image = Image.new()
	var load_err: int = _load_image(image, src)
	if load_err != OK:
		_resize_button.disabled = false
		_set_error("加载失败: %s (err=%d)" % [src, load_err])
		return

	var original_size: Vector2i = Vector2i(image.get_width(), image.get_height())
	if original_size.x <= 0 or original_size.y <= 0:
		_resize_button.disabled = false
		_set_error("原图尺寸无效: %s" % [original_size])
		return

	var target_size: Vector2i = Vector2i(int(_width_spin.value), int(_height_spin.value))
	var final_size: Vector2i = _compute_final_size(original_size, target_size, _keep_ratio_check.button_pressed)
	image.resize(final_size.x, final_size.y, _get_interpolation())

	var dst: String = _resolve_output_path(src)
	if dst.is_empty():
		_resize_button.disabled = false
		_set_error("output path 不能为空。")
		return
	if dst.get_extension().to_lower() == "svg":
		_resize_button.disabled = false
		_set_error("不支持输出 SVG，请使用 png/jpg/webp。")
		return

	var save_err: int = _save_image(image, dst)
	_resize_button.disabled = false
	if save_err != OK:
		_set_error("保存失败: %s (err=%d)" % [dst, save_err])
		return

	_refresh_filesystem()
	_set_status("Done: %s -> %s, %dx%d -> %dx%d" % [
		src,
		dst,
		original_size.x,
		original_size.y,
		final_size.x,
		final_size.y
	])

func _compute_final_size(original_size: Vector2i, target_size: Vector2i, keep_aspect_ratio: bool) -> Vector2i:
	var width: int = maxi(1, target_size.x)
	var height: int = maxi(1, target_size.y)

	if keep_aspect_ratio:
		var scale_x: float = float(width) / float(original_size.x)
		var scale_y: float = float(height) / float(original_size.y)
		var fit_scale: float = minf(scale_x, scale_y)
		width = maxi(1, int(round(float(original_size.x) * fit_scale)))
		height = maxi(1, int(round(float(original_size.y) * fit_scale)))

	return Vector2i(width, height)

func _resolve_output_path(src: String) -> String:
	var requested_output: String = _normalize_path(_output_edit.text)
	if not requested_output.is_empty():
		return requested_output
	if _overwrite_check.button_pressed:
		var src_ext: String = src.get_extension().to_lower()
		if src_ext in ["png", "jpg", "jpeg", "webp"]:
			return src
	return _default_output_path(src)

func _default_output_path(src: String) -> String:
	var src_ext: String = src.get_extension().to_lower()
	var output_ext: String = "png"
	if src_ext in ["png", "jpg", "jpeg", "webp"]:
		output_ext = src_ext
	return "%s_resized.%s" % [src.get_basename(), output_ext]

func _load_image(image: Image, src: String) -> int:
	var err: int = image.load(src)
	if err == OK:
		return OK

	if src.begins_with("res://") or src.begins_with("user://"):
		var absolute_path: String = ProjectSettings.globalize_path(src)
		return image.load(absolute_path)

	return err

func _save_image(image: Image, dst: String) -> int:
	var write_path: String = dst
	if dst.begins_with("res://") or dst.begins_with("user://"):
		write_path = ProjectSettings.globalize_path(dst)

	var output_dir: String = write_path.get_base_dir()
	if not output_dir.is_empty() and not DirAccess.dir_exists_absolute(output_dir):
		var make_dir_err: int = DirAccess.make_dir_recursive_absolute(output_dir)
		if make_dir_err != OK:
			return make_dir_err

	var ext: String = dst.get_extension().to_lower()
	var quality: float = clampf(float(_quality_spin.value), 0.0, 1.0)
	match ext:
		"png":
			return image.save_png(write_path)
		"jpg", "jpeg":
			return image.save_jpg(write_path, quality)
		"webp":
			return image.save_webp(write_path, true, quality)
		_:
			return ERR_UNAVAILABLE

func _get_interpolation() -> int:
	match _interpolation_option.get_selected_id():
		0:
			return Image.INTERPOLATE_NEAREST
		1:
			return Image.INTERPOLATE_BILINEAR
		2:
			return Image.INTERPOLATE_CUBIC
		3:
			return Image.INTERPOLATE_TRILINEAR
		4:
			return Image.INTERPOLATE_LANCZOS
		_:
			return Image.INTERPOLATE_BILINEAR

func _normalize_path(path_value: String) -> String:
	var normalized: String = path_value.strip_edges().replace("\\", "/")
	if normalized.is_empty():
		return ""
	if normalized.begins_with("res://") or normalized.begins_with("user://"):
		return normalized
	if normalized.is_absolute_path():
		return normalized
	if normalized.begins_with("/"):
		normalized = normalized.trim_prefix("/")
	return "res://%s" % normalized

func _refresh_filesystem() -> void:
	if _editor_plugin == null:
		return
	var editor_interface: EditorInterface = _editor_plugin.get_editor_interface()
	if editor_interface == null:
		return
	var filesystem: EditorFileSystem = editor_interface.get_resource_filesystem()
	if filesystem:
		filesystem.scan()

func _set_status(message: String) -> void:
	_status_label.modulate = Color(0.82, 0.98, 0.82, 1.0)
	_status_label.text = message

func _set_error(message: String) -> void:
	_status_label.modulate = Color(1.0, 0.72, 0.72, 1.0)
	_status_label.text = message

func _make_separator() -> HSeparator:
	var separator: HSeparator = HSeparator.new()
	separator.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return separator
