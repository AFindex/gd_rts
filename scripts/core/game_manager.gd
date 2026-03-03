extends Node3D

const UNIT_SCENE: PackedScene = preload("res://scenes/units/unit.tscn")
const BUILDING_SCENE: PackedScene = preload("res://scenes/buildings/building.tscn")

const BARRACKS_COST: int = 160
const WORKER_COST: int = 50
const SOLDIER_COST: int = 70
const BUILDING_BLOCK_RADIUS: float = 3.8
const RESOURCE_BLOCK_RADIUS: float = 3.2

@export var camera_path: NodePath
@export var units_root_path: NodePath
@export var buildings_root_path: NodePath
@export var selection_overlay_path: NodePath
@export var resource_label_path: NodePath
@export var hint_label_path: NodePath

var _camera: Camera3D
var _units_root: Node3D
var _buildings_root: Node3D
var _selection_overlay: Control
var _resource_label: Label
var _hint_label: Label

var _dragging: bool = false
var _drag_start: Vector2 = Vector2.ZERO
var _selected_units: Array[Node] = []
var _selected_buildings: Array[Node] = []

var _minerals: int = 220

var _placing_building: bool = false
var _placing_kind: String = ""
var _placing_cost: int = 0
var _placement_current_position: Vector3 = Vector3.ZERO
var _placement_can_place: bool = false
var _placement_preview: MeshInstance3D
var _placement_preview_material: StandardMaterial3D

var _hint_refresh_accum: float = 0.0

func _ready() -> void:
	add_to_group("game_manager")
	_camera = get_node_or_null(camera_path) as Camera3D
	_units_root = get_node_or_null(units_root_path) as Node3D
	_buildings_root = get_node_or_null(buildings_root_path) as Node3D
	_selection_overlay = get_node_or_null(selection_overlay_path) as Control
	_resource_label = get_node_or_null(resource_label_path) as Label
	_hint_label = get_node_or_null(hint_label_path) as Label
	_create_placement_preview()
	_register_existing_buildings()
	_refresh_resource_label()
	_refresh_hint_label()

func _process(delta: float) -> void:
	if _placing_building:
		_update_placement_preview()

	_hint_refresh_accum += delta
	if _hint_refresh_accum >= 0.2:
		_hint_refresh_accum = 0.0
		_refresh_hint_label()

func _unhandled_input(event: InputEvent) -> void:
	if _camera == null:
		return

	var key_event: InputEventKey = event as InputEventKey
	if key_event != null and key_event.pressed and not key_event.echo:
		if key_event.keycode == KEY_B:
			_start_building_placement("barracks")
			return
		if key_event.keycode == KEY_ESCAPE and _placing_building:
			_cancel_building_placement()
			return
		if key_event.keycode == KEY_R:
			_queue_worker_from_selection()
			return
		if key_event.keycode == KEY_T:
			_queue_soldier_from_selection()
			return

	var mouse_button: InputEventMouseButton = event as InputEventMouseButton
	if _placing_building and mouse_button != null:
		if mouse_button.button_index == MOUSE_BUTTON_RIGHT and mouse_button.pressed:
			_cancel_building_placement()
			return
		if mouse_button.button_index == MOUSE_BUTTON_LEFT and mouse_button.pressed:
			_try_place_building(mouse_button.position)
			return

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
			_refresh_hint_label()

	var mouse_motion: InputEventMouseMotion = event as InputEventMouseMotion
	if mouse_motion != null and _dragging:
		if _selection_overlay != null and _selection_overlay.has_method("update_drag"):
			_selection_overlay.call("update_drag", mouse_motion.position)

	if mouse_button != null and mouse_button.button_index == MOUSE_BUTTON_RIGHT and mouse_button.pressed:
		_issue_context_command(mouse_button.position)

func add_minerals(amount: int) -> void:
	if amount <= 0:
		return
	_minerals += amount
	_refresh_resource_label()

func try_spend_minerals(cost: int) -> bool:
	if cost <= 0:
		return true
	if _minerals < cost:
		return false
	_minerals -= cost
	_refresh_resource_label()
	return true

func get_minerals() -> int:
	return _minerals

func _refresh_resource_label() -> void:
	if _resource_label != null:
		_resource_label.text = "Minerals: %d" % _minerals

func _refresh_hint_label() -> void:
	if _hint_label == null:
		return

	var lines: Array[String] = []
	lines.append("B Place Barracks(160) | R Queue Worker(50) | T Queue Soldier(70) | ESC Cancel")
	lines.append("Selected: Units %d / Buildings %d" % [_selected_units.size(), _selected_buildings.size()])

	if _placing_building:
		var place_state: String = "Valid" if _placement_can_place else "Invalid"
		lines.append("Mode: Barracks placement (%d) - %s" % [_placing_cost, place_state])
	elif _selected_buildings.size() == 1:
		var selected_building: Node = _selected_buildings[0]
		if selected_building != null and selected_building.has_method("get_queue_size"):
			var queue_size_value: Variant = selected_building.call("get_queue_size")
			var queue_size: int = int(queue_size_value)
			lines.append("Building queue: %d" % queue_size)

	_hint_label.text = "\n".join(lines)

func _issue_context_command(screen_pos: Vector2) -> void:
	if _selected_units.is_empty():
		return

	var ray_result: Dictionary = _raycast_from_screen(screen_pos)
	if not ray_result.is_empty():
		var collider: Node = ray_result.get("collider") as Node
		if collider != null and collider.is_in_group("resource_node"):
			_issue_gather_command(collider as Node3D, screen_pos)
			return

	_issue_move_command(screen_pos)

func _select_single(screen_pos: Vector2, additive: bool) -> void:
	if not additive:
		_clear_selection()

	var result: Dictionary = _raycast_from_screen(screen_pos)
	if result.is_empty():
		return

	var collider: Node = result.get("collider") as Node
	if collider == null:
		return

	if collider.is_in_group("selectable_unit"):
		_add_selected_unit(collider)
		return

	if collider.is_in_group("selectable_building"):
		_add_selected_building(collider)

func _select_by_rect(start_pos: Vector2, end_pos: Vector2, additive: bool) -> void:
	if not additive:
		_clear_selection()

	var rect: Rect2 = Rect2(
		Vector2(minf(start_pos.x, end_pos.x), minf(start_pos.y, end_pos.y)),
		Vector2(absf(end_pos.x - start_pos.x), absf(end_pos.y - start_pos.y))
	)

	var candidates: Array[Node]
	if _units_root != null:
		candidates = _units_root.get_children()
	else:
		candidates = get_tree().get_nodes_in_group("selectable_unit")

	for node in candidates:
		var unit: Node3D = node as Node3D
		if unit == null:
			continue
		if _camera.is_position_behind(unit.global_position):
			continue
		var projected_pos: Vector2 = _camera.unproject_position(unit.global_position)
		if rect.has_point(projected_pos):
			_add_selected_unit(unit)

func _queue_worker_from_selection() -> void:
	var queued_count: int = 0
	for node in _selected_buildings:
		if node == null:
			continue
		var can_queue: bool = false
		if node.has_method("can_queue_worker_unit"):
			var can_queue_value: Variant = node.call("can_queue_worker_unit")
			can_queue = bool(can_queue_value)
		if not can_queue:
			continue
		if not try_spend_minerals(WORKER_COST):
			break
		if node.has_method("queue_worker"):
			var queued_value: Variant = node.call("queue_worker")
			if bool(queued_value):
				queued_count += 1
			else:
				add_minerals(WORKER_COST)

	if queued_count > 0:
		_refresh_hint_label()

func _queue_soldier_from_selection() -> void:
	var queued_count: int = 0
	for node in _selected_buildings:
		if node == null:
			continue
		var can_queue: bool = false
		if node.has_method("can_queue_soldier_unit"):
			var can_queue_value: Variant = node.call("can_queue_soldier_unit")
			can_queue = bool(can_queue_value)
		if not can_queue:
			continue
		if not try_spend_minerals(SOLDIER_COST):
			break
		if node.has_method("queue_soldier"):
			var queued_value: Variant = node.call("queue_soldier")
			if bool(queued_value):
				queued_count += 1
			else:
				add_minerals(SOLDIER_COST)

	if queued_count > 0:
		_refresh_hint_label()

func _issue_gather_command(resource_node: Node3D, fallback_screen_pos: Vector2) -> void:
	if resource_node == null:
		return

	var dropoff: Node3D = _nearest_dropoff(resource_node.global_position)
	if dropoff == null:
		_issue_move_command(fallback_screen_pos)
		return

	var issued_count: int = 0
	for unit_node in _selected_units:
		if unit_node == null:
			continue
		var is_worker: bool = false
		if unit_node.has_method("is_worker_unit"):
			var worker_value: Variant = unit_node.call("is_worker_unit")
			is_worker = bool(worker_value)
		if is_worker and unit_node.has_method("command_gather"):
			unit_node.call("command_gather", resource_node, dropoff)
			issued_count += 1

	if issued_count == 0:
		_issue_move_command(fallback_screen_pos)

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
		var unit: Node = _selected_units[i] as Node
		if unit == null:
			continue
		if unit.has_method("command_move"):
			unit.call("command_move", target_point + offset)
		elif unit.has_method("move_to"):
			unit.call("move_to", target_point + offset)

func _nearest_dropoff(from_position: Vector3) -> Node3D:
	var nearest: Node3D = null
	var best_distance_sq: float = INF
	var dropoff_nodes: Array[Node] = get_tree().get_nodes_in_group("resource_dropoff")
	for node in dropoff_nodes:
		var dropoff: Node3D = node as Node3D
		if dropoff == null:
			continue
		var distance_sq: float = from_position.distance_squared_to(dropoff.global_position)
		if distance_sq < best_distance_sq:
			best_distance_sq = distance_sq
			nearest = dropoff
	return nearest

func _start_building_placement(kind: String) -> void:
	if kind != "barracks":
		return
	_placing_building = true
	_placing_kind = kind
	_placing_cost = BARRACKS_COST
	_placement_preview.visible = true
	_update_placement_preview()
	_refresh_hint_label()

func _cancel_building_placement() -> void:
	_placing_building = false
	_placing_kind = ""
	_placing_cost = 0
	_placement_can_place = false
	if _placement_preview != null:
		_placement_preview.visible = false
	_refresh_hint_label()

func _create_placement_preview() -> void:
	_placement_preview = MeshInstance3D.new()
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = 1.35
	mesh.bottom_radius = 1.35
	mesh.height = 0.08
	_placement_preview.mesh = mesh

	_placement_preview_material = StandardMaterial3D.new()
	_placement_preview_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_placement_preview_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_placement_preview_material.albedo_color = Color(0.15, 0.95, 0.3, 0.35)
	_placement_preview.material_override = _placement_preview_material
	_placement_preview.visible = false
	add_child(_placement_preview)

func _update_placement_preview() -> void:
	var screen_pos: Vector2 = get_viewport().get_mouse_position()
	_update_placement_preview_from_screen(screen_pos)

func _update_placement_preview_from_screen(screen_pos: Vector2) -> void:
	var point: Variant = _ground_point_from_screen(screen_pos)
	if point == null:
		_placement_preview.visible = false
		_placement_can_place = false
		return

	var raw_position: Vector3 = point as Vector3
	var snapped: Vector3 = Vector3(roundf(raw_position.x * 2.0) * 0.5, 0.04, roundf(raw_position.z * 2.0) * 0.5)
	_placement_current_position = snapped

	var is_valid_spot: bool = _is_build_spot_valid(snapped)
	var can_afford: bool = _minerals >= _placing_cost
	_placement_can_place = is_valid_spot and can_afford

	_placement_preview.visible = true
	_placement_preview.global_position = snapped
	if _placement_can_place:
		_placement_preview_material.albedo_color = Color(0.15, 0.95, 0.3, 0.35)
	else:
		_placement_preview_material.albedo_color = Color(0.95, 0.2, 0.2, 0.35)

func _try_place_building(screen_pos: Vector2) -> void:
	_update_placement_preview_from_screen(screen_pos)
	if not _placement_can_place:
		return
	if not try_spend_minerals(_placing_cost):
		return

	var instance: Node = BUILDING_SCENE.instantiate()
	var building: Node3D = instance as Node3D
	if building == null:
		add_minerals(_placing_cost)
		return

	if _buildings_root != null:
		_buildings_root.add_child(building)
	else:
		add_child(building)

	building.global_position = Vector3(_placement_current_position.x, 0.0, _placement_current_position.z)
	if _placing_kind == "barracks" and building.has_method("configure_as_barracks"):
		building.call("configure_as_barracks")

	_register_building(building)
	_cancel_building_placement()

func _is_build_spot_valid(world_pos: Vector3) -> bool:
	if absf(world_pos.x) > 56.0 or absf(world_pos.z) > 56.0:
		return false

	var building_nodes: Array[Node] = get_tree().get_nodes_in_group("selectable_building")
	for node in building_nodes:
		var building: Node3D = node as Node3D
		if building == null:
			continue
		if world_pos.distance_to(building.global_position) < BUILDING_BLOCK_RADIUS:
			return false

	var resource_nodes: Array[Node] = get_tree().get_nodes_in_group("resource_node")
	for node in resource_nodes:
		var resource: Node3D = node as Node3D
		if resource == null:
			continue
		if world_pos.distance_to(resource.global_position) < RESOURCE_BLOCK_RADIUS:
			return false

	return true

func _register_existing_buildings() -> void:
	var building_nodes: Array[Node] = get_tree().get_nodes_in_group("selectable_building")
	for node in building_nodes:
		_register_building(node)

func _register_building(building_node: Node) -> void:
	if building_node == null:
		return
	if not building_node.has_signal("production_finished"):
		return
	var callback: Callable = Callable(self, "_on_building_production_finished")
	if not building_node.is_connected("production_finished", callback):
		building_node.connect("production_finished", callback)

func _on_building_production_finished(unit_kind: String, spawn_position: Vector3) -> void:
	_spawn_unit(unit_kind, spawn_position)

func _spawn_unit(unit_kind: String, spawn_position: Vector3) -> void:
	if _units_root == null:
		return

	var instance: Node = UNIT_SCENE.instantiate()
	var unit: CharacterBody3D = instance as CharacterBody3D
	if unit == null:
		return

	var is_worker: bool = unit_kind == "worker"
	unit.set("is_worker", is_worker)
	_units_root.add_child(unit)
	unit.global_position = _find_open_spawn_position(spawn_position)

func _find_open_spawn_position(origin: Vector3) -> Vector3:
	for ring in 4:
		var radius: float = 1.6 + float(ring) * 1.0
		for step in 8:
			var angle: float = TAU * float(step) / 8.0
			var candidate: Vector3 = origin + Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
			if _is_spawn_position_free(candidate):
				return candidate
	return origin

func _is_spawn_position_free(candidate: Vector3) -> bool:
	var units: Array[Node] = get_tree().get_nodes_in_group("selectable_unit")
	for node in units:
		var unit: Node3D = node as Node3D
		if unit == null:
			continue
		if candidate.distance_to(unit.global_position) < 1.2:
			return false

	var buildings: Array[Node] = get_tree().get_nodes_in_group("selectable_building")
	for node in buildings:
		var building: Node3D = node as Node3D
		if building == null:
			continue
		if candidate.distance_to(building.global_position) < 2.4:
			return false

	var resources: Array[Node] = get_tree().get_nodes_in_group("resource_node")
	for node in resources:
		var resource: Node3D = node as Node3D
		if resource == null:
			continue
		if candidate.distance_to(resource.global_position) < 2.0:
			return false

	return true

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

func _add_selected_building(building: Node) -> void:
	if _selected_buildings.has(building):
		return
	_selected_buildings.append(building)
	if building.has_method("set_selected"):
		building.call("set_selected", true)

func _clear_selection() -> void:
	for node in _selected_units:
		if node != null and node.has_method("set_selected"):
			node.call("set_selected", false)
	for node in _selected_buildings:
		if node != null and node.has_method("set_selected"):
			node.call("set_selected", false)
	_selected_units.clear()
	_selected_buildings.clear()