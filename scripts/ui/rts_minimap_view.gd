extends Control

signal navigate_requested(world_position: Vector3)
signal ping_requested(world_position: Vector3)

@export var map_half_size: Vector2 = Vector2(58.0, 58.0)
@export var player_team_id: int = 1
@export var grid_divisions: int = 4
@export var background_color: Color = Color(0.04, 0.08, 0.12, 0.96)
@export var border_color: Color = Color(0.18, 0.42, 0.58, 0.95)
@export var player_unit_color: Color = Color(0.32, 0.95, 0.52, 1.0)
@export var enemy_unit_color: Color = Color(0.98, 0.45, 0.38, 1.0)
@export var neutral_unit_color: Color = Color(0.72, 0.8, 0.9, 1.0)
@export var player_building_color: Color = Color(0.38, 0.72, 1.0, 1.0)
@export var enemy_building_color: Color = Color(1.0, 0.62, 0.34, 1.0)
@export var resource_color: Color = Color(0.45, 0.82, 1.0, 1.0)
@export var selected_outline_color: Color = Color(1.0, 1.0, 1.0, 1.0)
@export var camera_rect_color: Color = Color(1.0, 0.92, 0.46, 1.0)
@export var ping_color: Color = Color(1.0, 0.86, 0.36, 0.95)
@export var alert_ping_color: Color = Color(1.0, 0.34, 0.32, 0.98)
@export var ping_mode_outline_color: Color = Color(1.0, 0.82, 0.3, 1.0)

var _units: Array = []
var _buildings: Array = []
var _resources: Array = []
var _pings: Array = []
var _camera_world_pos: Vector3 = Vector3.ZERO
var _camera_world_half_extent: Vector2 = Vector2(10.0, 10.0)
var _is_drag_navigate: bool = false
var _ping_mode: bool = false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	queue_redraw()

func apply_snapshot(snapshot: Dictionary) -> void:
	if snapshot.has("map_half_size"):
		var half_value: Variant = snapshot.get("map_half_size")
		if half_value is Vector2:
			map_half_size = (half_value as Vector2).abs()
	if snapshot.has("player_team_id"):
		player_team_id = int(snapshot.get("player_team_id"))
	_units = []
	_buildings = []
	_resources = []
	_pings = []
	var unit_values: Variant = snapshot.get("units", [])
	if unit_values is Array:
		_units = (unit_values as Array).duplicate(true)
	var building_values: Variant = snapshot.get("buildings", [])
	if building_values is Array:
		_buildings = (building_values as Array).duplicate(true)
	var resource_values: Variant = snapshot.get("resources", [])
	if resource_values is Array:
		_resources = (resource_values as Array).duplicate(true)
	var ping_values: Variant = snapshot.get("pings", [])
	if ping_values is Array:
		_pings = (ping_values as Array).duplicate(true)
	var camera_pos_value: Variant = snapshot.get("camera_position", Vector3.ZERO)
	if camera_pos_value is Vector3:
		_camera_world_pos = camera_pos_value as Vector3
	var camera_extent_value: Variant = snapshot.get("camera_half_extent", Vector2(10.0, 10.0))
	if camera_extent_value is Vector2:
		_camera_world_half_extent = (camera_extent_value as Vector2).abs()
	queue_redraw()

func set_ping_mode(enabled: bool) -> void:
	_ping_mode = enabled
	_is_drag_navigate = false
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	var mouse_button: InputEventMouseButton = event as InputEventMouseButton
	if mouse_button != null and mouse_button.button_index == MOUSE_BUTTON_LEFT:
		if mouse_button.pressed:
			if _ping_mode:
				_emit_ping(mouse_button.position)
				_ping_mode = false
				_is_drag_navigate = false
			else:
				_is_drag_navigate = true
				_emit_navigation(mouse_button.position)
		else:
			_is_drag_navigate = false
		accept_event()
		return

	var mouse_motion: InputEventMouseMotion = event as InputEventMouseMotion
	if mouse_motion != null and _is_drag_navigate and (mouse_motion.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		_emit_navigation(mouse_motion.position)
		accept_event()

func _draw() -> void:
	var view_rect: Rect2 = Rect2(Vector2.ZERO, size)
	if view_rect.size.x <= 1.0 or view_rect.size.y <= 1.0:
		return

	draw_rect(view_rect, background_color, true)
	_draw_grid(view_rect)
	_draw_resources()
	_draw_buildings()
	_draw_units()
	_draw_pings()
	_draw_camera_rect()
	_draw_ping_mode_outline()
	draw_rect(view_rect, border_color, false, 1.0)

func _draw_grid(view_rect: Rect2) -> void:
	if grid_divisions <= 0:
		return
	var steps: int = maxi(1, grid_divisions)
	var grid_color: Color = Color(border_color.r, border_color.g, border_color.b, 0.22)
	for i in range(1, steps):
		var t: float = float(i) / float(steps)
		var x: float = lerpf(view_rect.position.x, view_rect.end.x, t)
		var y: float = lerpf(view_rect.position.y, view_rect.end.y, t)
		draw_line(Vector2(x, view_rect.position.y), Vector2(x, view_rect.end.y), grid_color, 1.0)
		draw_line(Vector2(view_rect.position.x, y), Vector2(view_rect.end.x, y), grid_color, 1.0)

func _draw_resources() -> void:
	for value in _resources:
		if not (value is Dictionary):
			continue
		var entry: Dictionary = value as Dictionary
		var world: Vector2 = _entry_world_xz(entry)
		var point: Vector2 = _world_to_minimap(world)
		draw_rect(Rect2(point - Vector2(1.5, 1.5), Vector2(3.0, 3.0)), resource_color, true)

func _draw_buildings() -> void:
	for value in _buildings:
		if not (value is Dictionary):
			continue
		var entry: Dictionary = value as Dictionary
		var world: Vector2 = _entry_world_xz(entry)
		var team_id: int = int(entry.get("team", 0))
		var selected: bool = bool(entry.get("selected", false))
		var point: Vector2 = _world_to_minimap(world)
		var color: Color = _team_color(team_id, player_building_color, enemy_building_color, neutral_unit_color)
		var rect: Rect2 = Rect2(point - Vector2(2.5, 2.5), Vector2(5.0, 5.0))
		draw_rect(rect, color, true)
		if selected:
			draw_rect(rect.grow(1.0), selected_outline_color, false, 1.0)

func _draw_units() -> void:
	for value in _units:
		if not (value is Dictionary):
			continue
		var entry: Dictionary = value as Dictionary
		var world: Vector2 = _entry_world_xz(entry)
		var team_id: int = int(entry.get("team", 0))
		var selected: bool = bool(entry.get("selected", false))
		var point: Vector2 = _world_to_minimap(world)
		var color: Color = _team_color(team_id, player_unit_color, enemy_unit_color, neutral_unit_color)
		draw_circle(point, 2.0, color)
		if selected:
			draw_arc(point, 3.5, 0.0, TAU, 18, selected_outline_color, 1.2)

func _draw_camera_rect() -> void:
	var map_full: Vector2 = _safe_map_full_size()
	var center: Vector2 = _world_to_minimap(Vector2(_camera_world_pos.x, _camera_world_pos.z))
	var half_size: Vector2 = Vector2(
		(_camera_world_half_extent.x / map_full.x) * size.x,
		(_camera_world_half_extent.y / map_full.y) * size.y
	)
	half_size.x = clampf(half_size.x, 2.0, size.x * 0.5)
	half_size.y = clampf(half_size.y, 2.0, size.y * 0.5)
	var rect: Rect2 = Rect2(center - half_size, half_size * 2.0)
	draw_rect(rect, camera_rect_color, false, 1.2)
	draw_circle(center, 1.8, camera_rect_color)

func _draw_pings() -> void:
	for value in _pings:
		if not (value is Dictionary):
			continue
		var entry: Dictionary = value as Dictionary
		var world: Vector2 = _entry_world_xz(entry)
		var progress: float = clampf(float(entry.get("progress", 0.0)), 0.0, 1.0)
		var ping_kind: String = str(entry.get("kind", "manual")).strip_edges().to_lower()
		var base_color: Color = alert_ping_color if ping_kind == "alert" else ping_color
		var center: Vector2 = _world_to_minimap(world)
		var radius: float = lerpf(4.0, 18.0, progress)
		var alpha: float = lerpf(0.95, 0.18, progress)
		var pulse_color: Color = Color(base_color.r, base_color.g, base_color.b, alpha)
		draw_arc(center, radius, 0.0, TAU, 32, pulse_color, 1.6)
		draw_circle(center, 1.6, Color(base_color.r, base_color.g, base_color.b, maxf(0.45, alpha)))

func _draw_ping_mode_outline() -> void:
	if not _ping_mode:
		return
	draw_rect(Rect2(Vector2.ZERO, size).grow(-1.0), ping_mode_outline_color, false, 2.0)

func _emit_navigation(local_position: Vector2) -> void:
	emit_signal("navigate_requested", _minimap_to_world(local_position))

func _emit_ping(local_position: Vector2) -> void:
	emit_signal("ping_requested", _minimap_to_world(local_position))

func _entry_world_xz(entry: Dictionary) -> Vector2:
	var x: float = float(entry.get("x", 0.0))
	var z: float = float(entry.get("z", 0.0))
	return Vector2(x, z)

func _safe_map_full_size() -> Vector2:
	var half_x: float = maxf(1.0, absf(map_half_size.x))
	var half_z: float = maxf(1.0, absf(map_half_size.y))
	return Vector2(half_x * 2.0, half_z * 2.0)

func _world_to_minimap(world_xz: Vector2) -> Vector2:
	var map_full: Vector2 = _safe_map_full_size()
	var u: float = (world_xz.x + map_half_size.x) / map_full.x
	var v: float = (world_xz.y + map_half_size.y) / map_full.y
	u = clampf(u, 0.0, 1.0)
	v = clampf(v, 0.0, 1.0)
	return Vector2(u * size.x, v * size.y)

func _minimap_to_world(local_position: Vector2) -> Vector3:
	var local_x: float = clampf(local_position.x, 0.0, maxf(1.0, size.x))
	var local_y: float = clampf(local_position.y, 0.0, maxf(1.0, size.y))
	var u: float = local_x / maxf(1.0, size.x)
	var v: float = local_y / maxf(1.0, size.y)
	var world_x: float = lerpf(-map_half_size.x, map_half_size.x, u)
	var world_z: float = lerpf(-map_half_size.y, map_half_size.y, v)
	return Vector3(world_x, 0.0, world_z)

func _team_color(team_id: int, ally: Color, enemy: Color, neutral: Color) -> Color:
	if team_id == player_team_id:
		return ally
	if team_id <= 0:
		return neutral
	return enemy
