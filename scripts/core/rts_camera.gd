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

var _target_zoom: float

func _ready() -> void:
	rotation_degrees = Vector3(-55.0, 0.0, 0.0)
	_target_zoom = global_position.y

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_target_zoom = max(min_zoom, _target_zoom - zoom_speed)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_target_zoom = min(max_zoom, _target_zoom + zoom_speed)

func _process(delta: float) -> void:
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
