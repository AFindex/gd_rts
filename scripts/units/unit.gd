extends CharacterBody3D

const RTS_CATALOG: Script = preload("res://scripts/core/rts_catalog.gd")
const NAV_VERTICAL_POINT_TOLERANCE: float = 0.65

@export var move_speed: float = 6.0
@export var is_worker: bool = false
@export var team_id: int = 1
@export var max_health: float = 100.0
@export var gather_range: float = 1.8
@export var dropoff_range: float = 2.4
@export var carry_capacity: int = 24
@export var gather_amount: int = 4
@export var gather_interval: float = 0.55
@export var attack_range: float = 2.4
@export var attack_damage: float = 12.0
@export var attack_cooldown: float = 0.8
@export var auto_acquire_range: float = 8.0
@export var attack_move_acquire_range: float = 11.0
@export var retarget_interval: float = 0.2
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
}

var _mode: UnitMode = UnitMode.IDLE
var _health: float = 100.0
var _has_target: bool = false
var _target_position: Vector3 = Vector3.ZERO
var _gather_target: Node3D = null
var _dropoff_target: Node3D = null
var _gather_timer: float = 0.0
var _carried_amount: int = 0
var _attack_target: Node3D = null
var _attack_timer: float = 0.0
var _attack_move_point: Vector3 = Vector3.ZERO
var _has_attack_move_point: bool = false
var _retarget_timer: float = 0.0
var _base_tint: Color = Color.WHITE
var _nav_target_cached: Vector3 = Vector3.ZERO
var _has_nav_target_cached: bool = false
var _safe_velocity: Vector3 = Vector3.ZERO
var _has_safe_velocity: bool = false
var _safe_velocity_frame: int = -1
var _stuck_log_accum: float = 0.0
var _last_desired_velocity: Vector3 = Vector3.ZERO

func _ready() -> void:
	add_to_group("selectable_unit")
	_selection_ring.visible = false
	_apply_runtime_config_for_role()
	_health = max_health
	_apply_role_visual()
	_setup_navigation_agent()

func _physics_process(delta: float) -> void:
	if _mode == UnitMode.GATHER_RESOURCE or _mode == UnitMode.RETURN_RESOURCE:
		_process_worker_cycle(delta)
	elif _mode == UnitMode.ATTACK or _mode == UnitMode.ATTACK_MOVE:
		_process_combat_cycle(delta)
	_apply_movement(delta)

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
	return RTS_CATALOG.get_unit_skill_ids(get_unit_kind())

func get_build_skill_ids() -> Array[String]:
	return RTS_CATALOG.get_unit_build_skill_ids(get_unit_kind())

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

func command_move(target: Vector3) -> void:
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

func command_gather(resource_node: Node3D, dropoff_node: Node3D) -> void:
	if not is_worker:
		return
	if resource_node == null or dropoff_node == null:
		return
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

func command_return_to_dropoff(dropoff_node: Node3D) -> void:
	if not is_worker:
		return
	if dropoff_node == null or not is_instance_valid(dropoff_node):
		return
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

func command_stop() -> void:
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

func command_attack(target_node: Node3D) -> bool:
	if target_node == null or not is_instance_valid(target_node):
		return false
	if is_worker:
		return false
	if attack_damage <= 0.0 or attack_range <= 0.0:
		return false
	if not _target_is_enemy(target_node):
		return false
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

func command_attack_move(target: Vector3) -> bool:
	if is_worker:
		return false
	if attack_damage <= 0.0 or attack_range <= 0.0:
		return false
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
			if _gather_target != null and is_instance_valid(_gather_target):
				_mode = UnitMode.GATHER_RESOURCE
				_move_to(_gather_target.global_position)
			else:
				_stop_worker_cycle(false)
		elif not _has_target:
			_move_to(_dropoff_target.global_position)

func _process_combat_cycle(delta: float) -> void:
	if is_worker or attack_damage <= 0.0 or attack_range <= 0.0:
		command_stop()
		return
	_retarget_timer = maxf(0.0, _retarget_timer - delta)

	if not _is_valid_enemy_target(_attack_target):
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

	var target_position: Vector3 = _attack_target.global_position
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
		command_stop()
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
		var target: Node3D = node as Node3D
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

func _is_valid_enemy_target(target_node: Node) -> bool:
	if target_node == null or not is_instance_valid(target_node):
		return false
	if target_node == self:
		return false
	if not _target_is_enemy(target_node):
		return false
	if target_node.has_method("is_alive") and not bool(target_node.call("is_alive")):
		return false
	return true

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
	attack_damage = float(unit_def.get("attack_damage", attack_damage))
	attack_range = float(unit_def.get("attack_range", attack_range))
	attack_cooldown = float(unit_def.get("attack_cooldown", attack_cooldown))
	if _nav_agent != null:
		_nav_agent.max_speed = move_speed

func _target_is_enemy(target_node: Node) -> bool:
	if target_node == null:
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
