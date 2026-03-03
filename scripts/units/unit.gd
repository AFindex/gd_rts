extends CharacterBody3D

const RTS_CATALOG: Script = preload("res://scripts/core/rts_catalog.gd")

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

@onready var _selection_ring: MeshInstance3D = $SelectionRing
@onready var _sprite: Sprite3D = $Sprite3D
@onready var _nav_agent: NavigationAgent3D = $NavigationAgent3D

enum UnitMode {
	IDLE,
	MOVE,
	GATHER_RESOURCE,
	RETURN_RESOURCE,
	ATTACK,
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
var _base_tint: Color = Color.WHITE
var _nav_target_cached: Vector3 = Vector3.ZERO
var _has_nav_target_cached: bool = false

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
	elif _mode == UnitMode.ATTACK:
		_process_attack_cycle(delta)
	_apply_movement()

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
	_gather_timer = 0.0
	_has_nav_target_cached = false

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
	_gather_target = null
	_dropoff_target = null
	_mode = UnitMode.ATTACK
	_move_to(target_node.global_position)
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

func _process_attack_cycle(delta: float) -> void:
	if _attack_target == null or not is_instance_valid(_attack_target):
		command_stop()
		return
	if not _target_is_enemy(_attack_target):
		command_stop()
		return
	if _attack_target.has_method("is_alive") and not bool(_attack_target.call("is_alive")):
		command_stop()
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
				_spawn_attack_vfx(_attack_target.global_position)
	else:
		_move_to(target_position)

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

func _apply_movement() -> void:
	if not _has_target:
		velocity = Vector3.ZERO
		move_and_slide()
		return

	var move_target: Vector3 = _target_position
	if _can_use_navigation():
		if _nav_agent.is_navigation_finished():
			_has_target = false
			_has_nav_target_cached = false
			velocity = Vector3.ZERO
			move_and_slide()
			return
		move_target = _nav_agent.get_next_path_position()

	var to_target: Vector3 = move_target - global_position
	to_target.y = 0.0
	if to_target.length() <= 0.1:
		if not _can_use_navigation() or _nav_agent.is_navigation_finished():
			_has_target = false
			_has_nav_target_cached = false
		velocity = Vector3.ZERO
		move_and_slide()
		return

	var direction: Vector3 = to_target.normalized()
	velocity = direction * move_speed
	move_and_slide()

func _move_to(target: Vector3) -> void:
	_target_position = Vector3(target.x, global_position.y, target.z)
	_has_target = true
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
	tracer.global_position = launch_pos
	root_3d.add_child(tracer)

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
	_nav_agent.path_desired_distance = 0.2
	_nav_agent.target_desired_distance = 0.25
	_nav_agent.avoidance_enabled = true
	_nav_agent.radius = 0.32
	_nav_agent.height = 1.0

func _can_use_navigation() -> bool:
	if _nav_agent == null:
		return false
	return _nav_agent.get_navigation_map().is_valid()
