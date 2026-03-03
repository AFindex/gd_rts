extends Node3D

const UNIT_SCENE: PackedScene = preload("res://scenes/units/unit.tscn")
const BUILDING_SCENE: PackedScene = preload("res://scenes/buildings/building.tscn")
const RTS_CATALOG: Script = preload("res://scripts/core/rts_catalog.gd")
const RTS_COMMAND: Script = preload("res://scripts/core/rts_command.gd")

const WORKER_COST: int = 50
const SOLDIER_COST: int = 70
const SUPPLY_CAP: int = 40
const HUD_MULTI_MAX: int = 24
const BUILDING_BLOCK_RADIUS: float = 3.8
const RESOURCE_BLOCK_RADIUS: float = 3.2
const PLAYER_TEAM_ID: int = 1
const NAV_SOURCE_GROUP: StringName = &"navmesh_runtime_source"

enum InputState {
	IDLE,
	UNIT_SELECTED,
	SKILL_SELECTED,
	BUILDING_PLACEMENT,
	QUEUE_INPUT,
}

@export var camera_path: NodePath
@export var units_root_path: NodePath
@export var buildings_root_path: NodePath
@export var selection_overlay_path: NodePath
@export var hud_path: NodePath
@export var nav_region_path: NodePath = NodePath("World/NavRegion")
@export var nav_rebake_on_runtime: bool = true
@export var nav_rebake_on_thread: bool = true

var _camera: Camera3D
var _units_root: Node3D
var _buildings_root: Node3D
var _selection_overlay: Control
var _hud: Control
var _nav_region: NavigationRegion3D

var _dragging: bool = false
var _drag_start: Vector2 = Vector2.ZERO
var _selected_units: Array[Node] = []
var _selected_buildings: Array[Node] = []

var _minerals: int = 220
var _worker_cost: int = WORKER_COST
var _soldier_cost: int = SOLDIER_COST

var _placing_building: bool = false
var _placing_kind: String = ""
var _placing_cost: int = 0
var _placement_current_position: Vector3 = Vector3.ZERO
var _placement_can_place: bool = false
var _placement_preview: MeshInstance3D
var _placement_preview_material: StandardMaterial3D

var _pending_target_skill: String = ""
var _build_menu_open: bool = false
var _input_state: int = InputState.IDLE
var _execution_queue: Array[Dictionary] = []

var _hint_refresh_accum: float = 0.0
var _match_rule_check_interval: float = 0.25
var _match_notify_only: bool = true
var _match_rule_defs: Array[Dictionary] = []
var _match_check_accum: float = 0.0
var _match_outcome_rule_id: String = ""
var _match_notice: String = ""
var _unlocked_techs: Dictionary = {}
var _active_research: Dictionary = {}
var _nav_rebake_in_progress: bool = false
var _nav_rebake_pending: bool = false

func _ready() -> void:
	add_to_group("game_manager")
	_camera = get_node_or_null(camera_path) as Camera3D
	_units_root = get_node_or_null(units_root_path) as Node3D
	_buildings_root = get_node_or_null(buildings_root_path) as Node3D
	_selection_overlay = get_node_or_null(selection_overlay_path) as Control
	_hud = get_node_or_null(hud_path) as Control
	_nav_region = get_node_or_null(nav_region_path) as NavigationRegion3D
	_apply_runtime_config()
	_connect_hud_signals()
	_create_placement_preview()
	_setup_runtime_navigation_baking()
	_register_existing_buildings()
	_register_existing_resources()
	_request_navmesh_rebake("startup")
	_refresh_resource_label()
	_refresh_hint_label()
	_refresh_input_state()

func _apply_runtime_config() -> void:
	var worker_def: Dictionary = RTS_CATALOG.get_unit_def("worker")
	var soldier_def: Dictionary = RTS_CATALOG.get_unit_def("soldier")
	var match_settings: Dictionary = RTS_CATALOG.get_match_settings()
	_worker_cost = int(worker_def.get("cost", WORKER_COST))
	_soldier_cost = int(soldier_def.get("cost", SOLDIER_COST))
	_match_rule_check_interval = maxf(0.05, float(match_settings.get("rule_check_interval", 0.25)))
	_match_notify_only = bool(match_settings.get("notify_only", true))
	_match_rule_defs = RTS_CATALOG.get_match_rule_defs()
	_active_research.clear()
	_unlocked_techs.clear()
	var default_techs: Array[String] = RTS_CATALOG.get_default_unlocked_techs()
	for tech_id in default_techs:
		if tech_id == "":
			continue
		_unlocked_techs[tech_id] = true

func _connect_hud_signals() -> void:
	if _hud == null or not _hud.has_signal("command_pressed"):
		return
	var callback: Callable = Callable(self, "_on_hud_command_pressed")
	if not _hud.is_connected("command_pressed", callback):
		_hud.connect("command_pressed", callback)

func _process(delta: float) -> void:
	_drain_execution_queue()
	if _placing_building:
		_update_placement_preview()

	_process_match_rules(delta)
	_process_active_research(delta)
	_refresh_input_state()

	_hint_refresh_accum += delta
	if _hint_refresh_accum >= 0.2:
		_hint_refresh_accum = 0.0
		_refresh_hint_label()

func _process_active_research(delta: float) -> void:
	if _active_research.is_empty():
		return
	var finished: Array[String] = []
	for tech_key in _active_research.keys():
		var tech_id: String = str(tech_key)
		var entry: Variant = _active_research.get(tech_id, {})
		if not (entry is Dictionary):
			finished.append(tech_id)
			continue
		var task: Dictionary = entry as Dictionary
		var remaining: float = maxf(0.0, float(task.get("remaining", 0.0)) - delta)
		task["remaining"] = remaining
		_active_research[tech_id] = task
		if remaining <= 0.0:
			finished.append(tech_id)
	for tech_id in finished:
		_active_research.erase(tech_id)
		unlock_tech(tech_id)

func _process_match_rules(delta: float) -> void:
	if _match_outcome_rule_id != "":
		return
	if _match_rule_defs.is_empty():
		return
	_match_check_accum += delta
	if _match_check_accum < _match_rule_check_interval:
		return
	_match_check_accum = 0.0
	_evaluate_match_rules()

func _evaluate_match_rules() -> void:
	for rule in _match_rule_defs:
		if _is_match_rule_triggered(rule):
			_trigger_match_rule(rule)
			return

func _is_match_rule_triggered(rule: Dictionary) -> bool:
	var watch_group: String = str(rule.get("watch_group", ""))
	if watch_group == "":
		return false
	var threshold: int = int(rule.get("trigger_at_or_below", 0))
	var count: int = _count_rule_targets(rule)
	return count <= threshold

func _count_rule_targets(rule: Dictionary) -> int:
	var watch_group: String = str(rule.get("watch_group", ""))
	if watch_group == "":
		return 0

	var team_filter: int = int(rule.get("team_id", -1))
	var building_kind_filter: String = str(rule.get("building_kind", ""))
	var unit_kind_filter: String = str(rule.get("unit_kind", ""))
	var requires_alive: bool = bool(rule.get("requires_alive", true))

	var count: int = 0
	var nodes: Array[Node] = get_tree().get_nodes_in_group(watch_group)
	for node in nodes:
		if node == null or not is_instance_valid(node):
			continue
		if team_filter >= 0:
			if not node.has_method("get_team_id"):
				continue
			if int(node.call("get_team_id")) != team_filter:
				continue
		if requires_alive and node.has_method("is_alive") and not bool(node.call("is_alive")):
			continue
		if building_kind_filter != "":
			if str(node.get("building_kind")) != building_kind_filter:
				continue
		if unit_kind_filter != "":
			if not node.has_method("get_unit_kind"):
				continue
			if str(node.call("get_unit_kind")) != unit_kind_filter:
				continue
		count += 1
	return count

func _trigger_match_rule(rule: Dictionary) -> void:
	_match_outcome_rule_id = str(rule.get("id", "match_outcome"))
	var notice: String = str(rule.get("notice", "")).strip_edges()
	if notice == "":
		notice = "Match outcome triggered: %s" % _match_outcome_rule_id
	_match_notice = notice
	_refresh_hint_label()
	if not _match_notify_only:
		_pending_target_skill = ""
		_build_menu_open = false

func _input(event: InputEvent) -> void:
	if _camera == null:
		return

	var mouse_button: InputEventMouseButton = event as InputEventMouseButton
	if mouse_button != null and mouse_button.button_index == MOUSE_BUTTON_LEFT:
		if mouse_button.pressed:
			if _pending_target_skill != "":
				if _pick_ui_control(mouse_button.position) != null:
					return
				if _try_execute_pending_target_skill(mouse_button.position, _is_queue_input_active()):
					_pending_target_skill = ""
				_refresh_hint_label()
				return
			if _placing_building:
				return
			if _pick_ui_control(mouse_button.position) != null:
				return
			_dragging = true
			_drag_start = mouse_button.position
			if _selection_overlay != null and _selection_overlay.has_method("begin_drag"):
				_selection_overlay.call("begin_drag", _drag_start)
		else:
			if not _dragging:
				return
			var drag_end: Vector2 = mouse_button.position
			var drag_distance: float = _drag_start.distance_to(drag_end)
			var additive: bool = Input.is_key_pressed(KEY_SHIFT)
			if drag_distance < 8.0:
				_select_single(drag_end, additive)
			else:
				_select_by_rect(_drag_start, drag_end, additive)
			_dragging = false
			if _selection_overlay != null and _selection_overlay.has_method("end_drag"):
				_selection_overlay.call("end_drag")
			_refresh_hint_label()
		return

	var mouse_motion: InputEventMouseMotion = event as InputEventMouseMotion
	if mouse_motion != null and _dragging:
		if _selection_overlay != null and _selection_overlay.has_method("update_drag"):
			_selection_overlay.call("update_drag", mouse_motion.position)

func _unhandled_input(event: InputEvent) -> void:
	if _camera == null:
		return

	var key_event: InputEventKey = event as InputEventKey
	if key_event != null and key_event.pressed and not key_event.echo:
		match key_event.keycode:
			KEY_B:
				_execute_command("build_menu")
				return
			KEY_A:
				_execute_command("attack")
				return
			KEY_ESCAPE:
				if _placing_building:
					_execute_command("placement_cancel")
					return
				if _build_menu_open:
					_execute_command("close_menu")
					return
				if _pending_target_skill != "":
					_pending_target_skill = ""
					_refresh_hint_label()
					return
			KEY_R:
				_execute_command("train_worker")
				return
			KEY_T:
				_execute_command("train_soldier")
				return
			KEY_S:
				_execute_command("stop")
				return

		if _build_menu_open and _try_execute_build_hotkey(key_event.keycode):
			return

	var mouse_button: InputEventMouseButton = event as InputEventMouseButton
	if _placing_building and mouse_button != null:
		if mouse_button.button_index == MOUSE_BUTTON_RIGHT and mouse_button.pressed:
			_execute_command("placement_cancel")
			return
		if mouse_button.button_index == MOUSE_BUTTON_LEFT and mouse_button.pressed:
			_try_place_building(mouse_button.position)
			return

	if mouse_button != null and mouse_button.button_index == MOUSE_BUTTON_RIGHT and mouse_button.pressed:
		if _pending_target_skill != "":
			_pending_target_skill = ""
			_refresh_hint_label()
			return
		_issue_context_command(mouse_button.position, _is_queue_input_active())

func _pick_ui_control(screen_pos: Vector2) -> Control:
	var viewport: Viewport = get_viewport()
	if viewport == null:
		return null

	if viewport.has_method("gui_pick"):
		return viewport.call("gui_pick", screen_pos) as Control

	if viewport.has_method("gui_get_hovered_control"):
		var hovered: Control = viewport.call("gui_get_hovered_control") as Control
		if hovered != null and hovered.get_global_rect().has_point(screen_pos):
			return hovered

	return null

func _try_execute_build_hotkey(keycode: int) -> bool:
	for skill_id in _build_menu_skill_ids():
		var skill_def: Dictionary = RTS_CATALOG.get_skill_def(skill_id)
		var hotkey: String = str(skill_def.get("hotkey", "")).strip_edges().to_upper()
		if hotkey.length() != 1:
			continue
		if keycode == hotkey.unicode_at(0):
			_execute_command(skill_id)
			return true
	return false

func _is_queue_input_active() -> bool:
	return Input.is_key_pressed(KEY_SHIFT)

func _refresh_input_state() -> void:
	var next_state: int = InputState.IDLE
	if _placing_building:
		next_state = InputState.BUILDING_PLACEMENT
	elif _pending_target_skill != "":
		next_state = InputState.SKILL_SELECTED
	elif _is_queue_input_active() and (not _selected_units.is_empty() or not _selected_buildings.is_empty()):
		next_state = InputState.QUEUE_INPUT
	elif not _selected_units.is_empty() or not _selected_buildings.is_empty():
		next_state = InputState.UNIT_SELECTED
	_input_state = next_state

func _schedule_unit_command(unit_node: Node, command: RTSCommand) -> void:
	if unit_node == null or not is_instance_valid(unit_node):
		return
	if command == null:
		return
	_execution_queue.append({
		"unit": unit_node,
		"command": command
	})
	if not command.is_queue_command:
		_drain_execution_queue()

func _drain_execution_queue() -> void:
	if _execution_queue.is_empty():
		return
	while not _execution_queue.is_empty():
		var entry_value: Variant = _execution_queue.pop_front()
		if not (entry_value is Dictionary):
			continue
		var entry: Dictionary = entry_value as Dictionary
		var unit_node: Node = entry.get("unit") as Node
		var command: RTSCommand = entry.get("command") as RTSCommand
		if unit_node == null or not is_instance_valid(unit_node):
			continue
		if command == null:
			continue
		if unit_node.has_method("submit_command"):
			unit_node.call("submit_command", command)
			continue
		_fallback_execute_unit_command(unit_node, command)

func _fallback_execute_unit_command(unit_node: Node, command: RTSCommand) -> void:
	match command.command_type:
		RTSCommand.CommandType.MOVE:
			if unit_node.has_method("command_move"):
				unit_node.call("command_move", command.target_position)
		RTSCommand.CommandType.ATTACK:
			var target_unit: Node3D = command.target_unit as Node3D
			if target_unit != null and unit_node.has_method("command_attack"):
				unit_node.call("command_attack", target_unit)
		RTSCommand.CommandType.ATTACK_MOVE:
			if unit_node.has_method("command_attack_move"):
				unit_node.call("command_attack_move", command.target_position)
		RTSCommand.CommandType.GATHER:
			var resource_node: Node3D = command.payload.get("resource") as Node3D
			var dropoff_node: Node3D = command.payload.get("dropoff") as Node3D
			if resource_node != null and dropoff_node != null and unit_node.has_method("command_gather"):
				unit_node.call("command_gather", resource_node, dropoff_node)
		RTSCommand.CommandType.RETURN_RESOURCE:
			var dropoff: Node3D = command.payload.get("dropoff") as Node3D
			if dropoff != null and unit_node.has_method("command_return_to_dropoff"):
				unit_node.call("command_return_to_dropoff", dropoff)
		RTSCommand.CommandType.STOP:
			if unit_node.has_method("command_stop"):
				unit_node.call("command_stop")

func add_minerals(amount: int) -> void:
	if amount <= 0:
		return
	_minerals += amount
	_refresh_resource_label()

func try_spend_minerals(cost: int) -> bool:
	if cost <= 0:
		return true
	if _minerals < cost:
		return false
	_minerals -= cost
	_refresh_resource_label()
	return true

func get_minerals() -> int:
	return _minerals

func _refresh_resource_label() -> void:
	_push_hud_update()

func _refresh_hint_label() -> void:
	_push_hud_update()

func _push_hud_update() -> void:
	if _hud == null or not _hud.has_method("update_hud"):
		return
	_hud.call("update_hud", _build_hud_snapshot())

func _build_hud_snapshot() -> Dictionary:
	_prune_invalid_selection()
	var selected_worker_count: int = 0
	var selected_soldier_count: int = 0
	for selected_unit in _selected_units:
		if selected_unit == null:
			continue
		var is_worker: bool = false
		if selected_unit.has_method("is_worker_unit"):
			is_worker = bool(selected_unit.call("is_worker_unit"))
		if is_worker:
			selected_worker_count += 1
		else:
			selected_soldier_count += 1

	var selected_building_count: int = _selected_buildings.size()
	var selection_total: int = _selected_units.size() + selected_building_count
	var mode: String = _selection_mode(selection_total)

	var single_title: String = "No Selection"
	var single_detail: String = "Select a unit or building to inspect details."
	var single_armor: String = "Armor Type: --"
	var status_health: float = 1.0
	var status_shield: float = 0.0
	var status_energy: float = 0.0

	var show_production: bool = false
	var queue_size: int = 0
	var queue_progress: float = 0.0
	var queue_preview: Array[String] = []

	var portrait_title: String = "No Selection"
	var portrait_subtitle: String = "-"
	var portrait_glyph: String = "?"
	var multi_roles: Array[String] = []

	if mode == "single":
		if _selected_units.size() == 1 and _selected_units[0] != null:
			var unit: Node = _selected_units[0]
			var unit_name: String = "Unit"
			if unit.has_method("get_unit_display_name"):
				unit_name = str(unit.call("get_unit_display_name"))
			single_title = unit_name

			var unit_state: String = "Idle"
			if unit.has_method("get_mode_label"):
				unit_state = str(unit.call("get_mode_label"))
			var unit_role: String = "Soldier"
			var is_worker: bool = false
			if unit.has_method("is_worker_unit"):
				is_worker = bool(unit.call("is_worker_unit"))
			if is_worker:
				unit_role = "Worker"
				status_energy = float(unit.call("get_carry_fill_ratio")) if unit.has_method("get_carry_fill_ratio") else 0.0
			status_health = float(unit.call("get_health_ratio")) if unit.has_method("get_health_ratio") else 1.0
			var unit_hp_text: String = "%d%%" % int(round(status_health * 100.0))
			var pending_commands: int = int(unit.call("get_pending_command_count")) if unit.has_method("get_pending_command_count") else 0
			single_detail = "Role: %s\nState: %s\nHP: %s\nCmd Queue: %d" % [unit_role, unit_state, unit_hp_text, pending_commands]
			single_armor = "Armor Type: Light"

			portrait_title = unit_name
			portrait_subtitle = unit_state
			portrait_glyph = "W" if is_worker else "S"
		elif _selected_buildings.size() == 1 and _selected_buildings[0] != null:
			var building: Node = _selected_buildings[0]
			var building_name: String = "Building"
			if building.has_method("get_building_display_name"):
				building_name = str(building.call("get_building_display_name"))
			single_title = building_name
			single_armor = "Armor Type: Structure"

			var can_train_worker: bool = bool(building.call("can_queue_worker_unit")) if building.has_method("can_queue_worker_unit") else false
			var can_train_soldier: bool = bool(building.call("can_queue_soldier_unit")) if building.has_method("can_queue_soldier_unit") else false
			status_health = float(building.call("get_health_ratio")) if building.has_method("get_health_ratio") else 1.0
			var building_hp_text: String = "%d%%" % int(round(status_health * 100.0))
			single_detail = "Train Worker: %s\nTrain Soldier: %s" % [
				"Yes" if can_train_worker else "No",
				"Yes" if can_train_soldier else "No"
			]
			single_detail += "\nHP: %s" % building_hp_text

			queue_size = int(building.call("get_queue_size")) if building.has_method("get_queue_size") else 0
			queue_progress = float(building.call("get_production_progress")) if building.has_method("get_production_progress") else 0.0
			if building.has_method("get_queue_preview"):
				var preview_variant: Variant = building.call("get_queue_preview", 5)
				if preview_variant is Array:
					for item in preview_variant:
						queue_preview.append(str(item))
			show_production = queue_size > 0

			portrait_title = building_name
			portrait_subtitle = "Queue %d" % queue_size
			if building.has_method("get_building_role_tag"):
				portrait_glyph = str(building.call("get_building_role_tag")).substr(0, 1)
			else:
				portrait_glyph = "B"
	elif mode == "multi":
		multi_roles = _build_multi_roles()
		portrait_title = "%d Selected" % selection_total
		portrait_subtitle = "W %d  S %d  B %d" % [selected_worker_count, selected_soldier_count, selected_building_count]
		portrait_glyph = "%d" % selection_total

	var total_units: int = _count_total_units()
	var queued_units: int = _count_total_queued_units()
	var supply_used: int = total_units + queued_units
	var top_legacy_text: String = "M: %d   G: 0   Supply: %d/%d" % [_minerals, supply_used, SUPPLY_CAP]

	return {
		"minerals": _minerals,
		"gas": 0,
		"supply_used": supply_used,
		"supply_cap": SUPPLY_CAP,
		"top_legacy_text": top_legacy_text,
		"input_state": _input_state_label(),
		"mode": mode,
		"selection_hint": _build_selection_hint(selected_worker_count, selected_soldier_count, selected_building_count, queue_size),
		"single_title": single_title,
		"single_detail": single_detail,
		"single_armor": single_armor,
		"status_health": status_health,
		"status_shield": status_shield,
		"status_energy": status_energy,
		"show_production": show_production,
		"queue_size": queue_size,
		"queue_progress": queue_progress,
		"queue_preview": queue_preview,
		"multi_roles": multi_roles,
		"matrix_page_text": "Page 1/1",
		"portrait_glyph": portrait_glyph,
		"portrait_title": portrait_title,
		"portrait_subtitle": portrait_subtitle,
		"subgroup_text": _build_subgroup_text(mode, selection_total),
		"command_hint": _build_command_hint(),
		"command_entries": _build_command_entries(),
		"notifications": _build_notifications()
	}

func _selection_mode(selection_total: int) -> String:
	if selection_total <= 0:
		return "none"
	if selection_total == 1:
		return "single"
	return "multi"

func _input_state_label() -> String:
	match _input_state:
		InputState.UNIT_SELECTED:
			return "UNIT_SELECTED"
		InputState.SKILL_SELECTED:
			return "SKILL_SELECTED"
		InputState.BUILDING_PLACEMENT:
			return "BUILDING_PLACEMENT"
		InputState.QUEUE_INPUT:
			return "QUEUE_INPUT"
		_:
			return "IDLE"

func _build_selection_hint(selected_worker_count: int, selected_soldier_count: int, selected_building_count: int, queue_size: int) -> String:
	if _placing_building:
		var placement_state: String = "Valid" if _placement_can_place else "Invalid"
		var placing_name: String = _placing_kind.capitalize()
		var placing_def: Dictionary = RTS_CATALOG.get_building_def(_placing_kind)
		if not placing_def.is_empty():
			placing_name = str(placing_def.get("display_name", placing_name))
		return "Placing %s (%d): %s | LMB Confirm, RMB/ESC Cancel" % [placing_name, _placing_cost, placement_state]
	if _build_menu_open:
		return _build_menu_hint_text()
	if _pending_target_skill != "":
		var skill_info: Dictionary = RTS_CATALOG.get_skill_def(_pending_target_skill)
		var skill_label: String = str(skill_info.get("label", _pending_target_skill.capitalize()))
		var target_mode: String = str(skill_info.get("target_mode", "none"))
		if target_mode == "resource":
			return "Targeting %s | Left Click Resource | RMB/ESC Cancel" % skill_label
		if target_mode == "ground":
			return "Targeting %s | Left Click Ground | RMB/ESC Cancel" % skill_label
		if target_mode == "unit_or_building":
			return "Targeting %s | Left Click Enemy for focus fire, or Ground for attack-move | RMB/ESC Cancel" % skill_label
		return "Targeting %s | RMB/ESC Cancel" % skill_label
	if _selected_units.is_empty() and _selected_buildings.is_empty():
		return "No selection | Select worker/builder to open Build Menu | Left drag: Box Select"
	if _selected_buildings.size() == 1 and _selected_units.is_empty():
		return "Selected Building: %d queue item(s) | R/T: Train by building type" % queue_size
	if _input_state == InputState.QUEUE_INPUT:
		return "Queue Input: Shift held | Worker %d | Soldier %d | Building %d" % [selected_worker_count, selected_soldier_count, selected_building_count]
	return "Selected -> Worker %d | Soldier %d | Building %d" % [selected_worker_count, selected_soldier_count, selected_building_count]

func _build_subgroup_text(mode: String, selection_total: int) -> String:
	if mode == "multi":
		return "Subgroup: %d Units" % selection_total
	if mode == "single":
		return "Subgroup: Single"
	return "Subgroup: None"

func _build_command_hint() -> String:
	if _match_notice != "":
		return _match_notice
	if _placing_building:
		return "Placement mode active. Use mouse or command card to confirm/cancel."
	if _build_menu_open:
		return "Build menu open. Select a building option or press ESC to close."
	if _pending_target_skill != "":
		return "Targeted skill armed. Left click world target, RMB/ESC to cancel."
	if _input_state == InputState.QUEUE_INPUT:
		return "Queue input active. Shift-held commands are appended."
	if not _active_research.is_empty():
		return _active_research_hint_text()
	if _selected_buildings.size() == 1 and _selected_units.is_empty():
		return "Click command cards or use hotkeys for production/build commands."
	if not _selected_units.is_empty():
		return "RMB context command or click move/gather/stop in command card."
	return "Select something to open context commands."

func _active_research_hint_text() -> String:
	if _active_research.is_empty():
		return ""
	var best_tech_id: String = ""
	var best_remaining: float = INF
	for tech_key in _active_research.keys():
		var tech_id: String = str(tech_key)
		var task_value: Variant = _active_research.get(tech_id, {})
		if not (task_value is Dictionary):
			continue
		var task: Dictionary = task_value as Dictionary
		var remaining: float = maxf(0.0, float(task.get("remaining", 0.0)))
		if best_tech_id == "" or remaining < best_remaining:
			best_tech_id = tech_id
			best_remaining = remaining
	if best_tech_id == "":
		return "Research in progress."
	var tech_name: String = _tech_display_name(best_tech_id)
	var rounded_remaining: int = int(ceil(best_remaining))
	if _active_research.size() > 1:
		return "Researching %s (%ds). +%d more active." % [tech_name, rounded_remaining, _active_research.size() - 1]
	return "Researching %s (%ds remaining)." % [tech_name, rounded_remaining]

func _build_menu_hint_text() -> String:
	var parts: Array[String] = []
	for skill_id in _build_menu_skill_ids():
		var skill_def: Dictionary = RTS_CATALOG.get_skill_def(skill_id)
		var label: String = str(skill_def.get("label", skill_id.capitalize()))
		var hotkey: String = str(skill_def.get("hotkey", "")).strip_edges().to_upper()
		var building_kind: String = RTS_CATALOG.get_build_kind_from_skill(skill_id)
		var cost: int = _building_cost(building_kind)
		var text: String = "%s (%d)" % [label, cost]
		if hotkey != "":
			text = "%s %s (%d)" % [hotkey, label, cost]
		parts.append(text)
	if parts.is_empty():
		return "Build Menu: No available build options | ESC Back"
	return "Build Menu: %s | ESC Back" % ", ".join(parts)

func _build_command_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	if _placing_building:
		entries.append(_command_entry("placement_confirm", {
			"enabled": _placement_can_place and _minerals >= _placing_cost,
			"cost_text": str(_placing_cost)
		}))
		entries.append(_command_entry("placement_cancel"))
		return entries

	if _build_menu_open:
		if not _can_open_build_menu():
			_build_menu_open = false
		else:
			for skill_id in _build_menu_skill_ids():
				entries.append(_build_menu_command_entry(skill_id))
			entries.append(_command_entry("close_menu"))
			return entries

	var skill_ids: Array[String] = _selection_skill_ids()
	for skill_id in skill_ids:
		entries.append(_command_entry(skill_id, _command_overrides_for(skill_id)))
	if not entries.is_empty():
		return entries

	entries.append(_command_entry("build_menu", {
		"enabled": _can_open_build_menu(),
		"disabled_reason": _build_menu_disabled_reason()
	}))
	entries.append(_command_entry("menu"))
	return entries

func _command_entry(skill_id: String, overrides: Dictionary = {}) -> Dictionary:
	return RTS_CATALOG.make_command_entry(skill_id, overrides)

func _build_menu_command_entry(command_id: String) -> Dictionary:
	var build_kind: String = RTS_CATALOG.get_build_kind_from_skill(command_id)
	if build_kind == "":
		return _command_entry(command_id)
	var cost: int = _building_cost(build_kind)
	var enabled: bool = _can_start_build_skill(command_id)
	var reason: String = _build_skill_block_reason(command_id)
	return _command_entry(command_id, {
		"enabled": enabled,
		"cost_text": str(cost),
		"disabled_reason": reason
	})

func _build_menu_skill_ids() -> Array[String]:
	var skill_ids: Array[String] = []
	if not _can_open_build_menu():
		return skill_ids

	if not _selected_units.is_empty():
		for selected_unit in _selected_units:
			if selected_unit == null or not is_instance_valid(selected_unit):
				continue
			if not _is_player_owned(selected_unit):
				continue
			var raw_skills: Variant = []
			if selected_unit.has_method("get_build_skill_ids"):
				raw_skills = selected_unit.call("get_build_skill_ids")
			elif selected_unit.has_method("get_unit_kind"):
				raw_skills = RTS_CATALOG.get_unit_build_skill_ids(str(selected_unit.call("get_unit_kind")))
			_append_unique_skill_ids(skill_ids, raw_skills)
		return _sanitize_build_skill_ids(skill_ids)

	for selected_building in _selected_buildings:
		if selected_building == null or not is_instance_valid(selected_building):
			continue
		if not _is_player_owned(selected_building):
			continue
		var raw_building_skills: Variant = []
		if selected_building.has_method("get_build_skill_ids"):
			raw_building_skills = selected_building.call("get_build_skill_ids")
		else:
			var building_kind: String = str(selected_building.get("building_kind"))
			raw_building_skills = RTS_CATALOG.get_building_build_skill_ids(building_kind)
		_append_unique_skill_ids(skill_ids, raw_building_skills)
	return _sanitize_build_skill_ids(skill_ids)

func _sanitize_build_skill_ids(skill_ids: Array[String]) -> Array[String]:
	var result: Array[String] = []
	for skill_id in skill_ids:
		var building_kind: String = RTS_CATALOG.get_build_kind_from_skill(skill_id)
		if building_kind == "":
			continue
		if _building_cost(building_kind) <= 0:
			continue
		result.append(skill_id)
	return result

func _selection_skill_ids() -> Array[String]:
	var skill_ids: Array[String] = []
	if not _selected_units.is_empty():
		for selected_unit in _selected_units:
			if selected_unit == null or not is_instance_valid(selected_unit):
				continue
			if not _is_player_owned(selected_unit):
				continue
			var raw_skills: Variant = []
			if selected_unit.has_method("get_skill_ids"):
				raw_skills = selected_unit.call("get_skill_ids")
			elif selected_unit.has_method("is_worker_unit") and bool(selected_unit.call("is_worker_unit")):
				raw_skills = RTS_CATALOG.get_unit_skill_ids("worker")
			else:
				raw_skills = RTS_CATALOG.get_unit_skill_ids("soldier")
			_append_unique_skill_ids(skill_ids, raw_skills)
		return skill_ids

	for selected_building in _selected_buildings:
		if selected_building == null or not is_instance_valid(selected_building):
			continue
		if not _is_player_owned(selected_building):
			continue
		var raw_building_skills: Variant = []
		if selected_building.has_method("get_skill_ids"):
			raw_building_skills = selected_building.call("get_skill_ids")
		else:
			var building_kind: String = str(selected_building.get("building_kind"))
			raw_building_skills = RTS_CATALOG.get_building_skill_ids(building_kind)
		_append_unique_skill_ids(skill_ids, raw_building_skills)
	return skill_ids

func _append_unique_skill_ids(skill_ids: Array[String], raw_skills: Variant) -> void:
	if not (raw_skills is Array):
		return
	for value in raw_skills:
		var skill_id: String = str(value)
		if skill_id == "":
			continue
		if skill_ids.has(skill_id):
			continue
		skill_ids.append(skill_id)

func _command_overrides_for(skill_id: String) -> Dictionary:
	var overrides: Dictionary = {}
	match skill_id:
		"build_menu":
			var build_menu_enabled: bool = _can_open_build_menu()
			overrides["enabled"] = build_menu_enabled
			overrides["disabled_reason"] = "" if build_menu_enabled else _build_menu_disabled_reason()
		"gather":
			var gather_enabled: bool = _selection_has_worker()
			overrides["enabled"] = gather_enabled
			overrides["disabled_reason"] = "" if gather_enabled else "Requires at least one worker in selection."
		"return_resource":
			var has_worker_cargo: bool = _selection_has_worker_cargo()
			overrides["enabled"] = has_worker_cargo
			overrides["disabled_reason"] = "" if has_worker_cargo else "Selected workers are not carrying minerals."
		"attack":
			var attack_enabled: bool = _selection_has_combat_unit()
			overrides["enabled"] = attack_enabled
			overrides["disabled_reason"] = "" if attack_enabled else "Requires at least one combat unit."
		"train_worker":
			var train_worker_enabled: bool = _can_train_worker_from_selection()
			overrides["enabled"] = train_worker_enabled
			overrides["cost_text"] = str(_worker_cost)
			overrides["cooldown_ratio"] = _selected_queue_cooldown_ratio("worker")
			overrides["disabled_reason"] = "" if train_worker_enabled else _train_worker_block_reason()
		"train_soldier":
			var train_soldier_enabled: bool = _can_train_soldier_from_selection()
			overrides["enabled"] = train_soldier_enabled
			overrides["cost_text"] = str(_soldier_cost)
			overrides["cooldown_ratio"] = _selected_queue_cooldown_ratio("soldier")
			overrides["disabled_reason"] = "" if train_soldier_enabled else _train_soldier_block_reason()
	if overrides.is_empty():
		var tech_id: String = RTS_CATALOG.get_tech_id_from_skill(skill_id)
		if tech_id != "":
			var research_cost: int = RTS_CATALOG.get_tech_cost(tech_id)
			var reason: String = _research_skill_block_reason(skill_id)
			overrides["enabled"] = reason == ""
			overrides["cost_text"] = str(research_cost) if research_cost > 0 else ""
			overrides["cooldown_ratio"] = _research_skill_cooldown_ratio(skill_id)
			overrides["disabled_reason"] = reason
	return overrides

func _build_notifications() -> Array[String]:
	var lines: Array[String] = [
		"B: Build Menu | Open build options from selected builder",
		"R: Train Worker (%d) | T: Train Soldier (%d) | A: Attack/Attack-Move | S: Stop" % [_worker_cost, _soldier_cost],
		"Shift + Left Click: Additive Select | Shift + Right Click: Queue Command"
	]
	if _match_notice != "":
		lines[0] = _match_notice
		lines[1] = "Match Rule: %s" % _match_outcome_rule_id
		lines[2] = "Notify-only mode for testing."
		return lines
	if _placing_building:
		var state: String = "valid" if _placement_can_place else "invalid"
		lines[0] = "Placement %s | Cost: %d Minerals" % [state, _placing_cost]
	elif _build_menu_open:
		lines[0] = _build_menu_hint_text()
	elif _pending_target_skill != "":
		var skill_info: Dictionary = RTS_CATALOG.get_skill_def(_pending_target_skill)
		lines[0] = "Targeting: %s" % str(skill_info.get("label", _pending_target_skill))
	elif not _active_research.is_empty():
		lines[0] = _active_research_hint_text()
		lines[1] = "Unlocked Tech: %d | Active Research: %d" % [_unlocked_techs.size(), _active_research.size()]
	return lines

func _build_multi_roles() -> Array[String]:
	var roles: Array[String] = []
	for selected_unit in _selected_units:
		if selected_unit == null or not is_instance_valid(selected_unit):
			continue
		if not _is_player_owned(selected_unit):
			continue
		var role_tag: String = "U"
		if selected_unit.has_method("get_unit_role_tag"):
			role_tag = str(selected_unit.call("get_unit_role_tag"))
		roles.append(role_tag)
		if roles.size() >= HUD_MULTI_MAX:
			return roles

	for selected_building in _selected_buildings:
		if selected_building == null or not is_instance_valid(selected_building):
			continue
		if not _is_player_owned(selected_building):
			continue
		var role: String = "Building"
		if selected_building.has_method("get_building_role_tag"):
			role = str(selected_building.call("get_building_role_tag"))
		roles.append(role)
		if roles.size() >= HUD_MULTI_MAX:
			return roles

	return roles

func _count_total_units() -> int:
	var count: int = 0
	var units: Array[Node] = get_tree().get_nodes_in_group("selectable_unit")
	for unit_node in units:
		if unit_node != null and is_instance_valid(unit_node) and _is_player_owned(unit_node):
			count += 1
	return count

func _count_total_queued_units() -> int:
	var count: int = 0
	var buildings: Array[Node] = get_tree().get_nodes_in_group("selectable_building")
	for building_node in buildings:
		if building_node == null or not is_instance_valid(building_node):
			continue
		if not _is_player_owned(building_node):
			continue
		if not building_node.has_method("get_queue_size"):
			continue
		count += int(building_node.call("get_queue_size"))
	return count

func _has_supply_for(extra_units: int = 1) -> bool:
	if extra_units <= 0:
		return true
	return _count_total_units() + _count_total_queued_units() + extra_units <= SUPPLY_CAP

func _selection_has_worker() -> bool:
	for selected_unit in _selected_units:
		if selected_unit == null or not is_instance_valid(selected_unit):
			continue
		if not _is_player_owned(selected_unit):
			continue
		if selected_unit.has_method("is_worker_unit") and bool(selected_unit.call("is_worker_unit")):
			return true
	return false

func _selection_has_worker_cargo() -> bool:
	for selected_unit in _selected_units:
		if selected_unit == null or not is_instance_valid(selected_unit):
			continue
		if not _is_player_owned(selected_unit):
			continue
		if not selected_unit.has_method("is_worker_unit"):
			continue
		if not bool(selected_unit.call("is_worker_unit")):
			continue
		if selected_unit.has_method("has_cargo") and bool(selected_unit.call("has_cargo")):
			return true
	return false

func _selection_has_combat_unit() -> bool:
	for selected_unit in _selected_units:
		if selected_unit == null or not is_instance_valid(selected_unit):
			continue
		if selected_unit.has_method("is_worker_unit") and not bool(selected_unit.call("is_worker_unit")):
			if _is_player_owned(selected_unit):
				return true
	return false

func _can_open_build_menu() -> bool:
	if _placing_building:
		return false
	if _selection_has_worker():
		return true
	if _selected_units.is_empty() and not _selected_buildings.is_empty():
		return _building_selection_has_skill("build_menu")
	return false

func _build_menu_disabled_reason() -> String:
	if _placing_building:
		return "Finish or cancel current placement first."
	if _selected_units.is_empty() and _selected_buildings.is_empty():
		return "Select a worker or builder building to open build commands."
	if not _selected_units.is_empty() and not _selection_has_worker():
		return "Requires at least one worker in selection."
	if _selected_units.is_empty() and not _selected_buildings.is_empty() and not _building_selection_has_skill("build_menu"):
		return "Selected buildings cannot build structures."
	return ""

func _building_selection_has_skill(skill_id: String) -> bool:
	if skill_id == "":
		return false
	for selected_building in _selected_buildings:
		if selected_building == null or not is_instance_valid(selected_building):
			continue
		if not _is_player_owned(selected_building):
			continue
		var raw_skills: Variant = []
		if selected_building.has_method("get_skill_ids"):
			raw_skills = selected_building.call("get_skill_ids")
		else:
			var building_kind: String = str(selected_building.get("building_kind"))
			raw_skills = RTS_CATALOG.get_building_skill_ids(building_kind)
		if not (raw_skills is Array):
			continue
		for value in raw_skills:
			if str(value) == skill_id:
				return true
	return false

func _building_cost(building_kind: String) -> int:
	if building_kind == "":
		return 0
	var building_def: Dictionary = RTS_CATALOG.get_building_def(building_kind)
	return int(building_def.get("cost", 0))

func has_tech(tech_id: String) -> bool:
	if tech_id == "":
		return false
	return bool(_unlocked_techs.get(tech_id, false))

func unlock_tech(tech_id: String) -> bool:
	var normalized: String = tech_id.strip_edges()
	if normalized == "":
		return false
	if has_tech(normalized):
		return false
	_unlocked_techs[normalized] = true
	_refresh_hint_label()
	return true

func _requirements_reason_for_building_kind(building_kind: String) -> String:
	var required_buildings: Array[Dictionary] = RTS_CATALOG.get_building_requires_buildings(building_kind)
	var required_techs: Array[String] = RTS_CATALOG.get_building_requires_tech(building_kind)
	return _requirements_reason_from_lists(required_buildings, required_techs)

func _requirements_reason_for_unit_kind(unit_kind: String) -> String:
	var required_buildings: Array[Dictionary] = RTS_CATALOG.get_unit_requires_buildings(unit_kind)
	var required_techs: Array[String] = RTS_CATALOG.get_unit_requires_tech(unit_kind)
	return _requirements_reason_from_lists(required_buildings, required_techs)

func _requirements_reason_from_lists(required_buildings: Array[Dictionary], required_techs: Array[String]) -> String:
	var parts: Array[String] = []
	var missing_buildings: Array[String] = _missing_required_buildings(required_buildings)
	if not missing_buildings.is_empty():
		parts.append("Buildings: %s" % ", ".join(missing_buildings))
	var missing_techs: Array[String] = _missing_required_techs(required_techs)
	if not missing_techs.is_empty():
		parts.append("Tech: %s" % ", ".join(missing_techs))
	if parts.is_empty():
		return ""
	return "Locked - %s" % " | ".join(parts)

func _missing_required_buildings(requirements: Array[Dictionary]) -> Array[String]:
	var missing: Array[String] = []
	for requirement in requirements:
		var kind: String = str(requirement.get("kind", "")).strip_edges()
		if kind == "":
			continue
		var required_count: int = maxi(1, int(requirement.get("count", 1)))
		var current_count: int = _player_owned_building_count(kind)
		if current_count >= required_count:
			continue
		var display_name: String = _building_display_name(kind)
		missing.append("%s (%d/%d)" % [display_name, current_count, required_count])
	return missing

func _missing_required_techs(required_techs: Array[String]) -> Array[String]:
	var missing: Array[String] = []
	for tech_id in required_techs:
		var normalized: String = tech_id.strip_edges()
		if normalized == "":
			continue
		if has_tech(normalized):
			continue
		missing.append(_tech_display_name(normalized))
	return missing

func _player_owned_building_count(building_kind: String) -> int:
	if building_kind == "":
		return 0
	var count: int = 0
	var nodes: Array[Node] = get_tree().get_nodes_in_group("selectable_building")
	for node in nodes:
		if node == null or not is_instance_valid(node):
			continue
		if not _is_player_owned(node):
			continue
		if node.has_method("is_alive") and not bool(node.call("is_alive")):
			continue
		if str(node.get("building_kind")) != building_kind:
			continue
		count += 1
	return count

func _building_display_name(building_kind: String) -> String:
	var building_def: Dictionary = RTS_CATALOG.get_building_def(building_kind)
	return str(building_def.get("display_name", building_kind.capitalize()))

func _tech_display_name(tech_id: String) -> String:
	var tech_def: Dictionary = RTS_CATALOG.get_tech_def(tech_id)
	return str(tech_def.get("display_name", tech_id.capitalize()))

func _requirements_reason_for_tech(tech_id: String) -> String:
	var required_buildings: Array[Dictionary] = RTS_CATALOG.get_tech_requires_buildings(tech_id)
	var required_techs: Array[String] = RTS_CATALOG.get_tech_requires_tech(tech_id)
	return _requirements_reason_from_lists(required_buildings, required_techs)

func _selection_has_skill(skill_id: String) -> bool:
	if skill_id == "":
		return false
	var skill_ids: Array[String] = _selection_skill_ids()
	return skill_ids.has(skill_id)

func _is_tech_researching(tech_id: String) -> bool:
	if tech_id == "":
		return false
	return _active_research.has(tech_id)

func _research_skill_block_reason(skill_id: String) -> String:
	var tech_id: String = RTS_CATALOG.get_tech_id_from_skill(skill_id)
	if tech_id == "":
		return "Unknown research command."
	if not _selection_has_skill(skill_id):
		return "Selected buildings cannot perform this research."
	if has_tech(tech_id):
		return "Already researched."
	if _is_tech_researching(tech_id):
		return "Research in progress."
	var requirement_reason: String = _requirements_reason_for_tech(tech_id)
	if requirement_reason != "":
		return requirement_reason
	var research_cost: int = RTS_CATALOG.get_tech_cost(tech_id)
	if research_cost <= 0:
		return "Invalid research cost."
	if _minerals < research_cost:
		return "Not enough minerals."
	return ""

func _research_skill_cooldown_ratio(skill_id: String) -> float:
	var tech_id: String = RTS_CATALOG.get_tech_id_from_skill(skill_id)
	if tech_id == "" or not _is_tech_researching(tech_id):
		return 0.0
	var task_value: Variant = _active_research.get(tech_id, {})
	if not (task_value is Dictionary):
		return 0.0
	var task: Dictionary = task_value as Dictionary
	var total: float = maxf(0.01, float(task.get("total", 0.01)))
	var remaining: float = clampf(float(task.get("remaining", 0.0)), 0.0, total)
	return clampf(remaining / total, 0.0, 1.0)

func _start_research_skill(skill_id: String) -> bool:
	var reason: String = _research_skill_block_reason(skill_id)
	if reason != "":
		return false
	var tech_id: String = RTS_CATALOG.get_tech_id_from_skill(skill_id)
	if tech_id == "":
		return false
	var research_cost: int = RTS_CATALOG.get_tech_cost(tech_id)
	if not try_spend_minerals(research_cost):
		return false
	var research_time: float = RTS_CATALOG.get_tech_research_time(tech_id)
	if research_time <= 0.0:
		unlock_tech(tech_id)
		return true
	_active_research[tech_id] = {
		"remaining": research_time,
		"total": research_time
	}
	return true

func _can_start_build_skill(skill_id: String) -> bool:
	return _build_skill_block_reason(skill_id) == ""

func _build_skill_block_reason(skill_id: String) -> String:
	if not _can_open_build_menu():
		return _build_menu_disabled_reason()
	var build_kind: String = RTS_CATALOG.get_build_kind_from_skill(skill_id)
	if build_kind == "":
		return "Unknown build skill."
	var requirement_reason: String = _requirements_reason_for_building_kind(build_kind)
	if requirement_reason != "":
		return requirement_reason
	var build_cost: int = _building_cost(build_kind)
	if build_cost <= 0:
		return "Invalid build cost."
	if _minerals < build_cost:
		return "Not enough minerals."
	return ""

func _can_train_worker_from_selection() -> bool:
	return _train_block_reason("worker", "Worker", _worker_cost) == ""

func _can_train_soldier_from_selection() -> bool:
	return _train_block_reason("soldier", "Soldier", _soldier_cost) == ""

func _train_worker_block_reason() -> String:
	return _train_block_reason("worker", "Worker", _worker_cost)

func _train_soldier_block_reason() -> String:
	return _train_block_reason("soldier", "Soldier", _soldier_cost)

func _selected_queue_cooldown_ratio(unit_kind: String) -> float:
	if _selected_buildings.size() != 1 or not _selected_units.is_empty():
		return 0.0
	var selected_building: Node = _selected_buildings[0]
	if selected_building == null or not is_instance_valid(selected_building):
		return 0.0
	if not selected_building.has_method("get_primary_queue_kind"):
		return 0.0
	if not selected_building.has_method("get_production_progress"):
		return 0.0
	var primary_kind: String = str(selected_building.call("get_primary_queue_kind"))
	if primary_kind != unit_kind:
		return 0.0
	var progress: float = clampf(float(selected_building.call("get_production_progress")), 0.0, 1.0)
	return clampf(1.0 - progress, 0.0, 1.0)

func _train_block_reason(unit_kind: String, label: String, cost: int) -> String:
	if not _has_trainer_for_kind(unit_kind):
		return "No selected building can train %s." % label
	var requirement_reason: String = _requirements_reason_for_unit_kind(unit_kind)
	if requirement_reason != "":
		return requirement_reason
	if _all_trainers_queue_full(unit_kind):
		return "All production queues are full."
	if _minerals < cost:
		return "Not enough minerals."
	if not _has_supply_for(1):
		return "Supply is capped."
	if not _has_available_trainer_for_kind(unit_kind):
		return "No available trainer for %s." % label
	return ""

func _has_trainer_for_kind(unit_kind: String) -> bool:
	for selected_building in _selected_buildings:
		if selected_building == null or not is_instance_valid(selected_building):
			continue
		if not _is_player_owned(selected_building):
			continue
		if _building_can_train_kind_raw(selected_building, unit_kind):
			return true
	return false

func _has_available_trainer_for_kind(unit_kind: String) -> bool:
	for selected_building in _selected_buildings:
		if selected_building == null or not is_instance_valid(selected_building):
			continue
		if not _is_player_owned(selected_building):
			continue
		if _building_can_queue_kind_now(selected_building, unit_kind):
			return true
	return false

func _all_trainers_queue_full(unit_kind: String) -> bool:
	var has_trainer: bool = false
	for selected_building in _selected_buildings:
		if selected_building == null or not is_instance_valid(selected_building):
			continue
		if not _is_player_owned(selected_building):
			continue
		if not _building_can_train_kind_raw(selected_building, unit_kind):
			continue
		has_trainer = true
		var queue_full: bool = false
		if selected_building.has_method("is_queue_full"):
			queue_full = bool(selected_building.call("is_queue_full"))
		elif selected_building.has_method("get_queue_size") and selected_building.has_method("get_queue_limit"):
			queue_full = int(selected_building.call("get_queue_size")) >= int(selected_building.call("get_queue_limit"))
		if not queue_full:
			return false
	return has_trainer

func _building_can_train_kind_raw(building_node: Node, unit_kind: String) -> bool:
	match unit_kind:
		"worker":
			return bool(building_node.get("can_queue_worker"))
		"soldier":
			return bool(building_node.get("can_queue_soldier"))
		_:
			return false

func _building_can_queue_kind_now(building_node: Node, unit_kind: String) -> bool:
	match unit_kind:
		"worker":
			if building_node.has_method("can_queue_worker_unit"):
				return bool(building_node.call("can_queue_worker_unit"))
		"soldier":
			if building_node.has_method("can_queue_soldier_unit"):
				return bool(building_node.call("can_queue_soldier_unit"))
	return false

func _selection_team_id() -> int:
	for selected_unit in _selected_units:
		if selected_unit == null or not is_instance_valid(selected_unit):
			continue
		if selected_unit.has_method("get_team_id"):
			return int(selected_unit.call("get_team_id"))
	for selected_building in _selected_buildings:
		if selected_building == null or not is_instance_valid(selected_building):
			continue
		if selected_building.has_method("get_team_id"):
			return int(selected_building.call("get_team_id"))
	return PLAYER_TEAM_ID

func _is_attackable_enemy(node: Node) -> bool:
	if node == null or not is_instance_valid(node):
		return false
	var selectable: bool = node.is_in_group("selectable_unit") or node.is_in_group("selectable_building")
	if not selectable:
		return false
	if not node.has_method("get_team_id"):
		return false
	if node.has_method("is_alive") and not bool(node.call("is_alive")):
		return false
	return int(node.call("get_team_id")) != _selection_team_id()

func _is_player_owned(node: Node) -> bool:
	if node == null or not is_instance_valid(node):
		return false
	if not node.has_method("get_team_id"):
		return true
	return int(node.call("get_team_id")) == PLAYER_TEAM_ID

func _prune_invalid_selection() -> void:
	for i in range(_selected_units.size() - 1, -1, -1):
		var node: Node = _selected_units[i]
		if node == null or not is_instance_valid(node):
			_selected_units.remove_at(i)
			continue
		if not _is_player_owned(node):
			if node.has_method("set_selected"):
				node.call("set_selected", false)
			_selected_units.remove_at(i)
	for i in range(_selected_buildings.size() - 1, -1, -1):
		var node: Node = _selected_buildings[i]
		if node == null or not is_instance_valid(node):
			_selected_buildings.remove_at(i)
			continue
		if not _is_player_owned(node):
			if node.has_method("set_selected"):
				node.call("set_selected", false)
			_selected_buildings.remove_at(i)

func _on_hud_command_pressed(command_id: String) -> void:
	_execute_command(command_id)

func _execute_command(command_id: String) -> void:
	_prune_invalid_selection()
	match command_id:
		"build_menu":
			if _can_open_build_menu():
				_build_menu_open = true
				_pending_target_skill = ""
				_refresh_hint_label()
			return
		"close_menu":
			_build_menu_open = false
			_refresh_hint_label()
			return
		"placement_confirm":
			_confirm_building_placement()
		"placement_cancel":
			_cancel_building_placement()
		"train_worker":
			_queue_worker_from_selection()
		"train_soldier":
			_queue_soldier_from_selection()
		"move", "gather", "attack":
			_begin_target_skill(command_id)
		"return_resource":
			_issue_return_command(_is_queue_input_active())
		"stop":
			_issue_stop_command(_is_queue_input_active())
		"menu":
			pass
		_:
			var research_tech_id: String = RTS_CATALOG.get_tech_id_from_skill(command_id)
			if research_tech_id != "":
				_start_research_skill(command_id)
				_refresh_hint_label()
				return
			var build_kind: String = RTS_CATALOG.get_build_kind_from_skill(command_id)
			if build_kind == "":
				return
			if not _can_start_build_skill(command_id):
				return
			_build_menu_open = false
			_start_building_placement(build_kind)
	_refresh_hint_label()

func _begin_target_skill(skill_id: String) -> void:
	if _selected_units.is_empty():
		return
	if skill_id == "attack" and not _selection_has_combat_unit():
		return
	if skill_id == "gather" and not _selection_has_worker():
		return
	_build_menu_open = false
	_pending_target_skill = skill_id

func _try_execute_pending_target_skill(screen_pos: Vector2, queue_command: bool = false) -> bool:
	match _pending_target_skill:
		"move":
			_issue_move_command(screen_pos, queue_command)
			return true
		"gather":
			var ray_result: Dictionary = _raycast_from_screen(screen_pos)
			if ray_result.is_empty():
				return false
			var collider: Node = ray_result.get("collider") as Node
			if collider == null or not collider.is_in_group("resource_node"):
				return false
			_issue_gather_command(collider as Node3D, screen_pos, queue_command)
			return true
		"attack":
			var ray_result: Dictionary = _raycast_from_screen(screen_pos)
			if not ray_result.is_empty():
				var collider: Node = ray_result.get("collider") as Node
				if collider != null and _is_attackable_enemy(collider):
					_issue_attack_command(collider as Node3D, screen_pos, queue_command)
					return true
			if not _issue_attack_move_command(screen_pos, queue_command):
				return false
			return true
		_:
			return false

func _issue_context_command(screen_pos: Vector2, queue_command: bool = false) -> void:
	_prune_invalid_selection()
	_build_menu_open = false
	if _selected_units.is_empty():
		return

	var ray_result: Dictionary = _raycast_from_screen(screen_pos)
	if not ray_result.is_empty():
		var collider: Node = ray_result.get("collider") as Node
		if collider != null and collider.is_in_group("resource_node"):
			_issue_gather_command(collider as Node3D, screen_pos, queue_command)
			return
		if collider != null and _is_attackable_enemy(collider):
			_issue_attack_command(collider as Node3D, screen_pos, queue_command)
			return

	_issue_move_command(screen_pos, queue_command)

func _select_single(screen_pos: Vector2, additive: bool) -> void:
	_build_menu_open = false
	_pending_target_skill = ""
	if not additive:
		_clear_selection()

	var result: Dictionary = _raycast_from_screen(screen_pos)
	if result.is_empty():
		return

	var collider: Node = result.get("collider") as Node
	if collider == null:
		return

	if collider.is_in_group("selectable_unit"):
		if _is_player_owned(collider):
			_add_selected_unit(collider)
		return

	if collider.is_in_group("selectable_building"):
		if _is_player_owned(collider):
			_add_selected_building(collider)

func _select_by_rect(start_pos: Vector2, end_pos: Vector2, additive: bool) -> void:
	_build_menu_open = false
	_pending_target_skill = ""
	if not additive:
		_clear_selection()

	var rect: Rect2 = Rect2(
		Vector2(minf(start_pos.x, end_pos.x), minf(start_pos.y, end_pos.y)),
		Vector2(absf(end_pos.x - start_pos.x), absf(end_pos.y - start_pos.y))
	)

	var candidates: Array[Node]
	if _units_root != null:
		candidates = _units_root.get_children()
	else:
		candidates = get_tree().get_nodes_in_group("selectable_unit")

	for node in candidates:
		var unit: Node3D = node as Node3D
		if unit == null:
			continue
		if _camera.is_position_behind(unit.global_position):
			continue
		if not _is_player_owned(unit):
			continue
		var projected_pos: Vector2 = _camera.unproject_position(unit.global_position)
		if rect.has_point(projected_pos):
			_add_selected_unit(unit)

func _queue_worker_from_selection() -> void:
	if _train_worker_block_reason() != "":
		return
	var queued_count: int = 0
	for node in _selected_buildings:
		if node == null or not is_instance_valid(node):
			continue
		if not _is_player_owned(node):
			continue
		var can_queue: bool = false
		if node.has_method("can_queue_worker_unit"):
			var can_queue_value: Variant = node.call("can_queue_worker_unit")
			can_queue = bool(can_queue_value)
		if not can_queue:
			continue
		if not _has_supply_for(1):
			break
		if not try_spend_minerals(_worker_cost):
			break
		if node.has_method("queue_worker"):
			var queued_value: Variant = node.call("queue_worker")
			if bool(queued_value):
				queued_count += 1
			else:
				add_minerals(_worker_cost)

	if queued_count > 0:
		_refresh_hint_label()

func _queue_soldier_from_selection() -> void:
	if _train_soldier_block_reason() != "":
		return
	var queued_count: int = 0
	for node in _selected_buildings:
		if node == null or not is_instance_valid(node):
			continue
		if not _is_player_owned(node):
			continue
		var can_queue: bool = false
		if node.has_method("can_queue_soldier_unit"):
			var can_queue_value: Variant = node.call("can_queue_soldier_unit")
			can_queue = bool(can_queue_value)
		if not can_queue:
			continue
		if not _has_supply_for(1):
			break
		if not try_spend_minerals(_soldier_cost):
			break
		if node.has_method("queue_soldier"):
			var queued_value: Variant = node.call("queue_soldier")
			if bool(queued_value):
				queued_count += 1
			else:
				add_minerals(_soldier_cost)

	if queued_count > 0:
		_refresh_hint_label()

func _issue_gather_command(resource_node: Node3D, fallback_screen_pos: Vector2, queue_command: bool = false) -> void:
	if resource_node == null:
		return

	var dropoff: Node3D = _nearest_dropoff(resource_node.global_position)
	if dropoff == null:
		_issue_move_command(fallback_screen_pos, queue_command)
		return

	var issued_count: int = 0
	for unit_node in _selected_units:
		if unit_node == null or not is_instance_valid(unit_node):
			continue
		if not _is_player_owned(unit_node):
			continue
		var is_worker: bool = false
		if unit_node.has_method("is_worker_unit"):
			var worker_value: Variant = unit_node.call("is_worker_unit")
			is_worker = bool(worker_value)
		if is_worker and unit_node.has_method("command_gather"):
			var gather_command: RTSCommand = RTS_COMMAND.make_gather(resource_node, dropoff, queue_command)
			_schedule_unit_command(unit_node, gather_command)
			issued_count += 1

	if issued_count == 0:
		_issue_move_command(fallback_screen_pos, queue_command)

func _issue_attack_command(target_node: Node3D, fallback_screen_pos: Vector2, queue_command: bool = false) -> void:
	if target_node == null or not is_instance_valid(target_node):
		return
	var issued_count: int = 0
	for unit_node in _selected_units:
		if unit_node == null or not is_instance_valid(unit_node):
			continue
		if not _is_player_owned(unit_node):
			continue
		if not unit_node.has_method("is_worker_unit"):
			continue
		if bool(unit_node.call("is_worker_unit")):
			continue
		var attack_command: RTSCommand = RTS_COMMAND.make_attack(target_node, queue_command)
		_schedule_unit_command(unit_node, attack_command)
		issued_count += 1
	if issued_count == 0:
		_issue_move_command(fallback_screen_pos, queue_command)

func _issue_attack_move_command(screen_pos: Vector2, queue_command: bool = false) -> bool:
	if _selected_units.is_empty():
		return false
	var target: Variant = _ground_point_from_screen(screen_pos)
	if target == null:
		return false
	var target_point: Vector3 = target as Vector3
	var issued_count: int = 0
	var count: int = _selected_units.size()
	var cols: int = int(ceil(sqrt(float(count))))
	var spacing: float = 1.6
	for i in count:
		var row: int = i / cols
		var col: int = i % cols
		var offset: Vector3 = Vector3((float(col) - float(cols - 1) * 0.5) * spacing, 0.0, (float(row) - float(cols - 1) * 0.5) * spacing)
		var unit_node: Node = _selected_units[i] as Node
		if unit_node == null or not is_instance_valid(unit_node):
			continue
		if not _is_player_owned(unit_node):
			continue
		var destination: Vector3 = target_point + offset
		var attack_move_command: RTSCommand = RTS_COMMAND.make_attack_move(destination, queue_command)
		_schedule_unit_command(unit_node, attack_move_command)
		issued_count += 1
	return issued_count > 0

func _issue_move_command(screen_pos: Vector2, queue_command: bool = false) -> void:
	if _selected_units.is_empty():
		return

	var target: Variant = _ground_point_from_screen(screen_pos)
	if target == null:
		return

	var target_point: Vector3 = target as Vector3
	var count: int = _selected_units.size()
	var cols: int = int(ceil(sqrt(float(count))))
	var spacing: float = 1.6

	for i in count:
		var row: int = i / cols
		var col: int = i % cols
		var offset: Vector3 = Vector3((float(col) - float(cols - 1) * 0.5) * spacing, 0.0, (float(row) - float(cols - 1) * 0.5) * spacing)
		var unit: Node = _selected_units[i] as Node
		if unit == null or not is_instance_valid(unit):
			continue
		if not _is_player_owned(unit):
			continue
		var move_command: RTSCommand = RTS_COMMAND.make_move(target_point + offset, queue_command)
		_schedule_unit_command(unit, move_command)

func _issue_stop_command(queue_command: bool = false) -> void:
	for unit_node in _selected_units:
		if unit_node == null or not is_instance_valid(unit_node):
			continue
		if not _is_player_owned(unit_node):
			continue
		var stop_command: RTSCommand = RTS_COMMAND.make_stop(queue_command)
		_schedule_unit_command(unit_node, stop_command)

func _issue_return_command(queue_command: bool = false) -> void:
	for unit_node in _selected_units:
		if unit_node == null or not is_instance_valid(unit_node):
			continue
		if not _is_player_owned(unit_node):
			continue
		if not unit_node.has_method("is_worker_unit"):
			continue
		if not bool(unit_node.call("is_worker_unit")):
			continue
		var unit_3d: Node3D = unit_node as Node3D
		if unit_3d == null:
			continue
		var dropoff: Node3D = _nearest_dropoff(unit_3d.global_position)
		if dropoff == null:
			continue
		var return_command: RTSCommand = RTS_COMMAND.make_return(dropoff, queue_command)
		_schedule_unit_command(unit_node, return_command)

func _nearest_dropoff(from_position: Vector3) -> Node3D:
	var nearest: Node3D = null
	var best_distance_sq: float = INF
	var dropoff_nodes: Array[Node] = get_tree().get_nodes_in_group("resource_dropoff")
	for node in dropoff_nodes:
		var dropoff: Node3D = node as Node3D
		if dropoff == null:
			continue
		var distance_sq: float = from_position.distance_squared_to(dropoff.global_position)
		if distance_sq < best_distance_sq:
			best_distance_sq = distance_sq
			nearest = dropoff
	return nearest

func _start_building_placement(kind: String) -> void:
	var build_cost: int = _building_cost(kind)
	if build_cost <= 0:
		return
	_placing_building = true
	_pending_target_skill = ""
	_build_menu_open = false
	_placing_kind = kind
	_placing_cost = build_cost
	_placement_preview.visible = true
	_update_placement_preview()
	_refresh_hint_label()

func _cancel_building_placement() -> void:
	_placing_building = false
	_placing_kind = ""
	_placing_cost = 0
	_placement_can_place = false
	if _placement_preview != null:
		_placement_preview.visible = false
	_refresh_hint_label()

func _create_placement_preview() -> void:
	_placement_preview = MeshInstance3D.new()
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = 1.35
	mesh.bottom_radius = 1.35
	mesh.height = 0.08
	_placement_preview.mesh = mesh

	_placement_preview_material = StandardMaterial3D.new()
	_placement_preview_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_placement_preview_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_placement_preview_material.albedo_color = Color(0.15, 0.95, 0.3, 0.35)
	_placement_preview.material_override = _placement_preview_material
	_placement_preview.visible = false
	add_child(_placement_preview)

func _update_placement_preview() -> void:
	var screen_pos: Vector2 = get_viewport().get_mouse_position()
	_update_placement_preview_from_screen(screen_pos)

func _update_placement_preview_from_screen(screen_pos: Vector2) -> void:
	var point: Variant = _ground_point_from_screen(screen_pos)
	if point == null:
		_placement_preview.visible = false
		_placement_can_place = false
		return

	var raw_position: Vector3 = point as Vector3
	var snapped: Vector3 = Vector3(roundf(raw_position.x * 2.0) * 0.5, 0.04, roundf(raw_position.z * 2.0) * 0.5)
	_placement_current_position = snapped

	var is_valid_spot: bool = _is_build_spot_valid(snapped)
	var can_afford: bool = _minerals >= _placing_cost
	_placement_can_place = is_valid_spot and can_afford

	_placement_preview.visible = true
	_placement_preview.global_position = snapped
	if _placement_can_place:
		_placement_preview_material.albedo_color = Color(0.15, 0.95, 0.3, 0.35)
	else:
		_placement_preview_material.albedo_color = Color(0.95, 0.2, 0.2, 0.35)

func _try_place_building(screen_pos: Vector2) -> void:
	_update_placement_preview_from_screen(screen_pos)
	_confirm_building_placement()

func _confirm_building_placement() -> void:
	if not _placement_can_place:
		return
	if not try_spend_minerals(_placing_cost):
		return

	var instance: Node = BUILDING_SCENE.instantiate()
	var building: Node3D = instance as Node3D
	if building == null:
		add_minerals(_placing_cost)
		return

	if _buildings_root != null:
		_buildings_root.add_child(building)
	else:
		add_child(building)

	building.global_position = Vector3(_placement_current_position.x, 0.0, _placement_current_position.z)
	if building.has_method("configure_by_kind"):
		building.call("configure_by_kind", _placing_kind)
	elif _placing_kind == "barracks" and building.has_method("configure_as_barracks"):
		building.call("configure_as_barracks")
	elif _placing_kind == "tower" and building.has_method("configure_as_tower"):
		building.call("configure_as_tower")

	_register_building(building)
	_request_navmesh_rebake("building_placed")
	_cancel_building_placement()

func _is_build_spot_valid(world_pos: Vector3) -> bool:
	if absf(world_pos.x) > 56.0 or absf(world_pos.z) > 56.0:
		return false

	var building_nodes: Array[Node] = get_tree().get_nodes_in_group("selectable_building")
	for node in building_nodes:
		var building: Node3D = node as Node3D
		if building == null:
			continue
		if world_pos.distance_to(building.global_position) < BUILDING_BLOCK_RADIUS:
			return false

	var resource_nodes: Array[Node] = get_tree().get_nodes_in_group("resource_node")
	for node in resource_nodes:
		var resource: Node3D = node as Node3D
		if resource == null:
			continue
		if world_pos.distance_to(resource.global_position) < RESOURCE_BLOCK_RADIUS:
			return false

	return true

func _register_existing_buildings() -> void:
	var building_nodes: Array[Node] = get_tree().get_nodes_in_group("selectable_building")
	for node in building_nodes:
		_register_building(node)

func _register_existing_resources() -> void:
	var resource_nodes: Array[Node] = get_tree().get_nodes_in_group("resource_node")
	for node in resource_nodes:
		_track_navigation_dynamic_node(node)

func _register_building(building_node: Node) -> void:
	if building_node == null:
		return
	_track_navigation_dynamic_node(building_node)
	if not building_node.has_signal("production_finished"):
		return
	var callback: Callable = Callable(self, "_on_building_production_finished").bind(building_node)
	if not building_node.is_connected("production_finished", callback):
		building_node.connect("production_finished", callback)

func _track_navigation_dynamic_node(nav_node: Node) -> void:
	if nav_node == null:
		return
	var callback: Callable = Callable(self, "_on_navigation_dynamic_node_exited").bind(nav_node)
	if not nav_node.is_connected("tree_exited", callback):
		nav_node.connect("tree_exited", callback)

func _on_navigation_dynamic_node_exited(_node: Node) -> void:
	_request_navmesh_rebake("dynamic_obstacle_removed")

func _setup_runtime_navigation_baking() -> void:
	if not nav_rebake_on_runtime:
		return
	if _nav_region == null:
		return
	if not is_in_group(str(NAV_SOURCE_GROUP)):
		add_to_group(str(NAV_SOURCE_GROUP))
	var nav_mesh: NavigationMesh = _nav_region.navigation_mesh
	if nav_mesh == null:
		nav_mesh = NavigationMesh.new()
		_nav_region.navigation_mesh = nav_mesh
	nav_mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nav_mesh.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_GROUPS_WITH_CHILDREN
	nav_mesh.geometry_source_group_name = NAV_SOURCE_GROUP
	var callback: Callable = Callable(self, "_on_nav_region_bake_finished")
	if not _nav_region.is_connected("bake_finished", callback):
		_nav_region.connect("bake_finished", callback)

func _request_navmesh_rebake(_reason: String = "") -> void:
	if not nav_rebake_on_runtime:
		return
	if _nav_region == null:
		return
	if _nav_region.navigation_mesh == null:
		return
	if _nav_rebake_in_progress or _nav_region.is_baking():
		_nav_rebake_pending = true
		return
	_nav_rebake_in_progress = true
	_nav_region.bake_navigation_mesh(nav_rebake_on_thread)

func _on_nav_region_bake_finished() -> void:
	_nav_rebake_in_progress = false
	if not _nav_rebake_pending:
		return
	_nav_rebake_pending = false
	_request_navmesh_rebake("queued")

func _on_building_production_finished(unit_kind: String, spawn_position: Vector3, source_building: Node = null) -> void:
	_spawn_unit(unit_kind, spawn_position, source_building)

func _spawn_unit(unit_kind: String, spawn_position: Vector3, source_building: Node = null) -> void:
	if _units_root == null:
		return

	var instance: Node = UNIT_SCENE.instantiate()
	var unit: CharacterBody3D = instance as CharacterBody3D
	if unit == null:
		return

	var is_worker: bool = unit_kind == "worker"
	if source_building != null and source_building.has_method("get_team_id"):
		unit.set("team_id", int(source_building.call("get_team_id")))
	if unit.has_method("set_worker_role"):
		unit.call("set_worker_role", is_worker)
	else:
		unit.set("is_worker", is_worker)
	_units_root.add_child(unit)
	unit.global_position = _find_open_spawn_position(spawn_position)

func _find_open_spawn_position(origin: Vector3) -> Vector3:
	for ring in 4:
		var radius: float = 1.6 + float(ring) * 1.0
		for step in 8:
			var angle: float = TAU * float(step) / 8.0
			var candidate: Vector3 = origin + Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
			if _is_spawn_position_free(candidate):
				return candidate
	return origin

func _is_spawn_position_free(candidate: Vector3) -> bool:
	var units: Array[Node] = get_tree().get_nodes_in_group("selectable_unit")
	for node in units:
		var unit: Node3D = node as Node3D
		if unit == null:
			continue
		if candidate.distance_to(unit.global_position) < 1.2:
			return false

	var buildings: Array[Node] = get_tree().get_nodes_in_group("selectable_building")
	for node in buildings:
		var building: Node3D = node as Node3D
		if building == null:
			continue
		if candidate.distance_to(building.global_position) < 2.4:
			return false

	var resources: Array[Node] = get_tree().get_nodes_in_group("resource_node")
	for node in resources:
		var resource: Node3D = node as Node3D
		if resource == null:
			continue
		if candidate.distance_to(resource.global_position) < 2.0:
			return false

	return true

func _ground_point_from_screen(screen_pos: Vector2) -> Variant:
	var origin: Vector3 = _camera.project_ray_origin(screen_pos)
	var normal: Vector3 = _camera.project_ray_normal(screen_pos)
	var plane: Plane = Plane(Vector3.UP, 0.0)
	var intersection: Variant = plane.intersects_ray(origin, normal)
	if intersection == null:
		return null
	return intersection

func _raycast_from_screen(screen_pos: Vector2) -> Dictionary:
	var origin: Vector3 = _camera.project_ray_origin(screen_pos)
	var normal: Vector3 = _camera.project_ray_normal(screen_pos)
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(origin, origin + normal * 4000.0)
	query.collide_with_areas = true
	return get_world_3d().direct_space_state.intersect_ray(query)

func _add_selected_unit(unit: Node) -> void:
	if not _is_player_owned(unit):
		return
	if _selected_units.has(unit):
		return
	_selected_units.append(unit)
	if unit.has_method("set_selected"):
		unit.call("set_selected", true)

func _add_selected_building(building: Node) -> void:
	if not _is_player_owned(building):
		return
	if _selected_buildings.has(building):
		return
	_selected_buildings.append(building)
	if building.has_method("set_selected"):
		building.call("set_selected", true)

func _clear_selection() -> void:
	for node in _selected_units:
		if node != null and is_instance_valid(node) and node.has_method("set_selected"):
			node.call("set_selected", false)
	for node in _selected_buildings:
		if node != null and is_instance_valid(node) and node.has_method("set_selected"):
			node.call("set_selected", false)
	_selected_units.clear()
	_selected_buildings.clear()
	_build_menu_open = false
	_pending_target_skill = ""
