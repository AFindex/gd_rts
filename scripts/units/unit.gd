extends CharacterBody3D

@export var move_speed: float = 6.0
@export var is_worker: bool = false
@export var gather_range: float = 1.8
@export var dropoff_range: float = 2.4
@export var carry_capacity: int = 24
@export var gather_amount: int = 4
@export var gather_interval: float = 0.55

@onready var _selection_ring: MeshInstance3D = $SelectionRing
@onready var _sprite: Sprite3D = $Sprite3D

enum UnitMode {
	IDLE,
	MOVE,
	GATHER_RESOURCE,
	RETURN_RESOURCE,
}

var _mode: UnitMode = UnitMode.IDLE
var _has_target: bool = false
var _target_position: Vector3 = Vector3.ZERO
var _gather_target: Node3D = null
var _dropoff_target: Node3D = null
var _gather_timer: float = 0.0
var _carried_amount: int = 0

func _ready() -> void:
	add_to_group("selectable_unit")
	_selection_ring.visible = false
	_apply_role_visual()

func _physics_process(delta: float) -> void:
	if _mode == UnitMode.GATHER_RESOURCE or _mode == UnitMode.RETURN_RESOURCE:
		_process_worker_cycle(delta)
	_apply_movement()

func is_worker_unit() -> bool:
	return is_worker

func get_unit_display_name() -> String:
	return "Worker" if is_worker else "Soldier"

func get_unit_role_tag() -> String:
	return "W" if is_worker else "S"

func get_mode_label() -> String:
	match _mode:
		UnitMode.MOVE:
			return "Moving"
		UnitMode.GATHER_RESOURCE:
			return "Gathering"
		UnitMode.RETURN_RESOURCE:
			return "Returning"
		_:
			return "Idle"

func get_carry_fill_ratio() -> float:
	if carry_capacity <= 0:
		return 0.0
	return clampf(float(_carried_amount) / float(carry_capacity), 0.0, 1.0)

func set_worker_role(worker: bool) -> void:
	is_worker = worker
	_apply_role_visual()

func command_move(target: Vector3) -> void:
	_mode = UnitMode.MOVE
	_gather_target = null
	_dropoff_target = null
	_gather_timer = 0.0
	_carried_amount = 0
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
	_gather_timer = 0.0
	_mode = UnitMode.GATHER_RESOURCE
	_move_to(_gather_target.global_position)

func set_selected(selected: bool) -> void:
	_selection_ring.visible = selected

func _process_worker_cycle(delta: float) -> void:
	if _gather_target == null or not is_instance_valid(_gather_target):
		_stop_worker_cycle(false)
		return

	if _mode == UnitMode.GATHER_RESOURCE:
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

	var to_target: Vector3 = _target_position - global_position
	to_target.y = 0.0
	if to_target.length() <= 0.1:
		_has_target = false
		velocity = Vector3.ZERO
		move_and_slide()
		return

	var direction: Vector3 = to_target.normalized()
	velocity = direction * move_speed
	move_and_slide()

func _move_to(target: Vector3) -> void:
	_target_position = Vector3(target.x, global_position.y, target.z)
	_has_target = true

func _is_near(target_position: Vector3, distance_limit: float) -> bool:
	var delta: Vector3 = target_position - global_position
	delta.y = 0.0
	return delta.length() <= distance_limit

func _apply_role_visual() -> void:
	if _sprite == null:
		return
	if is_worker:
		_sprite.modulate = Color(0.45, 1.0, 0.45, 1.0)
	else:
		_sprite.modulate = Color(1.0, 0.5, 0.5, 1.0)
