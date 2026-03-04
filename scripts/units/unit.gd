extends CharacterBody3D

const RTS_CATALOG: Script = preload("res://scripts/core/rts_catalog.gd")
const RTS_COMMAND: Script = preload("res://scripts/core/rts_command.gd")
const NAV_VERTICAL_POINT_TOLERANCE: float = 0.65
const UNIT_COLLISION_LAYER_BIT: int = 1 << 1

@export var move_speed: float = 6.0
@export var is_worker: bool = false
@export var team_id: int = 1
@export var max_health: float = 100.0
@export var gather_range: float = 1.8
@export var dropoff_range: float = 2.4
@export var carry_capacity: int = 24
@export var gather_amount: int = 4
@export var gather_interval: float = 0.55
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

var _mode: UnitMode = UnitMode.IDLE
var _health: float = 100.0
var _has_target: bool = false
var _target_position: Vector3 = Vector3.ZERO
var _gather_target: Node3D = null
var _dropoff_target: Node3D = null
var _gather_timer: float = 0.0
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
var _safe_velocity: Vector3 = Vector3.ZERO
var _has_safe_velocity: bool = false
var _safe_velocity_frame: int = -1
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

signal command_queue_changed

func _ready() -> void:
	add_to_group("selectable_unit")
	_selection_ring.visible = false
	_apply_runtime_config_for_role()
	_health = max_health
	_apply_role_visual()
	_default_collision_layer = collision_layer
	_default_collision_mask = collision_mask
	_setup_navigation_agent()

func _physics_process(delta: float) -> void:
	if _mode == UnitMode.GATHER_RESOURCE or _mode == UnitMode.RETURN_RESOURCE:
		_process_worker_cycle(delta)
	elif _mode == UnitMode.REPAIR:
		_process_repair_cycle(delta)
	elif _mode == UnitMode.ATTACK or _mode == UnitMode.ATTACK_MOVE:
		_process_combat_cycle(delta)
	_sync_worker_collection_navigation_profile()
	_apply_movement(delta)
	_process_command_queue()

func is_worker_unit() -> bool:
	return is_worker

func get_unit_display_name() -> String:
	var unit_kind: String = get_unit_kind()
	var unit_def: Dictionary = RTS_CATALOG.get_unit_def(unit_kind)
	return str(unit_def.get("display_name", "Worker" if is_worker else "Soldier"))

func get_unit_role_tag() -> String:
	var unit_kind: String = get_unit_kind()
	var unit_def: Dictionary = RTS_CATALOG.get_unit_def(unit_kind)
	return str(unit_def.get("role_tag", "W" if is_worker else "S"))

func get_unit_kind() -> String:
	return "worker" if is_worker else "soldier"

func get_skill_ids() -> Array[String]:
	if _construction_lock_mode == ConstructionLockMode.CAST:
		return []
	if _construction_lock_mode == ConstructionLockMode.GARRISONED:
		return ["construction_exit"]
	if _construction_lock_mode == ConstructionLockMode.INCORPORATED:
		return []
	return RTS_CATALOG.get_unit_skill_ids(get_unit_kind())

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
	_mode = UnitMode.IDLE
	_has_target = false
	velocity = Vector3.ZERO
	_gather_target = null
	_dropoff_target = null
	_attack_target = null
	_attack_timer = 0.0
	_has_attack_move_point = false
	_attack_move_point = Vector3.ZERO
	_clear_repair_state()
	_retarget_timer = 0.0
	_gather_timer = 0.0
	_defer_queue_until_worker_cycle_checkpoint = false
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
			return "Moving"
		UnitMode.GATHER_RESOURCE:
			return "Gathering"
		UnitMode.RETURN_RESOURCE:
			return "Returning"
		UnitMode.ATTACK:
			return "Attacking"
		UnitMode.ATTACK_MOVE:
			return "Attack-Move"
		UnitMode.REPAIR:
			return "Repairing"
		_:
			return "Idle"

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
	_play_repair_flash()
	return true

func get_carry_fill_ratio() -> float:
	if carry_capacity <= 0:
		return 0.0
	return clampf(float(_carried_amount) / float(carry_capacity), 0.0, 1.0)

func has_cargo() -> bool:
	return _carried_amount > 0

func set_worker_role(worker: bool) -> void:
	is_worker = worker
	_apply_runtime_config_for_role()
	_health = max_health
	_apply_role_visual()

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

	if _construction_lock_mode == ConstructionLockMode.CAST and not is_internal_build_order:
		return false

	var locked_deferred_mode: bool = (_construction_lock_mode == ConstructionLockMode.GARRISONED or _construction_lock_mode == ConstructionLockMode.INCORPORATED) and not is_internal_build_order
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
	_clear_repair_state()
	_mode = UnitMode.MOVE
	_gather_target = null
	_dropoff_target = null
	_attack_target = null
	_attack_timer = 0.0
	_has_attack_move_point = false
	_attack_move_point = Vector3.ZERO
	_retarget_timer = 0.0
	_gather_timer = 0.0
	_move_to(target)

func move_to(target: Vector3) -> void:
	command_move(target)

func command_gather(resource_node: Node3D, dropoff_node: Node3D, preserve_queue: bool = false) -> void:
	if not is_worker:
		return
	if resource_node == null or dropoff_node == null:
		return
	_defer_queue_until_worker_cycle_checkpoint = false
	if not preserve_queue:
		_command_queue.clear()
		_active_command = null
	_clear_repair_state()
	_gather_target = resource_node
	_dropoff_target = dropoff_node
	_attack_target = null
	_attack_timer = 0.0
	_has_attack_move_point = false
	_attack_move_point = Vector3.ZERO
	_retarget_timer = 0.0
	_gather_timer = 0.0
	_mode = UnitMode.GATHER_RESOURCE
	_move_to(_gather_target.global_position)

func command_return_to_dropoff(dropoff_node: Node3D, preserve_queue: bool = false) -> void:
	if not is_worker:
		return
	if dropoff_node == null or not is_instance_valid(dropoff_node):
		return
	_defer_queue_until_worker_cycle_checkpoint = false
	if not preserve_queue:
		_command_queue.clear()
		_active_command = null
	_clear_repair_state()
	_dropoff_target = dropoff_node
	_gather_target = null
	_attack_target = null
	_attack_timer = 0.0
	_has_attack_move_point = false
	_attack_move_point = Vector3.ZERO
	_retarget_timer = 0.0
	_gather_timer = 0.0
	_mode = UnitMode.RETURN_RESOURCE
	_move_to(_dropoff_target.global_position)

func command_stop(preserve_queue: bool = false) -> void:
	_defer_queue_until_worker_cycle_checkpoint = false
	if not preserve_queue:
		_command_queue.clear()
		_active_command = null
	_clear_repair_state()
	_mode = UnitMode.IDLE
	_has_target = false
	velocity = Vector3.ZERO
	_gather_target = null
	_dropoff_target = null
	_attack_target = null
	_attack_timer = 0.0
	_has_attack_move_point = false
	_attack_move_point = Vector3.ZERO
	_retarget_timer = 0.0
	_gather_timer = 0.0
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
	_clear_repair_state()
	_attack_target = target_node
	_attack_timer = 0.0
	_attack_move_point = target_node.global_position
	_has_attack_move_point = true
	_retarget_timer = 0.0
	_gather_target = null
	_dropoff_target = null
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
	_clear_repair_state()
	_attack_target = null
	_attack_timer = 0.0
	_attack_move_point = Vector3(target.x, global_position.y, target.z)
	_has_attack_move_point = true
	_retarget_timer = 0.0
	_gather_target = null
	_dropoff_target = null
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
	_clear_repair_state()
	_gather_target = null
	_dropoff_target = null
	_attack_target = null
	_attack_timer = 0.0
	_has_attack_move_point = false
	_attack_move_point = Vector3.ZERO
	_retarget_timer = 0.0
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
		var traveling_to_resource: bool = _has_target
		if traveling_to_resource and _gather_target != null and is_instance_valid(_gather_target):
			traveling_to_resource = not _is_near(_gather_target.global_position, gather_range)
		if traveling_to_resource:
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
		game_manager.call("_on_worker_queue_transition", self, event_type)

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
			if gather_resource == null or gather_dropoff == null:
				command_stop(true)
				return
			if not is_instance_valid(gather_resource) or not is_instance_valid(gather_dropoff):
				command_stop(true)
				return
			command_gather(gather_resource, gather_dropoff, true)
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
	points.append({
		"position": position,
		"command_type": command.command_type,
		"queued": queued
	})

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
	_play_hit_flash()
	if _health <= 0.0:
		_die()

func set_selected(selected: bool) -> void:
	_selection_ring.visible = selected

func _process_worker_cycle(delta: float) -> void:
	if _mode == UnitMode.GATHER_RESOURCE:
		if _gather_target == null or not is_instance_valid(_gather_target):
			_stop_worker_cycle(false)
			return
		if _carried_amount >= carry_capacity:
			_switch_to_return_mode()
			return

		if _is_near(_gather_target.global_position, gather_range):
			_has_target = false
			velocity = Vector3.ZERO
			_gather_timer += delta
			if _gather_timer >= gather_interval:
				_gather_timer = 0.0
				var request_amount: int = mini(gather_amount, carry_capacity - _carried_amount)
				var harvested: int = _harvest_resource(_gather_target, request_amount)
				_carried_amount += harvested
				if _defer_queue_until_worker_cycle_checkpoint:
					_defer_queue_until_worker_cycle_checkpoint = false
					_stop_worker_cycle(false)
					_notify_game_manager_worker_queue_transition("interrupt_checkpoint")
					return
				if harvested <= 0:
					if _carried_amount > 0:
						_switch_to_return_mode()
					else:
						_stop_worker_cycle(false)
				elif _carried_amount >= carry_capacity:
					_switch_to_return_mode()
		elif not _has_target:
			_move_to(_gather_target.global_position)
		return

	if _mode == UnitMode.RETURN_RESOURCE:
		if _dropoff_target == null or not is_instance_valid(_dropoff_target):
			_stop_worker_cycle(true)
			return
		if _is_near(_dropoff_target.global_position, dropoff_range):
			_has_target = false
			velocity = Vector3.ZERO
			if _carried_amount > 0:
				_deposit_to_game_manager(_carried_amount)
				_carried_amount = 0
			if _defer_queue_until_worker_cycle_checkpoint:
				_defer_queue_until_worker_cycle_checkpoint = false
				_stop_worker_cycle(false)
				_notify_game_manager_worker_queue_transition("interrupt_checkpoint")
				return
			if _gather_target != null and is_instance_valid(_gather_target):
				_mode = UnitMode.GATHER_RESOURCE
				_move_to(_gather_target.global_position)
			else:
				_stop_worker_cycle(false)
		elif not _has_target:
			_move_to(_dropoff_target.global_position)

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
	var effective_repair_range: float = maxf(0.5, repair_range)
	if _is_near(_repair_target.global_position, effective_repair_range):
		_has_target = false
		velocity = Vector3.ZERO
		_repair_timer += delta
		var effective_interval: float = maxf(0.05, repair_interval)
		if _repair_timer < effective_interval:
			return
		_repair_timer = 0.0
		var repaired: bool = false
		if _repair_target.has_method("repair"):
			repaired = bool(_repair_target.call("repair", maxf(0.0, repair_amount), self))
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
	if _is_near(target_position, attack_range):
		_has_target = false
		velocity = Vector3.ZERO
		_attack_timer += delta
		var cooldown: float = maxf(0.05, attack_cooldown)
		if _attack_timer >= cooldown:
			_attack_timer = 0.0
			if _attack_target != null and _attack_target.has_method("apply_damage"):
				_attack_target.call("apply_damage", attack_damage, self)
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
		_stop_worker_cycle(true)
		return
	_mode = UnitMode.RETURN_RESOURCE
	_gather_timer = 0.0
	_move_to(_dropoff_target.global_position)

func _stop_worker_cycle(reset_carry: bool) -> void:
	_mode = UnitMode.IDLE
	_has_target = false
	velocity = Vector3.ZERO
	_gather_target = null
	_dropoff_target = null
	_gather_timer = 0.0
	_defer_queue_until_worker_cycle_checkpoint = false
	_clear_repair_state()
	_has_attack_move_point = false
	_attack_move_point = Vector3.ZERO
	_retarget_timer = 0.0
	_reset_navigation_motion()
	if reset_carry:
		_carried_amount = 0

func _harvest_resource(resource_node: Node3D, amount: int) -> int:
	if amount <= 0:
		return 0
	if not resource_node.has_method("harvest"):
		return 0
	var harvested_value: Variant = resource_node.call("harvest", amount)
	return maxi(0, int(harvested_value))

func _deposit_to_game_manager(amount: int) -> void:
	if amount <= 0:
		return
	var game_manager: Node = get_tree().get_first_node_in_group("game_manager")
	if game_manager != null and game_manager.has_method("add_minerals"):
		game_manager.call("add_minerals", amount)

func _apply_movement(delta: float) -> void:
	if not _has_target:
		velocity = Vector3.ZERO
		move_and_slide()
		return

	var move_target: Vector3 = _target_position
	var nav_finished: bool = false
	if _can_use_navigation():
		nav_finished = _nav_agent.is_navigation_finished()
		if nav_finished:
			_has_target = false
			_reset_navigation_motion()
			velocity = Vector3.ZERO
			move_and_slide()
			return
		move_target = _nav_agent.get_next_path_position()

	var to_target: Vector3 = move_target - global_position
	to_target.y = 0.0
	if to_target.length() <= 0.1:
		if _can_use_navigation() and not _nav_agent.is_navigation_finished():
			var to_final_target: Vector3 = _target_position - global_position
			to_final_target.y = 0.0
			if to_final_target.length() > 0.18:
				if debug_nav_log:
					_log_nav_state("next_point_same_as_current", move_target, to_final_target.normalized() * move_speed, nav_finished, to_final_target.length())
				to_target = to_final_target
			else:
				_has_target = false
				_reset_navigation_motion()
				velocity = Vector3.ZERO
				move_and_slide()
				return
		else:
			_has_target = false
			_reset_navigation_motion()
			velocity = Vector3.ZERO
			move_and_slide()
			return

	var direction: Vector3 = to_target.normalized()
	var desired_velocity: Vector3 = direction * move_speed
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
		var target_distance: float = to_target.length()
		if target_distance > 0.45 and velocity.length_squared() < 0.0025:
			_stuck_log_accum += delta
			if _stuck_log_accum >= maxf(0.2, debug_nav_log_interval):
				_stuck_log_accum = 0.0
				_log_nav_state("stuck", move_target, desired_velocity, nav_finished, target_distance)
		else:
			_stuck_log_accum = 0.0
	move_and_slide()

func _move_to(target: Vector3) -> void:
	_target_position = Vector3(target.x, global_position.y, target.z)
	_has_target = true
	_has_safe_velocity = false
	_last_desired_velocity = Vector3.ZERO
	if debug_nav_log:
		_log_nav_state("move_to", _target_position, Vector3.ZERO, false, global_position.distance_to(_target_position))
	if _can_use_navigation():
		if not _has_nav_target_cached or _nav_target_cached.distance_to(_target_position) > 0.25:
			_nav_agent.target_position = _target_position
			_nav_target_cached = _target_position
			_has_nav_target_cached = true

func _is_near(target_position: Vector3, distance_limit: float) -> bool:
	var delta: Vector3 = target_position - global_position
	delta.y = 0.0
	return delta.length() <= distance_limit

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
	repair_range = float(unit_def.get("repair_range", repair_range))
	repair_amount = float(unit_def.get("repair_amount", repair_amount))
	repair_interval = float(unit_def.get("repair_interval", repair_interval))
	attack_damage = float(unit_def.get("attack_damage", attack_damage))
	attack_range = float(unit_def.get("attack_range", attack_range))
	attack_cooldown = float(unit_def.get("attack_cooldown", attack_cooldown))
	if _nav_agent != null:
		_nav_agent.max_speed = move_speed

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
		if _nav_agent != null:
			_nav_agent.avoidance_enabled = false
			_nav_agent.set_velocity_forced(Vector3.ZERO)
		return
	if not is_in_group("selectable_unit"):
		add_to_group("selectable_unit")
	collision_layer = _default_collision_layer
	collision_mask = _default_collision_mask
	if _nav_agent != null:
		_nav_agent.avoidance_enabled = not _worker_collection_profile_active
		_nav_agent.set_velocity_forced(Vector3.ZERO)

func _setup_navigation_agent() -> void:
	if _nav_agent == null:
		return
	_nav_agent.max_speed = move_speed
	# Nav path points are often elevated by ~0.5 on baked meshes; keep tolerance above that
	# so waypoint progression does not stall when XZ is aligned but Y differs.
	_nav_agent.path_desired_distance = NAV_VERTICAL_POINT_TOLERANCE
	_nav_agent.target_desired_distance = NAV_VERTICAL_POINT_TOLERANCE
	_nav_agent.avoidance_enabled = true
	_nav_agent.radius = 0.32
	_nav_agent.height = 1.0
	var callback: Callable = Callable(self, "_on_nav_velocity_computed")
	if not _nav_agent.is_connected("velocity_computed", callback):
		_nav_agent.connect("velocity_computed", callback)
	_sync_worker_collection_navigation_profile()

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
	_stuck_log_accum = 0.0
	_last_desired_velocity = Vector3.ZERO
	if _nav_agent != null and _nav_agent.avoidance_enabled:
		_nav_agent.set_velocity_forced(Vector3.ZERO)

func _sync_worker_collection_navigation_profile() -> void:
	var should_use_collection_profile: bool = is_worker and (_mode == UnitMode.GATHER_RESOURCE or _mode == UnitMode.RETURN_RESOURCE)
	if should_use_collection_profile == _worker_collection_profile_active:
		return
	_worker_collection_profile_active = should_use_collection_profile
	if should_use_collection_profile:
		# SC2-style worker flow: gather/return keeps navmesh pathing, but ignores local avoidance and unit collision.
		collision_mask = _default_collision_mask & ~UNIT_COLLISION_LAYER_BIT
		if _nav_agent != null:
			_nav_agent.set_velocity_forced(Vector3.ZERO)
			_nav_agent.avoidance_enabled = false
		_has_safe_velocity = false
		_safe_velocity = Vector3.ZERO
		_safe_velocity_frame = -1
		return
	collision_mask = _default_collision_mask
	if _nav_agent != null:
		_nav_agent.avoidance_enabled = true
		_nav_agent.set_velocity_forced(Vector3.ZERO)
	_has_safe_velocity = false
	_safe_velocity = Vector3.ZERO
	_safe_velocity_frame = -1

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
