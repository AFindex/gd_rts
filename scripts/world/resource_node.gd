extends StaticBody3D

signal harvest_complete(worker: Node, amount: int)
signal slot_available(worker: Node)
signal depleted

enum ResourceType {
	MINERALS,
	GAS,
}

enum MineralType {
	NEAR_PATCH,
	FAR_PATCH,
}

@export var resource_type: int = ResourceType.MINERALS
@export var mineral_type: int = MineralType.NEAR_PATCH
@export var total_minerals: int = 1500
@export var max_visual_minerals: int = 1500
@export var near_patch_capacity: int = 1500
@export var far_patch_capacity: int = 750
@export var gas_capacity: int = 1400
@export var harvest_yield: int = 5
@export var harvest_time: float = 1.5
@export var gas_harvest_yield: int = 4
@export var gas_harvest_time: float = 1.8
@export var wait_queue_limit: int = 1
@export var optimal_worker_count: int = 2
@export var enforce_type_capacity_on_ready: bool = true

@onready var _sprite: Sprite3D = $Sprite3D

var _occupier: Node = null
var _wait_queue: Array[Node] = []

func _ready() -> void:
	add_to_group("resource_node")
	if resource_type == ResourceType.GAS:
		add_to_group("resource_node_gas")
	else:
		add_to_group("resource_node_minerals")
	if enforce_type_capacity_on_ready:
		var type_capacity: int = _capacity_for_type()
		total_minerals = type_capacity
		max_visual_minerals = type_capacity
	else:
		if total_minerals <= 0:
			total_minerals = _capacity_for_type()
		if max_visual_minerals <= 0:
			max_visual_minerals = maxi(1, total_minerals)
	_refresh_visual()

func get_mineral_type_name() -> String:
	if resource_type == ResourceType.GAS:
		return "GAS"
	if mineral_type == MineralType.FAR_PATCH:
		return "FAR_PATCH"
	return "NEAR_PATCH"

func get_resource_type_key() -> String:
	if resource_type == ResourceType.GAS:
		return "gas"
	return "minerals"

func get_resource_display_name() -> String:
	return "Gas" if resource_type == ResourceType.GAS else "Minerals"

func get_remaining_amount() -> int:
	return maxi(0, total_minerals)

func get_remaining_minerals() -> int:
	return maxi(0, total_minerals)

func get_harvest_time() -> float:
	if resource_type == ResourceType.GAS:
		return maxf(0.05, gas_harvest_time)
	return maxf(0.05, harvest_time)

func get_harvest_yield() -> int:
	if resource_type == ResourceType.GAS:
		return maxi(1, gas_harvest_yield)
	return maxi(1, harvest_yield)

func get_wait_queue_length() -> int:
	_cleanup_runtime_state()
	return _wait_queue.size()

func get_wait_queue_limit() -> int:
	return maxi(0, wait_queue_limit)

func get_optimal_worker_count() -> int:
	return maxi(1, optimal_worker_count)

func get_occupier() -> Node:
	_cleanup_runtime_state()
	return _occupier

func is_depleted() -> bool:
	return total_minerals <= 0

func is_occupied() -> bool:
	_cleanup_runtime_state()
	return _occupier != null

func can_accept_waiter(worker: Node = null) -> bool:
	_cleanup_runtime_state()
	if is_depleted():
		return false
	if worker != null and is_instance_valid(worker):
		if _occupier == worker:
			return true
		if _is_worker_in_queue(worker):
			return true
	return _wait_queue.size() < maxi(0, wait_queue_limit)

func estimate_wait_seconds() -> float:
	_cleanup_runtime_state()
	if is_depleted():
		return INF
	var active_slots: int = 1 if _occupier != null else 0
	var slots_ahead: int = active_slots + _wait_queue.size()
	return float(slots_ahead) * get_harvest_time()

func request_harvest_slot(worker: Node, allow_enqueue: bool = true) -> Dictionary:
	if worker == null or not is_instance_valid(worker):
		return {"status": "denied"}
	_cleanup_runtime_state()
	if is_depleted():
		return {"status": "depleted"}
	if _occupier == worker:
		return {"status": "granted"}
	if _occupier == null:
		_remove_from_wait_queue(worker)
		_occupier = worker
		return {"status": "granted"}
	if not allow_enqueue:
		return {"status": "occupied"}
	if _is_worker_in_queue(worker):
		return {"status": "queued", "index": _wait_queue.find(worker)}
	if _wait_queue.size() >= maxi(0, wait_queue_limit):
		return {"status": "full"}
	_wait_queue.append(worker)
	return {"status": "queued", "index": _wait_queue.size() - 1}

func remove_waiter(worker: Node) -> void:
	if worker == null:
		return
	_remove_from_wait_queue(worker)

func release_harvest_slot(worker: Node) -> void:
	_cleanup_runtime_state()
	if worker == null or not is_instance_valid(worker):
		return
	var was_occupier: bool = _occupier == worker
	var was_waiting: bool = _is_worker_in_queue(worker)
	if not was_occupier and not was_waiting:
		return
	if was_occupier:
		_occupier = null
	if was_waiting:
		_remove_from_wait_queue(worker)
	if is_depleted():
		_notify_depleted_to_waiters()
		return
	_notify_next_waiter()

func harvest(request_amount: int, worker: Node = null) -> int:
	if request_amount <= 0:
		return 0
	_cleanup_runtime_state()
	if total_minerals <= 0:
		return 0
	if _occupier == null:
		return 0
	if worker == null or not is_instance_valid(worker) or _occupier != worker:
		return 0

	var requested: int = mini(maxi(1, request_amount), get_harvest_yield())
	var mined: int = mini(requested, total_minerals)
	total_minerals -= mined
	_refresh_visual()
	emit_signal("harvest_complete", worker, mined)

	if total_minerals <= 0:
		total_minerals = 0
		_occupier = null
		_notify_depleted_to_waiters()
		emit_signal("depleted")
		queue_free()
	return mined

func _refresh_visual() -> void:
	if _sprite == null:
		return
	var ratio: float = clampf(float(total_minerals) / float(maxi(1, max_visual_minerals)), 0.25, 1.0)
	_sprite.scale = Vector3.ONE * ratio
	if resource_type == ResourceType.GAS:
		_sprite.modulate = Color(0.52, 0.94, 0.62, 1.0)
	else:
		_sprite.modulate = Color(0.45, 0.85, 1.0, 1.0)

func _capacity_for_type() -> int:
	if resource_type == ResourceType.GAS:
		return maxi(1, gas_capacity)
	if mineral_type == MineralType.FAR_PATCH:
		return maxi(1, far_patch_capacity)
	return maxi(1, near_patch_capacity)

func _cleanup_runtime_state() -> void:
	if _occupier != null and not is_instance_valid(_occupier):
		_occupier = null
	for i in range(_wait_queue.size() - 1, -1, -1):
		var queued_worker: Node = _wait_queue[i]
		if queued_worker == null or not is_instance_valid(queued_worker):
			_wait_queue.remove_at(i)

func _is_worker_in_queue(worker: Node) -> bool:
	return _wait_queue.has(worker)

func _remove_from_wait_queue(worker: Node) -> void:
	for i in range(_wait_queue.size() - 1, -1, -1):
		if _wait_queue[i] == worker:
			_wait_queue.remove_at(i)

func _notify_next_waiter() -> void:
	_cleanup_runtime_state()
	if _occupier != null:
		return
	while not _wait_queue.is_empty():
		var queued_worker: Node = _wait_queue.pop_front()
		if queued_worker == null or not is_instance_valid(queued_worker):
			continue
		emit_signal("slot_available", queued_worker)
		if queued_worker.has_method("_on_mineral_slot_available"):
			queued_worker.call_deferred("_on_mineral_slot_available", self)
		return

func _notify_depleted_to_waiters() -> void:
	_cleanup_runtime_state()
	var queued_copy: Array = _wait_queue.duplicate()
	_wait_queue.clear()
	if _occupier != null and is_instance_valid(_occupier):
		if _occupier.has_method("_on_mineral_depleted"):
			_occupier.call("_on_mineral_depleted", self)
		_occupier = null
	for queued_worker in queued_copy:
		if queued_worker == null or not is_instance_valid(queued_worker):
			continue
		if queued_worker.has_method("_on_mineral_depleted"):
			queued_worker.call("_on_mineral_depleted", self)
