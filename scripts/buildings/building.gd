extends StaticBody3D

const RTS_CATALOG: Script = preload("res://scripts/core/config/rts_runtime_catalog.gd")
const RTS_INTERACTION: Script = preload("res://scripts/core/rts_interaction.gd")
const RALLY_MAX_HOPS: int = 3
const RALLY_ALERT_DURATION: float = 1.2
const QUEUE_ENTRY_TYPE_UNIT: String = "unit"
const QUEUE_ENTRY_TYPE_RESEARCH: String = "research"
const CONSTRUCTION_PARADIGM_SUMMONING: String = "summoning"
const CONSTRUCTION_PARADIGM_GARRISONED: String = "garrisoned"
const CONSTRUCTION_PARADIGM_INCORPORATED: String = "incorporated"
const CONSTRUCTION_STAGE_CAST: String = "cast"
const CONSTRUCTION_STAGE_BUILD: String = "build"
const BUILDING_HEALTH_BAR_BASE_HEIGHT: float = 2.0
const BUILDING_HEALTH_BAR_SCALE_HEIGHT_FACTOR: float = 0.45
const BUILDING_HEALTH_BAR_WIDTH: float = 1.42
const BUILDING_HEALTH_BAR_HEIGHT: float = 0.14
const BUILDING_HEALTH_BAR_PADDING: float = 0.02
const BASE_MINING_UI_LABEL_Y_OFFSET: float = 0.92

@export var sprite_match_collider: bool = true
@export var sprite_outline_enabled: bool = true
@export var sprite_outline_color: Color = Color(0.25, 0.95, 1.0, 0.9)
@export var sprite_outline_scale: float = 1.1
@export var sprite_outline_check_interval: float = 0.12
@export var base_mining_ui_enabled: bool = true
@export var base_mining_ui_update_interval: float = 0.4
@export var base_mining_ui_scan_radius: float = 26.0

signal production_finished(unit_kind: String, spawn_position: Vector3)
signal research_finished(tech_id: String)
signal construction_state_changed(event_type: String, payload: Dictionary)

@export var building_kind: String = "base"
@export var team_id: int = 1
@export var max_health: float = 1200.0
@export var is_resource_dropoff: bool = true
@export var can_queue_worker: bool = true
@export var can_queue_soldier: bool = false
@export var worker_build_time: float = 2.8
@export var soldier_build_time: float = 4.6
@export var construction_paradigm: String = CONSTRUCTION_PARADIGM_GARRISONED
@export var construction_build_time: float = 0.0
@export var construction_cancel_refund_ratio: float = 0.75
@export var queue_limit: int = 6
@export var spawn_offset: Vector3 = Vector3(3.2, 0.0, 0.0)
@export var attack_range: float = 0.0
@export var attack_damage: float = 0.0
@export var attack_cooldown: float = 1.0

@onready var _selection_ring: MeshInstance3D = $SelectionRing
@onready var _sprite: Sprite3D = $Sprite3D

var _production_queue: Array[Dictionary] = []
var _production_timer: float = 0.0
var _trainable_units: Dictionary = {}
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
var _construction_active: bool = false
var _construction_paused: bool = false
var _construction_paradigm: String = CONSTRUCTION_PARADIGM_GARRISONED
var _construction_stage: String = ""
var _construction_elapsed: float = 0.0
var _construction_total_time: float = 0.0
var _construction_cast_elapsed: float = 0.0
var _construction_cast_time: float = 0.0
var _construction_assigned_worker_path: NodePath = NodePath("")
var _construction_total_cost: int = 0
var _construction_total_gas_cost: int = 0
var _construction_cancel_ratio: float = 0.75
var _construction_pause_reason: String = ""
var _health_bar_root: Node3D = null
var _health_bar_background: MeshInstance3D = null
var _health_bar_fill: MeshInstance3D = null
var _health_bar_fill_full_width: float = maxf(0.02, BUILDING_HEALTH_BAR_WIDTH - BUILDING_HEALTH_BAR_PADDING * 2.0)
var _sprite_base_scale: Vector3 = Vector3.ONE
var _sprite_base_ready: bool = false
var _outline_sprite: Sprite3D = null
var _outline_material: StandardMaterial3D = null
var _outline_timer: float = 0.0
var _outline_visible: bool = false
var _base_mining_ui_root: Node3D = null
var _base_mining_ui_label: Label3D = null
var _base_mining_ui_timer: float = 0.0
var _base_mining_ui_last_text: String = ""

func _ready() -> void:
	add_to_group("selectable_building")
	_apply_building_config(building_kind)
	_health = max_health
	_refresh_dropoff_group()
	_sync_sprite_to_collider()
	_apply_building_visual()
	_ensure_health_bar_nodes()
	_update_health_bar_visual()
	_refresh_base_mining_ui_nodes()
	_update_base_mining_ui(0.0, true)
	_selection_ring.visible = false

func _process(delta: float) -> void:
	_update_sprite_outline(delta)
	_update_base_mining_ui(delta)
	if _rally_alert_timer > 0.0:
		_rally_alert_timer = maxf(0.0, _rally_alert_timer - delta)
	if _construction_active:
		_process_construction(delta)
		return

	if _production_queue.is_empty():
		_production_timer = 0.0
	else:
		_production_timer += delta
		var current_entry: Dictionary = _production_queue[0]
		var current_build_time: float = maxf(0.01, float(current_entry.get("build_time", 0.01)))
		if _production_timer >= current_build_time:
			_production_timer = 0.0
			_production_queue.remove_at(0)
			var entry_type: String = str(current_entry.get("entry_type", QUEUE_ENTRY_TYPE_UNIT))
			var entry_id: String = str(current_entry.get("entry_id", "")).strip_edges()
			if entry_type == QUEUE_ENTRY_TYPE_RESEARCH:
				if entry_id != "":
					emit_signal("research_finished", entry_id)
			elif entry_id != "":
				emit_signal("production_finished", entry_id, _get_spawn_position())

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

func is_damaged() -> bool:
	if not is_alive():
		return false
	return _health < maxf(0.0, max_health) - 0.01

func apply_damage(amount: float, _source: Node = null) -> void:
	if amount <= 0.0 or not is_alive():
		return
	_rally_alert_timer = RALLY_ALERT_DURATION
	_health = maxf(0.0, _health - amount)
	_update_health_bar_visual()
	_play_hit_flash()
	if _health <= 0.0:
		_die()

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

func can_queue_worker_unit() -> bool:
	return can_queue_unit("worker")

func can_queue_soldier_unit() -> bool:
	return can_queue_unit("soldier")

func can_train_unit(unit_kind: String) -> bool:
	var normalized: String = unit_kind.strip_edges().to_lower()
	if normalized == "":
		return false
	return _trainable_units.has(normalized)

func can_queue_unit(unit_kind: String) -> bool:
	if _construction_active:
		return false
	if not can_train_unit(unit_kind):
		return false
	return not is_queue_full()

func get_trainable_unit_kinds() -> Array[String]:
	var kinds: Array[String] = []
	for key_value in _trainable_units.keys():
		var unit_kind: String = str(key_value).strip_edges().to_lower()
		if unit_kind == "":
			continue
		kinds.append(unit_kind)
	return kinds

func get_train_build_time(unit_kind: String) -> float:
	var normalized: String = unit_kind.strip_edges().to_lower()
	if normalized == "":
		return 0.0
	return maxf(0.01, float(_trainable_units.get(normalized, 0.0)))

func queue_unit(unit_kind: String) -> bool:
	if not can_queue_unit(unit_kind):
		return false
	var normalized: String = unit_kind.strip_edges().to_lower()
	var build_time: float = get_train_build_time(normalized)
	return _enqueue_production_entry(QUEUE_ENTRY_TYPE_UNIT, normalized, build_time)

func queue_worker() -> bool:
	return queue_unit("worker")

func queue_soldier() -> bool:
	return queue_unit("soldier")

func can_queue_research_tech(tech_id: String) -> bool:
	if _construction_active:
		return false
	var normalized: String = tech_id.strip_edges()
	if normalized == "":
		return false
	if not _supports_research_tech(normalized):
		return false
	return not is_queue_full()

func queue_research_tech(tech_id: String, research_time: float) -> bool:
	if not can_queue_research_tech(tech_id):
		return false
	var normalized: String = tech_id.strip_edges()
	if normalized == "":
		return false
	return _enqueue_production_entry(QUEUE_ENTRY_TYPE_RESEARCH, normalized, research_time)

func has_tech_in_queue(tech_id: String) -> bool:
	var normalized: String = tech_id.strip_edges()
	if normalized == "":
		return false
	for entry in _production_queue:
		if str(entry.get("entry_type", "")) != QUEUE_ENTRY_TYPE_RESEARCH:
			continue
		if str(entry.get("entry_id", "")).strip_edges() == normalized:
			return true
	return false

func get_active_research_info() -> Dictionary:
	if _production_queue.is_empty():
		return {}
	var entry: Dictionary = _production_queue[0]
	if str(entry.get("entry_type", "")) != QUEUE_ENTRY_TYPE_RESEARCH:
		return {}
	var tech_id: String = str(entry.get("entry_id", "")).strip_edges()
	if tech_id == "":
		return {}
	var total: float = maxf(0.01, float(entry.get("build_time", 0.01)))
	var remaining: float = clampf(total - _production_timer, 0.0, total)
	return {
		"tech_id": tech_id,
		"remaining": remaining,
		"total": total
	}

func get_queued_unit_count() -> int:
	var count: int = 0
	for entry in _production_queue:
		if str(entry.get("entry_type", "")) == QUEUE_ENTRY_TYPE_UNIT:
			count += 1
	return count

func get_queued_unit_supply_cost() -> int:
	var total_supply: int = 0
	for entry in _production_queue:
		if str(entry.get("entry_type", "")) != QUEUE_ENTRY_TYPE_UNIT:
			continue
		var unit_kind: String = str(entry.get("entry_id", "")).strip_edges().to_lower()
		if unit_kind == "":
			continue
		var unit_def: Dictionary = RTS_CATALOG.get_unit_def(unit_kind)
		total_supply += maxi(1, int(unit_def.get("supply", 1)))
	return total_supply

func get_queue_size() -> int:
	return _production_queue.size()

func get_queue_limit() -> int:
	return queue_limit

func is_queue_full() -> bool:
	if queue_limit <= 0:
		return true
	return _production_queue.size() >= queue_limit

func has_active_queue() -> bool:
	return not _production_queue.is_empty()

func get_production_progress() -> float:
	if _production_queue.is_empty():
		return 0.0
	var current_entry: Dictionary = _production_queue[0]
	var current_build_time: float = maxf(0.01, float(current_entry.get("build_time", 0.01)))
	if current_build_time <= 0.0:
		return 1.0
	return clampf(_production_timer / current_build_time, 0.0, 1.0)

func get_primary_queue_kind() -> String:
	if _production_queue.is_empty():
		return ""
	return str(_production_queue[0].get("entry_id", ""))

func get_queue_preview(max_items: int = 5) -> Array[String]:
	var preview: Array[String] = []
	if max_items <= 0:
		return preview
	var max_count: int = mini(max_items, _production_queue.size())
	for i in max_count:
		preview.append(_format_queue_entry_label(_production_queue[i]))
	return preview

func get_building_display_name() -> String:
	var building_def: Dictionary = RTS_CATALOG.get_building_def(building_kind)
	return str(building_def.get("display_name", tr("Building")))

func get_building_role_tag() -> String:
	var building_def: Dictionary = RTS_CATALOG.get_building_def(building_kind)
	return str(building_def.get("role_tag", tr("Building")))

func get_skill_ids() -> Array[String]:
	if _construction_active:
		return _construction_skill_ids()
	return RTS_CATALOG.get_building_skill_ids(building_kind)

func get_build_skill_ids() -> Array[String]:
	return RTS_CATALOG.get_building_build_skill_ids(building_kind)

func is_under_construction() -> bool:
	return _construction_active

func is_construction_paused() -> bool:
	return _construction_active and _construction_paused

func get_construction_paradigm() -> String:
	return _construction_paradigm

func get_construction_stage() -> String:
	if not _construction_active:
		return ""
	return _construction_stage

func get_construction_progress() -> float:
	if not _construction_active:
		return 1.0
	if _construction_total_time <= 0.0:
		return 1.0
	return clampf(_construction_elapsed / _construction_total_time, 0.0, 1.0)

func get_construction_assigned_worker_path() -> NodePath:
	return _construction_assigned_worker_path

func has_construction_assigned_worker() -> bool:
	return str(_construction_assigned_worker_path) != ""

func start_construction(paradigm: String, build_time: float, assigned_worker: Node = null, build_cost: int = 0, cancel_refund_ratio: float = 0.75, build_gas_cost: int = 0) -> void:
	_clear_production_queue()
	_construction_active = true
	_construction_paused = false
	_construction_pause_reason = ""
	_construction_paradigm = _normalize_construction_paradigm(paradigm)
	_construction_stage = CONSTRUCTION_STAGE_BUILD
	_construction_elapsed = 0.0
	_construction_total_time = maxf(0.01, build_time)
	_construction_cast_elapsed = 0.0
	_construction_cast_time = 0.0
	_construction_total_cost = maxi(0, build_cost)
	_construction_total_gas_cost = maxi(0, build_gas_cost)
	_construction_cancel_ratio = clampf(cancel_refund_ratio, 0.0, 1.0)
	if assigned_worker != null and is_instance_valid(assigned_worker):
		_construction_assigned_worker_path = assigned_worker.get_path()
	else:
		_construction_assigned_worker_path = NodePath("")
	if _construction_paradigm == CONSTRUCTION_PARADIGM_SUMMONING and str(_construction_assigned_worker_path) != "":
		_construction_stage = CONSTRUCTION_STAGE_CAST
		var desired_cast: float = clampf(_construction_total_time * 0.35, 2.0, 3.0)
		var max_cast: float = maxf(0.1, _construction_total_time * 0.9)
		_construction_cast_time = min(desired_cast, max_cast)
	_apply_construction_visual(true)
	emit_signal("construction_state_changed", "started", {
		"paradigm": _construction_paradigm,
		"worker_path": _construction_assigned_worker_path,
		"build_time": _construction_total_time,
		"stage": _construction_stage,
		"cast_time": _construction_cast_time
	})
	if _construction_total_time <= 0.01:
		_complete_construction()

func assign_construction_worker(worker_node: Node = null) -> bool:
	if not _construction_active:
		return false
	if _construction_paradigm != CONSTRUCTION_PARADIGM_GARRISONED:
		return false
	if worker_node == null or not is_instance_valid(worker_node):
		return false
	_construction_assigned_worker_path = worker_node.get_path()
	_construction_paused = false
	_construction_pause_reason = ""
	emit_signal("construction_state_changed", "resumed", {
		"paradigm": _construction_paradigm,
		"worker_path": _construction_assigned_worker_path,
		"progress": get_construction_progress()
	})
	return true

func exit_construction() -> Dictionary:
	if not _construction_active:
		return {"ok": false, "reason": "not_under_construction"}
	if _construction_paradigm != CONSTRUCTION_PARADIGM_GARRISONED:
		return {"ok": false, "reason": "not_garrisoned"}
	if _construction_paused:
		return {"ok": false, "reason": "already_paused"}
	_construction_paused = true
	_construction_pause_reason = "worker_exit"
	var payload: Dictionary = {
		"ok": true,
		"paradigm": _construction_paradigm,
		"worker_path": _construction_assigned_worker_path,
		"progress": get_construction_progress()
	}
	emit_signal("construction_state_changed", "paused", payload)
	return payload

func cancel_construction_and_destroy(eject_worker: bool = false) -> Dictionary:
	if not _construction_active:
		return {"ok": false, "reason": "not_under_construction"}
	if _construction_paradigm == CONSTRUCTION_PARADIGM_SUMMONING and _construction_stage == CONSTRUCTION_STAGE_CAST:
		return {"ok": false, "reason": "summoning_cast_locked"}
	var payload: Dictionary = {
		"ok": true,
		"paradigm": _construction_paradigm,
		"worker_path": _construction_assigned_worker_path,
		"cost": _construction_total_cost,
		"gas_cost": _construction_total_gas_cost,
		"refund_ratio": _construction_cancel_ratio,
		"eject_worker": eject_worker,
		"progress": get_construction_progress(),
		"position": global_position
	}
	emit_signal("construction_state_changed", "canceled", payload)
	_reset_construction_state()
	queue_free()
	return payload

func _construction_skill_ids() -> Array[String]:
	if _construction_paradigm == CONSTRUCTION_PARADIGM_INCORPORATED:
		return ["construction_cancel_eject"]
	if _construction_paradigm == CONSTRUCTION_PARADIGM_SUMMONING:
		if _construction_stage == CONSTRUCTION_STAGE_CAST:
			return []
		return ["construction_cancel_destroy"]
	if _construction_paradigm == CONSTRUCTION_PARADIGM_GARRISONED:
		var skill_ids: Array[String] = []
		if str(_construction_assigned_worker_path) != "":
			skill_ids.append("construction_select_worker")
		skill_ids.append("construction_cancel_destroy")
		return skill_ids
	return ["construction_cancel_destroy"]

func _normalize_construction_paradigm(paradigm: String) -> String:
	var normalized: String = paradigm.strip_edges().to_lower()
	if normalized == CONSTRUCTION_PARADIGM_SUMMONING:
		return CONSTRUCTION_PARADIGM_SUMMONING
	if normalized == CONSTRUCTION_PARADIGM_INCORPORATED:
		return CONSTRUCTION_PARADIGM_INCORPORATED
	return CONSTRUCTION_PARADIGM_GARRISONED

func _pause_garrisoned_construction(reason: String) -> void:
	if not _construction_active:
		return
	if _construction_paradigm != CONSTRUCTION_PARADIGM_GARRISONED:
		return
	var normalized_reason: String = reason.strip_edges()
	if normalized_reason == "":
		normalized_reason = "worker_missing"
	var was_paused: bool = _construction_paused
	var previous_reason: String = _construction_pause_reason
	_construction_paused = true
	_construction_pause_reason = normalized_reason
	if was_paused and previous_reason == normalized_reason:
		return
	emit_signal("construction_state_changed", "paused", {
		"paradigm": _construction_paradigm,
		"worker_path": _construction_assigned_worker_path,
		"reason": _construction_pause_reason,
		"progress": get_construction_progress()
	})

func _is_garrisoned_worker_valid(worker_node: Node) -> bool:
	if worker_node == null or not is_instance_valid(worker_node):
		return false
	if worker_node.has_method("is_alive") and not bool(worker_node.call("is_alive")):
		return false
	if worker_node.has_method("is_construction_locked") and not bool(worker_node.call("is_construction_locked")):
		return false
	if worker_node.has_method("get_construction_lock_mode"):
		var lock_mode: String = str(worker_node.call("get_construction_lock_mode")).strip_edges().to_lower()
		if lock_mode != "garrisoned":
			return false
	if worker_node.has_method("get_construction_building_path"):
		var worker_site_path: NodePath = worker_node.call("get_construction_building_path") as NodePath
		if worker_site_path != get_path():
			return false
	var worker_3d: Node3D = worker_node as Node3D
	if worker_3d == null:
		return false
	var max_distance: float = RTS_INTERACTION.compute_trigger_distance(
		worker_3d,
		self,
		0.0,
		0.35,
		0.12,
		true
	)
	return RTS_INTERACTION.is_within_distance_xz(worker_3d.global_position, global_position, max_distance)

func _process_construction(delta: float) -> void:
	if _construction_paused:
		return
	if _construction_paradigm == CONSTRUCTION_PARADIGM_SUMMONING and _construction_stage == CONSTRUCTION_STAGE_CAST:
		if str(_construction_assigned_worker_path) == "":
			_construction_paused = true
			_construction_pause_reason = "worker_missing"
			emit_signal("construction_state_changed", "paused", {
				"paradigm": _construction_paradigm,
				"worker_path": _construction_assigned_worker_path,
				"reason": _construction_pause_reason,
				"progress": get_construction_progress(),
				"stage": _construction_stage
			})
			return
		var cast_worker: Node = get_node_or_null(_construction_assigned_worker_path)
		if cast_worker == null or not is_instance_valid(cast_worker):
			_construction_paused = true
			_construction_pause_reason = "worker_missing"
			emit_signal("construction_state_changed", "paused", {
				"paradigm": _construction_paradigm,
				"worker_path": _construction_assigned_worker_path,
				"reason": _construction_pause_reason,
				"progress": get_construction_progress(),
				"stage": _construction_stage
			})
			return
		_construction_cast_elapsed += delta
		_construction_elapsed += delta
		if _construction_cast_elapsed >= _construction_cast_time:
			var released_worker_path: NodePath = _construction_assigned_worker_path
			_construction_assigned_worker_path = NodePath("")
			_construction_stage = CONSTRUCTION_STAGE_BUILD
			emit_signal("construction_state_changed", "summoning_cast_complete", {
				"paradigm": _construction_paradigm,
				"worker_path": released_worker_path,
				"progress": get_construction_progress(),
				"position": global_position
			})
		if _construction_elapsed >= _construction_total_time:
			_complete_construction()
		return
	if _construction_paradigm == CONSTRUCTION_PARADIGM_GARRISONED:
		if str(_construction_assigned_worker_path) == "":
			_pause_garrisoned_construction("worker_missing")
			return
		var worker_node: Node = get_node_or_null(_construction_assigned_worker_path)
		if not _is_garrisoned_worker_valid(worker_node):
			var pause_reason: String = "worker_missing"
			if worker_node != null and is_instance_valid(worker_node):
				pause_reason = "worker_not_garrisoned"
			_pause_garrisoned_construction(pause_reason)
			return
	_construction_elapsed += delta
	if _construction_elapsed >= _construction_total_time:
		_complete_construction()

func _complete_construction() -> void:
	var payload: Dictionary = {
		"paradigm": _construction_paradigm,
		"stage": _construction_stage,
		"worker_path": _construction_assigned_worker_path,
		"cost": _construction_total_cost,
		"gas_cost": _construction_total_gas_cost,
		"position": global_position
	}
	_reset_construction_state()
	emit_signal("construction_state_changed", "completed", payload)

func _reset_construction_state() -> void:
	_construction_active = false
	_construction_paused = false
	_construction_pause_reason = ""
	_construction_stage = ""
	_construction_elapsed = 0.0
	_construction_total_time = 0.0
	_construction_cast_elapsed = 0.0
	_construction_cast_time = 0.0
	_construction_assigned_worker_path = NodePath("")
	_construction_total_cost = 0
	_construction_total_gas_cost = 0
	_construction_cancel_ratio = construction_cancel_refund_ratio
	_apply_construction_visual(false)

func _apply_construction_visual(under_construction: bool) -> void:
	if _sprite == null:
		return
	if under_construction:
		var tint: Color = _base_tint
		tint.a = 0.58
		_sprite.modulate = tint
	else:
		_sprite.modulate = _base_tint

func supports_rally_point() -> bool:
	if _construction_active:
		return false
	return not _trainable_units.is_empty()

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

func _safe_node_from_variant(value: Variant) -> Node:
	if not (value is Object):
		return null
	if not is_instance_valid(value):
		return null
	return value as Node

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
		var valid_target: Node = _safe_node_from_variant(hop.get("target_node", null))
		hops.append({
			"position": Vector3(hop_position.x, 0.0, hop_position.z),
			"target_node": valid_target,
			"mode": str(hop.get("mode", "ground"))
		})
	if hops.is_empty():
		var fallback_target: Node = _safe_node_from_variant(_rally_target_node)
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
	_rally_target_node = _safe_node_from_variant(first_hop.get("target_node", null))
	_rally_mode = str(first_hop.get("mode", "ground"))

func configure_by_kind(kind: String) -> void:
	_apply_building_config(kind)
	_clear_production_queue()
	_rally_alert_timer = 0.0
	_attack_target = null
	_attack_timer = 0.0
	clear_rally_point()
	_reset_construction_state()
	_health = max_health
	_refresh_dropoff_group()
	_apply_building_visual()
	_ensure_health_bar_nodes()
	_update_health_bar_visual()
	_refresh_base_mining_ui_nodes()
	_update_base_mining_ui(0.0, true)

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
	var scale_factor: float = 1.0
	if building_kind == "barracks":
		building_color = Color(1.0, 0.6, 0.25, 1.0)
		scale_factor = 1.3
	elif building_kind == "supply_depot":
		building_color = Color(0.86, 0.92, 0.76, 1.0)
		scale_factor = 1.22
	elif building_kind == "tower":
		building_color = Color(0.95, 0.72, 0.3, 1.0)
		scale_factor = 1.15
	elif building_kind == "academy":
		building_color = Color(0.5, 0.88, 1.0, 1.0)
		scale_factor = 1.32
	elif building_kind == "engineering_bay":
		building_color = Color(0.72, 0.96, 0.62, 1.0)
		scale_factor = 1.34
	elif building_kind == "tech_lab":
		building_color = Color(0.98, 0.72, 0.46, 1.0)
		scale_factor = 1.36
	elif building_kind == "warp_gate":
		building_color = Color(0.82, 0.58, 1.0, 1.0)
		scale_factor = 1.35
	elif building_kind == "psionic_relay":
		building_color = Color(0.68, 0.76, 1.0, 1.0)
		scale_factor = 1.28
	elif building_kind == "bio_vat":
		building_color = Color(0.86, 0.95, 0.56, 1.0)
		scale_factor = 1.33
	elif building_kind == "void_core":
		building_color = Color(1.0, 0.64, 0.8, 1.0)
		scale_factor = 1.38
	else:
		building_color = Color(0.95, 0.95, 1.0, 1.0)
		scale_factor = 1.45
	if team_id != 1:
		building_color = Color(0.55, 0.75, 1.0, 1.0)
	_base_tint = building_color
	if not _sprite_base_ready:
		_sync_sprite_to_collider()
	var effective_scale: Vector3 = _sprite_base_scale
	if not sprite_match_collider:
		effective_scale *= scale_factor
	_sprite.scale = effective_scale
	_sprite.modulate = building_color
	_ensure_outline_sprite()
	_sync_outline_sprite_visual()
	_update_health_bar_visual()

func _sync_sprite_to_collider() -> void:
	if _sprite == null or not sprite_match_collider:
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
	_sprite_base_ready = true
	_sync_outline_sprite_visual()

func _get_collider_sprite_size() -> Vector2:
	var shape_node: CollisionShape3D = get_node_or_null("CollisionShape3D") as CollisionShape3D
	if shape_node == null or shape_node.shape == null:
		return Vector2.ZERO
	var shape: Shape3D = shape_node.shape
	if shape is BoxShape3D:
		var box: BoxShape3D = shape as BoxShape3D
		return Vector2(maxf(box.size.x, box.size.z), box.size.y)
	if shape is CapsuleShape3D:
		var capsule: CapsuleShape3D = shape as CapsuleShape3D
		return Vector2(capsule.radius * 2.0, capsule.height + capsule.radius * 2.0)
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

func _format_unit_kind(unit_kind: String) -> String:
	var normalized: String = unit_kind.strip_edges().to_lower()
	if normalized == "":
		return tr("Unit")
	var unit_def: Dictionary = RTS_CATALOG.get_unit_def(normalized)
	return str(unit_def.get("display_name", tr(normalized.capitalize())))

func _format_queue_entry_label(entry: Dictionary) -> String:
	var entry_type: String = str(entry.get("entry_type", QUEUE_ENTRY_TYPE_UNIT))
	var entry_id: String = str(entry.get("entry_id", "")).strip_edges()
	if entry_id == "":
		return tr("Unknown")
	if entry_type == QUEUE_ENTRY_TYPE_RESEARCH:
		var tech_def: Dictionary = RTS_CATALOG.get_tech_def(entry_id)
		return str(tech_def.get("display_name", tr(entry_id.capitalize())))
	return _format_unit_kind(entry_id)

func _supports_research_tech(tech_id: String) -> bool:
	if tech_id == "":
		return false
	var building_skill_ids: Array[String] = RTS_CATALOG.get_building_skill_ids(building_kind)
	for skill_id in building_skill_ids:
		if RTS_CATALOG.get_tech_id_from_skill(skill_id) == tech_id:
			return true
	return false

func _enqueue_production_entry(entry_type: String, entry_id: String, build_time: float) -> bool:
	if is_queue_full():
		return false
	var normalized_id: String = entry_id.strip_edges()
	if normalized_id == "":
		return false
	var clamped_time: float = maxf(0.01, build_time)
	_production_queue.append({
		"entry_type": entry_type,
		"entry_id": normalized_id,
		"build_time": clamped_time
	})
	return true

func _clear_production_queue() -> void:
	_production_queue.clear()
	_production_timer = 0.0

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
	_trainable_units.clear()
	var trainable_units_value: Variant = building_def.get("trainable_units", {})
	if trainable_units_value is Dictionary:
		var trainable_units: Dictionary = trainable_units_value as Dictionary
		for key_value in trainable_units.keys():
			var unit_kind: String = str(key_value).strip_edges().to_lower()
			if unit_kind == "":
				continue
			var build_time_value: Variant = trainable_units.get(key_value, 0.0)
			var build_time: float = maxf(0.01, float(build_time_value))
			_trainable_units[unit_kind] = build_time
	if _trainable_units.is_empty():
		if can_queue_worker and worker_build_time > 0.0:
			_trainable_units["worker"] = maxf(0.01, worker_build_time)
		if can_queue_soldier and soldier_build_time > 0.0:
			_trainable_units["soldier"] = maxf(0.01, soldier_build_time)
	can_queue_worker = _trainable_units.has("worker")
	can_queue_soldier = _trainable_units.has("soldier")
	if can_queue_worker:
		worker_build_time = maxf(0.01, float(_trainable_units.get("worker", worker_build_time)))
	if can_queue_soldier:
		soldier_build_time = maxf(0.01, float(_trainable_units.get("soldier", soldier_build_time)))
	construction_paradigm = _normalize_construction_paradigm(str(building_def.get("construction_paradigm", construction_paradigm)))
	construction_build_time = maxf(0.0, float(building_def.get("build_time", construction_build_time)))
	construction_cancel_refund_ratio = clampf(float(building_def.get("cancel_refund_ratio", construction_cancel_refund_ratio)), 0.0, 1.0)
	_construction_cancel_ratio = construction_cancel_refund_ratio
	queue_limit = int(building_def.get("queue_limit", queue_limit))
	var configured_spawn_offset: Variant = building_def.get("spawn_offset", spawn_offset)
	if configured_spawn_offset is Vector3:
		spawn_offset = configured_spawn_offset as Vector3
	_update_health_bar_visual()

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
	var unit_target: Node3D = _find_nearest_enemy_in_group("selectable_unit")
	if unit_target != null:
		return unit_target
	return _find_nearest_enemy_in_group("selectable_building")

func _find_nearest_enemy_in_group(group_name: String) -> Node3D:
	var nearest: Node3D = null
	var best_distance_sq: float = INF
	var nodes: Array[Node] = get_tree().get_nodes_in_group(group_name)
	for node in nodes:
		if node == null or not is_instance_valid(node):
			continue
		var target: Node3D = node as Node3D
		if target == null:
			continue
		if not _is_valid_enemy_target(target):
			continue
		if not _is_target_in_range(target):
			continue
		var distance_sq: float = _flat_distance_sq(global_position, target.global_position)
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
	return RTS_INTERACTION.is_triggered(
		self,
		target_3d,
		attack_range,
		0.0,
		0.05,
		true
	)

func _flat_distance_sq(a: Vector3, b: Vector3) -> float:
	var delta: Vector3 = b - a
	delta.y = 0.0
	return delta.length_squared()

func _die() -> void:
	_selection_ring.visible = false
	_attack_target = null
	_update_health_bar_visual()
	if _construction_active:
		var payload: Dictionary = {
			"paradigm": _construction_paradigm,
			"worker_path": _construction_assigned_worker_path,
			"position": global_position,
			"hp_penalty_ratio": 0.5 if _construction_paradigm == CONSTRUCTION_PARADIGM_INCORPORATED else 0.0
		}
		emit_signal("construction_state_changed", "forced_destroyed", payload)
		_reset_construction_state()
	queue_free()

func _ensure_health_bar_nodes() -> void:
	if _health_bar_root != null and is_instance_valid(_health_bar_root):
		return
	_health_bar_root = Node3D.new()
	_health_bar_root.name = "HealthBarRoot"
	_health_bar_root.position = Vector3(0.0, _compute_health_bar_world_height(), 0.0)
	add_child(_health_bar_root)

	_health_bar_background = MeshInstance3D.new()
	_health_bar_background.name = "HealthBarBackground"
	var background_mesh: QuadMesh = QuadMesh.new()
	background_mesh.size = Vector2(BUILDING_HEALTH_BAR_WIDTH, BUILDING_HEALTH_BAR_HEIGHT)
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
	fill_mesh.size = Vector2(_health_bar_fill_full_width, maxf(0.02, BUILDING_HEALTH_BAR_HEIGHT - BUILDING_HEALTH_BAR_PADDING * 2.0))
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
	_health_bar_root.position.y = _compute_health_bar_world_height()
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

func _supports_base_mining_ui() -> bool:
	if not base_mining_ui_enabled:
		return false
	if building_kind != "base":
		return false
	if not is_resource_dropoff:
		return false
	return is_alive()

func _refresh_base_mining_ui_nodes() -> void:
	if not _supports_base_mining_ui():
		_clear_base_mining_ui_nodes()
		return
	_ensure_base_mining_ui_nodes()

func _ensure_base_mining_ui_nodes() -> void:
	if _base_mining_ui_root != null and is_instance_valid(_base_mining_ui_root):
		return
	_base_mining_ui_root = Node3D.new()
	_base_mining_ui_root.name = "BaseMiningUI"
	_base_mining_ui_root.position = Vector3(0.0, _compute_base_mining_ui_height(), 0.0)
	add_child(_base_mining_ui_root)

	_base_mining_ui_label = Label3D.new()
	_base_mining_ui_label.name = "MiningStatusLabel3D"
	_base_mining_ui_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_base_mining_ui_label.modulate = Color(0.9, 0.95, 1.0, 0.98)
	_base_mining_ui_label.outline_size = 8
	_base_mining_ui_label.outline_modulate = Color(0.03, 0.04, 0.06, 0.9)
	_base_mining_ui_label.pixel_size = 0.0068
	_base_mining_ui_label.text = ""
	_base_mining_ui_root.add_child(_base_mining_ui_label)
	_base_mining_ui_timer = 0.0
	_base_mining_ui_last_text = ""

func _clear_base_mining_ui_nodes() -> void:
	if _base_mining_ui_root != null and is_instance_valid(_base_mining_ui_root):
		_base_mining_ui_root.queue_free()
	_base_mining_ui_root = null
	_base_mining_ui_label = null
	_base_mining_ui_timer = 0.0
	_base_mining_ui_last_text = ""

func _update_base_mining_ui(delta: float, force_update: bool = false) -> void:
	if not _supports_base_mining_ui():
		_clear_base_mining_ui_nodes()
		return
	_ensure_base_mining_ui_nodes()
	if _base_mining_ui_root == null or not is_instance_valid(_base_mining_ui_root):
		return
	if _base_mining_ui_label == null or not is_instance_valid(_base_mining_ui_label):
		return
	_base_mining_ui_root.position.y = _compute_base_mining_ui_height()
	if not force_update:
		_base_mining_ui_timer = maxf(0.0, _base_mining_ui_timer - delta)
		if _base_mining_ui_timer > 0.0:
			return
	_base_mining_ui_timer = maxf(0.08, base_mining_ui_update_interval)

	var current_miners: int = _count_active_miners_for_this_base()
	var optimal_miners: int = _count_optimal_miners_for_this_base()
	var status_text: String = tr("矿工 %d/%d") % [current_miners, optimal_miners]
	if status_text != _base_mining_ui_last_text:
		_base_mining_ui_label.text = status_text
		_base_mining_ui_last_text = status_text

	if optimal_miners <= 0:
		_base_mining_ui_label.modulate = Color(0.72, 0.78, 0.9, 0.9)
	elif current_miners < optimal_miners:
		_base_mining_ui_label.modulate = Color(0.98, 0.88, 0.42, 0.98)
	else:
		_base_mining_ui_label.modulate = Color(0.48, 0.96, 0.62, 0.98)

func _count_active_miners_for_this_base() -> int:
	var count: int = 0
	var units: Array[Node] = get_tree().get_nodes_in_group("selectable_unit")
	for node in units:
		if node == null or not is_instance_valid(node):
			continue
		if not node.has_method("get_team_id"):
			continue
		if int(node.call("get_team_id")) != team_id:
			continue
		if node.has_method("is_alive") and not bool(node.call("is_alive")):
			continue
		if not node.has_method("is_worker_unit") or not bool(node.call("is_worker_unit")):
			continue
		if node.has_method("is_collecting_for_dropoff") and bool(node.call("is_collecting_for_dropoff", self)):
			count += 1
	return count

func _count_optimal_miners_for_this_base() -> int:
	var resources: Array[Node] = get_tree().get_nodes_in_group("resource_node")
	if resources.is_empty():
		return 0
	var optimal_total: int = 0
	var scan_radius_sq: float = INF
	if base_mining_ui_scan_radius > 0.0:
		scan_radius_sq = base_mining_ui_scan_radius * base_mining_ui_scan_radius
	for node in resources:
		var mineral: Node3D = node as Node3D
		if mineral == null or not is_instance_valid(mineral):
			continue
		if mineral.has_method("is_depleted") and bool(mineral.call("is_depleted")):
			continue
		if scan_radius_sq < INF:
			var distance_sq: float = _flat_distance_sq(global_position, mineral.global_position)
			if distance_sq > scan_radius_sq:
				continue
		var optimal_for_patch: int = 2
		if mineral.has_method("get_optimal_worker_count"):
			optimal_for_patch = maxi(1, int(mineral.call("get_optimal_worker_count")))
		elif mineral.has_method("get_wait_queue_limit"):
			optimal_for_patch = maxi(1, int(mineral.call("get_wait_queue_limit")) + 1)
		optimal_total += optimal_for_patch
	return optimal_total

func _compute_base_mining_ui_height() -> float:
	return _compute_health_bar_world_height() + BASE_MINING_UI_LABEL_Y_OFFSET

func _compute_health_bar_world_height() -> float:
	var sprite_scale_y: float = 1.0
	if _sprite != null:
		sprite_scale_y = maxf(1.0, _sprite.scale.y)
	return BUILDING_HEALTH_BAR_BASE_HEIGHT + sprite_scale_y * BUILDING_HEALTH_BAR_SCALE_HEIGHT_FACTOR

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

func _play_repair_flash() -> void:
	if _sprite == null:
		return
	var repair_tint: Color = _base_tint.lerp(Color(0.52, 1.0, 0.68, _base_tint.a), 0.35)
	_sprite.modulate = repair_tint
	var tween: Tween = create_tween()
	tween.tween_property(_sprite, "modulate", _base_tint, 0.12)
