extends StaticBody3D

const RTS_CATALOG: Script = preload("res://scripts/core/rts_catalog.gd")
const RALLY_MAX_HOPS: int = 3
const RALLY_ALERT_DURATION: float = 1.2

signal production_finished(unit_kind: String, spawn_position: Vector3)

@export var building_kind: String = "base"
@export var team_id: int = 1
@export var max_health: float = 1200.0
@export var is_resource_dropoff: bool = true
@export var can_queue_worker: bool = true
@export var can_queue_soldier: bool = false
@export var worker_build_time: float = 2.8
@export var soldier_build_time: float = 4.6
@export var queue_limit: int = 6
@export var spawn_offset: Vector3 = Vector3(3.2, 0.0, 0.0)
@export var attack_range: float = 0.0
@export var attack_damage: float = 0.0
@export var attack_cooldown: float = 1.0

@onready var _selection_ring: MeshInstance3D = $SelectionRing
@onready var _sprite: Sprite3D = $Sprite3D

var _queue_unit_kinds: Array[String] = []
var _queue_build_times: Array[float] = []
var _production_timer: float = 0.0
var _health: float = 1200.0
var _attack_target: Node = null
var _attack_timer: float = 0.0
var _base_tint: Color = Color.WHITE
var _has_rally_point: bool = false
var _rally_point_position: Vector3 = Vector3.ZERO
var _rally_target_node: Node = null
var _rally_mode: String = "ground"
var _rally_hops: Array[Dictionary] = []
var _rally_alert_timer: float = 0.0

func _ready() -> void:
	add_to_group("selectable_building")
	_apply_building_config(building_kind)
	_health = max_health
	_refresh_dropoff_group()
	_apply_building_visual()
	_selection_ring.visible = false

func _process(delta: float) -> void:
	if _rally_alert_timer > 0.0:
		_rally_alert_timer = maxf(0.0, _rally_alert_timer - delta)

	if _queue_unit_kinds.is_empty():
		_production_timer = 0.0
	else:
		_production_timer += delta
		var current_build_time: float = _queue_build_times[0]
		if _production_timer >= current_build_time:
			_production_timer = 0.0
			var unit_kind: String = _queue_unit_kinds[0]
			_queue_unit_kinds.remove_at(0)
			_queue_build_times.remove_at(0)
			emit_signal("production_finished", unit_kind, _get_spawn_position())

	if building_kind == "tower":
		_process_tower_combat(delta)

func set_selected(selected: bool) -> void:
	_selection_ring.visible = selected

func get_team_id() -> int:
	return team_id

func is_alive() -> bool:
	return _health > 0.0

func get_health_ratio() -> float:
	if max_health <= 0.0:
		return 0.0
	return clampf(_health / max_health, 0.0, 1.0)

func get_health_points() -> float:
	return _health

func apply_damage(amount: float, _source: Node = null) -> void:
	if amount <= 0.0 or not is_alive():
		return
	_rally_alert_timer = RALLY_ALERT_DURATION
	_health = maxf(0.0, _health - amount)
	_play_hit_flash()
	if _health <= 0.0:
		_die()

func can_queue_worker_unit() -> bool:
	if not can_queue_worker:
		return false
	return not is_queue_full()

func can_queue_soldier_unit() -> bool:
	if not can_queue_soldier:
		return false
	return not is_queue_full()

func queue_worker() -> bool:
	if not can_queue_worker_unit():
		return false
	_queue_unit_kinds.append("worker")
	_queue_build_times.append(worker_build_time)
	return true

func queue_soldier() -> bool:
	if not can_queue_soldier_unit():
		return false
	_queue_unit_kinds.append("soldier")
	_queue_build_times.append(soldier_build_time)
	return true

func get_queue_size() -> int:
	return _queue_unit_kinds.size()

func get_queue_limit() -> int:
	return queue_limit

func is_queue_full() -> bool:
	if queue_limit <= 0:
		return true
	return _queue_unit_kinds.size() >= queue_limit

func has_active_queue() -> bool:
	return not _queue_unit_kinds.is_empty()

func get_production_progress() -> float:
	if _queue_unit_kinds.is_empty():
		return 0.0
	var current_build_time: float = _queue_build_times[0]
	if current_build_time <= 0.0:
		return 1.0
	return clampf(_production_timer / current_build_time, 0.0, 1.0)

func get_primary_queue_kind() -> String:
	if _queue_unit_kinds.is_empty():
		return ""
	return _queue_unit_kinds[0]

func get_queue_preview(max_items: int = 5) -> Array[String]:
	var preview: Array[String] = []
	if max_items <= 0:
		return preview
	var max_count: int = mini(max_items, _queue_unit_kinds.size())
	for i in max_count:
		preview.append(_format_unit_kind(_queue_unit_kinds[i]))
	return preview

func get_building_display_name() -> String:
	var building_def: Dictionary = RTS_CATALOG.get_building_def(building_kind)
	return str(building_def.get("display_name", "Building"))

func get_building_role_tag() -> String:
	var building_def: Dictionary = RTS_CATALOG.get_building_def(building_kind)
	return str(building_def.get("role_tag", "Building"))

func get_skill_ids() -> Array[String]:
	return RTS_CATALOG.get_building_skill_ids(building_kind)

func get_build_skill_ids() -> Array[String]:
	return RTS_CATALOG.get_building_build_skill_ids(building_kind)

func supports_rally_point() -> bool:
	return can_queue_worker or can_queue_soldier

func set_rally_point(target_position: Vector3, target_node: Node = null, mode: String = "ground", append_hop: bool = false) -> bool:
	if not supports_rally_point():
		return false
	var normalized_position: Vector3 = Vector3(target_position.x, 0.0, target_position.z)
	var hop: Dictionary = {
		"position": normalized_position,
		"target_node": target_node,
		"mode": mode
	}
	if append_hop:
		if _rally_hops.size() >= RALLY_MAX_HOPS:
			return false
		_rally_hops.append(hop)
	else:
		_rally_hops.clear()
		_rally_hops.append(hop)
	_sync_rally_legacy_fields()
	return true

func clear_rally_point() -> void:
	_rally_hops.clear()
	_has_rally_point = false
	_rally_point_position = Vector3.ZERO
	_rally_target_node = null
	_rally_mode = "ground"

func get_rally_point_data() -> Dictionary:
	if _rally_hops.is_empty() and not _has_rally_point:
		return {}
	var hops: Array[Dictionary] = []
	for hop_value in _rally_hops:
		if not (hop_value is Dictionary):
			continue
		var hop: Dictionary = hop_value as Dictionary
		var hop_position_value: Variant = hop.get("position", Vector3.ZERO)
		if not (hop_position_value is Vector3):
			continue
		var hop_position: Vector3 = hop_position_value as Vector3
		var hop_target_node: Node = hop.get("target_node") as Node
		var valid_target: Node = null
		if hop_target_node != null and is_instance_valid(hop_target_node):
			valid_target = hop_target_node
		hops.append({
			"position": Vector3(hop_position.x, 0.0, hop_position.z),
			"target_node": valid_target,
			"mode": str(hop.get("mode", "ground"))
		})
	if hops.is_empty():
		var fallback_target: Node = null
		if _rally_target_node != null and is_instance_valid(_rally_target_node):
			fallback_target = _rally_target_node
		hops.append({
			"position": _rally_point_position,
			"target_node": fallback_target,
			"mode": _rally_mode
		})
	var first_hop: Dictionary = hops[0]
	return {
		"position": first_hop.get("position", Vector3.ZERO),
		"target_node": first_hop.get("target_node", null),
		"mode": str(first_hop.get("mode", "ground")),
		"hops": hops,
		"max_hops": RALLY_MAX_HOPS
	}

func get_rally_hop_count() -> int:
	if not _rally_hops.is_empty():
		return _rally_hops.size()
	return 1 if _has_rally_point else 0

func is_rally_alerting() -> bool:
	return _rally_alert_timer > 0.0

func _sync_rally_legacy_fields() -> void:
	if _rally_hops.is_empty():
		_has_rally_point = false
		_rally_point_position = Vector3.ZERO
		_rally_target_node = null
		_rally_mode = "ground"
		return
	var first_hop: Dictionary = _rally_hops[0]
	var first_position: Variant = first_hop.get("position", Vector3.ZERO)
	_has_rally_point = true
	if first_position is Vector3:
		_rally_point_position = first_position as Vector3
	else:
		_rally_point_position = Vector3.ZERO
	_rally_target_node = first_hop.get("target_node") as Node
	_rally_mode = str(first_hop.get("mode", "ground"))

func configure_by_kind(kind: String) -> void:
	_apply_building_config(kind)
	_queue_unit_kinds.clear()
	_queue_build_times.clear()
	_production_timer = 0.0
	_rally_alert_timer = 0.0
	_attack_target = null
	_attack_timer = 0.0
	clear_rally_point()
	_health = max_health
	_refresh_dropoff_group()
	_apply_building_visual()

func configure_as_barracks() -> void:
	configure_by_kind("barracks")

func configure_as_tower() -> void:
	configure_by_kind("tower")

func _refresh_dropoff_group() -> void:
	if is_resource_dropoff:
		if not is_in_group("resource_dropoff"):
			add_to_group("resource_dropoff")
	else:
		if is_in_group("resource_dropoff"):
			remove_from_group("resource_dropoff")

func _get_spawn_position() -> Vector3:
	return global_position + spawn_offset.rotated(Vector3.UP, rotation.y)

func _apply_building_visual() -> void:
	if _sprite == null:
		return
	var building_color: Color
	if building_kind == "barracks":
		building_color = Color(1.0, 0.6, 0.25, 1.0)
		_sprite.scale = Vector3(1.3, 1.3, 1.3)
	elif building_kind == "tower":
		building_color = Color(0.95, 0.72, 0.3, 1.0)
		_sprite.scale = Vector3(1.15, 1.15, 1.15)
	elif building_kind == "academy":
		building_color = Color(0.5, 0.88, 1.0, 1.0)
		_sprite.scale = Vector3(1.32, 1.32, 1.32)
	elif building_kind == "engineering_bay":
		building_color = Color(0.72, 0.96, 0.62, 1.0)
		_sprite.scale = Vector3(1.34, 1.34, 1.34)
	elif building_kind == "tech_lab":
		building_color = Color(0.98, 0.72, 0.46, 1.0)
		_sprite.scale = Vector3(1.36, 1.36, 1.36)
	else:
		building_color = Color(0.95, 0.95, 1.0, 1.0)
		_sprite.scale = Vector3(1.45, 1.45, 1.45)
	if team_id != 1:
		building_color = Color(0.55, 0.75, 1.0, 1.0)
	_base_tint = building_color
	_sprite.modulate = building_color

func _format_unit_kind(unit_kind: String) -> String:
	if unit_kind == "worker":
		return "Worker"
	if unit_kind == "soldier":
		return "Soldier"
	return unit_kind.capitalize()

func _apply_building_config(kind: String) -> void:
	var building_def: Dictionary = RTS_CATALOG.get_building_def(kind)
	if building_def.is_empty():
		return
	building_kind = kind
	max_health = float(building_def.get("max_health", max_health))
	attack_range = float(building_def.get("attack_range", attack_range))
	attack_damage = float(building_def.get("attack_damage", attack_damage))
	attack_cooldown = float(building_def.get("attack_cooldown", attack_cooldown))
	is_resource_dropoff = bool(building_def.get("is_resource_dropoff", is_resource_dropoff))
	can_queue_worker = bool(building_def.get("can_queue_worker", can_queue_worker))
	can_queue_soldier = bool(building_def.get("can_queue_soldier", can_queue_soldier))
	worker_build_time = float(building_def.get("worker_build_time", worker_build_time))
	soldier_build_time = float(building_def.get("soldier_build_time", soldier_build_time))
	queue_limit = int(building_def.get("queue_limit", queue_limit))
	var configured_spawn_offset: Variant = building_def.get("spawn_offset", spawn_offset)
	if configured_spawn_offset is Vector3:
		spawn_offset = configured_spawn_offset as Vector3

func _process_tower_combat(delta: float) -> void:
	if not is_alive() or attack_damage <= 0.0 or attack_range <= 0.0:
		return

	if _attack_target == null or not is_instance_valid(_attack_target) or not _is_valid_enemy_target(_attack_target) or not _is_target_in_range(_attack_target):
		_attack_target = _acquire_tower_target()
		_attack_timer = 0.0
	if _attack_target == null:
		return

	_attack_timer += delta
	var cooldown: float = maxf(0.05, attack_cooldown)
	if _attack_timer < cooldown:
		return
	_attack_timer = 0.0
	var attack_target_3d: Node3D = _attack_target as Node3D
	if attack_target_3d != null and _attack_target.has_method("apply_damage"):
		var hit_position: Vector3 = attack_target_3d.global_position
		_attack_target.call("apply_damage", attack_damage, self)
		_spawn_attack_vfx(hit_position)

func _acquire_tower_target() -> Node3D:
	var range_sq: float = attack_range * attack_range
	var unit_target: Node3D = _find_nearest_enemy_in_group("selectable_unit", range_sq)
	if unit_target != null:
		return unit_target
	return _find_nearest_enemy_in_group("selectable_building", range_sq)

func _find_nearest_enemy_in_group(group_name: String, range_sq: float) -> Node3D:
	var nearest: Node3D = null
	var best_distance_sq: float = range_sq
	var nodes: Array[Node] = get_tree().get_nodes_in_group(group_name)
	for node in nodes:
		if node == null or not is_instance_valid(node):
			continue
		var target: Node3D = node as Node3D
		if target == null:
			continue
		if not _is_valid_enemy_target(target):
			continue
		var distance_sq: float = _flat_distance_sq(global_position, target.global_position)
		if distance_sq > range_sq:
			continue
		if nearest == null or distance_sq < best_distance_sq:
			nearest = target
			best_distance_sq = distance_sq
	return nearest

func _is_valid_enemy_target(node) -> bool:
	if node == null or not is_instance_valid(node) or node == self:
		return false
	if not node.has_method("get_team_id"):
		return false
	if int(node.call("get_team_id")) == team_id:
		return false
	if node.has_method("is_alive") and not bool(node.call("is_alive")):
		return false
	return true

func _is_target_in_range(target) -> bool:
	if target == null or not is_instance_valid(target):
		return false
	var target_3d: Node3D = target as Node3D
	if target_3d == null:
		return false
	return _flat_distance_sq(global_position, target_3d.global_position) <= attack_range * attack_range

func _flat_distance_sq(a: Vector3, b: Vector3) -> float:
	var delta: Vector3 = b - a
	delta.y = 0.0
	return delta.length_squared()

func _die() -> void:
	_selection_ring.visible = false
	_attack_target = null
	queue_free()

func _spawn_attack_vfx(target_position: Vector3) -> void:
	if not is_inside_tree():
		return
	var root: Node = get_tree().current_scene
	var root_3d: Node3D = root as Node3D
	if root_3d == null:
		return

	var tracer: MeshInstance3D = MeshInstance3D.new()
	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = 0.18
	mesh.height = 0.36
	tracer.mesh = mesh

	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1.0, 0.82, 0.35, 0.95) if team_id == 1 else Color(0.58, 0.8, 1.0, 0.95)
	tracer.material_override = mat

	var launch_pos: Vector3 = global_position + Vector3(0.0, 1.9, 0.0)
	var hit_pos: Vector3 = target_position + Vector3(0.0, 1.0, 0.0)
	root_3d.add_child(tracer)
	tracer.global_position = launch_pos

	var tween: Tween = create_tween()
	tween.tween_property(tracer, "global_position", hit_pos, 0.12)
	tween.tween_callback(Callable(tracer, "queue_free"))

func _play_hit_flash() -> void:
	if _sprite == null:
		return
	_sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)
	var tween: Tween = create_tween()
	tween.tween_property(_sprite, "modulate", _base_tint, 0.1)
