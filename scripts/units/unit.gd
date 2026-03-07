extends CharacterBody3D

const RTS_CATALOG: Script = preload("res://scripts/core/rts_catalog.gd")
const RTS_COMMAND: Script = preload("res://scripts/core/rts_command.gd")
const RTS_INTERACTION: Script = preload("res://scripts/core/rts_interaction.gd")
const NAV_VERTICAL_POINT_TOLERANCE: float = 0.65
const UNIT_COLLISION_LAYER_BIT: int = 1 << 1
const BUILDING_COLLISION_LAYER_BIT: int = 1 << 2
const WORKER_COLLECTION_GHOST_LAYER_BIT: int = 1 << 10
const HEALTH_BAR_WORLD_HEIGHT: float = 2.02
const HEALTH_BAR_WIDTH: float = 1.0
const HEALTH_BAR_HEIGHT: float = 0.12
const HEALTH_BAR_PADDING: float = 0.02
const MINING_BALANCE_ASSIGNED_WEIGHT: float = 7.5
const MINING_BALANCE_OVER_OPTIMAL_WEIGHT: float = 16.0

@export var sprite_match_collider: bool = true
@export var sprite_outline_enabled: bool = true
@export var sprite_outline_color: Color = Color(0.25, 0.95, 1.0, 0.9)
@export var sprite_outline_scale: float = 1.1
@export var sprite_outline_check_interval: float = 0.12

@export var move_speed: float = 6.0
@export var is_worker: bool = false
@export var team_id: int = 1
@export var max_health: float = 100.0
@export var gather_range: float = 1.8
@export var dropoff_range: float = 2.4
@export var carry_capacity: int = 24
@export var gather_amount: int = 4
@export var gather_interval: float = 0.55
@export var mining_search_radius: float = 34.0
@export var mining_queue_timeout: float = 3.0
@export var mining_queue_distance: float = 1.0
@export var mining_delivery_duration: float = 0.5
@export var gather_trigger_buffer: float = 0.12
@export var dropoff_trigger_buffer: float = 0.25
@export var interaction_edge_padding: float = 0.03
@export var mining_interaction_repath_interval: float = 0.35
@export var interaction_nav_path_desired_distance: float = 0.65
@export var interaction_nav_target_desired_distance: float = 0.28
@export var mining_nav_finish_contact_slack: float = 0.18
@export var mining_nav_finish_anchor_slack: float = 0.9
@export var nav_agent_radius: float = 0.32
@export var nav_agent_height: float = 1.0
@export var nav_avoidance_priority: float = 0.5
@export var push_priority: int = 1
@export var push_can_be_displaced: bool = true
@export var push_allow_cross_team_displace: bool = false
@export var push_yield_scan_interval: float = 0.08
@export var push_yield_duration: float = 0.24
@export var push_contact_padding: float = 0.1
@export var hover_acceleration_time: float = 0.5
@export var hover_deceleration_factor: float = 2.0
@export var hover_brake_release_duration: float = 0.2
@export var repair_range: float = 2.1
@export var repair_amount: float = 10.0
@export var repair_interval: float = 0.5
@export var attack_range: float = 2.4
@export var attack_damage: float = 12.0
@export var attack_cooldown: float = 0.8
@export var auto_acquire_range: float = 8.0
@export var attack_move_acquire_range: float = 11.0
@export var retarget_interval: float = 0.2
@export var max_command_queue: int = 32
@export var debug_nav_log: bool = false
@export var debug_nav_log_interval: float = 0.8
@export var debug_nav_draw_path: bool = false
@export var debug_mining_log: bool = false
@export var debug_mining_log_interval: float = 0.8
@export var debug_mining_stall_threshold: float = 2.0
@export var debug_mining_timeout_enabled: bool = false
@export var debug_mining_move_timeout: float = 8.0
@export var debug_mining_return_timeout: float = 8.0
@export var debug_mining_timeout_log_interval: float = 1.5
@export var congestion_ghosting_enabled: bool = true
@export var congestion_stuck_time: float = 0.35
@export var congestion_release_time: float = 0.5

@onready var _selection_ring: MeshInstance3D = $SelectionRing
@onready var _sprite: Sprite3D = $Sprite3D
@onready var _nav_agent: NavigationAgent3D = $NavigationAgent3D

enum UnitMode {
	IDLE,
	MOVE,
	GATHER_RESOURCE,
	RETURN_RESOURCE,
	ATTACK,
	ATTACK_MOVE,
	REPAIR,
}

enum ConstructionLockMode {
	NONE,
	CAST,
	GARRISONED,
	INCORPORATED,
}

enum MiningState {
	IDLE,
	RALLY_MINING,
	MOVING_TO_MINERAL,
	QUEUED,
	HARVESTING,
	MOVING_TO_BASE,
	DELIVERING,
}

var _mode: UnitMode = UnitMode.IDLE
var _health: float = 100.0
var _has_target: bool = false
var _target_position: Vector3 = Vector3.ZERO
var _gather_target: Node3D = null
var _dropoff_target: Node3D = null
var _gather_timer: float = 0.0
var _mining_state: int = MiningState.IDLE
var _mining_preferred_target: Node3D = null
var _mining_auto_cycle_enabled: bool = false
var _mining_queue_timer: float = 0.0
var _mining_delivery_timer: float = 0.0
var _mining_interaction_repath_timer: float = 0.0
var _last_successful_mineral_target: Node3D = null
var _mining_debug_accum: float = 0.0
var _mining_harvest_stall_timer: float = 0.0
var _mining_last_logged_state: int = MiningState.IDLE
var _mining_timeout_watch_state: int = MiningState.IDLE
var _mining_timeout_watch_elapsed: float = 0.0
var _mining_timeout_log_cooldown: float = 0.0
var _carried_amount: int = 0
var _attack_target: Node = null
var _attack_timer: float = 0.0
var _attack_move_point: Vector3 = Vector3.ZERO
var _has_attack_move_point: bool = false
var _repair_target: Node3D = null
var _repair_timer: float = 0.0
var _retarget_timer: float = 0.0
var _base_tint: Color = Color.WHITE
var _nav_target_cached: Vector3 = Vector3.ZERO
var _has_nav_target_cached: bool = false
var _default_nav_path_desired_distance: float = NAV_VERTICAL_POINT_TOLERANCE
var _default_nav_target_desired_distance: float = NAV_VERTICAL_POINT_TOLERANCE
var _interaction_fallback_table: Dictionary = {}
var _interaction_nav_precision_active: bool = false
var _target_progress_timer: float = 0.0
var _target_progress_best_distance: float = INF
var _target_progress_repath_cooldown: float = 0.0
var _safe_velocity: Vector3 = Vector3.ZERO
var _has_safe_velocity: bool = false
var _safe_velocity_frame: int = -1
var _congestion_stuck_timer: float = 0.0
var _congestion_release_timer: float = 0.0
var _congestion_repath_cooldown: float = 0.0
var _unit_collision_ghosted: bool = false
var _priority_yield_collision_ghosted: bool = false
var _push_yield_timer: float = 0.0
var _push_yield_scan_timer: float = 0.0
var _stuck_log_accum: float = 0.0
var _last_desired_velocity: Vector3 = Vector3.ZERO
var _default_collision_mask: int = 0
var _worker_collection_profile_active: bool = false
var _command_queue: Array[RefCounted] = []
var _active_command: RefCounted = null
var _construction_lock_mode: int = ConstructionLockMode.NONE
var _construction_lock_building_path: NodePath = NodePath("")
var _default_collision_layer: int = 0
var _construction_hidden: bool = false
var _defer_queue_until_worker_cycle_checkpoint: bool = false
var _hover_current_speed: float = 0.0
var _hover_brake_release_timer: float = 0.0
var _health_bar_root: Node3D = null
var _health_bar_background: MeshInstance3D = null
var _health_bar_fill: MeshInstance3D = null
var _health_bar_fill_full_width: float = maxf(0.02, HEALTH_BAR_WIDTH - HEALTH_BAR_PADDING * 2.0)
var _is_selected: bool = false
var _is_hovered: bool = false
var _sprite_base_scale: Vector3 = Vector3.ONE
var _outline_sprite: Sprite3D = null
var _outline_material: StandardMaterial3D = null
var _outline_timer: float = 0.0
var _outline_visible: bool = false
var _nav_debug_draw_initialized: bool = false
var _nav_debug_draw_last_enabled: bool = false

signal command_queue_changed

func _ready() -> void:
	add_to_group("selectable_unit")
	_selection_ring.visible = false
	_apply_runtime_config_for_role()
	_health = max_health
	_apply_role_visual()
	_sync_sprite_to_collider()
	_ensure_outline_sprite()
	_ensure_health_bar_nodes()
	_update_health_bar_visual()
	_default_collision_layer = collision_layer
	_default_collision_mask = collision_mask
	_setup_navigation_agent()

func _process(delta: float) -> void:
	_update_sprite_outline(delta)
	_sync_nav_debug_draw()

func _physics_process(delta: float) -> void:
	if _mode == UnitMode.GATHER_RESOURCE or _mode == UnitMode.RETURN_RESOURCE:
		_process_worker_cycle(delta)
	elif _mode == UnitMode.REPAIR:
		_process_repair_cycle(delta)
	elif _mode == UnitMode.ATTACK or _mode == UnitMode.ATTACK_MOVE:
		_process_combat_cycle(delta)
	_sync_worker_collection_navigation_profile()
	_sync_navigation_precision_profile()
	_process_priority_push_yield(delta)
	_apply_movement(delta)
	_process_command_queue()

func is_worker_unit() -> bool:
	return is_worker

func get_unit_display_name() -> String:
	var unit_kind: String = get_unit_kind()
	var unit_def: Dictionary = RTS_CATALOG.get_unit_def(unit_kind)
	return str(unit_def.get("display_name", tr("Worker") if is_worker else tr("Soldier")))

func get_unit_role_tag() -> String:
	var unit_kind: String = get_unit_kind()
	var unit_def: Dictionary = RTS_CATALOG.get_unit_def(unit_kind)
	return str(unit_def.get("role_tag", "W" if is_worker else "S"))

func get_unit_kind() -> String:
	return "worker" if is_worker else "soldier"

func get_push_priority() -> int:
	return push_priority

func can_be_displaced_by_push() -> bool:
	return push_can_be_displaced

func get_push_body_radius() -> float:
	return _agent_radius_xz()

func has_active_push_motion() -> bool:
	if _construction_hidden:
		return false
	if _worker_collection_profile_active:
		return true
	if _has_target:
		return true
	if _last_desired_velocity.length_squared() > 0.01:
		return true
	return velocity.length_squared() > 0.01

func get_skill_ids() -> Array[String]:
	var base_skills: Array[String] = RTS_CATALOG.get_unit_skill_ids(get_unit_kind())
	if _construction_lock_mode == ConstructionLockMode.GARRISONED:
		if not base_skills.has("construction_exit"):
			base_skills.append("construction_exit")
		return base_skills
	if _construction_lock_mode == ConstructionLockMode.INCORPORATED:
		return ["construction_cancel_eject"]
	return base_skills

func get_build_skill_ids() -> Array[String]:
	return RTS_CATALOG.get_unit_build_skill_ids(get_unit_kind())

func is_construction_locked() -> bool:
	return _construction_lock_mode != ConstructionLockMode.NONE

func get_construction_lock_mode() -> String:
	match _construction_lock_mode:
		ConstructionLockMode.CAST:
			return "cast"
		ConstructionLockMode.GARRISONED:
			return "garrisoned"
		ConstructionLockMode.INCORPORATED:
			return "incorporated"
		_:
			return "none"

func get_construction_building_path() -> NodePath:
	return _construction_lock_building_path

func enter_construction_lock(mode: String, building_path: NodePath = NodePath(""), hide_unit: bool = false) -> void:
	var normalized_mode: String = mode.strip_edges().to_lower()
	if normalized_mode == "cast":
		_construction_lock_mode = ConstructionLockMode.CAST
	elif normalized_mode == "incorporated":
		_construction_lock_mode = ConstructionLockMode.INCORPORATED
	elif normalized_mode == "garrisoned":
		_construction_lock_mode = ConstructionLockMode.GARRISONED
	else:
		_construction_lock_mode = ConstructionLockMode.NONE
	_construction_lock_building_path = building_path
	_abort_active_mining_target()
	_mode = UnitMode.IDLE
	_mining_state = MiningState.IDLE
	_has_target = false
	velocity = Vector3.ZERO
	_gather_target = null
	_dropoff_target = null
	_mining_preferred_target = null
	_mining_auto_cycle_enabled = false
	_attack_target = null
	_attack_timer = 0.0
	_has_attack_move_point = false
	_attack_move_point = Vector3.ZERO
	_clear_repair_state()
	_retarget_timer = 0.0
	_gather_timer = 0.0
	_mining_queue_timer = 0.0
	_mining_delivery_timer = 0.0
	_mining_interaction_repath_timer = 0.0
	_mining_debug_accum = 0.0
	_mining_harvest_stall_timer = 0.0
	_mining_last_logged_state = _mining_state
	_defer_queue_until_worker_cycle_checkpoint = false
	_hover_current_speed = 0.0
	_hover_brake_release_timer = 0.0
	_reset_navigation_motion()
	if hide_unit:
		_set_construction_hidden(true)
	else:
		_set_construction_hidden(false)

func exit_construction_lock() -> void:
	_construction_lock_mode = ConstructionLockMode.NONE
	_construction_lock_building_path = NodePath("")
	_defer_queue_until_worker_cycle_checkpoint = false
	_set_construction_hidden(false)

func get_mode_label() -> String:
	match _mode:
		UnitMode.MOVE:
			return tr("Moving")
		UnitMode.GATHER_RESOURCE:
			if _mining_state == MiningState.QUEUED:
				return tr("Queued")
			if _mining_state == MiningState.HARVESTING:
				return tr("Harvesting")
			return tr("Gathering")
		UnitMode.RETURN_RESOURCE:
			if _mining_state == MiningState.DELIVERING:
				return tr("Delivering")
			return tr("Returning")
		UnitMode.ATTACK:
			return tr("Attacking")
		UnitMode.ATTACK_MOVE:
			return tr("Attack-Move")
		UnitMode.REPAIR:
			return tr("Repairing")
		_:
			return tr("Idle")

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

func is_damaged() -> bool:
	if not is_alive():
		return false
	return _health < maxf(0.0, max_health) - 0.01

func repair(amount: float, _source: Node = null) -> bool:
	if amount <= 0.0 or not is_alive():
		return false
	var clamped_max_health: float = maxf(0.0, max_health)
	if _health >= clamped_max_health - 0.01:
		return false
	var before: float = _health
	_health = clampf(_health + amount, 0.0, clamped_max_health)
	if _health <= before + 0.001:
		return false
	_update_health_bar_visual()
	_play_repair_flash()
	return true

func get_carry_fill_ratio() -> float:
	if carry_capacity <= 0:
		return 0.0
	return clampf(float(_carried_amount) / float(carry_capacity), 0.0, 1.0)

func has_cargo() -> bool:
	return _carried_amount > 0

func is_collecting_for_dropoff(dropoff_node: Node) -> bool:
	if not is_worker:
		return false
	if dropoff_node == null or not is_instance_valid(dropoff_node):
		return false
	if _dropoff_target == null or not is_instance_valid(_dropoff_target):
		return false
	if _dropoff_target != dropoff_node:
		return false
	return _mode == UnitMode.GATHER_RESOURCE or _mode == UnitMode.RETURN_RESOURCE

func get_active_mining_target() -> Node3D:
	if not is_worker:
		return null
	if _gather_target == null or not is_instance_valid(_gather_target):
		return null
	if _mode != UnitMode.GATHER_RESOURCE and _mode != UnitMode.RETURN_RESOURCE:
		return null
	return _gather_target

func set_worker_role(worker: bool) -> void:
	is_worker = worker
	_apply_runtime_config_for_role()
	_health = max_health
	_apply_role_visual()
	_sync_sprite_to_collider()
	_update_health_bar_visual()

func submit_command(command: RefCounted) -> bool:
	if command == null:
		return false
	if not command is RTSCommand:
		return false
	var rts_command: RTSCommand = command as RTSCommand
	if rts_command == null:
		return false
	var explicit_queue_input: bool = rts_command.is_queue_command
	var is_internal_build_order: bool = false
	if rts_command.payload is Dictionary:
		is_internal_build_order = bool(rts_command.payload.get("internal_build_order", false))

	var locked_deferred_mode: bool = (
		_construction_lock_mode == ConstructionLockMode.CAST
		or _construction_lock_mode == ConstructionLockMode.GARRISONED
		or _construction_lock_mode == ConstructionLockMode.INCORPORATED
	) and not is_internal_build_order
	if locked_deferred_mode and not rts_command.is_queue_command:
		rts_command.is_queue_command = true
	if locked_deferred_mode and not explicit_queue_input:
		# In locked construction modes, non-Shift input keeps only one deferred command slot.
		_clear_non_internal_deferred_commands()

	if rts_command.is_queue_command:
		if not can_enqueue_command():
			return false
		_command_queue.append(rts_command)
		_update_worker_queue_hold_after_enqueue()
		if _active_command == null and not _should_delay_queued_command_start():
			_start_next_queued_command()
		_emit_command_queue_changed()
		return true

	_defer_queue_until_worker_cycle_checkpoint = false
	_command_queue.clear()
	_active_command = rts_command
	_execute_rts_command(rts_command)
	_emit_command_queue_changed()
	return true

func _clear_non_internal_deferred_commands() -> void:
	var active_command: RTSCommand = _active_command as RTSCommand
	if active_command != null and not _is_internal_build_order_command(active_command):
		_active_command = null
	for i in range(_command_queue.size() - 1, -1, -1):
		var queued_value: Variant = _command_queue[i]
		var queued_command: RTSCommand = queued_value as RTSCommand
		if queued_command == null:
			_command_queue.remove_at(i)
			continue
		if _is_internal_build_order_command(queued_command):
			continue
		_command_queue.remove_at(i)

func _is_internal_build_order_command(command: RTSCommand) -> bool:
	if command == null:
		return false
	if not (command.payload is Dictionary):
		return false
	return bool(command.payload.get("internal_build_order", false))

func clear_pending_commands() -> void:
	_command_queue.clear()
	_active_command = null
	_emit_command_queue_changed()

func insert_temporary_move_then_resume(target: Vector3, reason: String = "temporary_move") -> bool:
	if _construction_lock_mode != ConstructionLockMode.NONE:
		return false
	var resume_commands: Array[RTSCommand] = _snapshot_non_internal_commands()
	var temporary_move: RTSCommand = RTS_COMMAND.make_move(target, false)
	temporary_move.payload["temporary_insert"] = true
	temporary_move.payload["temporary_reason"] = reason
	temporary_move.payload["temporary_target"] = target
	_command_queue.clear()
	_active_command = temporary_move
	_execute_rts_command(temporary_move)
	for resume_command in resume_commands:
		if resume_command == null:
			continue
		resume_command.is_queue_command = true
		_command_queue.append(resume_command)
	_emit_command_queue_changed()
	return true

func _snapshot_non_internal_commands() -> Array[RTSCommand]:
	var snapshot: Array[RTSCommand] = []
	var active_command: RTSCommand = _active_command as RTSCommand
	if active_command != null and not _is_internal_build_order_command(active_command):
		snapshot.append(_clone_command(active_command))
	for queued_value in _command_queue:
		var queued_command: RTSCommand = queued_value as RTSCommand
		if queued_command == null:
			continue
		if _is_internal_build_order_command(queued_command):
			continue
		snapshot.append(_clone_command(queued_command))
	return snapshot

func _clone_command(source_command: RTSCommand) -> RTSCommand:
	var clone: RTSCommand = RTSCommand.new(source_command.command_type, source_command.target_type)
	clone.target_position = source_command.target_position
	clone.target_unit = source_command.target_unit
	clone.direction = source_command.direction
	clone.is_queue_command = source_command.is_queue_command
	clone.is_auto_cast = source_command.is_auto_cast
	clone.control_group_id = source_command.control_group_id
	clone.timestamp = source_command.timestamp
	clone.subgroup_index = source_command.subgroup_index
	if source_command.payload is Dictionary:
		clone.payload = (source_command.payload as Dictionary).duplicate(true)
	else:
		clone.payload = {}
	return clone

func get_pending_command_count() -> int:
	var active_count: int = 1 if _active_command != null else 0
	return active_count + _command_queue.size()

func can_enqueue_command() -> bool:
	return get_pending_command_count() < maxi(1, max_command_queue)

func get_command_queue_points(include_active: bool = true, max_points: int = 32) -> Array[Dictionary]:
	var points: Array[Dictionary] = []
	var cap: int = maxi(1, max_points)
	if include_active:
		var active_command: RTSCommand = _active_command as RTSCommand
		if active_command != null:
			_append_queue_point(points, active_command, false)
	if points.size() >= cap:
		return points
	for queued_value in _command_queue:
		var queued_command: RTSCommand = queued_value as RTSCommand
		if queued_command == null:
			continue
		_append_queue_point(points, queued_command, true)
		if points.size() >= cap:
			break
	return points

func remove_queued_commands_from(visible_index: int) -> bool:
	if visible_index < 0:
		return false
	var normalized: int = visible_index
	if _active_command != null:
		if normalized == 0:
			command_stop(true)
			_active_command = null
			_command_queue.clear()
			_emit_command_queue_changed()
			return true
		normalized -= 1
	if normalized < 0 or normalized >= _command_queue.size():
		return false
	while _command_queue.size() > normalized:
		_command_queue.pop_back()
	_emit_command_queue_changed()
	return true

func command_move(target: Vector3, preserve_queue: bool = false) -> void:
	_defer_queue_until_worker_cycle_checkpoint = false
	if not preserve_queue:
		_command_queue.clear()
		_active_command = null
	_abort_active_mining_target()
	_clear_repair_state()
	_mode = UnitMode.MOVE
	_mining_state = MiningState.IDLE
	_gather_target = null
	_dropoff_target = null
	_mining_preferred_target = null
	_mining_auto_cycle_enabled = false
	_attack_target = null
	_attack_timer = 0.0
	_has_attack_move_point = false
	_attack_move_point = Vector3.ZERO
	_retarget_timer = 0.0
	_gather_timer = 0.0
	_mining_queue_timer = 0.0
	_mining_delivery_timer = 0.0
	_move_to(target)

func move_to(target: Vector3) -> void:
	command_move(target)

func command_gather(resource_node: Node3D, dropoff_node: Node3D, preserve_queue: bool = false, from_rally: bool = false) -> void:
	if not is_worker:
		return
	if resource_node == null or dropoff_node == null:
		return
	_defer_queue_until_worker_cycle_checkpoint = false
	if not preserve_queue:
		_command_queue.clear()
		_active_command = null
	_abort_active_mining_target()
	_clear_repair_state()
	_dropoff_target = dropoff_node
	_mining_preferred_target = resource_node
	_mining_auto_cycle_enabled = true
	_gather_target = resource_node
	_attack_target = null
	_attack_timer = 0.0
	_has_attack_move_point = false
	_attack_move_point = Vector3.ZERO
	_retarget_timer = 0.0
	_gather_timer = 0.0
	_mining_queue_timer = 0.0
	_mining_delivery_timer = 0.0
	_mining_interaction_repath_timer = 0.0
	_mining_debug_accum = 0.0
	_mining_harvest_stall_timer = 0.0
	_mining_last_logged_state = _mining_state
	if from_rally:
		_set_mining_state(MiningState.RALLY_MINING)
	else:
		_set_mining_state(MiningState.MOVING_TO_MINERAL)

func command_return_to_dropoff(dropoff_node: Node3D, preserve_queue: bool = false) -> void:
	if not is_worker:
		return
	if dropoff_node == null or not is_instance_valid(dropoff_node):
		return
	_defer_queue_until_worker_cycle_checkpoint = false
	if not preserve_queue:
		_command_queue.clear()
		_active_command = null
	_abort_active_mining_target()
	_clear_repair_state()
	_dropoff_target = dropoff_node
	_mining_preferred_target = null
	_mining_auto_cycle_enabled = false
	_gather_target = null
	_attack_target = null
	_attack_timer = 0.0
	_has_attack_move_point = false
	_attack_move_point = Vector3.ZERO
	_retarget_timer = 0.0
	_gather_timer = 0.0
	_mining_queue_timer = 0.0
	_mining_delivery_timer = 0.0
	_mining_interaction_repath_timer = 0.0
	_mining_debug_accum = 0.0
	_mining_harvest_stall_timer = 0.0
	_mining_last_logged_state = _mining_state
	_set_mining_state(MiningState.MOVING_TO_BASE)

func command_stop(preserve_queue: bool = false) -> void:
	_defer_queue_until_worker_cycle_checkpoint = false
	if not preserve_queue:
		_command_queue.clear()
		_active_command = null
	_abort_active_mining_target()
	_clear_repair_state()
	_mode = UnitMode.IDLE
	_mining_state = MiningState.IDLE
	_has_target = false
	velocity = Vector3.ZERO
	_gather_target = null
	_dropoff_target = null
	_mining_preferred_target = null
	_mining_auto_cycle_enabled = false
	_attack_target = null
	_attack_timer = 0.0
	_has_attack_move_point = false
	_attack_move_point = Vector3.ZERO
	_retarget_timer = 0.0
	_gather_timer = 0.0
	_mining_queue_timer = 0.0
	_mining_delivery_timer = 0.0
	_mining_interaction_repath_timer = 0.0
	_mining_debug_accum = 0.0
	_mining_harvest_stall_timer = 0.0
	_mining_last_logged_state = _mining_state
	_hover_current_speed = 0.0
	_hover_brake_release_timer = 0.0
	_reset_navigation_motion()

func command_attack(target_node: Node3D, preserve_queue: bool = false) -> bool:
	if target_node == null or not is_instance_valid(target_node):
		return false
	if is_worker:
		return false
	if attack_damage <= 0.0 or attack_range <= 0.0:
		return false
	if not _target_is_enemy(target_node):
		return false
	_defer_queue_until_worker_cycle_checkpoint = false
	if not preserve_queue:
		_command_queue.clear()
		_active_command = null
	_abort_active_mining_target()
	_clear_repair_state()
	_attack_target = target_node
	_attack_timer = 0.0
	_attack_move_point = target_node.global_position
	_has_attack_move_point = true
	_retarget_timer = 0.0
	_gather_target = null
	_dropoff_target = null
	_mining_preferred_target = null
	_mining_auto_cycle_enabled = false
	_mining_state = MiningState.IDLE
	_mode = UnitMode.ATTACK
	_move_to(target_node.global_position)
	return true

func command_attack_move(target: Vector3, preserve_queue: bool = false) -> bool:
	if is_worker:
		return false
	if attack_damage <= 0.0 or attack_range <= 0.0:
		return false
	_defer_queue_until_worker_cycle_checkpoint = false
	if not preserve_queue:
		_command_queue.clear()
		_active_command = null
	_abort_active_mining_target()
	_clear_repair_state()
	_attack_target = null
	_attack_timer = 0.0
	_attack_move_point = Vector3(target.x, global_position.y, target.z)
	_has_attack_move_point = true
	_retarget_timer = 0.0
	_gather_target = null
	_dropoff_target = null
	_mining_preferred_target = null
	_mining_auto_cycle_enabled = false
	_mining_state = MiningState.IDLE
	_mode = UnitMode.ATTACK_MOVE
	_move_to(_attack_move_point)
	return true

func command_repair(building_node: Node3D, preserve_queue: bool = false) -> bool:
	if not is_worker:
		return false
	if not _is_valid_repair_target(building_node):
		return false
	if not _is_repair_target_damaged(building_node):
		return false
	_defer_queue_until_worker_cycle_checkpoint = false
	if not preserve_queue:
		_command_queue.clear()
		_active_command = null
	_abort_active_mining_target()
	_clear_repair_state()
	_gather_target = null
	_dropoff_target = null
	_mining_preferred_target = null
	_mining_auto_cycle_enabled = false
	_attack_target = null
	_attack_timer = 0.0
	_has_attack_move_point = false
	_attack_move_point = Vector3.ZERO
	_retarget_timer = 0.0
	_mining_state = MiningState.IDLE
	_mode = UnitMode.REPAIR
	_repair_target = building_node
	_move_to(building_node.global_position)
	return true

func _process_command_queue() -> void:
	if _construction_lock_mode != ConstructionLockMode.NONE:
		return
	if _defer_queue_until_worker_cycle_checkpoint and _mode != UnitMode.GATHER_RESOURCE and _mode != UnitMode.RETURN_RESOURCE:
		_defer_queue_until_worker_cycle_checkpoint = false
	if _active_command != null:
		var active_command: RTSCommand = _active_command as RTSCommand
		if active_command == null or _is_command_complete(active_command):
			_active_command = null
			_emit_command_queue_changed()
	if _active_command != null:
		return
	if _command_queue.is_empty():
		return
	if _should_delay_queued_command_start():
		return
	_start_next_queued_command()

func _should_delay_queued_command_start() -> bool:
	if not is_worker:
		return false
	if not _defer_queue_until_worker_cycle_checkpoint:
		return false
	return _mode == UnitMode.GATHER_RESOURCE or _mode == UnitMode.RETURN_RESOURCE

func _update_worker_queue_hold_after_enqueue() -> void:
	if not is_worker:
		return
	var was_deferred: bool = _defer_queue_until_worker_cycle_checkpoint
	if _mode == UnitMode.GATHER_RESOURCE:
		var can_interrupt_immediately: bool = _mining_state == MiningState.MOVING_TO_MINERAL or _mining_state == MiningState.RALLY_MINING
		if can_interrupt_immediately:
			_defer_queue_until_worker_cycle_checkpoint = false
			_stop_worker_cycle(false)
			_notify_game_manager_worker_queue_transition("interrupt_immediate")
			return
		_defer_queue_until_worker_cycle_checkpoint = true
		if not was_deferred:
			_notify_game_manager_worker_queue_transition("queued_checkpoint")
		return
	if _mode == UnitMode.RETURN_RESOURCE:
		_defer_queue_until_worker_cycle_checkpoint = true
		if not was_deferred:
			_notify_game_manager_worker_queue_transition("queued_checkpoint")
		return
	_defer_queue_until_worker_cycle_checkpoint = false

func _notify_game_manager_worker_queue_transition(event_type: String) -> void:
	if event_type == "":
		return
	var game_manager: Node = get_tree().get_first_node_in_group("game_manager")
	if game_manager == null:
		return
	if game_manager.has_method("_on_worker_queue_transition"):
		game_manager.call("_on_worker_queue_transition", self , event_type)

func _start_next_queued_command() -> void:
	if _command_queue.is_empty():
		return
	var queued_value: Variant = _command_queue.pop_front()
	var queued_command: RTSCommand = queued_value as RTSCommand
	if queued_command == null:
		return
	_active_command = queued_command
	_execute_rts_command(queued_command)
	if queued_command.command_type == RTSCommand.CommandType.STOP:
		_active_command = null
	_emit_command_queue_changed()

func _is_command_complete(command: RTSCommand) -> bool:
	match command.command_type:
		RTSCommand.CommandType.MOVE:
			return not _has_target and (_mode == UnitMode.MOVE or _mode == UnitMode.IDLE)
		RTSCommand.CommandType.ATTACK:
			if _attack_target != null:
				return false
			return _mode == UnitMode.IDLE or (not _has_target and _mode != UnitMode.ATTACK)
		RTSCommand.CommandType.ATTACK_MOVE:
			if _mode != UnitMode.ATTACK_MOVE:
				return true
			if _attack_target != null:
				return false
			return not _has_target and _is_near(_attack_move_point, maxf(0.45, attack_range * 0.35))
		RTSCommand.CommandType.GATHER:
			return _mode != UnitMode.GATHER_RESOURCE and _mode != UnitMode.RETURN_RESOURCE
		RTSCommand.CommandType.RETURN_RESOURCE:
			return _mode == UnitMode.IDLE and not _has_target and _carried_amount <= 0
		RTSCommand.CommandType.REPAIR:
			return _mode != UnitMode.REPAIR
		RTSCommand.CommandType.STOP:
			return true
		_:
			return true

func _execute_rts_command(command: RTSCommand) -> void:
	match command.command_type:
		RTSCommand.CommandType.MOVE:
			command_move(command.target_position, true)
		RTSCommand.CommandType.ATTACK:
			var attack_target: Node3D = command.target_unit as Node3D
			if attack_target != null and is_instance_valid(attack_target):
				if not command_attack(attack_target, true) and command.target_type == RTSCommand.TargetType.POINT:
					command_move(command.target_position, true)
			elif command.target_type == RTSCommand.TargetType.POINT:
				command_move(command.target_position, true)
			else:
				command_stop(true)
		RTSCommand.CommandType.ATTACK_MOVE:
			if not command_attack_move(command.target_position, true):
				command_move(command.target_position, true)
		RTSCommand.CommandType.GATHER:
			var gather_resource: Node3D = command.payload.get("resource") as Node3D
			var gather_dropoff: Node3D = command.payload.get("dropoff") as Node3D
			var from_rally: bool = bool(command.payload.get("from_rally", false))
			if gather_resource == null or gather_dropoff == null:
				command_stop(true)
				return
			if not is_instance_valid(gather_resource) or not is_instance_valid(gather_dropoff):
				command_stop(true)
				return
			command_gather(gather_resource, gather_dropoff, true, from_rally)
		RTSCommand.CommandType.RETURN_RESOURCE:
			var dropoff: Node3D = command.payload.get("dropoff") as Node3D
			if dropoff == null or not is_instance_valid(dropoff):
				command_stop(true)
				return
			command_return_to_dropoff(dropoff, true)
		RTSCommand.CommandType.REPAIR:
			var repair_target: Node3D = command.payload.get("building") as Node3D
			if repair_target == null:
				repair_target = command.target_unit as Node3D
			if repair_target == null or not is_instance_valid(repair_target):
				command_stop(true)
				return
			if not command_repair(repair_target, true):
				command_stop(true)
				return
		RTSCommand.CommandType.STOP:
			command_stop(true)
		_:
			command_stop(true)

func _append_queue_point(points: Array[Dictionary], command: RTSCommand, queued: bool) -> void:
	if command.command_type == RTSCommand.CommandType.STOP:
		return
	var position: Vector3 = command.target_position
	match command.command_type:
		RTSCommand.CommandType.ATTACK:
			var attack_target: Node3D = _safe_node3d_ref(command.target_unit)
			if attack_target != null:
				position = attack_target.global_position
		RTSCommand.CommandType.GATHER:
			var resource_target: Node3D = _safe_node3d_ref(command.payload.get("resource"))
			if resource_target != null:
				position = resource_target.global_position
		RTSCommand.CommandType.RETURN_RESOURCE:
			var dropoff_target: Node3D = _safe_node3d_ref(command.payload.get("dropoff"))
			if dropoff_target != null:
				position = dropoff_target.global_position
		RTSCommand.CommandType.REPAIR:
			var repair_target: Node3D = _safe_node3d_ref(command.payload.get("building"))
			if repair_target == null:
				repair_target = _safe_node3d_ref(command.target_unit)
			if repair_target != null:
				position = repair_target.global_position
	var point_data: Dictionary = {
		"position": position,
		"command_type": command.command_type,
		"queued": queued
	}
	var path_origin_value: Variant = command.payload.get("path_origin", null)
	if path_origin_value is Vector3:
		point_data["path_origin"] = path_origin_value as Vector3
	points.append(point_data)

func _safe_node3d_ref(value: Variant) -> Node3D:
	if not (value is Object):
		return null
	if not is_instance_valid(value):
		return null
	return value as Node3D

func _emit_command_queue_changed() -> void:
	emit_signal("command_queue_changed")

func apply_damage(amount: float, _source: Node = null) -> void:
	if amount <= 0.0 or not is_alive():
		return
	_health = maxf(0.0, _health - amount)
	_update_health_bar_visual()
	_play_hit_flash()
	if _health <= 0.0:
		_die()

func set_selected(selected: bool) -> void:
	_is_selected = selected
	_refresh_selection_ring_visual()

func set_hovered(hovered: bool) -> void:
	_is_hovered = hovered
	_refresh_selection_ring_visual()

func _refresh_selection_ring_visual() -> void:
	if _selection_ring == null:
		return
	_selection_ring.visible = _is_selected or _is_hovered

func _process_worker_cycle(delta: float) -> void:
	if not is_worker:
		command_stop(true)
		return
	if _dropoff_target == null or not is_instance_valid(_dropoff_target):
		_dropoff_target = _nearest_valid_dropoff(global_position)

	if _mining_state == MiningState.IDLE:
		if _mining_auto_cycle_enabled:
			_set_mining_state(MiningState.MOVING_TO_MINERAL)
		else:
			_stop_worker_cycle(false)
			_process_mining_debug(delta)
			return
	if _mining_state == MiningState.RALLY_MINING:
		if not _transition_to_next_mineral():
			_stop_worker_cycle(false)
		_process_mining_debug(delta)
		return

	match _mining_state:
		MiningState.MOVING_TO_MINERAL:
			_process_moving_to_mineral_state(delta)
		MiningState.QUEUED:
			_process_queued_mining_state(delta)
		MiningState.HARVESTING:
			_process_harvesting_state(delta)
		MiningState.MOVING_TO_BASE:
			_process_moving_to_base_state(delta)
		MiningState.DELIVERING:
			_process_delivering_state(delta)
		_:
			_stop_worker_cycle(false)
	_process_mining_timeout_watchdog(delta)
	_process_mining_debug(delta)

func _set_mining_state(next_state: int) -> void:
	_mining_state = next_state
	match _mining_state:
		MiningState.IDLE:
			_mode = UnitMode.IDLE
			_gather_timer = 0.0
			_mining_queue_timer = 0.0
			_mining_delivery_timer = 0.0
		MiningState.RALLY_MINING:
			_mode = UnitMode.GATHER_RESOURCE
			_gather_timer = 0.0
			_mining_queue_timer = 0.0
		MiningState.MOVING_TO_MINERAL:
			_mode = UnitMode.GATHER_RESOURCE
			_gather_timer = 0.0
			_mining_queue_timer = 0.0
			_mining_interaction_repath_timer = 0.0
			if _gather_target != null and is_instance_valid(_gather_target):
				_move_to(_mining_gather_approach_point(_gather_target))
		MiningState.QUEUED:
			_mode = UnitMode.GATHER_RESOURCE
			_mining_queue_timer = 0.0
			_mining_interaction_repath_timer = 0.0
			_has_target = false
			velocity = Vector3.ZERO
		MiningState.HARVESTING:
			_mode = UnitMode.GATHER_RESOURCE
			_gather_timer = 0.0
			_mining_interaction_repath_timer = 0.0
			_has_target = false
			velocity = Vector3.ZERO
		MiningState.MOVING_TO_BASE:
			_mode = UnitMode.RETURN_RESOURCE
			_mining_delivery_timer = 0.0
			_mining_interaction_repath_timer = 0.0
			if _dropoff_target == null or not is_instance_valid(_dropoff_target):
				_dropoff_target = _nearest_valid_dropoff(global_position)
			if _dropoff_target != null and is_instance_valid(_dropoff_target):
				_move_to(_mining_dropoff_approach_point(_dropoff_target))
		MiningState.DELIVERING:
			_mode = UnitMode.RETURN_RESOURCE
			_mining_delivery_timer = 0.0
			_mining_interaction_repath_timer = 0.0
			_has_target = false
			velocity = Vector3.ZERO

func _is_mining_debug_candidate() -> bool:
	if not debug_mining_log:
		return false
	if not is_worker:
		return false
	if _mode == UnitMode.GATHER_RESOURCE or _mode == UnitMode.RETURN_RESOURCE:
		return true
	if _mining_state != MiningState.IDLE:
		return true
	return _mining_auto_cycle_enabled

func _mining_state_name(state: int) -> String:
	match state:
		MiningState.RALLY_MINING:
			return "RALLY_MINING"
		MiningState.MOVING_TO_MINERAL:
			return "MOVING_TO_MINERAL"
		MiningState.QUEUED:
			return "QUEUED"
		MiningState.HARVESTING:
			return "HARVESTING"
		MiningState.MOVING_TO_BASE:
			return "MOVING_TO_BASE"
		MiningState.DELIVERING:
			return "DELIVERING"
		_:
			return "IDLE"

func _mode_debug_name() -> String:
	match _mode:
		UnitMode.MOVE:
			return "MOVE"
		UnitMode.GATHER_RESOURCE:
			return "GATHER_RESOURCE"
		UnitMode.RETURN_RESOURCE:
			return "RETURN_RESOURCE"
		UnitMode.ATTACK:
			return "ATTACK"
		UnitMode.ATTACK_MOVE:
			return "ATTACK_MOVE"
		UnitMode.REPAIR:
			return "REPAIR"
		_:
			return "IDLE"

func _process_mining_debug(delta: float) -> void:
	if not _is_mining_debug_candidate():
		_mining_debug_accum = 0.0
		_mining_harvest_stall_timer = 0.0
		_mining_last_logged_state = _mining_state
		return
	if _mining_last_logged_state != _mining_state:
		_log_mining_event("state_change", {
			"from_state": _mining_state_name(_mining_last_logged_state),
			"to_state": _mining_state_name(_mining_state)
		})
		_mining_last_logged_state = _mining_state
		_mining_debug_accum = 0.0
	_mining_debug_accum += delta
	if _mining_debug_accum >= maxf(0.1, debug_mining_log_interval):
		_mining_debug_accum = 0.0
		_log_mining_event("heartbeat")
	if _mining_state == MiningState.HARVESTING:
		_mining_harvest_stall_timer += delta
		var stall_threshold: float = maxf(0.3, debug_mining_stall_threshold)
		if _mining_harvest_stall_timer >= stall_threshold:
			var expected_harvest_duration: float = _harvest_duration_for_target(_gather_target)
			_log_mining_event("harvest_stall", {
				"stall_sec": snappedf(_mining_harvest_stall_timer, 0.01),
				"expected_harvest_sec": snappedf(expected_harvest_duration, 0.01)
			})
			_mining_harvest_stall_timer = 0.0
	else:
		_mining_harvest_stall_timer = 0.0

func _log_mining_event(tag: String, extra: Dictionary = {}, force_log: bool = false) -> void:
	if not force_log and not _is_mining_debug_candidate():
		return
	var gather_distance: float = -1.0
	var gather_contact: float = -1.0
	if _gather_target != null and is_instance_valid(_gather_target):
		gather_distance = RTS_INTERACTION.flat_distance_xz(global_position, _gather_target.global_position)
		gather_contact = _effective_gather_contact_range(_gather_target)
	var dropoff_distance: float = -1.0
	var dropoff_contact: float = -1.0
	if _dropoff_target != null and is_instance_valid(_dropoff_target):
		dropoff_distance = RTS_INTERACTION.flat_distance_xz(global_position, _dropoff_target.global_position)
		dropoff_contact = _effective_dropoff_contact_range(_dropoff_target)
	var occupied_text: String = "n/a"
	var queue_len: int = -1
	if _gather_target != null and is_instance_valid(_gather_target):
		if _gather_target.has_method("is_occupied"):
			occupied_text = str(bool(_gather_target.call("is_occupied")))
		if _gather_target.has_method("get_wait_queue_length"):
			queue_len = int(_gather_target.call("get_wait_queue_length"))
	var command_distance: float = -1.0
	var command_to_gather: float = -1.0
	var command_to_dropoff: float = -1.0
	if _has_target:
		var to_command: Vector3 = _target_position - global_position
		to_command.y = 0.0
		command_distance = to_command.length()
		if _gather_target != null and is_instance_valid(_gather_target):
			command_to_gather = RTS_INTERACTION.flat_distance_xz(_target_position, _gather_target.global_position)
		if _dropoff_target != null and is_instance_valid(_dropoff_target):
			command_to_dropoff = RTS_INTERACTION.flat_distance_xz(_target_position, _dropoff_target.global_position)
	var nav_finished_text: String = "n/a"
	if _can_use_navigation():
		nav_finished_text = str(_nav_agent.is_navigation_finished())
	var message: String = "[MINING][%s][team=%d] tag=%s mode=%s state=%s auto=%s carried=%d/%d gather=%s dropoff=%s dist_m=%.2f dist_b=%.2f g_contact=%.2f d_contact=%.2f g_timer=%.2f q_timer=%.2f d_timer=%.2f has_target=%s dist_cmd=%.2f cmd_to_m=%.2f cmd_to_b=%.2f vel=%.2f nav_fin=%s occupied=%s qlen=%d" % [
		name,
		team_id,
		tag,
		_mode_debug_name(),
		_mining_state_name(_mining_state),
		str(_mining_auto_cycle_enabled),
		_carried_amount,
		carry_capacity,
		_mining_debug_target_name(_gather_target),
		_mining_debug_target_name(_dropoff_target),
		gather_distance,
		dropoff_distance,
		gather_contact,
		dropoff_contact,
		_gather_timer,
		_mining_queue_timer,
		_mining_delivery_timer,
		str(_has_target),
		command_distance,
		command_to_gather,
		command_to_dropoff,
		velocity.length(),
		nav_finished_text,
		occupied_text,
		queue_len
	]
	if not extra.is_empty():
		var keys: Array = extra.keys()
		keys.sort()
		var suffix: String = ""
		for key_value in keys:
			var key_text: String = str(key_value)
			var value_text: String = str(extra.get(key_value))
			if suffix != "":
				suffix += " "
			suffix += "%s=%s" % [key_text, value_text]
		if suffix != "":
			message += " " + suffix
	print(message)

func _process_mining_timeout_watchdog(delta: float) -> void:
	if not debug_mining_timeout_enabled:
		_reset_mining_timeout_watchdog()
		return
	if not is_worker:
		_reset_mining_timeout_watchdog()
		return
	var tracked_state: bool = _mining_state == MiningState.MOVING_TO_MINERAL or _mining_state == MiningState.MOVING_TO_BASE
	if not tracked_state:
		_reset_mining_timeout_watchdog()
		return
	if _mining_timeout_watch_state != _mining_state:
		_mining_timeout_watch_state = _mining_state
		_mining_timeout_watch_elapsed = 0.0
		_mining_timeout_log_cooldown = 0.0

	_mining_timeout_watch_elapsed += maxf(0.0, delta)
	_mining_timeout_log_cooldown = maxf(0.0, _mining_timeout_log_cooldown - delta)
	var timeout_limit: float = debug_mining_move_timeout if _mining_state == MiningState.MOVING_TO_MINERAL else debug_mining_return_timeout
	timeout_limit = maxf(0.5, timeout_limit)
	if _mining_timeout_watch_elapsed < timeout_limit:
		return
	if _mining_timeout_log_cooldown > 0.0:
		return
	_mining_timeout_log_cooldown = maxf(0.4, debug_mining_timeout_log_interval)

	var tracked_target: Node3D = _gather_target if _mining_state == MiningState.MOVING_TO_MINERAL else _dropoff_target
	var dist_target: float = -1.0
	if tracked_target != null and is_instance_valid(tracked_target):
		dist_target = RTS_INTERACTION.flat_distance_xz(global_position, tracked_target.global_position)
	var dist_anchor: float = -1.0
	if _has_target:
		dist_anchor = RTS_INTERACTION.flat_distance_xz(global_position, _target_position)
	var nav_finished: bool = false
	if _can_use_navigation():
		nav_finished = _nav_agent.is_navigation_finished()
	var timeout_tag: String = "gather_move_timeout" if _mining_state == MiningState.MOVING_TO_MINERAL else "return_move_timeout"
	_log_mining_event(timeout_tag, {
		"elapsed_sec": snappedf(_mining_timeout_watch_elapsed, 0.01),
		"timeout_sec": snappedf(timeout_limit, 0.01),
		"dist_target": snappedf(dist_target, 0.01),
		"dist_anchor": snappedf(dist_anchor, 0.01),
		"nav_finished": nav_finished
	}, true)

func _reset_mining_timeout_watchdog() -> void:
	_mining_timeout_watch_state = MiningState.IDLE
	_mining_timeout_watch_elapsed = 0.0
	_mining_timeout_log_cooldown = 0.0

func _mining_debug_target_name(target_node: Node3D) -> String:
	if target_node == null or not is_instance_valid(target_node):
		return "null"
	return "%s@%s" % [target_node.name, str(target_node.get_instance_id())]

func _process_moving_to_mineral_state(_delta: float) -> void:
	if _dropoff_target == null or not is_instance_valid(_dropoff_target):
		_dropoff_target = _nearest_valid_dropoff(global_position)
		if _dropoff_target == null:
			_log_mining_event("no_dropoff_while_moving_to_mineral")
			_stop_worker_cycle(true)
			return
	if _gather_target == null or not is_instance_valid(_gather_target) or _is_mineral_depleted(_gather_target):
		_log_mining_event("gather_target_invalid_or_depleted")
		if not _transition_to_next_mineral():
			_stop_worker_cycle(false)
		return
	var contact_range: float = _effective_gather_contact_range(_gather_target)
	var interaction_key: String = "gather"
	if not _has_target:
		_move_to(_mining_gather_approach_point(_gather_target))
	var in_hard_contact: bool = RTS_INTERACTION.is_within_distance_xz(global_position, _gather_target.global_position, contact_range)
	var anchor_contact: bool = false
	if not in_hard_contact and _has_target:
		var anchor_tolerance: float = _interaction_anchor_tolerance()
		anchor_contact = RTS_INTERACTION.is_within_distance_xz(global_position, _target_position, anchor_tolerance)
		if not anchor_contact and _can_use_navigation() and _nav_agent.is_navigation_finished():
			var nav_anchor_tolerance: float = anchor_tolerance + _interaction_anchor_slack(interaction_key, mining_nav_finish_anchor_slack)
			anchor_contact = RTS_INTERACTION.is_within_distance_xz(global_position, _target_position, nav_anchor_tolerance)
			if anchor_contact:
				_log_mining_event("nav_anchor_contact_fallback", {
					"anchor_tol": snappedf(anchor_tolerance, 0.01),
					"nav_anchor_tol": snappedf(nav_anchor_tolerance, 0.01),
					"dist_anchor": snappedf(RTS_INTERACTION.flat_distance_xz(global_position, _target_position), 0.01)
				})
	var nav_soft_contact: bool = false
	if not in_hard_contact and not anchor_contact:
		nav_soft_contact = _is_navigation_soft_contact(_gather_target, contact_range, interaction_key)
	if not in_hard_contact and not anchor_contact and not nav_soft_contact:
		var allow_reissue: bool = _interaction_fallback_bool(interaction_key, "enable_nav_reissue", true)
		if allow_reissue and _has_target and _can_use_navigation() and _nav_agent.is_navigation_finished():
			_mining_interaction_repath_timer += _delta
			var reissue_interval: float = _interaction_fallback_float(interaction_key, "reissue_interval", mining_interaction_repath_interval)
			if _mining_interaction_repath_timer >= maxf(0.15, reissue_interval):
				_mining_interaction_repath_timer = 0.0
				_log_mining_event("nav_finished_reissue_mineral_move", {
					"dist_anchor": snappedf(RTS_INTERACTION.flat_distance_xz(global_position, _target_position), 0.01),
					"dist_target": snappedf(RTS_INTERACTION.flat_distance_xz(global_position, _gather_target.global_position), 0.01)
				})
				_move_to(_mining_gather_approach_point(_gather_target))
		else:
			_mining_interaction_repath_timer = 0.0
		return
	_mining_interaction_repath_timer = 0.0
	if anchor_contact and not in_hard_contact:
		_log_mining_event("anchor_contact_fallback", {
			"anchor_tol": snappedf(_interaction_anchor_tolerance(), 0.01),
			"dist_anchor": snappedf(RTS_INTERACTION.flat_distance_xz(global_position, _target_position), 0.01)
		})
	elif nav_soft_contact and not in_hard_contact:
		_log_mining_event("nav_soft_contact_fallback", {
			"soft_slack": snappedf(_interaction_contact_slack(interaction_key, mining_nav_finish_contact_slack), 0.01),
			"dist_target": snappedf(RTS_INTERACTION.flat_distance_xz(global_position, _gather_target.global_position), 0.01)
		})
	_has_target = false
	velocity = Vector3.ZERO
	var slot_status: String = _request_mineral_slot(_gather_target, true)
	if slot_status == "granted":
		_log_mining_event("slot_granted")
		_set_mining_state(MiningState.HARVESTING)
		return
	if slot_status == "queued":
		_log_mining_event("slot_queued")
		_set_mining_state(MiningState.QUEUED)
		return
	_log_mining_event("slot_request_failed", {"slot_status": slot_status})
	if not _transition_to_next_mineral(_gather_target):
		_stop_worker_cycle(false)

func _process_queued_mining_state(delta: float) -> void:
	if _gather_target == null or not is_instance_valid(_gather_target) or _is_mineral_depleted(_gather_target):
		_log_mining_event("queued_target_invalid_or_depleted")
		if not _transition_to_next_mineral():
			_stop_worker_cycle(false)
		return

	var queue_anchor: Vector3 = _queue_anchor_for_mineral(_gather_target)
	if _is_near(queue_anchor, 0.2):
		_has_target = false
		velocity = Vector3.ZERO
	elif not _has_target:
		_move_to(queue_anchor)

	var slot_status: String = _request_mineral_slot(_gather_target, false)
	if slot_status == "granted":
		_log_mining_event("queue_promoted_to_harvest")
		_set_mining_state(MiningState.HARVESTING)
		return
	if slot_status == "depleted":
		_log_mining_event("queued_target_depleted")
		if not _transition_to_next_mineral(_gather_target):
			_stop_worker_cycle(false)
		return

	_mining_queue_timer += delta
	if _mining_queue_timer < maxf(0.2, mining_queue_timeout):
		return
	_log_mining_event("queue_timeout_switch_target", {
		"queue_wait_sec": snappedf(_mining_queue_timer, 0.01),
		"slot_status": slot_status
	})
	if not _transition_to_next_mineral(_gather_target):
		_mining_queue_timer = 0.0

func _process_harvesting_state(delta: float) -> void:
	if _gather_target == null or not is_instance_valid(_gather_target) or _is_mineral_depleted(_gather_target):
		_log_mining_event("harvesting_target_invalid_or_depleted")
		_abort_active_mining_target()
		if _carried_amount > 0:
			_set_mining_state(MiningState.MOVING_TO_BASE)
		elif not _transition_to_next_mineral():
			_stop_worker_cycle(false)
		return

	_has_target = false
	velocity = Vector3.ZERO
	_gather_timer += delta
	var harvest_duration: float = _harvest_duration_for_target(_gather_target)
	if _gather_timer < harvest_duration:
		return
	_gather_timer = 0.0

	var request_amount: int = _harvest_amount_for_target(_gather_target)
	if carry_capacity > 0:
		request_amount = mini(request_amount, maxi(0, carry_capacity - _carried_amount))
	if request_amount <= 0:
		_log_mining_event("harvest_skipped_no_capacity", {
			"carried": _carried_amount,
			"capacity": carry_capacity
		})
		_abort_active_mining_target()
		_set_mining_state(MiningState.MOVING_TO_BASE)
		return

	var harvested: int = _harvest_resource(_gather_target, request_amount)
	_abort_active_mining_target()
	if carry_capacity > 0:
		_carried_amount = mini(carry_capacity, _carried_amount + harvested)
	else:
		_carried_amount += harvested
	if harvested > 0:
		_remember_last_successful_mineral(_gather_target)
		_mining_harvest_stall_timer = 0.0
		_log_mining_event("harvest_success", {
			"harvested": harvested,
			"request_amount": request_amount
		})
	else:
		_log_mining_event("harvest_zero", {
			"request_amount": request_amount
		})

	if _defer_queue_until_worker_cycle_checkpoint:
		_defer_queue_until_worker_cycle_checkpoint = false
		_stop_worker_cycle(false)
		_notify_game_manager_worker_queue_transition("interrupt_checkpoint")
		return

	if harvested <= 0:
		if _carried_amount > 0:
			_set_mining_state(MiningState.MOVING_TO_BASE)
		elif not _transition_to_next_mineral():
			_stop_worker_cycle(false)
		return
	_set_mining_state(MiningState.MOVING_TO_BASE)

func _process_moving_to_base_state(_delta: float) -> void:
	if _dropoff_target == null or not is_instance_valid(_dropoff_target):
		_dropoff_target = _nearest_valid_dropoff(global_position)
		if _dropoff_target == null:
			_log_mining_event("no_dropoff_while_returning")
			_stop_worker_cycle(true)
			return
	var contact_range: float = _effective_dropoff_contact_range(_dropoff_target)
	var interaction_key: String = "dropoff"
	var direct_contact: bool = _is_interaction_ready(_dropoff_target, contact_range)
	if not direct_contact and _has_target and _can_use_navigation() and _nav_agent.is_navigation_finished():
		var nav_anchor_tolerance: float = _interaction_anchor_tolerance() + _interaction_anchor_slack(interaction_key, mining_nav_finish_anchor_slack)
		direct_contact = RTS_INTERACTION.is_within_distance_xz(global_position, _target_position, nav_anchor_tolerance)
		if direct_contact:
			_log_mining_event("dropoff_nav_anchor_contact", {
				"nav_anchor_tol": snappedf(nav_anchor_tolerance, 0.01),
				"dist_anchor": snappedf(RTS_INTERACTION.flat_distance_xz(global_position, _target_position), 0.01)
			})
	var nav_soft_contact: bool = false
	if not direct_contact:
		nav_soft_contact = _is_navigation_soft_contact(_dropoff_target, contact_range, interaction_key)
	if direct_contact or nav_soft_contact:
		if nav_soft_contact and not direct_contact:
			_log_mining_event("dropoff_nav_soft_contact", {
				"soft_slack": snappedf(_interaction_contact_slack(interaction_key, mining_nav_finish_contact_slack), 0.01),
				"dist_target": snappedf(RTS_INTERACTION.flat_distance_xz(global_position, _dropoff_target.global_position), 0.01)
			})
		_set_mining_state(MiningState.DELIVERING)
		return
	if _interaction_fallback_bool(interaction_key, "enable_nav_reissue", true) and _has_target and _can_use_navigation() and _nav_agent.is_navigation_finished():
		_mining_interaction_repath_timer += _delta
		var reissue_interval: float = _interaction_fallback_float(interaction_key, "reissue_interval", mining_interaction_repath_interval)
		if _mining_interaction_repath_timer >= maxf(0.15, reissue_interval):
			_mining_interaction_repath_timer = 0.0
			_log_mining_event("nav_finished_reissue_dropoff_move", {
				"dist_anchor": snappedf(RTS_INTERACTION.flat_distance_xz(global_position, _target_position), 0.01),
				"dist_target": snappedf(RTS_INTERACTION.flat_distance_xz(global_position, _dropoff_target.global_position), 0.01)
			})
			_move_to(_mining_dropoff_approach_point(_dropoff_target))
			return
	else:
		_mining_interaction_repath_timer = 0.0
	if not _has_target:
		_move_to(_mining_dropoff_approach_point(_dropoff_target))

func _process_delivering_state(delta: float) -> void:
	if _dropoff_target == null or not is_instance_valid(_dropoff_target):
		_dropoff_target = _nearest_valid_dropoff(global_position)
		if _dropoff_target == null:
			_log_mining_event("no_dropoff_while_delivering")
			_stop_worker_cycle(false)
			return
		_move_to(_mining_dropoff_approach_point(_dropoff_target))
		_set_mining_state(MiningState.MOVING_TO_BASE)
		return

	_has_target = false
	velocity = Vector3.ZERO
	_mining_delivery_timer += delta
	if _mining_delivery_timer < maxf(0.05, mining_delivery_duration):
		return
	_mining_delivery_timer = 0.0

	if _carried_amount > 0:
		_log_mining_event("deposit", {"deposit_amount": _carried_amount})
		_deposit_to_game_manager(_carried_amount)
		_carried_amount = 0

	if _defer_queue_until_worker_cycle_checkpoint:
		_defer_queue_until_worker_cycle_checkpoint = false
		_stop_worker_cycle(false)
		_notify_game_manager_worker_queue_transition("interrupt_checkpoint")
		return

	if _mining_auto_cycle_enabled:
		if _try_transition_to_last_successful_mineral():
			return
		if _transition_to_next_mineral():
			return
	_stop_worker_cycle(false)

func _transition_to_next_mineral(excluded_target: Node3D = null) -> bool:
	var next_target: Node3D = _find_best_mineral(_mining_preferred_target, excluded_target)
	if next_target == null:
		_log_mining_event("find_next_mineral_failed", {
			"excluded": _mining_debug_target_name(excluded_target)
		})
		return false
	if _gather_target != null and _gather_target != next_target:
		_abort_active_mining_target()
	_gather_target = next_target
	_log_mining_event("next_mineral_selected", {
		"next_target": _mining_debug_target_name(next_target),
		"excluded": _mining_debug_target_name(excluded_target)
	})
	_set_mining_state(MiningState.MOVING_TO_MINERAL)
	return true

func _remember_last_successful_mineral(mineral: Node3D) -> void:
	if mineral == null or not is_instance_valid(mineral):
		return
	_last_successful_mineral_target = mineral

func _try_transition_to_last_successful_mineral() -> bool:
	var remembered_target: Node3D = _last_successful_mineral_target
	if remembered_target == null or not is_instance_valid(remembered_target):
		_last_successful_mineral_target = null
		return false
	if _is_mineral_depleted(remembered_target):
		_last_successful_mineral_target = null
		return false
	var worker_load_map: Dictionary = _build_mineral_worker_load_map()
	var assigned_workers: int = int(worker_load_map.get(remembered_target.get_instance_id(), 0))
	var optimal_workers: int = _mineral_optimal_worker_count(remembered_target)
	if assigned_workers > optimal_workers:
		return false
	if _gather_target != null and _gather_target != remembered_target:
		_abort_active_mining_target()
	_gather_target = remembered_target
	_log_mining_event("resume_last_success_mineral", {
		"target": _mining_debug_target_name(remembered_target),
		"assigned": assigned_workers,
		"optimal": optimal_workers
	})
	_set_mining_state(MiningState.MOVING_TO_MINERAL)
	return true

func _find_best_mineral(preferred_target: Node3D = null, excluded_target: Node3D = null, ignore_radius: bool = false) -> Node3D:
	var search_origin: Vector3 = global_position
	if _dropoff_target != null and is_instance_valid(_dropoff_target):
		search_origin = _dropoff_target.global_position
	var best_available: Node3D = null
	var best_available_score: float = INF
	var best_queueable: Node3D = null
	var best_queueable_score: float = INF
	var resources: Array[Node] = get_tree().get_nodes_in_group("resource_node")
	var worker_load_map: Dictionary = _build_mineral_worker_load_map()

	for resource_node in resources:
		var mineral: Node3D = resource_node as Node3D
		if mineral == null or not is_instance_valid(mineral):
			continue
		if excluded_target != null and mineral == excluded_target:
			continue
		if _is_mineral_depleted(mineral):
			continue
		var base_distance: float = search_origin.distance_to(mineral.global_position)
		if not ignore_radius and mining_search_radius > 0.0 and base_distance > mining_search_radius:
			continue
		var worker_distance: float = global_position.distance_to(mineral.global_position)
		var assigned_workers: int = int(worker_load_map.get(mineral.get_instance_id(), 0))
		var optimal_workers: int = _mineral_optimal_worker_count(mineral)
		var overload_workers: int = maxi(0, assigned_workers - optimal_workers)
		var load_penalty: float = float(assigned_workers) * MINING_BALANCE_ASSIGNED_WEIGHT + float(overload_workers) * MINING_BALANCE_OVER_OPTIMAL_WEIGHT
		var score: float = worker_distance + base_distance * 0.15 + load_penalty
		if preferred_target != null and mineral == preferred_target:
			score -= 3.0
		var occupied: bool = _is_mineral_occupied(mineral)
		if not occupied:
			if score < best_available_score:
				best_available_score = score
				best_available = mineral
			continue
		if not _can_queue_for_mineral(mineral):
			continue
		var queue_penalty: float = _estimate_mineral_wait(mineral)
		var queue_score: float = score + queue_penalty + 4.0
		if preferred_target != null and mineral == preferred_target:
			queue_score -= 1.0
		if queue_score < best_queueable_score:
			best_queueable_score = queue_score
			best_queueable = mineral

	if best_available != null:
		return best_available
	if best_queueable != null:
		return best_queueable

	# Fallback pass without radius clamp when no candidate is found nearby.
	if not ignore_radius and mining_search_radius > 0.0:
		return _find_best_mineral(preferred_target, excluded_target, true)
	return null

func _build_mineral_worker_load_map() -> Dictionary:
	var load_map: Dictionary = {}
	var units: Array[Node] = get_tree().get_nodes_in_group("selectable_unit")
	for unit_node in units:
		if unit_node == null or not is_instance_valid(unit_node):
			continue
		if not unit_node.has_method("get_team_id") or int(unit_node.call("get_team_id")) != team_id:
			continue
		if not unit_node.has_method("get_active_mining_target"):
			continue
		var target_value: Variant = unit_node.call("get_active_mining_target")
		if not (target_value is Node3D):
			continue
		var target_mineral: Node3D = target_value as Node3D
		if target_mineral == null or not is_instance_valid(target_mineral):
			continue
		var mineral_id: int = target_mineral.get_instance_id()
		load_map[mineral_id] = int(load_map.get(mineral_id, 0)) + 1
	return load_map

func _mineral_optimal_worker_count(mineral: Node3D) -> int:
	if mineral == null or not is_instance_valid(mineral):
		return 1
	if mineral.has_method("get_optimal_worker_count"):
		return maxi(1, int(mineral.call("get_optimal_worker_count")))
	return 2

func _queue_anchor_for_mineral(mineral: Node3D) -> Vector3:
	var anchor_direction: Vector3 = global_position - mineral.global_position
	anchor_direction.y = 0.0
	if anchor_direction.length_squared() <= 0.0001 and _dropoff_target != null and is_instance_valid(_dropoff_target):
		anchor_direction = _dropoff_target.global_position - mineral.global_position
		anchor_direction.y = 0.0
	if anchor_direction.length_squared() <= 0.0001:
		anchor_direction = Vector3.RIGHT
	anchor_direction = anchor_direction.normalized()
	var offset: float = maxf(_effective_gather_contact_range(mineral) + 0.1, mining_queue_distance)
	return mineral.global_position + anchor_direction * offset

func _mining_gather_approach_point(mineral: Node3D) -> Vector3:
	return _interaction_edge_approach_point(mineral, true)

func _mining_dropoff_approach_point(dropoff: Node3D) -> Vector3:
	return _interaction_edge_approach_point(dropoff, true)

func _interaction_edge_approach_point(target_node: Node3D, include_obstacle: bool) -> Vector3:
	if target_node == null or not is_instance_valid(target_node):
		return global_position
	var outward: Vector3 = global_position - target_node.global_position
	outward.y = 0.0
	if outward.length_squared() <= 0.0001 and _has_target:
		outward = _target_position - target_node.global_position
		outward.y = 0.0
	if outward.length_squared() <= 0.0001:
		outward = Vector3.RIGHT
	var direction: Vector3 = outward.normalized()
	var target_radius: float = RTS_INTERACTION.collision_radius_xz(target_node, false)
	if include_obstacle:
		target_radius = maxf(target_radius, RTS_INTERACTION.obstacle_radius_xz(target_node))
	var edge_padding: float = clampf(interaction_edge_padding, 0.0, 0.25)
	var distance_from_target: float = maxf(0.05, target_radius + edge_padding)
	var approach_point: Vector3 = target_node.global_position + direction * distance_from_target
	approach_point.y = global_position.y
	return approach_point

func _effective_gather_contact_range(mineral: Node3D) -> float:
	return RTS_INTERACTION.compute_trigger_distance(
		self ,
		mineral,
		gather_range,
		gather_trigger_buffer,
		0.16,
		true
	)

func _effective_dropoff_contact_range(dropoff: Node3D) -> float:
	var nav_contact_padding: float = maxf(0.08, NAV_VERTICAL_POINT_TOLERANCE * 0.25)
	return RTS_INTERACTION.compute_trigger_distance(
		self ,
		dropoff,
		dropoff_range,
		dropoff_trigger_buffer + nav_contact_padding,
		0.2,
		true
	)

func _effective_repair_contact_range(target_node: Node3D) -> float:
	return RTS_INTERACTION.compute_trigger_distance(
		self ,
		target_node,
		repair_range,
		0.0,
		0.08,
		true
	)

func _effective_attack_contact_range(target_node: Node3D) -> float:
	return RTS_INTERACTION.compute_trigger_distance(
		self ,
		target_node,
		attack_range,
		0.0,
		0.05,
		true
	)

func _target_collision_radius_xz(target_node: Node3D) -> float:
	return RTS_INTERACTION.collision_radius_xz(target_node, false)

func _target_obstacle_radius_xz(target_node: Node3D) -> float:
	return RTS_INTERACTION.obstacle_radius_xz(target_node)

func _agent_radius_xz() -> float:
	return RTS_INTERACTION.collision_radius_xz(self , false)

func _interaction_anchor_tolerance() -> float:
	return maxf(0.18, interaction_nav_target_desired_distance + 0.08)

func _interaction_fallback_config(interaction_key: String) -> Dictionary:
	var key: String = interaction_key.strip_edges().to_lower()
	if key == "":
		return {}
	var config_value: Variant = _interaction_fallback_table.get(key, {})
	if config_value is Dictionary:
		return config_value as Dictionary
	return {}

func _interaction_fallback_bool(interaction_key: String, field: String, default_value: bool = false) -> bool:
	var config: Dictionary = _interaction_fallback_config(interaction_key)
	if config.is_empty():
		return default_value
	return bool(config.get(field, default_value))

func _interaction_fallback_float(interaction_key: String, field: String, default_value: float = 0.0) -> float:
	var config: Dictionary = _interaction_fallback_config(interaction_key)
	if config.is_empty():
		return default_value
	return float(config.get(field, default_value))

func _interaction_contact_slack(interaction_key: String, default_slack: float = 0.0) -> float:
	if not _interaction_fallback_bool(interaction_key, "enable_nav_soft_contact", false):
		return 0.0
	return maxf(0.0, _interaction_fallback_float(interaction_key, "contact_slack", default_slack))

func _interaction_anchor_slack(interaction_key: String, default_slack: float = 0.0) -> float:
	if not _interaction_fallback_bool(interaction_key, "enable_nav_anchor_fallback", false):
		return 0.0
	return maxf(0.0, _interaction_fallback_float(interaction_key, "anchor_slack", default_slack))

func _is_navigation_soft_contact(target_node: Node3D, contact_range: float, interaction_key: String) -> bool:
	if target_node == null or not is_instance_valid(target_node):
		return false
	var extra_slack: float = _interaction_contact_slack(interaction_key, 0.0)
	if extra_slack <= 0.0:
		return false
	if not _can_use_navigation() or not _nav_agent.is_navigation_finished():
		return false
	return RTS_INTERACTION.is_within_distance_xz(
		global_position,
		target_node.global_position,
		maxf(0.0, contact_range) + extra_slack
	)

func _is_interaction_ready(target_node: Node3D, contact_range: float, interaction_key: String = "") -> bool:
	if target_node == null or not is_instance_valid(target_node):
		return false
	if RTS_INTERACTION.is_within_distance_xz(global_position, target_node.global_position, contact_range):
		return true
	var anchor_tolerance: float = _interaction_anchor_tolerance()
	if _has_target and RTS_INTERACTION.is_within_distance_xz(global_position, _target_position, anchor_tolerance):
		return true
	if interaction_key.strip_edges().is_empty():
		return false
	if _has_target and _can_use_navigation() and _nav_agent.is_navigation_finished():
		var nav_anchor_tolerance: float = anchor_tolerance + _interaction_anchor_slack(interaction_key, 0.0)
		if nav_anchor_tolerance > anchor_tolerance and RTS_INTERACTION.is_within_distance_xz(global_position, _target_position, nav_anchor_tolerance):
			return true
	return _is_navigation_soft_contact(target_node, contact_range, interaction_key)

func _harvest_duration_for_target(mineral: Node3D) -> float:
	if mineral != null and is_instance_valid(mineral) and mineral.has_method("get_harvest_time"):
		return maxf(0.05, float(mineral.call("get_harvest_time")))
	return maxf(0.05, gather_interval)

func _harvest_amount_for_target(mineral: Node3D) -> int:
	if mineral != null and is_instance_valid(mineral) and mineral.has_method("get_harvest_yield"):
		return maxi(1, int(mineral.call("get_harvest_yield")))
	return maxi(1, gather_amount)

func _is_mineral_depleted(mineral: Node3D) -> bool:
	if mineral == null or not is_instance_valid(mineral):
		return true
	if mineral.has_method("is_depleted"):
		return bool(mineral.call("is_depleted"))
	if mineral.has_method("get_remaining_minerals"):
		return int(mineral.call("get_remaining_minerals")) <= 0
	return false

func _is_mineral_occupied(mineral: Node3D) -> bool:
	if mineral == null or not is_instance_valid(mineral):
		return false
	if mineral.has_method("is_occupied"):
		return bool(mineral.call("is_occupied"))
	return false

func _can_queue_for_mineral(mineral: Node3D) -> bool:
	if mineral == null or not is_instance_valid(mineral):
		return false
	if mineral.has_method("can_accept_waiter"):
		return bool(mineral.call("can_accept_waiter", self ))
	return false

func _estimate_mineral_wait(mineral: Node3D) -> float:
	if mineral == null or not is_instance_valid(mineral):
		return INF
	if mineral.has_method("estimate_wait_seconds"):
		return maxf(0.0, float(mineral.call("estimate_wait_seconds")))
	var queue_length: int = 0
	if mineral.has_method("get_wait_queue_length"):
		queue_length = maxi(0, int(mineral.call("get_wait_queue_length")))
	var has_occupier: bool = _is_mineral_occupied(mineral)
	var slots_ahead: int = queue_length + (1 if has_occupier else 0)
	return float(slots_ahead) * _harvest_duration_for_target(mineral)

func _request_mineral_slot(mineral: Node3D, allow_enqueue: bool = true) -> String:
	if mineral == null or not is_instance_valid(mineral):
		return "depleted"
	if not mineral.has_method("request_harvest_slot"):
		return "granted"
	var request_result_value: Variant = mineral.call("request_harvest_slot", self , allow_enqueue)
	if request_result_value is Dictionary:
		var request_result: Dictionary = request_result_value as Dictionary
		return str(request_result.get("status", "denied"))
	return "denied"

func _abort_active_mining_target() -> void:
	if _gather_target == null or not is_instance_valid(_gather_target):
		return
	if _gather_target.has_method("release_harvest_slot"):
		_gather_target.call("release_harvest_slot", self )
	elif _gather_target.has_method("remove_waiter"):
		_gather_target.call("remove_waiter", self )

func _nearest_valid_dropoff(from_position: Vector3) -> Node3D:
	var nearest: Node3D = null
	var best_distance_sq: float = INF
	var dropoff_nodes: Array[Node] = get_tree().get_nodes_in_group("resource_dropoff")
	for node in dropoff_nodes:
		var dropoff: Node3D = node as Node3D
		if dropoff == null or not is_instance_valid(dropoff):
			continue
		if dropoff.has_method("is_alive") and not bool(dropoff.call("is_alive")):
			continue
		if dropoff.has_method("get_team_id") and int(dropoff.call("get_team_id")) != team_id:
			continue
		var distance_sq: float = from_position.distance_squared_to(dropoff.global_position)
		if distance_sq < best_distance_sq:
			best_distance_sq = distance_sq
			nearest = dropoff
	return nearest

func request_speed_mining_brake_cancel() -> void:
	_hover_brake_release_timer = maxf(0.0, hover_brake_release_duration)

func _on_mineral_slot_available(mineral_node: Node) -> void:
	var mineral: Node3D = mineral_node as Node3D
	if mineral == null or not is_instance_valid(mineral):
		return
	if _mining_state != MiningState.QUEUED:
		return
	if _gather_target != mineral:
		return
	if _request_mineral_slot(mineral, false) == "granted":
		_set_mining_state(MiningState.HARVESTING)

func _on_mineral_depleted(mineral_node: Node) -> void:
	var mineral: Node3D = mineral_node as Node3D
	if mineral == null:
		return
	if _gather_target == mineral:
		_gather_target = null
	if _mining_preferred_target == mineral:
		_mining_preferred_target = null
	if _last_successful_mineral_target == mineral:
		_last_successful_mineral_target = null

func _process_repair_cycle(delta: float) -> void:
	if not is_worker:
		command_stop(true)
		return
	if not _is_valid_repair_target(_repair_target):
		command_stop(true)
		return
	if not _is_repair_target_damaged(_repair_target):
		command_stop(true)
		return
	var effective_repair_range: float = _effective_repair_contact_range(_repair_target)
	if _is_interaction_ready(_repair_target, effective_repair_range, "repair"):
		_has_target = false
		velocity = Vector3.ZERO
		_repair_timer += delta
		var effective_interval: float = maxf(0.05, repair_interval)
		if _repair_timer < effective_interval:
			return
		_repair_timer = 0.0
		var repaired: bool = false
		if _repair_target.has_method("repair"):
			repaired = bool(_repair_target.call("repair", maxf(0.0, repair_amount), self ))
		if not repaired or not _is_repair_target_damaged(_repair_target):
			command_stop(true)
		return
	if not _has_target:
		_move_to(_repair_target.global_position)

func _process_combat_cycle(delta: float) -> void:
	if is_worker or attack_damage <= 0.0 or attack_range <= 0.0:
		command_stop(true)
		return
	_retarget_timer = maxf(0.0, _retarget_timer - delta)

	if _attack_target == null or not is_instance_valid(_attack_target) or not _is_valid_enemy_target(_attack_target):
		_attack_target = null
		if _mode == UnitMode.ATTACK:
			_mode = UnitMode.ATTACK_MOVE
			if not _has_attack_move_point:
				_attack_move_point = _target_position
				_has_attack_move_point = true
		if not _try_acquire_new_combat_target(true):
			_continue_attack_move_progress()
			return

	if _attack_target == null:
		_continue_attack_move_progress()
		return
	if not is_instance_valid(_attack_target):
		_attack_target = null
		_continue_attack_move_progress()
		return
	var attack_target_3d: Node3D = _attack_target as Node3D
	if attack_target_3d == null:
		_attack_target = null
		_continue_attack_move_progress()
		return

	var target_position: Vector3 = attack_target_3d.global_position
	var effective_attack_range: float = _effective_attack_contact_range(attack_target_3d)
	if _is_interaction_ready(attack_target_3d, effective_attack_range, "attack"):
		_has_target = false
		velocity = Vector3.ZERO
		_attack_timer += delta
		var cooldown: float = maxf(0.05, attack_cooldown)
		if _attack_timer >= cooldown:
			_attack_timer = 0.0
			if _attack_target != null and _attack_target.has_method("apply_damage"):
				_attack_target.call("apply_damage", attack_damage, self )
				_spawn_attack_vfx(target_position)
		return

	_move_to(target_position)
	if _mode == UnitMode.ATTACK_MOVE and _retarget_timer <= 0.0:
		_try_acquire_new_combat_target()

func _continue_attack_move_progress() -> void:
	if _mode != UnitMode.ATTACK_MOVE:
		command_stop(true)
		return
	if _try_acquire_new_combat_target():
		return
	if not _has_attack_move_point:
		_has_target = false
		velocity = Vector3.ZERO
		return
	if _is_near(_attack_move_point, maxf(0.45, attack_range * 0.35)):
		_has_target = false
		velocity = Vector3.ZERO
		return
	_move_to(_attack_move_point)

func _try_acquire_new_combat_target(force: bool = false) -> bool:
	if not force and _retarget_timer > 0.0:
		return false
	_retarget_timer = maxf(0.05, retarget_interval)
	var search_range: float = auto_acquire_range
	if _mode == UnitMode.ATTACK_MOVE:
		search_range = maxf(search_range, attack_move_acquire_range)
	var new_target: Node3D = _find_priority_enemy_in_range(search_range)
	if new_target == null:
		return false
	_attack_target = new_target
	_attack_timer = 0.0
	return true

func _find_priority_enemy_in_range(search_range: float) -> Node3D:
	var range_sq: float = search_range * search_range
	var from_position: Vector3 = global_position
	var best_unit: Node3D = _find_nearest_enemy_in_group("selectable_unit", from_position, range_sq)
	if best_unit != null:
		return best_unit
	return _find_nearest_enemy_in_group("selectable_building", from_position, range_sq)

func _find_nearest_enemy_in_group(group_name: String, from_position: Vector3, range_sq: float) -> Node3D:
	var nearest: Node3D = null
	var best_distance_sq: float = range_sq
	var candidates: Array[Node] = get_tree().get_nodes_in_group(group_name)
	for node in candidates:
		if node == null or not is_instance_valid(node):
			continue
		var target: Node3D = node as Node3D
		if target == null:
			continue
		if not _is_valid_enemy_target(target):
			continue
		var delta: Vector3 = target.global_position - from_position
		delta.y = 0.0
		var distance_sq: float = delta.length_squared()
		if distance_sq > range_sq:
			continue
		if nearest == null or distance_sq < best_distance_sq:
			nearest = target
			best_distance_sq = distance_sq
	return nearest

func _is_valid_enemy_target(target_node) -> bool:
	if target_node == null or not is_instance_valid(target_node):
		return false
	if target_node == self:
		return false
	if not _target_is_enemy(target_node):
		return false
	if target_node.has_method("is_alive") and not bool(target_node.call("is_alive")):
		return false
	return true

func _clear_repair_state() -> void:
	_repair_target = null
	_repair_timer = 0.0

func _is_valid_repair_target(target_node: Node3D) -> bool:
	if target_node == null or not is_instance_valid(target_node):
		return false
	if target_node == self:
		return false
	var selectable: bool = target_node.is_in_group("selectable_unit") or target_node.is_in_group("selectable_building")
	if not selectable:
		return false
	if target_node.has_method("is_alive") and not bool(target_node.call("is_alive")):
		return false
	if target_node.has_method("get_team_id") and int(target_node.call("get_team_id")) != team_id:
		return false
	return target_node.has_method("repair")

func _is_repair_target_damaged(target_node: Node3D) -> bool:
	if target_node == null or not is_instance_valid(target_node):
		return false
	if target_node.has_method("is_damaged"):
		return bool(target_node.call("is_damaged"))
	if target_node.has_method("get_health_points"):
		var max_hp: float = float(target_node.get("max_health"))
		if max_hp <= 0.0:
			return false
		var hp: float = float(target_node.call("get_health_points"))
		return hp < max_hp - 0.01
	return false

func _switch_to_return_mode() -> void:
	if _dropoff_target == null or not is_instance_valid(_dropoff_target):
		_dropoff_target = _nearest_valid_dropoff(global_position)
		if _dropoff_target == null:
			_stop_worker_cycle(true)
			return
	_set_mining_state(MiningState.MOVING_TO_BASE)

func _stop_worker_cycle(reset_carry: bool) -> void:
	_log_mining_event("stop_worker_cycle", {
		"reset_carry": reset_carry,
		"carried_before_stop": _carried_amount
	})
	_abort_active_mining_target()
	_set_mining_state(MiningState.IDLE)
	_has_target = false
	velocity = Vector3.ZERO
	_gather_target = null
	_dropoff_target = null
	_mining_preferred_target = null
	_mining_auto_cycle_enabled = false
	_gather_timer = 0.0
	_mining_queue_timer = 0.0
	_mining_delivery_timer = 0.0
	_mining_interaction_repath_timer = 0.0
	_mining_debug_accum = 0.0
	_mining_harvest_stall_timer = 0.0
	_mining_last_logged_state = _mining_state
	_defer_queue_until_worker_cycle_checkpoint = false
	_clear_repair_state()
	_has_attack_move_point = false
	_attack_move_point = Vector3.ZERO
	_retarget_timer = 0.0
	_hover_current_speed = 0.0
	_hover_brake_release_timer = 0.0
	_reset_navigation_motion()
	if reset_carry:
		_carried_amount = 0

func _harvest_resource(resource_node: Node3D, amount: int) -> int:
	if amount <= 0:
		return 0
	if not resource_node.has_method("harvest"):
		return 0
	var harvested_value: Variant = resource_node.call("harvest", amount, self )
	return maxi(0, int(harvested_value))

func _deposit_to_game_manager(amount: int) -> void:
	if amount <= 0:
		return
	var game_manager: Node = get_tree().get_first_node_in_group("game_manager")
	if game_manager != null and game_manager.has_method("add_minerals_for_team"):
		game_manager.call("add_minerals_for_team", team_id, amount)
	elif game_manager != null and game_manager.has_method("add_minerals"):
		game_manager.call("add_minerals", amount)

func _apply_movement(delta: float) -> void:
	if not _has_target:
		_reset_congestion_ghosting()
		_hover_current_speed = 0.0
		_hover_brake_release_timer = 0.0
		velocity = Vector3.ZERO
		move_and_slide()
		return

	var frame_start_position: Vector3 = global_position
	var move_target: Vector3 = _target_position
	var nav_finished: bool = false
	if _can_use_navigation():
		nav_finished = _nav_agent.is_navigation_finished()
		if nav_finished:
			_has_target = false
			_reset_navigation_motion()
			_hover_current_speed = 0.0
			_hover_brake_release_timer = 0.0
			velocity = Vector3.ZERO
			move_and_slide()
			return
		move_target = _nav_agent.get_next_path_position()

	var to_target: Vector3 = move_target - global_position
	to_target.y = 0.0
	if to_target.length() <= 0.1:
		if _can_use_navigation() and not _nav_agent.is_navigation_finished():
			_force_navigation_repath("next_point_same_as_current", RTS_INTERACTION.flat_distance_xz(global_position, _target_position))
			_hover_current_speed = 0.0
			_hover_brake_release_timer = 0.0
			velocity = Vector3.ZERO
			move_and_slide()
			return
		else:
			_has_target = false
			_reset_navigation_motion()
			_hover_current_speed = 0.0
			_hover_brake_release_timer = 0.0
			velocity = Vector3.ZERO
			move_and_slide()
			return

	var waypoint_distance: float = to_target.length()
	var final_target_delta: Vector3 = _target_position - global_position
	final_target_delta.y = 0.0
	var final_target_distance: float = final_target_delta.length()
	var motion_distance: float = waypoint_distance
	if _can_use_navigation():
		# Use remaining distance to final interaction anchor for braking decisions.
		# Avoids slowing to zero at every intermediate nav waypoint.
		motion_distance = maxf(waypoint_distance, final_target_distance)
	else:
		motion_distance = final_target_distance
	var direction: Vector3 = to_target.normalized()
	var desired_speed: float = move_speed
	if _use_hover_mining_dynamics():
		_hover_brake_release_timer = maxf(0.0, _hover_brake_release_timer - delta)
		var acceleration: float = maxf(0.01, move_speed / maxf(0.05, hover_acceleration_time))
		var braking_denominator: float = maxf(0.01, 2.0 * maxf(0.1, hover_deceleration_factor))
		var braking_distance: float = (_hover_current_speed * _hover_current_speed) / braking_denominator
		var should_brake: bool = motion_distance <= braking_distance and _hover_brake_release_timer <= 0.0
		if should_brake:
			_hover_current_speed = maxf(0.0, _hover_current_speed - maxf(0.1, hover_deceleration_factor) * delta)
		else:
			_hover_current_speed = minf(move_speed, _hover_current_speed + acceleration * delta)
		desired_speed = _hover_current_speed
	else:
		_hover_current_speed = move_speed
		_hover_brake_release_timer = 0.0
	var desired_velocity: Vector3 = direction * desired_speed
	_last_desired_velocity = desired_velocity
	if _can_use_navigation() and _nav_agent.avoidance_enabled:
		_nav_agent.set_velocity(desired_velocity)
		var current_physics_frame: int = Engine.get_physics_frames()
		var has_recent_safe_velocity: bool = _has_safe_velocity and _safe_velocity_frame >= current_physics_frame - 2
		if has_recent_safe_velocity and _safe_velocity.length_squared() > 0.0004:
			velocity = _safe_velocity
		else:
			velocity = desired_velocity
	else:
		velocity = desired_velocity
	velocity.y = 0.0

	# Stuck diagnostics: target exists, distance still large, but final velocity stays near zero.
	if debug_nav_log:
		if motion_distance > 0.45 and velocity.length_squared() < 0.0025:
			_stuck_log_accum += delta
			if _stuck_log_accum >= maxf(0.2, debug_nav_log_interval):
				_stuck_log_accum = 0.0
				_log_nav_state("stuck", move_target, desired_velocity, nav_finished, motion_distance)
		else:
			_stuck_log_accum = 0.0
	move_and_slide()
	_process_target_progress_watchdog(delta)
	_update_congestion_state(delta, motion_distance, desired_velocity.length(), frame_start_position)

func _move_to(target: Vector3) -> void:
	_target_position = Vector3(target.x, global_position.y, target.z)
	_has_target = true
	_has_safe_velocity = false
	_last_desired_velocity = Vector3.ZERO
	_target_progress_timer = 0.0
	_target_progress_best_distance = RTS_INTERACTION.flat_distance_xz(global_position, _target_position)
	_target_progress_repath_cooldown = 0.0
	if debug_nav_log:
		_log_nav_state("move_to", _target_position, Vector3.ZERO, false, global_position.distance_to(_target_position))
	if _can_use_navigation():
		if not _has_nav_target_cached or _nav_target_cached.distance_to(_target_position) > 0.25:
			_nav_agent.target_position = _target_position
			_nav_target_cached = _target_position
			_has_nav_target_cached = true

func _process_target_progress_watchdog(delta: float) -> void:
	if not _has_target:
		_target_progress_timer = 0.0
		_target_progress_best_distance = INF
		_target_progress_repath_cooldown = 0.0
		return
	var remaining_distance: float = RTS_INTERACTION.flat_distance_xz(global_position, _target_position)
	_target_progress_repath_cooldown = maxf(0.0, _target_progress_repath_cooldown - delta)
	if _target_progress_best_distance == INF or remaining_distance < _target_progress_best_distance - 0.04:
		_target_progress_best_distance = remaining_distance
		_target_progress_timer = 0.0
		return
	_target_progress_timer += delta
	if remaining_distance <= maxf(0.35, _interaction_anchor_tolerance()):
		return
	if _target_progress_timer < 0.7:
		return
	_force_navigation_repath("repath_no_progress", remaining_distance)

func _force_navigation_repath(reason: String, remaining_distance: float) -> void:
	if _target_progress_repath_cooldown > 0.0:
		return
	if _can_use_navigation():
		_has_nav_target_cached = false
		_nav_agent.target_position = _target_position
		_nav_target_cached = _target_position
		_has_nav_target_cached = true
	_target_progress_timer = 0.0
	_target_progress_best_distance = remaining_distance
	_target_progress_repath_cooldown = 0.45
	if _is_mining_debug_candidate():
		_log_mining_event(reason, {
			"dist_cmd": snappedf(remaining_distance, 0.01)
		})
	elif debug_nav_log:
		_log_nav_state(reason, _target_position, _last_desired_velocity, _can_use_navigation() and _nav_agent.is_navigation_finished(), remaining_distance)

func _is_near(target_position: Vector3, distance_limit: float) -> bool:
	return RTS_INTERACTION.is_within_distance_xz(global_position, target_position, distance_limit)

func _use_hover_mining_dynamics() -> bool:
	if not is_worker:
		return false
	return _mining_state == MiningState.MOVING_TO_MINERAL or _mining_state == MiningState.MOVING_TO_BASE

func _apply_role_visual() -> void:
	if _sprite == null:
		return
	var unit_color: Color
	if is_worker:
		unit_color = Color(0.45, 1.0, 0.45, 1.0)
	else:
		unit_color = Color(1.0, 0.5, 0.5, 1.0)
	if team_id != 1:
		unit_color = Color(0.45, 0.72, 1.0, 1.0)
	_base_tint = unit_color
	_sprite.modulate = unit_color
	_sync_outline_sprite_visual()
	_update_health_bar_visual()

func _sync_sprite_to_collider() -> void:
	if not sprite_match_collider or _sprite == null:
		return
	var desired_size: Vector2 = _get_collider_sprite_size()
	if desired_size == Vector2.ZERO:
		return
	var texture: Texture2D = _sprite.texture
	if texture == null:
		return
	var tex_size: Vector2 = texture.get_size()
	if tex_size.x <= 0.0 or tex_size.y <= 0.0:
		return
	var base_world: Vector2 = tex_size * _sprite.pixel_size
	_sprite_base_scale = Vector3(
		desired_size.x / maxf(0.001, base_world.x),
		desired_size.y / maxf(0.001, base_world.y),
		1.0
	)
	_sprite.scale = _sprite_base_scale
	_sync_outline_sprite_visual()

func _get_collider_sprite_size() -> Vector2:
	var shape_node: CollisionShape3D = get_node_or_null("CollisionShape3D") as CollisionShape3D
	if shape_node == null or shape_node.shape == null:
		return Vector2.ZERO
	var shape: Shape3D = shape_node.shape
	if shape is CapsuleShape3D:
		var capsule: CapsuleShape3D = shape as CapsuleShape3D
		var width: float = capsule.radius * 2.0
		var height: float = capsule.height + capsule.radius * 2.0
		return Vector2(width, height)
	if shape is BoxShape3D:
		var box: BoxShape3D = shape as BoxShape3D
		return Vector2(maxf(box.size.x, box.size.z), box.size.y)
	if shape is CylinderShape3D:
		var cylinder: CylinderShape3D = shape as CylinderShape3D
		return Vector2(cylinder.radius * 2.0, cylinder.height)
	if shape is SphereShape3D:
		var sphere: SphereShape3D = shape as SphereShape3D
		return Vector2(sphere.radius * 2.0, sphere.radius * 2.0)
	return Vector2.ZERO

func _ensure_outline_sprite() -> void:
	if _sprite == null or not sprite_outline_enabled:
		return
	if _outline_sprite != null and is_instance_valid(_outline_sprite):
		return
	_outline_sprite = Sprite3D.new()
	_outline_sprite.name = "OutlineSprite3D"
	_outline_sprite.billboard = _sprite.billboard
	_outline_sprite.texture = _sprite.texture
	_outline_sprite.pixel_size = _sprite.pixel_size
	_outline_sprite.position = _sprite.position
	_outline_sprite.scale = _sprite.scale * sprite_outline_scale
	_outline_sprite.visible = false
	_outline_sprite.render_priority = _sprite.render_priority + 2
	_outline_material = StandardMaterial3D.new()
	_outline_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_outline_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_outline_material.no_depth_test = true
	_outline_material.albedo_color = sprite_outline_color
	_outline_material.albedo_texture = _sprite.texture
	_outline_sprite.material_override = _outline_material
	add_child(_outline_sprite)

func _sync_outline_sprite_visual() -> void:
	if _outline_sprite == null or not is_instance_valid(_outline_sprite) or _sprite == null:
		return
	_outline_sprite.texture = _sprite.texture
	_outline_sprite.pixel_size = _sprite.pixel_size
	_outline_sprite.position = _sprite.position
	_outline_sprite.scale = _sprite.scale * sprite_outline_scale
	if _outline_material != null:
		_outline_material.albedo_color = sprite_outline_color
		_outline_material.albedo_texture = _sprite.texture

func _update_sprite_outline(delta: float) -> void:
	if not sprite_outline_enabled or _sprite == null:
		_set_outline_visible(false)
		return
	if _outline_sprite == null or not is_instance_valid(_outline_sprite):
		_ensure_outline_sprite()
	if _outline_sprite == null:
		return
	_outline_timer -= delta
	if _outline_timer > 0.0:
		return
	_outline_timer = maxf(0.02, sprite_outline_check_interval)
	var occluded: bool = _is_sprite_occluded()
	_set_outline_visible(occluded)

func _set_outline_visible(visible: bool) -> void:
	if _outline_visible == visible:
		return
	_outline_visible = visible
	if _outline_sprite != null and is_instance_valid(_outline_sprite):
		_outline_sprite.visible = visible

func _is_sprite_occluded() -> bool:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null:
		return false
	if not is_inside_tree():
		return false
	var world: World3D = get_world_3d()
	if world == null:
		return false
	var origin: Vector3 = camera.global_position
	var target: Vector3 = _sprite.global_position
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(origin, target)
	query.collide_with_areas = false
	query.collision_mask = 0x7fffffff
	query.exclude = [get_rid()]
	var hit: Dictionary = world.direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return false
	var collider: Object = hit.get("collider")
	return collider != null and collider != self

func _apply_runtime_config_for_role() -> void:
	var unit_kind: String = get_unit_kind()
	var unit_def: Dictionary = RTS_CATALOG.get_unit_def(unit_kind)
	max_health = float(unit_def.get("max_health", max_health))
	move_speed = float(unit_def.get("move_speed", move_speed))
	gather_range = float(unit_def.get("gather_range", gather_range))
	dropoff_range = float(unit_def.get("dropoff_range", dropoff_range))
	carry_capacity = int(unit_def.get("carry_capacity", carry_capacity))
	gather_amount = int(unit_def.get("gather_amount", gather_amount))
	gather_interval = float(unit_def.get("gather_interval", gather_interval))
	mining_search_radius = maxf(0.0, float(unit_def.get("mining_search_radius", mining_search_radius)))
	mining_nav_finish_contact_slack = maxf(0.0, float(unit_def.get("mining_nav_finish_contact_slack", mining_nav_finish_contact_slack)))
	mining_nav_finish_anchor_slack = maxf(0.0, float(unit_def.get("mining_nav_finish_anchor_slack", mining_nav_finish_anchor_slack)))
	repair_range = float(unit_def.get("repair_range", repair_range))
	repair_amount = float(unit_def.get("repair_amount", repair_amount))
	repair_interval = float(unit_def.get("repair_interval", repair_interval))
	attack_damage = float(unit_def.get("attack_damage", attack_damage))
	attack_range = float(unit_def.get("attack_range", attack_range))
	attack_cooldown = float(unit_def.get("attack_cooldown", attack_cooldown))
	nav_agent_radius = maxf(0.08, float(unit_def.get("nav_agent_radius", nav_agent_radius)))
	nav_agent_height = maxf(0.2, float(unit_def.get("nav_agent_height", nav_agent_height)))
	nav_avoidance_priority = clampf(float(unit_def.get("nav_avoidance_priority", nav_avoidance_priority)), 0.0, 1.0)
	push_priority = int(unit_def.get("push_priority", push_priority))
	push_can_be_displaced = bool(unit_def.get("push_can_be_displaced", push_can_be_displaced))
	push_allow_cross_team_displace = bool(unit_def.get("push_allow_cross_team_displace", push_allow_cross_team_displace))
	_apply_interaction_fallback_table(unit_def)
	var body_radius: float = float(unit_def.get("body_radius", -1.0))
	if body_radius > 0.0:
		_apply_body_radius_profile(body_radius)
	_apply_nav_avoidance_profile()
	if _nav_agent != null:
		_nav_agent.max_speed = move_speed
	_update_health_bar_visual()

func _default_interaction_fallback_table() -> Dictionary:
	return {
		"gather": {
			"enable_nav_soft_contact": true,
			"contact_slack": mining_nav_finish_contact_slack,
			"enable_nav_anchor_fallback": true,
			"anchor_slack": mining_nav_finish_anchor_slack,
			"enable_nav_reissue": true,
			"reissue_interval": mining_interaction_repath_interval
		},
		"dropoff": {
			"enable_nav_soft_contact": true,
			"contact_slack": mining_nav_finish_contact_slack,
			"enable_nav_anchor_fallback": true,
			"anchor_slack": mining_nav_finish_anchor_slack,
			"enable_nav_reissue": true,
			"reissue_interval": mining_interaction_repath_interval
		},
		"repair": {
			"enable_nav_soft_contact": false,
			"contact_slack": 0.0,
			"enable_nav_anchor_fallback": false,
			"anchor_slack": 0.0,
			"enable_nav_reissue": true,
			"reissue_interval": 0.45
		},
		"attack": {
			"enable_nav_soft_contact": false,
			"contact_slack": 0.0,
			"enable_nav_anchor_fallback": false,
			"anchor_slack": 0.0,
			"enable_nav_reissue": true,
			"reissue_interval": 0.35
		}
	}

func _apply_interaction_fallback_table(unit_def: Dictionary) -> void:
	var resolved: Dictionary = _default_interaction_fallback_table()
	var override_value: Variant = unit_def.get("interaction_fallbacks", {})
	if override_value is Dictionary:
		var overrides: Dictionary = override_value as Dictionary
		for key_value in overrides.keys():
			var key: String = str(key_value).strip_edges().to_lower()
			if key == "":
				continue
			var override_config_value: Variant = overrides.get(key_value, {})
			if not (override_config_value is Dictionary):
				continue
			var merged_config: Dictionary = {}
			var existing_value: Variant = resolved.get(key, {})
			if existing_value is Dictionary:
				merged_config = (existing_value as Dictionary).duplicate(true)
			var override_config: Dictionary = override_config_value as Dictionary
			for field_value in override_config.keys():
				merged_config[str(field_value)] = override_config.get(field_value)
			resolved[key] = merged_config
	_interaction_fallback_table = resolved

func _apply_body_radius_profile(body_radius: float) -> void:
	var shape_node: CollisionShape3D = get_node_or_null("CollisionShape3D") as CollisionShape3D
	if shape_node != null and shape_node.shape is CapsuleShape3D:
		var source_capsule: CapsuleShape3D = shape_node.shape as CapsuleShape3D
		var capsule: CapsuleShape3D = source_capsule.duplicate(true) as CapsuleShape3D
		if capsule != null:
			capsule.radius = clampf(body_radius, 0.12, 1.5)
			shape_node.shape = capsule
	var obstacle_node: NavigationObstacle3D = get_node_or_null("Obstacle3D") as NavigationObstacle3D
	if obstacle_node != null:
		obstacle_node.set("radius", clampf(body_radius + 0.05, 0.12, 1.8))

func _apply_nav_avoidance_profile() -> void:
	if _nav_agent == null:
		return
	_nav_agent.radius = maxf(0.08, nav_agent_radius)
	_nav_agent.height = maxf(0.2, nav_agent_height)
	_nav_agent.avoidance_priority = clampf(nav_avoidance_priority, 0.0, 1.0)

func _target_is_enemy(target_node) -> bool:
	if target_node == null:
		return false
	if not is_instance_valid(target_node):
		return false
	if not target_node.has_method("get_team_id"):
		return false
	return int(target_node.call("get_team_id")) != team_id

func _die() -> void:
	_selection_ring.visible = false
	_abort_active_mining_target()
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
	mesh.radius = 0.1
	mesh.height = 0.2
	tracer.mesh = mesh

	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1.0, 0.55, 0.45, 0.95) if team_id == 1 else Color(0.55, 0.75, 1.0, 0.95)
	tracer.material_override = mat

	var launch_pos: Vector3 = global_position + Vector3(0.0, 1.1, 0.0)
	var hit_pos: Vector3 = target_position + Vector3(0.0, 1.0, 0.0)
	root_3d.add_child(tracer)
	tracer.global_position = launch_pos

	var tween: Tween = create_tween()
	tween.tween_property(tracer, "global_position", hit_pos, 0.09)
	tween.tween_callback(Callable(tracer, "queue_free"))

func _play_hit_flash() -> void:
	if _sprite == null:
		return
	_sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)
	var tween: Tween = create_tween()
	tween.tween_property(_sprite, "modulate", _base_tint, 0.08)

func _play_repair_flash() -> void:
	if _sprite == null:
		return
	var repair_tint: Color = _base_tint.lerp(Color(0.52, 1.0, 0.68, _base_tint.a), 0.35)
	_sprite.modulate = repair_tint
	var tween: Tween = create_tween()
	tween.tween_property(_sprite, "modulate", _base_tint, 0.1)

func _ensure_health_bar_nodes() -> void:
	if _health_bar_root != null and is_instance_valid(_health_bar_root):
		return
	_health_bar_root = Node3D.new()
	_health_bar_root.name = "HealthBarRoot"
	_health_bar_root.position = Vector3(0.0, HEALTH_BAR_WORLD_HEIGHT, 0.0)
	add_child(_health_bar_root)

	_health_bar_background = MeshInstance3D.new()
	_health_bar_background.name = "HealthBarBackground"
	var background_mesh: QuadMesh = QuadMesh.new()
	background_mesh.size = Vector2(HEALTH_BAR_WIDTH, HEALTH_BAR_HEIGHT)
	_health_bar_background.mesh = background_mesh
	var background_material: StandardMaterial3D = StandardMaterial3D.new()
	background_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	background_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	background_material.albedo_color = Color(0.05, 0.05, 0.07, 0.72)
	background_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_health_bar_background.material_override = background_material
	_health_bar_root.add_child(_health_bar_background)

	_health_bar_fill = MeshInstance3D.new()
	_health_bar_fill.name = "HealthBarFill"
	var fill_mesh: QuadMesh = QuadMesh.new()
	fill_mesh.size = Vector2(_health_bar_fill_full_width, maxf(0.02, HEALTH_BAR_HEIGHT - HEALTH_BAR_PADDING * 2.0))
	_health_bar_fill.mesh = fill_mesh
	_health_bar_fill.position = Vector3(0.0, 0.0, 0.005)
	var fill_material: StandardMaterial3D = StandardMaterial3D.new()
	fill_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fill_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fill_material.albedo_color = Color(0.22, 0.9, 0.36, 0.92)
	fill_material.emission_enabled = true
	fill_material.emission = Color(0.18, 0.78, 0.3, 1.0)
	fill_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_health_bar_fill.material_override = fill_material
	_health_bar_root.add_child(_health_bar_fill)

func _update_health_bar_visual() -> void:
	if _health_bar_root == null or not is_instance_valid(_health_bar_root):
		return
	if _health_bar_fill == null or not is_instance_valid(_health_bar_fill):
		return
	_health_bar_root.visible = is_alive()
	if not is_alive():
		return
	var ratio: float = clampf(get_health_ratio(), 0.0, 1.0)
	if ratio <= 0.001:
		_health_bar_fill.visible = false
		return
	_health_bar_fill.visible = true
	_health_bar_fill.scale.x = maxf(0.001, ratio)
	_health_bar_fill.position.x = -0.5 * _health_bar_fill_full_width * (1.0 - ratio)
	var low: Color = Color(0.95, 0.2, 0.2, 0.92)
	var high: Color = Color(0.2, 0.9, 0.36, 0.92)
	var hp_color: Color = low.lerp(high, ratio)
	var fill_material: StandardMaterial3D = _health_bar_fill.material_override as StandardMaterial3D
	if fill_material != null:
		fill_material.albedo_color = hp_color
		fill_material.emission = Color(hp_color.r * 0.85, hp_color.g * 0.85, hp_color.b * 0.85, 1.0)

func _set_construction_hidden(hidden: bool) -> void:
	if hidden == _construction_hidden:
		return
	_construction_hidden = hidden
	visible = not hidden
	_selection_ring.visible = false
	if hidden:
		if is_in_group("selectable_unit"):
			remove_from_group("selectable_unit")
		collision_layer = 0
		collision_mask = 0
		_push_yield_timer = 0.0
		_push_yield_scan_timer = 0.0
		_set_priority_yield_collision_ghosted(false)
		_reset_congestion_ghosting()
		if _nav_agent != null:
			_nav_agent.avoidance_enabled = false
			_nav_agent.set_velocity_forced(Vector3.ZERO)
		return
	if not is_in_group("selectable_unit"):
		add_to_group("selectable_unit")
	collision_layer = _default_collision_layer
	_refresh_unit_collision_mask()
	if _nav_agent != null:
		_nav_agent.avoidance_enabled = not _worker_collection_profile_active
		_nav_agent.set_velocity_forced(Vector3.ZERO)

func _setup_navigation_agent() -> void:
	if _nav_agent == null:
		return
	_nav_agent.max_speed = move_speed
	# Nav path points are often elevated by ~0.5 on baked meshes; keep tolerance above that
	# so waypoint progression does not stall when XZ is aligned but Y differs.
	_default_nav_path_desired_distance = maxf(0.05, NAV_VERTICAL_POINT_TOLERANCE)
	_default_nav_target_desired_distance = maxf(0.05, NAV_VERTICAL_POINT_TOLERANCE)
	_nav_agent.path_desired_distance = _default_nav_path_desired_distance
	_nav_agent.target_desired_distance = _default_nav_target_desired_distance
	_nav_agent.avoidance_enabled = true
	_apply_nav_avoidance_profile()
	var callback: Callable = Callable(self , "_on_nav_velocity_computed")
	if not _nav_agent.is_connected("velocity_computed", callback):
		_nav_agent.connect("velocity_computed", callback)
	_sync_nav_debug_draw()
	_sync_worker_collection_navigation_profile()
	_sync_navigation_precision_profile()

func _sync_nav_debug_draw() -> void:
	if _nav_agent == null:
		return
	if _nav_debug_draw_initialized and _nav_debug_draw_last_enabled == debug_nav_draw_path:
		return
	_nav_agent.debug_enabled = debug_nav_draw_path
	_nav_debug_draw_last_enabled = debug_nav_draw_path
	_nav_debug_draw_initialized = true

func _can_use_navigation() -> bool:
	if _nav_agent == null:
		return false
	return _nav_agent.get_navigation_map().is_valid()

func _on_nav_velocity_computed(safe_velocity: Vector3) -> void:
	_safe_velocity = safe_velocity
	_safe_velocity.y = 0.0
	_has_safe_velocity = true
	_safe_velocity_frame = Engine.get_physics_frames()
	if debug_nav_log and _has_target and _safe_velocity.length_squared() < 0.0004:
		_log_nav_state("safe_velocity_zero", _target_position, _last_desired_velocity, _nav_agent.is_navigation_finished(), global_position.distance_to(_target_position))

func _reset_navigation_motion() -> void:
	_has_nav_target_cached = false
	_has_safe_velocity = false
	_safe_velocity = Vector3.ZERO
	_safe_velocity_frame = -1
	_target_progress_timer = 0.0
	_target_progress_best_distance = INF
	_target_progress_repath_cooldown = 0.0
	_hover_current_speed = 0.0
	_hover_brake_release_timer = 0.0
	_reset_congestion_ghosting()
	_stuck_log_accum = 0.0
	_last_desired_velocity = Vector3.ZERO
	if _nav_agent != null:
		if _interaction_nav_precision_active:
			_interaction_nav_precision_active = false
			_nav_agent.path_desired_distance = _default_nav_path_desired_distance
			_nav_agent.target_desired_distance = _default_nav_target_desired_distance
		if _nav_agent.avoidance_enabled:
			_nav_agent.set_velocity_forced(Vector3.ZERO)

func _sync_worker_collection_navigation_profile() -> void:
	var should_use_collection_profile: bool = is_worker and (
		_mining_state == MiningState.RALLY_MINING
		or _mining_state == MiningState.MOVING_TO_MINERAL
		or _mining_state == MiningState.QUEUED
		or _mining_state == MiningState.HARVESTING
		or _mining_state == MiningState.MOVING_TO_BASE
		or _mining_state == MiningState.DELIVERING
	)
	if should_use_collection_profile == _worker_collection_profile_active:
		return
	_worker_collection_profile_active = should_use_collection_profile
	if should_use_collection_profile:
		# SC2-style mineral walk: moving/queuing to mineral ignores local avoidance and unit collision.
		_reset_congestion_ghosting()
		_refresh_unit_collision_mask()
		if _nav_agent != null:
			_nav_agent.set_velocity_forced(Vector3.ZERO)
			_nav_agent.avoidance_enabled = false
		_has_safe_velocity = false
		_safe_velocity = Vector3.ZERO
		_safe_velocity_frame = -1
		return
	_refresh_unit_collision_mask()
	if _nav_agent != null:
		_nav_agent.avoidance_enabled = true
		_nav_agent.set_velocity_forced(Vector3.ZERO)
	_has_safe_velocity = false
	_safe_velocity = Vector3.ZERO
	_safe_velocity_frame = -1

func _requires_precise_interaction_navigation() -> bool:
	if _construction_hidden:
		return false
	if _mode == UnitMode.GATHER_RESOURCE:
		return _mining_state == MiningState.MOVING_TO_MINERAL
	if _mode == UnitMode.RETURN_RESOURCE:
		return _mining_state == MiningState.MOVING_TO_BASE
	if _mode == UnitMode.REPAIR:
		return _repair_target != null and is_instance_valid(_repair_target)
	if _mode == UnitMode.ATTACK:
		return _attack_target != null and is_instance_valid(_attack_target)
	if _mode == UnitMode.ATTACK_MOVE:
		return _attack_target != null and is_instance_valid(_attack_target)
	return false

func _sync_navigation_precision_profile() -> void:
	if _nav_agent == null:
		return
	var should_use_precise: bool = _has_target and _requires_precise_interaction_navigation()
	if should_use_precise == _interaction_nav_precision_active:
		return
	_interaction_nav_precision_active = should_use_precise
	if should_use_precise:
		_nav_agent.path_desired_distance = _default_nav_path_desired_distance
		_nav_agent.target_desired_distance = clampf(interaction_nav_target_desired_distance, 0.05, _default_nav_target_desired_distance)
		return
	_nav_agent.path_desired_distance = _default_nav_path_desired_distance
	_nav_agent.target_desired_distance = _default_nav_target_desired_distance

func _refresh_unit_collision_mask() -> void:
	if _construction_hidden:
		collision_layer = 0
		collision_mask = 0
		return
	var desired_layer: int = _default_collision_layer
	var desired_mask: int = _default_collision_mask
	if _worker_collection_profile_active:
		# While worker is in collection/return profile, remove unit/building collision
		# and keep a dedicated ghost layer for ray picking.
		desired_layer &= ~UNIT_COLLISION_LAYER_BIT
		desired_layer |= WORKER_COLLECTION_GHOST_LAYER_BIT
		desired_mask &= ~UNIT_COLLISION_LAYER_BIT
		desired_mask &= ~BUILDING_COLLISION_LAYER_BIT
	elif _unit_collision_ghosted or _priority_yield_collision_ghosted:
		# Congestion ghosting only needs to pass through other units.
		desired_layer &= ~UNIT_COLLISION_LAYER_BIT
		desired_layer |= WORKER_COLLECTION_GHOST_LAYER_BIT
		desired_mask &= ~UNIT_COLLISION_LAYER_BIT
	else:
		desired_layer &= ~WORKER_COLLECTION_GHOST_LAYER_BIT
	collision_layer = desired_layer
	collision_mask = desired_mask

func _set_unit_collision_ghosted(ghosted: bool) -> void:
	if _unit_collision_ghosted == ghosted:
		return
	_unit_collision_ghosted = ghosted
	_refresh_unit_collision_mask()

func _set_priority_yield_collision_ghosted(ghosted: bool) -> void:
	if _priority_yield_collision_ghosted == ghosted:
		return
	_priority_yield_collision_ghosted = ghosted
	_refresh_unit_collision_mask()

func _reset_congestion_ghosting() -> void:
	_congestion_stuck_timer = 0.0
	_congestion_release_timer = 0.0
	_congestion_repath_cooldown = 0.0
	_set_unit_collision_ghosted(false)

func _process_priority_push_yield(delta: float) -> void:
	_push_yield_timer = maxf(0.0, _push_yield_timer - delta)
	_push_yield_scan_timer = maxf(0.0, _push_yield_scan_timer - delta)
	if _construction_hidden or _worker_collection_profile_active:
		if _priority_yield_collision_ghosted:
			_set_priority_yield_collision_ghosted(false)
		return
	var should_yield: bool = _push_yield_timer > 0.0
	if push_can_be_displaced and _push_yield_scan_timer <= 0.0:
		_push_yield_scan_timer = maxf(0.03, push_yield_scan_interval)
		if _should_yield_to_higher_priority_unit():
			_push_yield_timer = maxf(_push_yield_timer, maxf(0.05, push_yield_duration))
			should_yield = true
	_set_priority_yield_collision_ghosted(should_yield)

func _should_yield_to_higher_priority_unit() -> bool:
	var tree: SceneTree = get_tree()
	if tree == null:
		return false
	var self_radius: float = _agent_radius_xz()
	var check_padding: float = maxf(0.0, push_contact_padding)
	var nodes: Array[Node] = tree.get_nodes_in_group("selectable_unit")
	for node in nodes:
		if node == self:
			continue
		var other: Node3D = node as Node3D
		if other == null or not is_instance_valid(other):
			continue
		if other.has_method("is_alive") and not bool(other.call("is_alive")):
			continue
		if not push_allow_cross_team_displace and other.has_method("get_team_id"):
			if int(other.call("get_team_id")) != team_id:
				continue
		if not other.has_method("get_push_priority"):
			continue
		var other_priority: int = int(other.call("get_push_priority"))
		if other_priority <= push_priority:
			continue
		if other.has_method("has_active_push_motion") and not bool(other.call("has_active_push_motion")):
			continue
		var other_radius: float = 0.32
		if other.has_method("get_push_body_radius"):
			other_radius = maxf(0.05, float(other.call("get_push_body_radius")))
		var trigger_distance: float = self_radius + other_radius + check_padding
		if RTS_INTERACTION.flat_distance_xz(global_position, other.global_position) <= trigger_distance:
			return true
	return false

func _update_congestion_state(delta: float, target_distance: float, desired_speed: float, frame_start_position: Vector3) -> void:
	if not congestion_ghosting_enabled or _worker_collection_profile_active or _construction_hidden or not push_can_be_displaced:
		_reset_congestion_ghosting()
		return
	_congestion_repath_cooldown = maxf(0.0, _congestion_repath_cooldown - delta)
	var frame_movement: Vector3 = global_position - frame_start_position
	frame_movement.y = 0.0
	var moved_distance: float = frame_movement.length()
	var expected_step: float = maxf(0.02, move_speed * delta * 0.25)
	var should_track_stuck: bool = _has_target and target_distance > 0.8 and desired_speed > 0.1
	if should_track_stuck and moved_distance < expected_step:
		_congestion_stuck_timer += delta
		if _congestion_stuck_timer >= maxf(0.1, congestion_stuck_time):
			if not _unit_collision_ghosted and debug_nav_log:
				_log_nav_state("ghost_on", _target_position, _last_desired_velocity, _can_use_navigation() and _nav_agent.is_navigation_finished(), target_distance)
			_set_unit_collision_ghosted(true)
			_congestion_release_timer = maxf(0.05, congestion_release_time)
			if _can_use_navigation() and _congestion_repath_cooldown <= 0.0:
				_has_nav_target_cached = false
				_nav_agent.target_position = _target_position
				_nav_target_cached = _target_position
				_has_nav_target_cached = true
				_congestion_repath_cooldown = 0.22
	else:
		_congestion_stuck_timer = maxf(0.0, _congestion_stuck_timer - delta * 1.8)
		if _unit_collision_ghosted and moved_distance > expected_step * 0.9:
			_congestion_release_timer = minf(_congestion_release_timer, 0.15)
	if _unit_collision_ghosted:
		_congestion_release_timer = maxf(0.0, _congestion_release_timer - delta)
		if _congestion_release_timer <= 0.0 and _congestion_stuck_timer <= maxf(0.05, congestion_stuck_time * 0.5):
			if debug_nav_log:
				_log_nav_state("ghost_off", _target_position, _last_desired_velocity, _can_use_navigation() and _nav_agent.is_navigation_finished(), target_distance)
			_set_unit_collision_ghosted(false)

func _log_nav_state(tag: String, move_target: Vector3, desired_velocity: Vector3, nav_finished: bool, target_distance: float) -> void:
	var map_valid: bool = _can_use_navigation()
	var safe_speed: float = _safe_velocity.length()
	var final_speed: float = velocity.length()
	print(
		"[NAV][%s][%s][team=%d] tag=%s mode=%s dist=%.2f desired=%.2f safe=%.2f final=%.2f nav_finished=%s map_valid=%s pos=(%.2f,%.2f,%.2f) next=(%.2f,%.2f,%.2f) target=(%.2f,%.2f,%.2f)" % [
			name,
			get_unit_kind(),
			team_id,
			tag,
			get_mode_label(),
			target_distance,
			desired_velocity.length(),
			safe_speed,
			final_speed,
			str(nav_finished),
			str(map_valid),
			global_position.x, global_position.y, global_position.z,
			move_target.x, move_target.y, move_target.z,
			_target_position.x, _target_position.y, _target_position.z
		]
	)
