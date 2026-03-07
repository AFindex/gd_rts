extends Node3D
class_name BuildPlacementGrid3D

const OCCUPANCY_BUILDING: StringName = &"building"
const OCCUPANCY_RESOURCE: StringName = &"resource"
const OCCUPANCY_UNIT: StringName = &"unit"
const OCCUPANCY_PENDING: StringName = &"pending"
const BLOCKING_CATEGORIES: Array[StringName] = [
	OCCUPANCY_BUILDING,
	OCCUPANCY_RESOURCE,
	OCCUPANCY_UNIT,
	OCCUPANCY_PENDING
]

@export var bounds_min: Vector2 = Vector2(-56.0, -56.0)
@export var bounds_max: Vector2 = Vector2(56.0, 56.0)
@export var cell_size: float = 0.5
@export var line_height: float = 0.022
@export var occupancy_height: float = 0.028
@export var preview_height: float = 0.034
@export var pulse_speed: float = 3.6
@export var default_building_footprint: Vector2 = Vector2(2.6, 1.8)
@export var fallback_resource_radius: float = 1.3
@export var fallback_unit_radius: float = 0.42
@export var line_color: Color = Color(0.26, 0.83, 1.0, 0.22)
@export var occupied_structure_color: Color = Color(1.0, 0.25, 0.25, 0.48)
@export var occupied_resource_color: Color = Color(0.95, 0.72, 0.18, 0.45)
@export var occupied_unit_color: Color = Color(1.0, 0.5, 0.22, 0.38)
@export var preview_valid_color: Color = Color(0.22, 0.95, 0.38, 0.34)
@export var preview_invalid_color: Color = Color(0.98, 0.18, 0.18, 0.38)

var _line_mesh_instance: MeshInstance3D
var _occupancy_mesh_instance: MeshInstance3D
var _preview_mesh_instance: MeshInstance3D
var _line_material: StandardMaterial3D
var _occupancy_material: StandardMaterial3D
var _preview_material: StandardMaterial3D
var _occupancy_by_cell: Dictionary = {}
var _cell_count_x: int = 0
var _cell_count_z: int = 0
var _build_mode_enabled: bool = false

func _ready() -> void:
	_recompute_grid_metrics()
	_create_visual_nodes()
	_rebuild_grid_lines_mesh()
	set_build_mode_enabled(false)

func _process(_delta: float) -> void:
	if not _build_mode_enabled:
		return
	var pulse: float = 0.75 + 0.25 * sin(float(Time.get_ticks_msec()) * 0.001 * pulse_speed)
	if _line_material != null:
		_line_material.emission_energy_multiplier = 0.24 + pulse * 0.28
	if _occupancy_material != null:
		_occupancy_material.emission_energy_multiplier = 0.4 + pulse * 0.45
	if _preview_material != null:
		_preview_material.emission_energy_multiplier = 0.58 + pulse * 0.52

func set_build_mode_enabled(enabled: bool) -> void:
	_build_mode_enabled = enabled
	visible = enabled
	if not enabled:
		clear_preview()

func clear_preview() -> void:
	if _preview_mesh_instance != null:
		_preview_mesh_instance.mesh = null

func is_world_inside(world_position: Vector3) -> bool:
	return (
		world_position.x >= bounds_min.x
		and world_position.x <= bounds_max.x
		and world_position.z >= bounds_min.y
		and world_position.z <= bounds_max.y
	)

func snap_world_position(world_position: Vector3) -> Vector3:
	var safe_cell_size: float = maxf(0.01, cell_size)
	var clamped_x: float = clampf(world_position.x, bounds_min.x, bounds_max.x)
	var clamped_z: float = clampf(world_position.z, bounds_min.y, bounds_max.y)
	var snapped_cell: Vector2i = Vector2i(
		clampi(int(roundf((clamped_x - bounds_min.x) / safe_cell_size)), 0, _cell_count_x),
		clampi(int(roundf((clamped_z - bounds_min.y) / safe_cell_size)), 0, _cell_count_z)
	)
	var snapped_world: Vector3 = _cell_to_world(snapped_cell)
	snapped_world.y = preview_height
	return snapped_world

func world_to_cell(world_position: Vector3) -> Vector2i:
	var safe_cell_size: float = maxf(0.01, cell_size)
	var clamped_x: float = clampf(world_position.x, bounds_min.x, bounds_max.x)
	var clamped_z: float = clampf(world_position.z, bounds_min.y, bounds_max.y)
	return Vector2i(
		clampi(int(roundf((clamped_x - bounds_min.x) / safe_cell_size)), 0, _cell_count_x),
		clampi(int(roundf((clamped_z - bounds_min.y) / safe_cell_size)), 0, _cell_count_z)
	)

func sync_occupancy(building_nodes: Array, resource_nodes: Array, unit_nodes: Array, pending_entries: Array) -> void:
	_occupancy_by_cell.clear()
	for node_value in building_nodes:
		_mark_node_occupancy(node_value as Node, OCCUPANCY_BUILDING)
	for node_value in resource_nodes:
		_mark_node_occupancy(node_value as Node, OCCUPANCY_RESOURCE)
	for node_value in unit_nodes:
		_mark_node_occupancy(node_value as Node, OCCUPANCY_UNIT)
	for pending_entry in pending_entries:
		_mark_pending_occupancy(pending_entry)
	_rebuild_occupancy_mesh()

func can_place_building(world_position: Vector3, rotation_y: float, footprint_size: Vector2) -> bool:
	var normalized_size: Vector2 = _normalized_footprint_size(footprint_size)
	if not _is_footprint_inside_bounds(world_position, normalized_size, rotation_y):
		return false
	var candidate_cells: Array[Vector2i] = _collect_cells_for_oriented_rect(world_position, normalized_size, rotation_y)
	if candidate_cells.is_empty():
		return false
	for cell in candidate_cells:
		var entry: Dictionary = _occupancy_by_cell.get(cell, {})
		if _entry_has_any_category(entry, BLOCKING_CATEGORIES):
			return false
	return true

func get_cell_occupancy(world_position: Vector3) -> Dictionary:
	var cell: Vector2i = world_to_cell(world_position)
	var entry_value: Variant = _occupancy_by_cell.get(cell, {})
	if entry_value is Dictionary:
		return (entry_value as Dictionary).duplicate(true)
	return {}

func set_preview_footprint(world_position: Vector3, rotation_y: float, footprint_size: Vector2, can_place: bool) -> void:
	if not _build_mode_enabled:
		clear_preview()
		return
	var normalized_size: Vector2 = _normalized_footprint_size(footprint_size)
	if not _is_footprint_inside_bounds(world_position, normalized_size, rotation_y):
		clear_preview()
		return
	var preview_color: Color = preview_valid_color if can_place else preview_invalid_color
	var preview_cells: Array[Vector2i] = _collect_cells_for_oriented_rect(world_position, normalized_size, rotation_y)
	if preview_cells.is_empty():
		preview_cells.append(world_to_cell(world_position))
	_preview_mesh_instance.mesh = _build_cells_mesh(preview_cells, preview_height, 0.92, preview_color)

func _recompute_grid_metrics() -> void:
	var safe_cell_size: float = maxf(0.01, cell_size)
	_cell_count_x = maxi(1, int(roundf((bounds_max.x - bounds_min.x) / safe_cell_size)))
	_cell_count_z = maxi(1, int(roundf((bounds_max.y - bounds_min.y) / safe_cell_size)))

func _create_visual_nodes() -> void:
	_line_mesh_instance = MeshInstance3D.new()
	_line_mesh_instance.name = "GridLines"
	_line_material = _create_vertex_material(line_color, true)
	_line_mesh_instance.material_override = _line_material
	add_child(_line_mesh_instance)

	_occupancy_mesh_instance = MeshInstance3D.new()
	_occupancy_mesh_instance.name = "OccupancyOverlay"
	_occupancy_material = _create_vertex_material(Color.WHITE, true)
	_occupancy_mesh_instance.material_override = _occupancy_material
	add_child(_occupancy_mesh_instance)

	_preview_mesh_instance = MeshInstance3D.new()
	_preview_mesh_instance.name = "PreviewOverlay"
	_preview_material = _create_vertex_material(Color.WHITE, true)
	_preview_mesh_instance.material_override = _preview_material
	add_child(_preview_mesh_instance)

func _create_vertex_material(default_color: Color, no_depth_test: bool) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.vertex_color_use_as_albedo = true
	material.albedo_color = default_color
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.no_depth_test = no_depth_test
	material.emission_enabled = true
	material.emission = Color(default_color.r, default_color.g, default_color.b, 1.0)
	material.emission_energy_multiplier = 0.35
	return material

func _rebuild_grid_lines_mesh() -> void:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_LINES)
	for x_idx in range(_cell_count_x + 1):
		var x: float = bounds_min.x + float(x_idx) * cell_size
		st.set_color(line_color)
		st.add_vertex(Vector3(x, line_height, bounds_min.y))
		st.set_color(line_color)
		st.add_vertex(Vector3(x, line_height, bounds_max.y))
	for z_idx in range(_cell_count_z + 1):
		var z: float = bounds_min.y + float(z_idx) * cell_size
		st.set_color(line_color)
		st.add_vertex(Vector3(bounds_min.x, line_height, z))
		st.set_color(line_color)
		st.add_vertex(Vector3(bounds_max.x, line_height, z))
	_line_mesh_instance.mesh = st.commit()

func _rebuild_occupancy_mesh() -> void:
	if _occupancy_by_cell.is_empty():
		_occupancy_mesh_instance.mesh = null
		return
	var cells: Array[Vector2i] = []
	var colors: Array[Color] = []
	for cell_key in _occupancy_by_cell.keys():
		var cell: Vector2i = cell_key as Vector2i
		var entry: Dictionary = _occupancy_by_cell.get(cell, {})
		var cell_color: Color = _occupancy_color(entry)
		if cell_color.a <= 0.001:
			continue
		cells.append(cell)
		colors.append(cell_color)
	_occupancy_mesh_instance.mesh = _build_cells_mesh_with_colors(cells, colors, occupancy_height, 0.84)

func _build_cells_mesh(cells: Array[Vector2i], y: float, fill_ratio: float, color: Color) -> ArrayMesh:
	var colors: Array[Color] = []
	for _cell in cells:
		colors.append(color)
	return _build_cells_mesh_with_colors(cells, colors, y, fill_ratio)

func _build_cells_mesh_with_colors(cells: Array[Vector2i], colors: Array[Color], y: float, fill_ratio: float) -> ArrayMesh:
	if cells.is_empty():
		return null
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ratio: float = clampf(fill_ratio, 0.2, 1.0)
	for idx in cells.size():
		var cell: Vector2i = cells[idx]
		var color: Color = colors[idx] if idx < colors.size() else Color(1.0, 1.0, 1.0, 0.25)
		var center: Vector3 = _cell_to_world(cell)
		_append_cell_quad(st, center, y, ratio, color)
	return st.commit()

func _append_cell_quad(st: SurfaceTool, center: Vector3, y: float, fill_ratio: float, color: Color) -> void:
	var half_size: float = cell_size * 0.5 * fill_ratio
	var x0: float = center.x - half_size
	var x1: float = center.x + half_size
	var z0: float = center.z - half_size
	var z1: float = center.z + half_size
	var a: Vector3 = Vector3(x0, y, z0)
	var b: Vector3 = Vector3(x1, y, z0)
	var c: Vector3 = Vector3(x1, y, z1)
	var d: Vector3 = Vector3(x0, y, z1)
	st.set_color(color)
	st.add_vertex(a)
	st.set_color(color)
	st.add_vertex(b)
	st.set_color(color)
	st.add_vertex(c)
	st.set_color(color)
	st.add_vertex(a)
	st.set_color(color)
	st.add_vertex(c)
	st.set_color(color)
	st.add_vertex(d)

func _mark_node_occupancy(node: Node, category: StringName) -> void:
	var node_3d: Node3D = node as Node3D
	if node_3d == null or not is_instance_valid(node_3d):
		return
	if node_3d.has_method("is_alive") and not bool(node_3d.call("is_alive")):
		return
	var shape_info: Dictionary = _node_occupancy_shape(node_3d, category)
	var mode: String = str(shape_info.get("mode", ""))
	var center_value: Variant = shape_info.get("center", node_3d.global_position)
	var center: Vector3 = center_value as Vector3 if center_value is Vector3 else node_3d.global_position
	if mode == "rect":
		var size_value: Variant = shape_info.get("size", default_building_footprint)
		var size: Vector2 = size_value as Vector2 if size_value is Vector2 else default_building_footprint
		var rotation_y: float = float(shape_info.get("rotation_y", node_3d.rotation.y))
		_mark_oriented_rect(center, size, rotation_y, category)
	elif mode == "circle":
		var radius: float = maxf(0.05, float(shape_info.get("radius", _fallback_radius_for(category))))
		_mark_circle(center, radius, category)
	else:
		_mark_oriented_rect(center, default_building_footprint, node_3d.rotation.y, category)

func _mark_pending_occupancy(entry_value: Variant) -> void:
	if entry_value is Vector3:
		_mark_oriented_rect(entry_value as Vector3, default_building_footprint, 0.0, OCCUPANCY_PENDING)
		return
	if not (entry_value is Dictionary):
		return
	var entry: Dictionary = entry_value as Dictionary
	var position_value: Variant = entry.get("position", Vector3.ZERO)
	if not (position_value is Vector3):
		return
	var center: Vector3 = position_value as Vector3
	var rotation_y: float = float(entry.get("rotation_y", 0.0))
	var footprint_value: Variant = entry.get("footprint_size", default_building_footprint)
	var footprint: Vector2 = footprint_value as Vector2 if footprint_value is Vector2 else default_building_footprint
	_mark_oriented_rect(center, footprint, rotation_y, OCCUPANCY_PENDING)

func _node_occupancy_shape(node_3d: Node3D, category: StringName) -> Dictionary:
	var shape_node: CollisionShape3D = _find_collision_shape(node_3d)
	if shape_node == null or shape_node.shape == null:
		if category == OCCUPANCY_UNIT:
			return {"mode": "circle", "center": node_3d.global_position, "radius": fallback_unit_radius}
		if category == OCCUPANCY_RESOURCE:
			return {"mode": "circle", "center": node_3d.global_position, "radius": fallback_resource_radius}
		return {"mode": "rect", "center": node_3d.global_position, "size": default_building_footprint, "rotation_y": node_3d.rotation.y}
	var shape_global: Transform3D = node_3d.global_transform * shape_node.transform
	var center: Vector3 = shape_global.origin
	var scale_x: float = shape_global.basis.x.length()
	var scale_z: float = shape_global.basis.z.length()
	var shape: Shape3D = shape_node.shape
	if shape is BoxShape3D:
		var box: BoxShape3D = shape as BoxShape3D
		return {
			"mode": "rect",
			"center": center,
			"size": Vector2(maxf(0.05, box.size.x * maxf(0.001, scale_x)), maxf(0.05, box.size.z * maxf(0.001, scale_z))),
			"rotation_y": _basis_yaw(shape_global.basis)
		}
	if shape is CapsuleShape3D:
		var capsule: CapsuleShape3D = shape as CapsuleShape3D
		return {
			"mode": "circle",
			"center": center,
			"radius": maxf(0.05, capsule.radius * maxf(0.001, maxf(scale_x, scale_z)))
		}
	if shape is CylinderShape3D:
		var cylinder: CylinderShape3D = shape as CylinderShape3D
		return {
			"mode": "circle",
			"center": center,
			"radius": maxf(0.05, cylinder.radius * maxf(0.001, maxf(scale_x, scale_z)))
		}
	if shape is SphereShape3D:
		var sphere: SphereShape3D = shape as SphereShape3D
		return {
			"mode": "circle",
			"center": center,
			"radius": maxf(0.05, sphere.radius * maxf(0.001, maxf(scale_x, scale_z)))
		}
	if category == OCCUPANCY_UNIT:
		return {"mode": "circle", "center": center, "radius": fallback_unit_radius}
	if category == OCCUPANCY_RESOURCE:
		return {"mode": "circle", "center": center, "radius": fallback_resource_radius}
	return {"mode": "rect", "center": center, "size": default_building_footprint, "rotation_y": node_3d.rotation.y}

func _fallback_radius_for(category: StringName) -> float:
	if category == OCCUPANCY_RESOURCE:
		return fallback_resource_radius
	if category == OCCUPANCY_UNIT:
		return fallback_unit_radius
	return maxf(0.1, default_building_footprint.length() * 0.3)

func _find_collision_shape(node_3d: Node3D) -> CollisionShape3D:
	if node_3d == null or not is_instance_valid(node_3d):
		return null
	var direct: CollisionShape3D = node_3d.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if direct != null:
		return direct
	for child in node_3d.get_children():
		var shape_child: CollisionShape3D = child as CollisionShape3D
		if shape_child != null:
			return shape_child
	return null

func _basis_yaw(basis: Basis) -> float:
	var x_axis: Vector3 = basis.x.normalized()
	return atan2(x_axis.z, x_axis.x)

func _mark_oriented_rect(center: Vector3, size: Vector2, rotation_y: float, category: StringName) -> void:
	var cells: Array[Vector2i] = _collect_cells_for_oriented_rect(center, _normalized_footprint_size(size), rotation_y)
	for cell in cells:
		_mark_cell_occupancy(cell, category)

func _mark_circle(center: Vector3, radius: float, category: StringName) -> void:
	var cells: Array[Vector2i] = _collect_cells_within_radius(center, radius)
	for cell in cells:
		_mark_cell_occupancy(cell, category)

func _mark_cell_occupancy(cell: Vector2i, category: StringName) -> void:
	if not _is_cell_inside(cell):
		return
	var entry_value: Variant = _occupancy_by_cell.get(cell, {})
	var entry: Dictionary
	if entry_value is Dictionary:
		entry = entry_value as Dictionary
	else:
		entry = {}
	entry[category] = int(entry.get(category, 0)) + 1
	_occupancy_by_cell[cell] = entry

func _normalized_footprint_size(raw_size: Vector2) -> Vector2:
	var source: Vector2 = raw_size
	if source.x <= 0.001 or source.y <= 0.001:
		source = default_building_footprint
	return Vector2(maxf(0.05, source.x), maxf(0.05, source.y))

func _collect_cells_for_oriented_rect(center: Vector3, size: Vector2, rotation_y: float) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var center_cell: Vector2i = world_to_cell(center)
	var half_x: float = size.x * 0.5
	var half_z: float = size.y * 0.5
	var search_radius: float = Vector2(half_x, half_z).length() + cell_size * 0.75
	var search_steps: int = maxi(0, int(ceil(search_radius / maxf(0.01, cell_size))))
	var cell_half_pad: float = cell_size * 0.5
	for z_offset in range(-search_steps, search_steps + 1):
		for x_offset in range(-search_steps, search_steps + 1):
			var cell: Vector2i = center_cell + Vector2i(x_offset, z_offset)
			if not _is_cell_inside(cell):
				continue
			var cell_world: Vector3 = _cell_to_world(cell)
			var local: Vector2 = _rotate_2d(
				Vector2(cell_world.x - center.x, cell_world.z - center.z),
				-rotation_y
			)
			if absf(local.x) <= half_x + cell_half_pad and absf(local.y) <= half_z + cell_half_pad:
				cells.append(cell)
	return cells

func _collect_cells_within_radius(world_position: Vector3, radius: float) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var center_cell: Vector2i = world_to_cell(world_position)
	var safe_radius: float = maxf(0.0, radius)
	var search_steps: int = maxi(0, int(ceil(safe_radius / maxf(0.01, cell_size))))
	var half_diag: float = cell_size * 0.5 * 1.415
	var expanded_radius_sq: float = (safe_radius + half_diag) * (safe_radius + half_diag)
	for z_offset in range(-search_steps, search_steps + 1):
		for x_offset in range(-search_steps, search_steps + 1):
			var cell: Vector2i = center_cell + Vector2i(x_offset, z_offset)
			if not _is_cell_inside(cell):
				continue
			var cell_world: Vector3 = _cell_to_world(cell)
			var delta_x: float = cell_world.x - world_position.x
			var delta_z: float = cell_world.z - world_position.z
			var distance_sq: float = delta_x * delta_x + delta_z * delta_z
			if safe_radius <= 0.001:
				if distance_sq <= half_diag * half_diag:
					cells.append(cell)
			elif distance_sq <= expanded_radius_sq:
				cells.append(cell)
	return cells

func _is_footprint_inside_bounds(world_position: Vector3, footprint_size: Vector2, rotation_y: float) -> bool:
	var half_x: float = footprint_size.x * 0.5
	var half_z: float = footprint_size.y * 0.5
	var corners: Array[Vector2] = [
		Vector2(-half_x, -half_z),
		Vector2(half_x, -half_z),
		Vector2(half_x, half_z),
		Vector2(-half_x, half_z)
	]
	for corner in corners:
		var rotated: Vector2 = _rotate_2d(corner, rotation_y)
		var wx: float = world_position.x + rotated.x
		var wz: float = world_position.z + rotated.y
		if wx < bounds_min.x or wx > bounds_max.x:
			return false
		if wz < bounds_min.y or wz > bounds_max.y:
			return false
	return true

func _rotate_2d(v: Vector2, angle: float) -> Vector2:
	var c: float = cos(angle)
	var s: float = sin(angle)
	return Vector2(v.x * c - v.y * s, v.x * s + v.y * c)

func _entry_has_any_category(entry: Dictionary, categories: Array) -> bool:
	for category_value in categories:
		var category: StringName = StringName(str(category_value))
		if int(entry.get(category, 0)) > 0:
			return true
	return false

func _occupancy_color(entry: Dictionary) -> Color:
	var building_count: int = int(entry.get(OCCUPANCY_BUILDING, 0))
	var resource_count: int = int(entry.get(OCCUPANCY_RESOURCE, 0))
	var unit_count: int = int(entry.get(OCCUPANCY_UNIT, 0))
	var pending_count: int = int(entry.get(OCCUPANCY_PENDING, 0))
	if resource_count > 0:
		return occupied_resource_color
	if building_count > 0 or pending_count > 0:
		return occupied_structure_color
	if unit_count > 0:
		return occupied_unit_color
	return Color(0.0, 0.0, 0.0, 0.0)

func _is_cell_inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x <= _cell_count_x and cell.y >= 0 and cell.y <= _cell_count_z

func _cell_to_world(cell: Vector2i) -> Vector3:
	return Vector3(
		bounds_min.x + float(cell.x) * cell_size,
		0.0,
		bounds_min.y + float(cell.y) * cell_size
	)
