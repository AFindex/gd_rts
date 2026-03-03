@tool
extends EditorScript

## Run this script from the Script Editor:
## Script -> Run (or Ctrl+Shift+X by default)
##
## Supports raster source files and SVG source files.
## Output formats: png, jpg/jpeg, webp.

@export_file("*.png", "*.jpg", "*.jpeg", "*.webp", "*.bmp", "*.tga", "*.svg") var source_path: String = ""
@export_file("*.png", "*.jpg", "*.jpeg", "*.webp") var output_path: String = ""

@export_enum("Target Size", "Scale Ratio") var resize_mode: int = 0
@export_range(1, 8192, 1) var target_width: int = 128
@export_range(1, 8192, 1) var target_height: int = 128
@export_range(0.01, 16.0, 0.01) var scale_ratio: float = 1.0
@export var keep_aspect_ratio: bool = true
@export_enum("Nearest", "Bilinear", "Cubic", "Trilinear", "Lanczos") var interpolation_mode: int = 1

@export var overwrite_source_when_possible: bool = false
@export_range(0.0, 1.0, 0.01) var lossy_quality: float = 0.9

func _run() -> void:
	var src: String = _normalize_path(source_path)
	if src.is_empty():
		printerr("[ImageResizer] source_path is empty.")
		return

	var image := Image.new()
	var load_err: int = _load_image(image, src)
	if load_err != OK:
		printerr("[ImageResizer] Failed to load source image: %s (err=%d)." % [src, load_err])
		return

	var original_size := Vector2i(image.get_width(), image.get_height())
	if original_size.x <= 0 or original_size.y <= 0:
		printerr("[ImageResizer] Invalid source size: %s." % [original_size])
		return

	var final_size: Vector2i = _compute_final_size(original_size)
	image.resize(final_size.x, final_size.y, _get_interpolation())

	var dst: String = _resolve_output_path(src)
	if dst.is_empty():
		printerr("[ImageResizer] output_path is empty.")
		return
	if dst.get_extension().to_lower() == "svg":
		printerr("[ImageResizer] SVG output is not supported. Use png/jpg/webp.")
		return

	var save_err: int = _save_image(image, dst)
	if save_err != OK:
		printerr("[ImageResizer] Failed to save output image: %s (err=%d)." % [dst, save_err])
		return

	_refresh_filesystem()
	print("[ImageResizer] Done: %s -> %s, %dx%d -> %dx%d" % [
		src,
		dst,
		original_size.x,
		original_size.y,
		final_size.x,
		final_size.y
	])

func _compute_final_size(original_size: Vector2i) -> Vector2i:
	if resize_mode == 1:
		var ratio: float = maxf(0.01, scale_ratio)
		var scaled_width: int = maxi(1, int(round(float(original_size.x) * ratio)))
		var scaled_height: int = maxi(1, int(round(float(original_size.y) * ratio)))
		return Vector2i(scaled_width, scaled_height)

	var width: int = maxi(1, target_width)
	var height: int = maxi(1, target_height)

	if keep_aspect_ratio:
		var scale_x: float = float(width) / float(original_size.x)
		var scale_y: float = float(height) / float(original_size.y)
		var fit_scale: float = minf(scale_x, scale_y)
		width = maxi(1, int(round(float(original_size.x) * fit_scale)))
		height = maxi(1, int(round(float(original_size.y) * fit_scale)))

	return Vector2i(width, height)

func _resolve_output_path(src: String) -> String:
	var requested_output: String = _normalize_path(output_path)
	if not requested_output.is_empty():
		return requested_output

	var src_ext: String = src.get_extension().to_lower()
	if overwrite_source_when_possible and src_ext in ["png", "jpg", "jpeg", "webp"]:
		return src

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
	match ext:
		"png":
			return image.save_png(write_path)
		"jpg", "jpeg":
			return image.save_jpg(write_path, clampf(lossy_quality, 0.0, 1.0))
		"webp":
			return image.save_webp(write_path, true, clampf(lossy_quality, 0.0, 1.0))
		_:
			return ERR_UNAVAILABLE

func _get_interpolation() -> int:
	match interpolation_mode:
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
	var editor_interface: EditorInterface = get_editor_interface()
	if editor_interface == null:
		return
	var filesystem: EditorFileSystem = editor_interface.get_resource_filesystem()
	if filesystem:
		filesystem.scan()
