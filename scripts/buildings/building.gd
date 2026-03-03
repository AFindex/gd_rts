extends StaticBody3D

signal production_finished(unit_kind: String, spawn_position: Vector3)

@export var building_kind: String = "base"
@export var is_resource_dropoff: bool = true
@export var can_queue_worker: bool = true
@export var can_queue_soldier: bool = false
@export var worker_build_time: float = 2.8
@export var soldier_build_time: float = 4.6
@export var spawn_offset: Vector3 = Vector3(3.2, 0.0, 0.0)

@onready var _selection_ring: MeshInstance3D = $SelectionRing
@onready var _sprite: Sprite3D = $Sprite3D

var _queue_unit_kinds: Array[String] = []
var _queue_build_times: Array[float] = []
var _production_timer: float = 0.0

func _ready() -> void:
	add_to_group("selectable_building")
	_refresh_dropoff_group()
	_apply_building_visual()
	_selection_ring.visible = false

func _process(delta: float) -> void:
	if _queue_unit_kinds.is_empty():
		_production_timer = 0.0
		return

	_production_timer += delta
	var current_build_time: float = _queue_build_times[0]
	if _production_timer < current_build_time:
		return

	_production_timer = 0.0
	var unit_kind: String = _queue_unit_kinds[0]
	_queue_unit_kinds.remove_at(0)
	_queue_build_times.remove_at(0)
	emit_signal("production_finished", unit_kind, _get_spawn_position())

func set_selected(selected: bool) -> void:
	_selection_ring.visible = selected

func can_queue_worker_unit() -> bool:
	return can_queue_worker

func can_queue_soldier_unit() -> bool:
	return can_queue_soldier

func queue_worker() -> bool:
	if not can_queue_worker:
		return false
	_queue_unit_kinds.append("worker")
	_queue_build_times.append(worker_build_time)
	return true

func queue_soldier() -> bool:
	if not can_queue_soldier:
		return false
	_queue_unit_kinds.append("soldier")
	_queue_build_times.append(soldier_build_time)
	return true

func get_queue_size() -> int:
	return _queue_unit_kinds.size()

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
	if building_kind == "barracks":
		return "Barracks"
	return "Main Base"

func get_building_role_tag() -> String:
	if building_kind == "barracks":
		return "Barracks"
	return "Base"

func configure_as_barracks() -> void:
	building_kind = "barracks"
	is_resource_dropoff = false
	can_queue_worker = false
	can_queue_soldier = true
	worker_build_time = 0.0
	soldier_build_time = 4.0
	spawn_offset = Vector3(3.6, 0.0, 0.0)
	_queue_unit_kinds.clear()
	_queue_build_times.clear()
	_production_timer = 0.0
	_refresh_dropoff_group()
	_apply_building_visual()

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
	if building_kind == "barracks":
		_sprite.modulate = Color(1.0, 0.6, 0.25, 1.0)
		_sprite.scale = Vector3(1.3, 1.3, 1.3)
	else:
		_sprite.modulate = Color(0.95, 0.95, 1.0, 1.0)
		_sprite.scale = Vector3(1.45, 1.45, 1.45)

func _format_unit_kind(unit_kind: String) -> String:
	if unit_kind == "worker":
		return "Worker"
	if unit_kind == "soldier":
		return "Soldier"
	return unit_kind.capitalize()
