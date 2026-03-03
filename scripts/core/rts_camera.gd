extends Camera3D

@export var pan_speed: float = 24.0
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
	if input_dir != Vector2.ZERO:
		var right := global_transform.basis.x
		var forward := -global_transform.basis.z
		right.y = 0.0
		forward.y = 0.0
		right = right.normalized()
		forward = forward.normalized()
		var movement := (right * input_dir.x + forward * input_dir.y) * pan_speed * delta
		global_position += movement
		global_position.x = clampf(global_position.x, -map_half_size.x, map_half_size.x)
		global_position.z = clampf(global_position.z, -map_half_size.y, map_half_size.y)

	var zoom_diff := _target_zoom - global_position.y
	if absf(zoom_diff) > 0.01:
		global_position.y += zoom_diff * min(1.0, delta * 10.0)
