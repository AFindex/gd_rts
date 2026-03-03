extends Node3D

const UNIT_SCENE: PackedScene = preload("res://scenes/units/unit.tscn")
const BUILDING_SCENE: PackedScene = preload("res://scenes/buildings/building.tscn")
const RTS_CATALOG: Script = preload("res://scripts/core/rts_catalog.gd")

const BARRACKS_COST: int = 160
const WORKER_COST: int = 50
const SOLDIER_COST: int = 70
const TOWER_COST: int = 120
const SUPPLY_CAP: int = 40
const HUD_MULTI_MAX: int = 24
const BUILDING_BLOCK_RADIUS: float = 3.8
const RESOURCE_BLOCK_RADIUS: float = 3.2
const PLAYER_TEAM_ID: int = 1

@export var camera_path: NodePath
@export var units_root_path: NodePath
@export var buildings_root_path: NodePath
@export var selection_overlay_path: NodePath
@export var hud_path: NodePath

var _camera: Camera3D
var _units_root: Node3D
var _buildings_root: Node3D
var _selection_overlay: Control
var _hud: Control

var _dragging: bool = false
var _drag_start: Vector2 = Vector2.ZERO
var _selected_units: Array[Node] = []
var _selected_buildings: Array[Node] = []

var _minerals: int = 220
var _worker_cost: int = WORKER_COST
var _soldier_cost: int = SOLDIER_COST
var _barracks_cost: int = BARRACKS_COST
var _tower_cost: int = TOWER_COST

var _placing_building: bool = false
var _placing_kind: String = ""
var _placing_cost: int = 0
var _placement_current_position: Vector3 = Vector3.ZERO
var _placement_can_place: bool = false
var _placement_preview: MeshInstance3D
var _placement_preview_material: StandardMaterial3D

var _pending_target_skill: String = ""
var _build_menu_open: bool = false

var _hint_refresh_accum: float = 0.0

func _ready() -> void:
	add_to_group("game_manager")
	_camera = get_node_or_null(camera_path) as Camera3D
	_units_root = get_node_or_null(units_root_path) as Node3D
	_buildings_root = get_node_or_null(buildings_root_path) as Node3D
	_selection_overlay = get_node_or_null(selection_overlay_path) as Control
	_hud = get_node_or_null(hud_path) as Control
	_apply_runtime_config()
	_connect_hud_signals()
	_create_placement_preview()
	_register_existing_buildings()
	_refresh_resource_label()
	_refresh_hint_label()

func _apply_runtime_config() -> void:
	var worker_def: Dictionary = RTS_CATALOG.get_unit_def("worker")
	var soldier_def: Dictionary = RTS_CATALOG.get_unit_def("soldier")
	var barracks_def: Dictionary = RTS_CATALOG.get_building_def("barracks")
	var tower_def: Dictionary = RTS_CATALOG.get_building_def("tower")
	_worker_cost = int(worker_def.get("cost", WORKER_COST))
	_soldier_cost = int(soldier_def.get("cost", SOLDIER_COST))
	_barracks_cost = int(barracks_def.get("cost", BARRACKS_COST))
	_tower_cost = int(tower_def.get("cost", TOWER_COST))

func _connect_hud_signals() -> void:
	if _hud == null or not _hud.has_signal("command_pressed"):
		return
	var callback: Callable = Callable(self, "_on_hud_command_pressed")
	if not _hud.is_connected("command_pressed", callback):
		_hud.connect("command_pressed", callback)

func _process(delta: float) -> void:
	if _placing_building:
		_update_placement_preview()

	_hint_refresh_accum += delta
	if _hint_refresh_accum >= 0.2:
		_hint_refresh_accum = 0.0
		_refresh_hint_label()

func _input(event: InputEvent) -> void:
	if _camera == null:
		return

	var mouse_button: InputEventMouseButton = event as InputEventMouseButton
	if mouse_button != null and mouse_button.button_index == MOUSE_BUTTON_LEFT:
		if mouse_button.pressed:
			if _pending_target_skill != "":
				if _pick_ui_control(mouse_button.position) != null:
					return
				if _try_execute_pending_target_skill(mouse_button.position):
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
			KEY_Q:
				if _build_menu_open:
					_execute_command("build_barracks")
					return
			KEY_W:
				if _build_menu_open:
					_execute_command("build_tower")
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
		_issue_context_command(mouse_button.position)

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
			single_detail = "Role: %s\nState: %s\nHP: %s" % [unit_role, unit_state, unit_hp_text]
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
	var top_legacy_text: String = "M: %d   G: 0   Supply: %d/%d" % [_minerals, total_units, SUPPLY_CAP]

	return {
		"minerals": _minerals,
		"gas": 0,
		"supply_used": total_units,
		"supply_cap": SUPPLY_CAP,
		"top_legacy_text": top_legacy_text,
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

func _build_selection_hint(selected_worker_count: int, selected_soldier_count: int, selected_building_count: int, queue_size: int) -> String:
	if _placing_building:
		var placement_state: String = "Valid" if _placement_can_place else "Invalid"
		return "Placing Barracks (%d): %s | LMB Confirm, RMB/ESC Cancel" % [_placing_cost, placement_state]
	if _build_menu_open:
		return "Build Menu: Q Barracks (%d), W Tower (%d, disabled), ESC Back" % [_barracks_cost, _tower_cost]
	if _pending_target_skill != "":
		var skill_info: Dictionary = RTS_CATALOG.get_skill_def(_pending_target_skill)
		var skill_label: String = str(skill_info.get("label", _pending_target_skill.capitalize()))
		var target_mode: String = str(skill_info.get("target_mode", "none"))
		if target_mode == "resource":
			return "Targeting %s | Left Click Resource | RMB/ESC Cancel" % skill_label
		if target_mode == "ground":
			return "Targeting %s | Left Click Ground | RMB/ESC Cancel" % skill_label
		if target_mode == "unit_or_building":
			return "Targeting %s | Left Click Enemy Unit/Building | RMB/ESC Cancel" % skill_label
		return "Targeting %s | RMB/ESC Cancel" % skill_label
	if _selected_units.is_empty() and _selected_buildings.is_empty():
		return "No selection | B: Build Menu | Left drag: Box Select | RMB: Move/Gather"
	if _selected_buildings.size() == 1 and _selected_units.is_empty():
		return "Selected Building: %d queue item(s) | R/T: Train by building type" % queue_size
	return "Selected -> Worker %d | Soldier %d | Building %d" % [selected_worker_count, selected_soldier_count, selected_building_count]

func _build_subgroup_text(mode: String, selection_total: int) -> String:
	if mode == "multi":
		return "Subgroup: %d Units" % selection_total
	if mode == "single":
		return "Subgroup: Single"
	return "Subgroup: None"

func _build_command_hint() -> String:
	if _placing_building:
		return "Placement mode active. Use mouse or command card to confirm/cancel."
	if _build_menu_open:
		return "Build menu open. Select a building option or press ESC to close."
	if _pending_target_skill != "":
		return "Targeted skill armed. Left click world target, RMB/ESC to cancel."
	if _selected_buildings.size() == 1 and _selected_units.is_empty():
		return "Click command cards or use hotkeys for production/build commands."
	if not _selected_units.is_empty():
		return "RMB context command or click move/gather/stop in command card."
	return "Select something to open context commands."

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
			entries.append(_command_entry("build_barracks", {
				"enabled": _can_start_barracks_build(),
				"cost_text": str(_barracks_cost),
				"disabled_reason": _barracks_block_reason()
			}))
			entries.append(_command_entry("build_tower", {
				"enabled": false,
				"cost_text": str(_tower_cost),
				"disabled_reason": "Tower scene is not implemented yet."
			}))
			entries.append(_command_entry("close_menu"))
			return entries

	if _selected_buildings.size() == 1 and _selected_units.is_empty():
		var selected_building: Node = _selected_buildings[0]
		if selected_building != null:
			var can_train_worker: bool = bool(selected_building.call("can_queue_worker_unit")) if selected_building.has_method("can_queue_worker_unit") else false
			var can_train_soldier: bool = bool(selected_building.call("can_queue_soldier_unit")) if selected_building.has_method("can_queue_soldier_unit") else false
			if can_train_worker:
				entries.append(_command_entry("train_worker", {
					"enabled": _minerals >= _worker_cost,
					"cost_text": str(_worker_cost)
				}))
			if can_train_soldier:
				entries.append(_command_entry("train_soldier", {
					"enabled": _minerals >= _soldier_cost,
					"cost_text": str(_soldier_cost)
				}))
		entries.append(_command_entry("build_menu"))
		return entries

	if not _selected_units.is_empty():
		entries.append(_command_entry("move"))
		if _selection_has_worker():
			entries.append(_command_entry("gather"))
			var has_worker_cargo: bool = _selection_has_worker_cargo()
			entries.append(_command_entry("return_resource", {
				"enabled": has_worker_cargo,
				"disabled_reason": "" if has_worker_cargo else "Selected workers are not carrying minerals."
			}))
		entries.append(_command_entry("build_menu", {
			"enabled": _selection_has_worker(),
			"disabled_reason": "" if _selection_has_worker() else "Requires at least one worker in selection."
		}))
		entries.append(_command_entry("stop"))
		if _selection_has_combat_unit():
			entries.append(_command_entry("attack"))
		return entries

	entries.append(_command_entry("build_menu"))
	entries.append(_command_entry("menu"))
	return entries

func _command_entry(skill_id: String, overrides: Dictionary = {}) -> Dictionary:
	return RTS_CATALOG.make_command_entry(skill_id, overrides)

func _build_notifications() -> Array[String]:
	var lines: Array[String] = [
		"B: Build Menu | Q: Barracks (%d) | W: Tower (%d)" % [_barracks_cost, _tower_cost],
		"R: Train Worker (%d) | T: Train Soldier (%d) | A: Attack | S: Stop" % [_worker_cost, _soldier_cost],
		"Shift + Left Click: Additive Selection | Command cards are clickable"
	]
	if _placing_building:
		var state: String = "valid" if _placement_can_place else "invalid"
		lines[0] = "Placement %s | Cost: %d Minerals" % [state, _placing_cost]
	elif _build_menu_open:
		lines[0] = "Build menu active | Q: Barracks | W: Tower (disabled) | ESC: Back"
	elif _pending_target_skill != "":
		var skill_info: Dictionary = RTS_CATALOG.get_skill_def(_pending_target_skill)
		lines[0] = "Targeting: %s" % str(skill_info.get("label", _pending_target_skill))
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
	if not _selected_units.is_empty():
		return _selection_has_worker()
	if _selected_buildings.size() == 1 and _selected_units.is_empty():
		return true
	return true

func _can_start_barracks_build() -> bool:
	if not _selected_units.is_empty() and not _selection_has_worker():
		return false
	return _minerals >= _barracks_cost

func _barracks_block_reason() -> String:
	if not _selected_units.is_empty() and not _selection_has_worker():
		return "Requires at least one worker in selection."
	if _minerals < _barracks_cost:
		return "Not enough minerals."
	return ""

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
		"build_barracks":
			if not _can_start_barracks_build():
				return
			_build_menu_open = false
			_start_building_placement("barracks")
		"build_tower":
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
			_issue_return_command()
		"stop":
			_issue_stop_command()
		"menu":
			pass
		_:
			return
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

func _try_execute_pending_target_skill(screen_pos: Vector2) -> bool:
	match _pending_target_skill:
		"move":
			_issue_move_command(screen_pos)
			return true
		"gather":
			var ray_result: Dictionary = _raycast_from_screen(screen_pos)
			if ray_result.is_empty():
				return false
			var collider: Node = ray_result.get("collider") as Node
			if collider == null or not collider.is_in_group("resource_node"):
				return false
			_issue_gather_command(collider as Node3D, screen_pos)
			return true
		"attack":
			var ray_result: Dictionary = _raycast_from_screen(screen_pos)
			if ray_result.is_empty():
				return false
			var collider: Node = ray_result.get("collider") as Node
			if collider == null:
				return false
			if not _is_attackable_enemy(collider):
				return false
			_issue_attack_command(collider as Node3D, screen_pos)
			return true
		_:
			return false

func _issue_context_command(screen_pos: Vector2) -> void:
	_prune_invalid_selection()
	_build_menu_open = false
	if _selected_units.is_empty():
		return

	var ray_result: Dictionary = _raycast_from_screen(screen_pos)
	if not ray_result.is_empty():
		var collider: Node = ray_result.get("collider") as Node
		if collider != null and collider.is_in_group("resource_node"):
			_issue_gather_command(collider as Node3D, screen_pos)
			return
		if collider != null and _is_attackable_enemy(collider):
			_issue_attack_command(collider as Node3D, screen_pos)
			return

	_issue_move_command(screen_pos)

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

func _issue_gather_command(resource_node: Node3D, fallback_screen_pos: Vector2) -> void:
	if resource_node == null:
		return

	var dropoff: Node3D = _nearest_dropoff(resource_node.global_position)
	if dropoff == null:
		_issue_move_command(fallback_screen_pos)
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
			unit_node.call("command_gather", resource_node, dropoff)
			issued_count += 1

	if issued_count == 0:
		_issue_move_command(fallback_screen_pos)

func _issue_attack_command(target_node: Node3D, fallback_screen_pos: Vector2) -> void:
	if target_node == null or not is_instance_valid(target_node):
		return
	var issued_count: int = 0
	for unit_node in _selected_units:
		if unit_node == null or not is_instance_valid(unit_node):
			continue
		if not _is_player_owned(unit_node):
			continue
		if not unit_node.has_method("command_attack"):
			continue
		var issued_variant: Variant = unit_node.call("command_attack", target_node)
		if bool(issued_variant):
			issued_count += 1
	if issued_count == 0:
		_issue_move_command(fallback_screen_pos)

func _issue_move_command(screen_pos: Vector2) -> void:
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
		if unit.has_method("command_move"):
			unit.call("command_move", target_point + offset)
		elif unit.has_method("move_to"):
			unit.call("move_to", target_point + offset)

func _issue_stop_command() -> void:
	for unit_node in _selected_units:
		if unit_node == null or not is_instance_valid(unit_node):
			continue
		if not _is_player_owned(unit_node):
			continue
		if unit_node.has_method("command_stop"):
			unit_node.call("command_stop")

func _issue_return_command() -> void:
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
		if unit_node.has_method("command_return_to_dropoff"):
			unit_node.call("command_return_to_dropoff", dropoff)

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
	if kind != "barracks":
		return
	_placing_building = true
	_pending_target_skill = ""
	_build_menu_open = false
	_placing_kind = kind
	_placing_cost = _barracks_cost
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
	if _placing_kind == "barracks" and building.has_method("configure_as_barracks"):
		building.call("configure_as_barracks")

	_register_building(building)
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

func _register_building(building_node: Node) -> void:
	if building_node == null:
		return
	if not building_node.has_signal("production_finished"):
		return
	var callback: Callable = Callable(self, "_on_building_production_finished").bind(building_node)
	if not building_node.is_connected("production_finished", callback):
		building_node.connect("production_finished", callback)

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
