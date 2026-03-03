extends Node3D

@export var camera_path: NodePath
@export var units_root_path: NodePath
@export var selection_overlay_path: NodePath

var _camera: Camera3D
var _units_root: Node3D
var _selection_overlay: Control
var _dragging: bool = false
var _drag_start: Vector2 = Vector2.ZERO
var _selected_units: Array[Node] = []

func _ready() -> void:
	_camera = get_node_or_null(camera_path) as Camera3D
	_units_root = get_node_or_null(units_root_path) as Node3D
	_selection_overlay = get_node_or_null(selection_overlay_path) as Control

func _unhandled_input(event: InputEvent) -> void:
	if _camera == null:
		return

	var mouse_button := event as InputEventMouseButton
	if mouse_button != null and mouse_button.button_index == MOUSE_BUTTON_LEFT:
		if mouse_button.pressed:
			_dragging = true
			_drag_start = mouse_button.position
			if _selection_overlay != null and _selection_overlay.has_method("begin_drag"):
				_selection_overlay.call("begin_drag", _drag_start)
		else:
			if _dragging:
				var drag_end: Vector2 = mouse_button.position
				var drag_distance: float = _drag_start.distance_to(drag_end)
				var additive: bool = Input.is_key_pressed(KEY_SHIFT)
				if drag_distance < 8.0:
					_select_single(drag_end, additive)
				else:
					_select_by_rect(_drag_start, drag_end, additive)
			_dragging = false
			if _selection_overlay != null and _selection_overlay.has_method("end_drag"):
				_selection_overlay.call("end_drag")

	var mouse_motion := event as InputEventMouseMotion
	if mouse_motion != null and _dragging:
		if _selection_overlay != null and _selection_overlay.has_method("update_drag"):
			_selection_overlay.call("update_drag", mouse_motion.position)

	if mouse_button != null and mouse_button.button_index == MOUSE_BUTTON_RIGHT and mouse_button.pressed:
		_issue_move_command(mouse_button.position)

func _select_single(screen_pos: Vector2, additive: bool) -> void:
	if not additive:
		_clear_selection()

	var result := _raycast_from_screen(screen_pos)
	if result.is_empty():
		return

	var collider := result.get("collider") as Node
	if collider == null:
		return

	if collider.is_in_group("selectable_unit"):
		_add_selected_unit(collider)

func _select_by_rect(start_pos: Vector2, end_pos: Vector2, additive: bool) -> void:
	if not additive:
		_clear_selection()

	var rect := Rect2(
		Vector2(minf(start_pos.x, end_pos.x), minf(start_pos.y, end_pos.y)),
		Vector2(absf(end_pos.x - start_pos.x), absf(end_pos.y - start_pos.y))
	)

	for node in get_tree().get_nodes_in_group("selectable_unit"):
		var unit := node as Node3D
		if unit == null:
			continue
		if _camera.is_position_behind(unit.global_position):
			continue
		var screen_pos := _camera.unproject_position(unit.global_position)
		if rect.has_point(screen_pos):
			_add_selected_unit(unit)

func _issue_move_command(screen_pos: Vector2) -> void:
	if _selected_units.is_empty():
		return

	var target: Variant = _ground_point_from_screen(screen_pos)
	if target == null:
		return

	var target_point: Vector3 = target as Vector3
	var count: int = _selected_units.size()
	var cols: int = int(ceil(sqrt(float(count))))
	var spacing: float = 1.6

	for i in count:
		var row: int = i / cols
		var col: int = i % cols
		var offset: Vector3 = Vector3((float(col) - float(cols - 1) * 0.5) * spacing, 0.0, (float(row) - float(cols - 1) * 0.5) * spacing)
		var unit := _selected_units[i] as Node
		if unit != null and unit.has_method("move_to"):
			unit.call("move_to", target_point + offset)

func _ground_point_from_screen(screen_pos: Vector2) -> Variant:
	var origin: Vector3 = _camera.project_ray_origin(screen_pos)
	var normal: Vector3 = _camera.project_ray_normal(screen_pos)
	var plane: Plane = Plane(Vector3.UP, 0.0)
	var intersection: Variant = plane.intersects_ray(origin, normal)
	if intersection == null:
		return null
	return intersection

func _raycast_from_screen(screen_pos: Vector2) -> Dictionary:
	var origin: Vector3 = _camera.project_ray_origin(screen_pos)
	var normal: Vector3 = _camera.project_ray_normal(screen_pos)
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(origin, origin + normal * 4000.0)
	query.collide_with_areas = true
	return get_world_3d().direct_space_state.intersect_ray(query)

func _add_selected_unit(unit: Node) -> void:
	if _selected_units.has(unit):
		return
	_selected_units.append(unit)
	if unit.has_method("set_selected"):
		unit.call("set_selected", true)

func _clear_selection() -> void:
	for node in _selected_units:
		if node != null and node.has_method("set_selected"):
			node.call("set_selected", false)
	_selected_units.clear()
