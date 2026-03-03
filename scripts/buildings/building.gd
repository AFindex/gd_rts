extends StaticBody3D

const RTS_CATALOG: Script = preload("res://scripts/core/rts_catalog.gd")

signal production_finished(unit_kind: String, spawn_position: Vector3)

@export var building_kind: String = "base"
@export var team_id: int = 1
@export var max_health: float = 1200.0
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
var _health: float = 1200.0

func _ready() -> void:
	add_to_group("selectable_building")
	_apply_building_config(building_kind)
	_health = max_health
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
	_health = maxf(0.0, _health - amount)
	if _health <= 0.0:
		_die()

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
	var building_def: Dictionary = RTS_CATALOG.get_building_def(building_kind)
	return str(building_def.get("display_name", "Building"))

func get_building_role_tag() -> String:
	var building_def: Dictionary = RTS_CATALOG.get_building_def(building_kind)
	return str(building_def.get("role_tag", "Building"))

func configure_as_barracks() -> void:
	_apply_building_config("barracks")
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
	var building_color: Color
	if building_kind == "barracks":
		building_color = Color(1.0, 0.6, 0.25, 1.0)
		_sprite.scale = Vector3(1.3, 1.3, 1.3)
	else:
		building_color = Color(0.95, 0.95, 1.0, 1.0)
		_sprite.scale = Vector3(1.45, 1.45, 1.45)
	if team_id != 1:
		building_color = Color(0.55, 0.75, 1.0, 1.0)
	_sprite.modulate = building_color
	_sprite.scale = Vector3.ONE * 8 # Temp: Scale up for better visibility

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
	is_resource_dropoff = bool(building_def.get("is_resource_dropoff", is_resource_dropoff))
	can_queue_worker = bool(building_def.get("can_queue_worker", can_queue_worker))
	can_queue_soldier = bool(building_def.get("can_queue_soldier", can_queue_soldier))
	worker_build_time = float(building_def.get("worker_build_time", worker_build_time))
	soldier_build_time = float(building_def.get("soldier_build_time", soldier_build_time))
	var configured_spawn_offset: Variant = building_def.get("spawn_offset", spawn_offset)
	if configured_spawn_offset is Vector3:
		spawn_offset = configured_spawn_offset as Vector3

func _die() -> void:
	_selection_ring.visible = false
	queue_free()
