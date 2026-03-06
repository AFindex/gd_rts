extends RefCounted
class_name RTSInteraction

const DEFAULT_AGENT_RADIUS: float = 0.32

static func flat_distance_xz(a: Vector3, b: Vector3) -> float:
	var delta: Vector3 = b - a
	delta.y = 0.0
	return delta.length()

static func is_within_distance_xz(a: Vector3, b: Vector3, distance_limit: float) -> bool:
	return flat_distance_xz(a, b) <= maxf(0.0, distance_limit)

static func compute_trigger_distance(
	source: Node3D,
	target: Node3D,
	base_range: float,
	trigger_buffer: float = 0.0,
	minimum_contact_padding: float = 0.0,
	include_target_obstacle: bool = true
) -> float:
	if source == null or target == null or not is_instance_valid(source) or not is_instance_valid(target):
		return maxf(0.0, base_range) + maxf(0.0, trigger_buffer)
	var source_radius: float = collision_radius_xz(source, false)
	var target_radius: float = collision_radius_xz(target, include_target_obstacle)
	var minimum_contact: float = source_radius + target_radius + maxf(0.0, minimum_contact_padding)
	return maxf(maxf(0.0, base_range), minimum_contact) + maxf(0.0, trigger_buffer)

static func is_triggered(
	source: Node3D,
	target: Node3D,
	base_range: float,
	trigger_buffer: float = 0.0,
	minimum_contact_padding: float = 0.0,
	include_target_obstacle: bool = true
) -> bool:
	if source == null or target == null or not is_instance_valid(source) or not is_instance_valid(target):
		return false
	var trigger_distance: float = compute_trigger_distance(
		source,
		target,
		base_range,
		trigger_buffer,
		minimum_contact_padding,
		include_target_obstacle
	)
	return is_within_distance_xz(source.global_position, target.global_position, trigger_distance)

static func compute_approach_point(
	source: Node3D,
	target: Node3D,
	desired_trigger_distance: float,
	preferred_direction: Vector3 = Vector3.ZERO,
	approach_factor: float = 0.92,
	minimum_spacing: float = 0.12,
	include_target_obstacle: bool = true
) -> Vector3:
	if source == null or not is_instance_valid(source):
		return Vector3.ZERO
	if target == null or not is_instance_valid(target):
		return source.global_position
	var outward: Vector3 = source.global_position - target.global_position
	outward.y = 0.0
	if outward.length_squared() <= 0.0001 and preferred_direction.length_squared() > 0.0001:
		outward = preferred_direction
		outward.y = 0.0
	if outward.length_squared() <= 0.0001:
		outward = Vector3.RIGHT
	var direction: Vector3 = outward.normalized()
	var source_radius: float = collision_radius_xz(source, false)
	var target_radius: float = collision_radius_xz(target, include_target_obstacle)
	var min_distance: float = source_radius + target_radius + maxf(0.0, minimum_spacing)
	var scaled_target_distance: float = maxf(0.1, desired_trigger_distance * clampf(approach_factor, 0.1, 1.0))
	var distance_from_target: float = maxf(scaled_target_distance, min_distance)
	var approach_point: Vector3 = target.global_position + direction * distance_from_target
	approach_point.y = source.global_position.y
	return approach_point

static func collision_radius_xz(node: Node3D, include_obstacle: bool = false) -> float:
	if node == null or not is_instance_valid(node):
		return 0.0
	var radius: float = _collision_shape_radius_xz(node)
	if radius <= 0.001:
		radius = _fallback_agent_radius(node)
	if include_obstacle:
		radius = maxf(radius, obstacle_radius_xz(node))
	return maxf(0.0, radius)

static func obstacle_radius_xz(node: Node3D) -> float:
	if node == null or not is_instance_valid(node):
		return 0.0
	var obstacle: NavigationObstacle3D = _find_navigation_obstacle(node)
	if obstacle == null:
		return 0.0
	var max_radius: float = 0.0
	var obstacle_scale: Vector3 = obstacle.scale
	for local_vertex in obstacle.vertices:
		var radial_length: float = Vector2(local_vertex.x * obstacle_scale.x, local_vertex.z * obstacle_scale.z).length()
		if radial_length > max_radius:
			max_radius = radial_length
	if max_radius <= 0.001:
		max_radius = maxf(0.0, float(obstacle.get("radius")))
	return max_radius

static func _collision_shape_radius_xz(node: Node3D) -> float:
	var shape_node: CollisionShape3D = _find_collision_shape(node)
	if shape_node == null or shape_node.shape == null:
		return 0.0
	var shape_global: Transform3D = node.global_transform * shape_node.transform
	var scale_x: float = shape_global.basis.x.length()
	var scale_z: float = shape_global.basis.z.length()
	var shape: Shape3D = shape_node.shape
	if shape is BoxShape3D:
		var box: BoxShape3D = shape as BoxShape3D
		var half_x: float = box.size.x * 0.5 * maxf(0.001, scale_x)
		var half_z: float = box.size.z * 0.5 * maxf(0.001, scale_z)
		return maxf(half_x, half_z)
	if shape is CapsuleShape3D:
		var capsule: CapsuleShape3D = shape as CapsuleShape3D
		return capsule.radius * maxf(0.001, maxf(scale_x, scale_z))
	if shape is CylinderShape3D:
		var cylinder: CylinderShape3D = shape as CylinderShape3D
		return cylinder.radius * maxf(0.001, maxf(scale_x, scale_z))
	if shape is SphereShape3D:
		var sphere: SphereShape3D = shape as SphereShape3D
		return sphere.radius * maxf(0.001, maxf(scale_x, scale_z))
	return 0.0

static func _find_collision_shape(node: Node3D) -> CollisionShape3D:
	if node == null or not is_instance_valid(node):
		return null
	var direct: CollisionShape3D = node.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if direct != null:
		return direct
	for child in node.get_children():
		var collision_child: CollisionShape3D = child as CollisionShape3D
		if collision_child != null:
			return collision_child
	return null

static func _find_navigation_obstacle(node: Node3D) -> NavigationObstacle3D:
	if node == null or not is_instance_valid(node):
		return null
	var named: NavigationObstacle3D = node.get_node_or_null("Obstacle3D") as NavigationObstacle3D
	if named != null:
		return named
	var generic_named: NavigationObstacle3D = node.get_node_or_null("NavigationObstacle3D") as NavigationObstacle3D
	if generic_named != null:
		return generic_named
	for child in node.get_children():
		var obstacle_child: NavigationObstacle3D = child as NavigationObstacle3D
		if obstacle_child != null:
			return obstacle_child
	return null

static func _fallback_agent_radius(node: Node3D) -> float:
	if node == null or not is_instance_valid(node):
		return DEFAULT_AGENT_RADIUS
	var nav_agent: NavigationAgent3D = node.get_node_or_null("NavigationAgent3D") as NavigationAgent3D
	if nav_agent != null:
		return maxf(0.0, nav_agent.radius)
	return DEFAULT_AGENT_RADIUS
