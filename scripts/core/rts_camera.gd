extends Camera3D

@export var pan_speed: float = 24.0
@export var edge_scroll_enabled: bool = true
@export var edge_scroll_margin: float = 12.0
@export var edge_scroll_speed: float = 24.0
@export var edge_scroll_ignore_ui: bool = true
@export var zoom_speed: float = 3.0
@export var min_zoom: float = 10.0
@export var max_zoom: float = 55.0
@export var map_half_size: Vector2 = Vector2(58.0, 58.0)
@export var start_point_path: NodePath = NodePath("../CameraStartPoint")
@export var intro_enabled: bool = true
@export var intro_lock_input: bool = true
@export var intro_height_offset: float = 30.0
@export var intro_duration: float = 1.6
@export var intro_delay: float = 0.0

var _target_zoom: float
var _intro_playing: bool = false

func _ready() -> void:
	rotation_degrees = Vector3(-55.0, 0.0, 0.0)
	var start_anchor: Node3D = _resolve_start_anchor()
	var start_position: Vector3 = _resolve_start_position(start_anchor)
	start_position = _clamp_camera_to_map(start_position)
	_target_zoom = clampf(start_position.y, min_zoom, max_zoom)
	intro_height_offset = _start_anchor_number(start_anchor, "intro_height_offset", intro_height_offset)
	intro_duration = _start_anchor_number(start_anchor, "intro_duration", intro_duration)
	intro_delay = _start_anchor_number(start_anchor, "intro_delay", intro_delay)
	intro_lock_input = _start_anchor_bool(start_anchor, "intro_lock_input", intro_lock_input)
	if intro_enabled:
		global_position = start_position + Vector3(0.0, maxf(0.0, intro_height_offset), 0.0)
		_play_intro_to(start_position)
	else:
		global_position = start_position

func _unhandled_input(event: InputEvent) -> void:
	if _intro_playing and intro_lock_input:
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_target_zoom = max(min_zoom, _target_zoom - zoom_speed)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_target_zoom = min(max_zoom, _target_zoom + zoom_speed)

func _process(delta: float) -> void:
	if _intro_playing and intro_lock_input:
		return
	var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var edge_dir := _edge_scroll_direction()
	var move_dir := input_dir + edge_dir
	if move_dir.length_squared() > 1.0:
		move_dir = move_dir.normalized()
	if move_dir != Vector2.ZERO:
		var move_speed: float = pan_speed
		if edge_dir != Vector2.ZERO:
			move_speed = maxf(pan_speed, edge_scroll_speed)
		var right := global_transform.basis.x
		var forward := -global_transform.basis.z
		right.y = 0.0
		forward.y = 0.0
		right = right.normalized()
		forward = forward.normalized()
		var movement := (right * move_dir.x + forward * move_dir.y) * move_speed * delta
		global_position += movement
		global_position.x = clampf(global_position.x, -map_half_size.x, map_half_size.x)
		global_position.z = clampf(global_position.z, -map_half_size.y, map_half_size.y)

	var zoom_diff := _target_zoom - global_position.y
	if absf(zoom_diff) > 0.01:
		global_position.y += zoom_diff * min(1.0, delta * 10.0)

func _resolve_start_anchor() -> Node3D:
	var start_node: Node3D = get_node_or_null(start_point_path) as Node3D
	if start_node == null or not is_instance_valid(start_node):
		return null
	return start_node

func _resolve_start_position(start_anchor: Node3D) -> Vector3:
	if start_anchor == null:
		return global_position
	var aim_point: Vector3 = start_anchor.global_position
	var camera_distance: float = _resolve_start_distance(start_anchor)
	var forward: Vector3 = -global_transform.basis.z
	if forward.length_squared() <= 0.0001:
		forward = Vector3(0.0, -0.8, -0.6)
	return aim_point - forward.normalized() * camera_distance

func _resolve_start_distance(start_anchor: Node3D) -> float:
	if start_anchor == null:
		return maxf(8.0, global_position.length())
	var fallback_distance: float = maxf(8.0, global_position.distance_to(start_anchor.global_position))
	return _start_anchor_number(start_anchor, "camera_distance", fallback_distance)

func _start_anchor_number(start_anchor: Node3D, property_name: String, fallback: float) -> float:
	if start_anchor == null:
		return fallback
	var value: Variant = start_anchor.get(property_name)
	if value is float or value is int:
		return float(value)
	return fallback

func _start_anchor_bool(start_anchor: Node3D, property_name: String, fallback: bool) -> bool:
	if start_anchor == null:
		return fallback
	var value: Variant = start_anchor.get(property_name)
	if value is bool:
		return value as bool
	return fallback

func _play_intro_to(target_position: Vector3) -> void:
	_intro_playing = true
	var tween: Tween = create_tween()
	if intro_delay > 0.0:
		tween.tween_interval(intro_delay)
	tween.tween_property(self, "global_position", target_position, maxf(0.05, intro_duration)).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_callback(Callable(self, "_on_intro_finished"))

func _on_intro_finished() -> void:
	_intro_playing = false
	global_position = _clamp_camera_to_map(global_position)
	_target_zoom = clampf(global_position.y, min_zoom, max_zoom)

func _clamp_camera_to_map(position: Vector3) -> Vector3:
	position.x = clampf(position.x, -map_half_size.x, map_half_size.x)
	position.z = clampf(position.z, -map_half_size.y, map_half_size.y)
	return position

func _edge_scroll_direction() -> Vector2:
	if not edge_scroll_enabled:
		return Vector2.ZERO
	if Input.get_mouse_mode() != Input.MOUSE_MODE_VISIBLE:
		return Vector2.ZERO
	var viewport: Viewport = get_viewport()
	if viewport == null:
		return Vector2.ZERO
	if edge_scroll_ignore_ui and _is_mouse_over_ui(viewport):
		return Vector2.ZERO
	var rect: Rect2 = viewport.get_visible_rect()
	var size: Vector2 = rect.size
	if size.x <= 1.0 or size.y <= 1.0:
		return Vector2.ZERO
	var margin: float = maxf(0.0, edge_scroll_margin)
	var mouse_pos: Vector2 = viewport.get_mouse_position()
	var dir := Vector2.ZERO
	if mouse_pos.x <= margin:
		dir.x -= 1.0
	elif mouse_pos.x >= size.x - margin:
		dir.x += 1.0
	if mouse_pos.y <= margin:
		dir.y += 1.0
	elif mouse_pos.y >= size.y - margin:
		dir.y -= 1.0
	return dir

func _is_mouse_over_ui(viewport: Viewport) -> bool:
	if viewport == null:
		return false
	var mouse_pos: Vector2 = viewport.get_mouse_position()
	if viewport.has_method("gui_get_hovered_control"):
		var hovered: Control = viewport.call("gui_get_hovered_control") as Control
		if hovered != null and hovered.visible and hovered.mouse_filter != Control.MOUSE_FILTER_IGNORE:
			if hovered.get_global_rect().has_point(mouse_pos):
				return true
	if viewport.has_method("gui_pick"):
		var picked: Control = viewport.call("gui_pick", mouse_pos) as Control
		if picked != null and picked.visible and picked.mouse_filter != Control.MOUSE_FILTER_IGNORE:
			return true
	return false
