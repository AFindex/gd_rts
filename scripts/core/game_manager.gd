extends Node3D

const UNIT_SCENE: PackedScene = preload("res://scenes/units/unit.tscn")
const BUILDING_SCENE: PackedScene = preload("res://scenes/buildings/building.tscn")
const RTS_CATALOG: Script = preload("res://scripts/core/rts_catalog.gd")
const RTS_COMMAND: Script = preload("res://scripts/core/rts_command.gd")
const BUILD_PLACEMENT_GRID_SCRIPT: Script = preload("res://scripts/core/build_placement_grid.gd")

const WORKER_COST: int = 50
const SOLDIER_COST: int = 70
const SUPPLY_CAP: int = 40
const HUD_MULTI_MAX: int = 30
const DEFAULT_BUILD_FOOTPRINT: Vector2 = Vector2(2.6, 1.8)
const PLAYER_TEAM_ID: int = 1
const DEFAULT_TEAM_START_MINERALS: int = 220
const NAV_SOURCE_GROUP: StringName = &"navmesh_runtime_source"
const QUEUE_MARKER_GROUP: StringName = &"command_queue_marker"
const QUEUE_MARKER_LAYER: int = 1 << 5
const QUEUE_MARKER_MAX_VISIBLE: int = 32
const QUEUE_LINK_HEIGHT: float = 0.2
const PATH_VISUAL_RENDER_PRIORITY: int = 127
const SMART_COMMAND_PRIORITY_RANGE: float = 0.5
const DEFAULT_WORKER_BUILD_TIME: float = 2.5
const BUILD_ORDER_START_DISTANCE: float = 1.4
const BUILD_ORDER_MOVE_REFRESH: float = 0.45
const BUILD_ORDER_FOOTPRINT_EXIT_PADDING: float = 0.9
const BUILD_ORDER_FOOTPRINT_INSIDE_EPSILON: float = 0.06
const PENDING_BUILD_FOOTPRINT_EXPAND_SCALE: float = 1.1
const BUILD_ORDER_CLEAR_ZONE_TIMEOUT: float = 7.5
const CONSTRUCTION_GHOST_RETRY_INTERVAL: float = 3.0
const CONSTRUCTION_GHOST_FLOAT_AMPLITUDE: float = 0.08
const CONSTRUCTION_GHOST_FLOAT_SPEED: float = 2.4
const RALLY_MAX_HOPS: int = 3
const RALLY_VISUAL_HEIGHT: float = 0.08
const RALLY_ALERT_BLINK_INTERVAL_SEC: float = 0.16
const FEEDBACK_TONE_SAMPLE_RATE: int = 22050
const CONTROL_GROUP_COUNT: int = 10
const CONTROL_GROUP_DOUBLE_TAP_WINDOW: float = 0.3
const SELECTION_DOUBLE_CLICK_WINDOW: float = 0.3
const CONTROL_GROUP_MARKER_GROUP: StringName = &"control_group_marker"
const CONTROL_GROUP_MARKER_DURATION: float = 0.9
const PING_DURATION: float = 1.6
const PING_VISUAL_HEIGHT: float = 0.1
const ATTACK_PING_CHECK_INTERVAL: float = 0.35
const ATTACK_PING_PER_BUILDING_COOLDOWN: float = 4.0
const BUILD_MENU_GROUP_ROOT: String = "root"
const BUILD_MENU_GROUP_GARRISONED: String = "garrisoned"
const BUILD_MENU_GROUP_SUMMONING: String = "summoning"
const BUILD_MENU_GROUP_INCORPORATED: String = "incorporated"

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
@export var debug_selection_hud_logs: bool = false
@export var debug_selection_hud_verbose: bool = false
@export var debug_selection_hud_max_entries: int = 8
@export var debug_selection_log_burst_only: bool = true
@export var debug_selection_log_burst_seconds: float = 1.0
@export var minimap_update_interval: float = 0.05

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
var _hovered_unit: Node = null

var _minerals: int = 220
var _team_minerals: Dictionary = {}
var _worker_cost: int = WORKER_COST
var _soldier_cost: int = SOLDIER_COST

var _placing_building: bool = false
var _placing_kind: String = ""
var _placing_skill_id: String = ""
var _placing_cost: int = 0
var _placement_current_position: Vector3 = Vector3.ZERO
var _placement_can_place: bool = false
var _placement_preview: MeshInstance3D
var _placement_preview_material: StandardMaterial3D
var _placement_rotation_y: float = 0.0
var _placement_footprint: Vector2 = DEFAULT_BUILD_FOOTPRINT
var _build_placement_grid = null

var _pending_target_skill: String = ""
var _build_menu_open: bool = false
var _build_menu_group: String = BUILD_MENU_GROUP_ROOT
var _input_state: int = InputState.IDLE
var _execution_queue: Array[Dictionary] = []

var _hint_refresh_accum: float = 0.0
var _minimap_update_accum: float = 0.0
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
var _queue_visual_root: Node3D
var _queue_visible_marker_nodes: Array[Node] = []
var _queue_reject_feedback_timer: float = 0.0
var _last_queue_visual_signature: String = ""
var _ping_visual_root: Node3D
var _active_pings: Array[Dictionary] = []
var _ping_targeting_active: bool = false
var _attack_ping_check_accum: float = 0.0
var _building_health_snapshot: Dictionary = {}
var _building_attack_ping_cooldowns: Dictionary = {}
var _construction_ghost_visual_root: Node3D
var _pending_construction_ghosts: Array[Dictionary] = []
var _next_construction_ghost_id: int = 1
var _rally_visual_root: Node3D
var _rally_visible_nodes: Array[Node] = []
var _last_rally_visual_signature: String = ""
var _rally_reject_feedback_timer: float = 0.0
var _feedback_audio_player: AudioStreamPlayer
var _feedback_tone_streams: Dictionary = {}
var _control_groups: Dictionary = {}
var _last_selected_group_id: int = -1
var _last_selected_group_time: float = -100.0
var _active_subgroup_index: int = -1
var _multi_matrix_page_index: int = 0
var _last_click_unit_kind: String = ""
var _last_click_time_sec: float = -100.0
var _ui_notice_text: String = ""
var _ui_notice_timer: float = 0.0
var _pending_build_orders: Array[Dictionary] = []
var _pending_construction_resume_orders: Array[Dictionary] = []
var _debug_hud_push_seq: int = 0
var _debug_selection_seq: int = 0
var _debug_log_burst_until_msec: float = 0.0

func _t(message: String) -> String:
	return tr(message)

func _tf(message: String, args: Array = []) -> String:
	var translated: String = _t(message)
	if args.is_empty():
		return translated
	return translated % args

func _ready() -> void:
	add_to_group("game_manager")
	TranslationServer.set_locale("zh_CN")
	_camera = get_node_or_null(camera_path) as Camera3D
	_units_root = get_node_or_null(units_root_path) as Node3D
	_buildings_root = get_node_or_null(buildings_root_path) as Node3D
	_selection_overlay = get_node_or_null(selection_overlay_path) as Control
	_hud = get_node_or_null(hud_path) as Control
	_nav_region = get_node_or_null(nav_region_path) as NavigationRegion3D
	_apply_runtime_config()
	_connect_hud_signals()
	_create_placement_preview()
	_setup_build_placement_grid()
	_setup_queue_visual_root()
	_setup_ping_visual_root()
	_setup_construction_ghost_visual_root()
	_setup_rally_visual_root()
	_setup_feedback_audio()
	_setup_runtime_navigation_baking()
	_register_existing_buildings()
	_refresh_building_health_snapshot()
	_register_existing_resources()
	_init_team_minerals()
	_request_navmesh_rebake("startup")
	_refresh_resource_label()
	_refresh_hint_label()
	_push_minimap_update()
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
	if _hud == null:
		return
	if _hud.has_signal("command_pressed"):
		var callback: Callable = Callable(self , "_on_hud_command_pressed")
		if not _hud.is_connected("command_pressed", callback):
			_hud.connect("command_pressed", callback)
	if _hud.has_signal("multi_role_cell_pressed"):
		var subgroup_callback: Callable = Callable(self , "_on_hud_multi_role_cell_pressed")
		if not _hud.is_connected("multi_role_cell_pressed", subgroup_callback):
			_hud.connect("multi_role_cell_pressed", subgroup_callback)
	if _hud.has_signal("control_group_pressed"):
		var control_group_callback: Callable = Callable(self , "_on_hud_control_group_pressed")
		if not _hud.is_connected("control_group_pressed", control_group_callback):
			_hud.connect("control_group_pressed", control_group_callback)
	if _hud.has_signal("matrix_page_selected"):
		var matrix_page_callback: Callable = Callable(self , "_on_hud_matrix_page_selected")
		if not _hud.is_connected("matrix_page_selected", matrix_page_callback):
			_hud.connect("matrix_page_selected", matrix_page_callback)
	if _hud.has_signal("minimap_navigate_requested"):
		var minimap_nav_callback: Callable = Callable(self, "_on_hud_minimap_navigate_requested")
		if not _hud.is_connected("minimap_navigate_requested", minimap_nav_callback):
			_hud.connect("minimap_navigate_requested", minimap_nav_callback)
	if _hud.has_signal("ping_button_pressed"):
		var ping_button_callback: Callable = Callable(self, "_on_hud_ping_button_pressed")
		if not _hud.is_connected("ping_button_pressed", ping_button_callback):
			_hud.connect("ping_button_pressed", ping_button_callback)
	if _hud.has_signal("ping_requested"):
		var ping_requested_callback: Callable = Callable(self, "_on_hud_ping_requested")
		if not _hud.is_connected("ping_requested", ping_requested_callback):
			_hud.connect("ping_requested", ping_requested_callback)

func _process(delta: float) -> void:
	_drain_execution_queue()
	_process_queue_feedback(delta)
	_process_pending_build_orders(delta)
	_process_pending_construction_resume_orders(delta)
	_process_pending_construction_ghosts(delta)
	if _placing_building:
		_update_placement_preview()
	_update_hovered_unit_from_mouse()

	_process_match_rules(delta)
	_process_active_research(delta)
	_refresh_input_state()
	_update_queue_visuals()
	_process_ping_visuals(delta)
	_process_under_attack_pings(delta)
	_update_rally_visuals()
	_process_minimap_update(delta)

	_hint_refresh_accum += delta
	if _hint_refresh_accum >= 0.2:
		_hint_refresh_accum = 0.0
		_refresh_hint_label()

func _process_active_research(_delta: float) -> void:
	_active_research.clear()
	var buildings: Array[Node] = get_tree().get_nodes_in_group("selectable_building")
	for building_node in buildings:
		if building_node == null or not is_instance_valid(building_node):
			continue
		if not _is_player_owned(building_node):
			continue
		if not building_node.has_method("get_active_research_info"):
			continue
		var info_value: Variant = building_node.call("get_active_research_info")
		if not (info_value is Dictionary):
			continue
		var info: Dictionary = info_value as Dictionary
		var tech_id: String = str(info.get("tech_id", "")).strip_edges()
		if tech_id == "":
			continue
		if has_tech(tech_id):
			continue
		var total: float = maxf(0.01, float(info.get("total", 0.01)))
		var remaining: float = clampf(float(info.get("remaining", total)), 0.0, total)
		_active_research[tech_id] = {
			"remaining": remaining,
			"total": total,
			"building_path": building_node.get_path()
		}

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
		notice = _tf("Match outcome triggered: %s", [_match_outcome_rule_id])
	_match_notice = notice
	_refresh_hint_label()
	if not _match_notify_only:
		_pending_target_skill = ""
		_close_build_menu()

func _input(event: InputEvent) -> void:
	if _camera == null:
		return

	var mouse_button: InputEventMouseButton = event as InputEventMouseButton
	if mouse_button != null and mouse_button.button_index == MOUSE_BUTTON_LEFT:
		if mouse_button.pressed:
			var ui_control: Control = _pick_ui_control(mouse_button.position)
			_gmhud_log("LMB down pos=%s shift=%s ctrl=%s alt=%s state=%s dragging=%s ui_pick=%s" % [
				str(mouse_button.position),
				str(Input.is_key_pressed(KEY_SHIFT)),
				str(Input.is_key_pressed(KEY_CTRL)),
				str(Input.is_key_pressed(KEY_ALT)),
				_input_state_label(),
				str(_dragging),
				_ui_control_debug_name(ui_control)
			], true)
			if _ping_targeting_active:
				if ui_control != null:
					# Let minimap/UI handle click when ping mode is active.
					return
				var ping_world_value: Variant = _ground_point_from_screen(mouse_button.position)
				if not (ping_world_value is Vector3):
					return
				_emit_ping(ping_world_value as Vector3)
				_set_ping_mode_active(false)
				_refresh_hint_label()
				return
			if Input.is_key_pressed(KEY_ALT):
				if _try_remove_queue_marker_at(mouse_button.position):
					_gmhud_log("LMB alt-remove queue marker success at %s" % str(mouse_button.position), true)
					_refresh_hint_label()
					return
			if _pending_target_skill != "":
				if ui_control != null:
					_gmhud_log("LMB down blocked by UI during pending target skill: %s" % _ui_control_debug_name(ui_control), true)
					return
				if _try_execute_pending_target_skill(mouse_button.position, _is_queue_input_active()):
					_pending_target_skill = ""
					_gmhud_log("pending target skill executed from LMB at %s" % str(mouse_button.position), true)
				_refresh_hint_label()
				return
			if _placing_building:
				_gmhud_log("LMB down ignored: placing building active.", true)
				return
			if ui_control != null:
				_gmhud_log("LMB down blocked by UI: %s" % _ui_control_debug_name(ui_control))
				return
			_dragging = true
			_drag_start = mouse_button.position
			_gmhud_log("drag begin start=%s %s" % [str(_drag_start), _selection_counts_text()], true)
			if _selection_overlay != null and _selection_overlay.has_method("begin_drag"):
				_selection_overlay.call("begin_drag", _drag_start)
		else:
			if not _dragging:
				_gmhud_log("LMB up ignored: not dragging.", true)
				return
			var drag_end: Vector2 = mouse_button.position
			var drag_distance: float = _drag_start.distance_to(drag_end)
			var additive: bool = Input.is_key_pressed(KEY_SHIFT)
			var is_box_select: bool = drag_distance >= 8.0
			if is_box_select:
				_begin_selection_debug_log_burst(5.0, "box_select_lmb_up distance=%.2f additive=%s" % [drag_distance, str(additive)])
			_gmhud_log("LMB up end=%s drag_distance=%.2f additive=%s before=%s" % [
				str(drag_end),
				drag_distance,
				str(additive),
				_selection_counts_text()
			])
			if not is_box_select:
				_select_single(drag_end, additive)
			else:
				_select_by_rect(_drag_start, drag_end, additive)
			_dragging = false
			_gmhud_log_selection("after LMB selection")
			if _selection_overlay != null and _selection_overlay.has_method("end_drag"):
				_selection_overlay.call("end_drag")
			_refresh_hint_label()
		return

	var mouse_motion: InputEventMouseMotion = event as InputEventMouseMotion
	if mouse_motion != null and _dragging:
		_gmhud_log("drag update pos=%s start=%s" % [str(mouse_motion.position), str(_drag_start)], true)
		if _selection_overlay != null and _selection_overlay.has_method("update_drag"):
			_selection_overlay.call("update_drag", mouse_motion.position)

func _unhandled_input(event: InputEvent) -> void:
	if _camera == null:
		return

	var key_event: InputEventKey = event as InputEventKey
	if key_event != null and key_event.pressed and not key_event.echo:
		if _try_handle_control_group_hotkey(key_event):
			_refresh_hint_label()
			return
		if key_event.keycode == KEY_TAB:
			_cycle_unit_subgroup()
			_refresh_hint_label()
			return
		if key_event.keycode == KEY_PAGEUP:
			if _cycle_multi_matrix_page(-1):
				_refresh_hint_label()
			return
		if key_event.keycode == KEY_PAGEDOWN:
			if _cycle_multi_matrix_page(1):
				_refresh_hint_label()
			return

		match key_event.keycode:
			KEY_B:
				_execute_command("build_menu")
				return
			KEY_A:
				_execute_command("attack")
				return
			KEY_ESCAPE:
				if _ping_targeting_active:
					_set_ping_mode_active(false)
					_refresh_hint_label()
					return
				if _placing_building:
					_execute_command("placement_cancel")
					return
				if _build_menu_open:
					if _build_menu_group != BUILD_MENU_GROUP_ROOT:
						_execute_command("build_menu_back")
					else:
						_execute_command("close_menu")
					return
				if _pending_target_skill != "":
					_pending_target_skill = ""
					_refresh_hint_label()
					return
				if _selection_has_construction_exit_worker():
					_execute_command("construction_exit")
					return
				if _cancel_pending_construction_for_selected_workers():
					return
			KEY_R:
				if _placing_building:
					_execute_command("placement_rotate")
				else:
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
			_try_place_building(mouse_button.position, _is_queue_input_active())
			return

	if mouse_button != null and mouse_button.button_index == MOUSE_BUTTON_RIGHT and mouse_button.pressed:
		if _ping_targeting_active:
			_set_ping_mode_active(false)
			_refresh_hint_label()
			return
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

func _update_hovered_unit_from_mouse() -> void:
	if _camera == null:
		_set_hovered_unit(null)
		return
	if _dragging:
		_set_hovered_unit(null)
		return
	var viewport: Viewport = get_viewport()
	if viewport == null:
		_set_hovered_unit(null)
		return
	var mouse_pos: Vector2 = viewport.get_mouse_position()
	var hovered_unit: Node = _resolve_hovered_unit_from_screen(mouse_pos)
	_set_hovered_unit(hovered_unit)

func _resolve_hovered_unit_from_screen(screen_pos: Vector2) -> Node:
	var ui_control: Control = _pick_ui_control(screen_pos)
	if ui_control != null:
		return null
	var result: Dictionary = _raycast_from_screen(screen_pos)
	if result.is_empty():
		return null
	var collider: Node = result.get("collider") as Node
	if collider == null:
		return null
	if not collider.is_in_group("selectable_unit"):
		return null
	return collider

func _set_hovered_unit(unit: Node) -> void:
	if _hovered_unit == unit:
		return
	if _hovered_unit != null and is_instance_valid(_hovered_unit) and _hovered_unit.has_method("set_hovered"):
		_hovered_unit.call("set_hovered", false)
	_hovered_unit = unit
	if _hovered_unit != null and is_instance_valid(_hovered_unit) and _hovered_unit.has_method("set_hovered"):
		_hovered_unit.call("set_hovered", true)

func _begin_selection_debug_log_burst(duration_sec: float = -1.0, reason: String = "") -> void:
	var burst_seconds: float = duration_sec if duration_sec > 0.0 else maxf(0.1, debug_selection_log_burst_seconds)
	_debug_log_burst_until_msec = float(Time.get_ticks_msec()) + burst_seconds * 1000.0
	_gmhud_log("begin_selection_debug_log_burst duration=%.2fs reason=%s" % [burst_seconds, reason], false, true)
	if _hud != null and _hud.has_method("begin_debug_log_burst"):
		_hud.call("begin_debug_log_burst", burst_seconds, reason)

func _is_selection_debug_log_burst_active() -> bool:
	return float(Time.get_ticks_msec()) <= _debug_log_burst_until_msec

func _gmhud_log(message: String, verbose_only: bool = false, force: bool = false) -> void:
	if not debug_selection_hud_logs:
		return
	if not force and debug_selection_log_burst_only and not _is_selection_debug_log_burst_active():
		return
	if verbose_only and not debug_selection_hud_verbose:
		return
	var frame: int = Engine.get_process_frames()
	var timestamp_sec: float = float(Time.get_ticks_msec()) / 1000.0
	print("[GMHUD][f=%d][t=%.3f] %s" % [frame, timestamp_sec, message])

func _selection_counts_text() -> String:
	var total: int = _selected_units.size() + _selected_buildings.size()
	return "units=%d buildings=%d total=%d subgroup_index=%d page_index=%d" % [
		_selected_units.size(),
		_selected_buildings.size(),
		total,
		_active_subgroup_index,
		_multi_matrix_page_index
	]

func _multi_entries_preview_text(limit: int = 8) -> String:
	var entries: Array[Dictionary] = _build_multi_role_entries()
	if entries.is_empty():
		return "[]"
	var max_items: int = mini(entries.size(), maxi(0, limit))
	var preview_parts: Array[String] = []
	for i in max_items:
		var entry: Dictionary = entries[i]
		preview_parts.append("%d:%s/%s" % [i, str(entry.get("role", "")), str(entry.get("kind", ""))])
	if entries.size() > max_items:
		preview_parts.append("+%d" % (entries.size() - max_items))
	return "[%s]" % ", ".join(preview_parts)

func _ui_control_debug_name(control: Control) -> String:
	if control == null:
		return "null"
	return "%s(%s mf=%d mod_a=%.2f self_a=%.2f vis=%s)" % [
		control.name,
		control.get_class(),
		control.mouse_filter,
		control.modulate.a,
		control.self_modulate.a,
		str(control.visible)
	]

func _gmhud_log_selection(tag: String, verbose_only: bool = false) -> void:
	if not debug_selection_hud_logs:
		return
	if debug_selection_log_burst_only and not _is_selection_debug_log_burst_active():
		return
	if verbose_only and not debug_selection_hud_verbose:
		return
	_gmhud_log("%s %s active_kind=%s entries=%s" % [
		tag,
		_selection_counts_text(),
		_active_subgroup_kind(),
		_multi_entries_preview_text(debug_selection_hud_max_entries)
	], verbose_only)

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

func _try_handle_control_group_hotkey(key_event: InputEventKey) -> bool:
	var group_id: int = _keycode_to_control_group_id(key_event.keycode)
	if group_id < 0:
		return false
	if key_event.ctrl_pressed:
		_assign_control_group_from_selection(group_id, false)
		return true
	if key_event.shift_pressed:
		_assign_control_group_from_selection(group_id, true)
		return true
	_select_control_group(group_id)
	return true

func _keycode_to_control_group_id(keycode: int) -> int:
	match keycode:
		KEY_0, KEY_KP_0:
			return 0
		KEY_1, KEY_KP_1:
			return 1
		KEY_2, KEY_KP_2:
			return 2
		KEY_3, KEY_KP_3:
			return 3
		KEY_4, KEY_KP_4:
			return 4
		KEY_5, KEY_KP_5:
			return 5
		KEY_6, KEY_KP_6:
			return 6
		KEY_7, KEY_KP_7:
			return 7
		KEY_8, KEY_KP_8:
			return 8
		KEY_9, KEY_KP_9:
			return 9
		_:
			return -1

func _assign_control_group_from_selection(group_id: int, append: bool) -> void:
	_prune_invalid_selection()
	if group_id < 0 or group_id >= CONTROL_GROUP_COUNT:
		return
	if _selected_units.is_empty() and _selected_buildings.is_empty():
		_set_ui_notice(_tf("Control Group %d: no selection.", [group_id]))
		_play_feedback_tone("error")
		return

	var next_entry: Dictionary = {
		"unit_paths": [],
		"building_paths": []
	}
	if append and _control_groups.has(group_id):
		var existing_value: Variant = _control_groups.get(group_id, {})
		if existing_value is Dictionary:
			var existing_entry: Dictionary = existing_value as Dictionary
			var existing_units: Variant = existing_entry.get("unit_paths", [])
			if existing_units is Array:
				next_entry["unit_paths"] = (existing_units as Array).duplicate()
			var existing_buildings: Variant = existing_entry.get("building_paths", [])
			if existing_buildings is Array:
				next_entry["building_paths"] = (existing_buildings as Array).duplicate()

	var unit_paths: Array = next_entry["unit_paths"] as Array
	var building_paths: Array = next_entry["building_paths"] as Array
	var unit_seen: Dictionary = {}
	var building_seen: Dictionary = {}

	for unit_path_value in unit_paths:
		var unit_path_str: String = str(unit_path_value)
		if unit_path_str != "":
			unit_seen[unit_path_str] = true
	for building_path_value in building_paths:
		var building_path_str: String = str(building_path_value)
		if building_path_str != "":
			building_seen[building_path_str] = true

	var added_count: int = 0
	for selected_unit in _selected_units:
		if selected_unit == null or not is_instance_valid(selected_unit):
			continue
		if not _is_player_owned(selected_unit):
			continue
		var path: NodePath = selected_unit.get_path()
		var key: String = str(path)
		if key == "" or unit_seen.has(key):
			continue
		unit_seen[key] = true
		unit_paths.append(path)
		added_count += 1

	for selected_building in _selected_buildings:
		if selected_building == null or not is_instance_valid(selected_building):
			continue
		if not _is_player_owned(selected_building):
			continue
		var path: NodePath = selected_building.get_path()
		var key: String = str(path)
		if key == "" or building_seen.has(key):
			continue
		building_seen[key] = true
		building_paths.append(path)
		added_count += 1

	next_entry["unit_paths"] = unit_paths
	next_entry["building_paths"] = building_paths
	_control_groups[group_id] = next_entry
	_show_control_group_assignment_feedback(group_id, append)

	var total_count: int = unit_paths.size() + building_paths.size()
	if append:
		_set_ui_notice(_tf("Control Group %d appended (+%d, total %d).", [group_id, added_count, total_count]))
	else:
		_set_ui_notice(_tf("Control Group %d set (%d).", [group_id, total_count]))
	_play_feedback_tone("ground")

func _select_control_group(group_id: int) -> void:
	if group_id < 0 or group_id >= CONTROL_GROUP_COUNT:
		return
	var entry_value: Variant = _control_groups.get(group_id, null)
	if not (entry_value is Dictionary):
		_set_ui_notice(_tf("Control Group %d is empty.", [group_id]))
		_play_feedback_tone("error")
		return
	var entry: Dictionary = entry_value as Dictionary
	var unit_paths: Array = entry.get("unit_paths", []) as Array
	var building_paths: Array = entry.get("building_paths", []) as Array

	_clear_selection()
	var selected_count: int = 0
	for path_value in unit_paths:
		var path: NodePath = NodePath(str(path_value))
		if str(path) == "":
			continue
		var unit_node: Node = get_node_or_null(path)
		if unit_node == null or not is_instance_valid(unit_node):
			continue
		if not unit_node.is_in_group("selectable_unit"):
			continue
		_add_selected_unit(unit_node)
		selected_count += 1

	for path_value in building_paths:
		var path: NodePath = NodePath(str(path_value))
		if str(path) == "":
			continue
		var building_node: Node = get_node_or_null(path)
		if building_node == null or not is_instance_valid(building_node):
			continue
		if not building_node.is_in_group("selectable_building"):
			continue
		_add_selected_building(building_node)
		selected_count += 1

	_refresh_subgroup_state(true)
	if selected_count <= 0:
		_set_ui_notice(_tf("Control Group %d has no valid units.", [group_id]))
		_play_feedback_tone("error")
		return

	var now_sec: float = float(Time.get_ticks_msec()) / 1000.0
	var is_double_tap: bool = _last_selected_group_id == group_id and (now_sec - _last_selected_group_time) <= CONTROL_GROUP_DOUBLE_TAP_WINDOW
	_last_selected_group_id = group_id
	_last_selected_group_time = now_sec

	if is_double_tap:
		_focus_camera_on_current_selection()
		_set_ui_notice(_tf("Control Group %d selected (%d), camera centered.", [group_id, selected_count]))
	else:
		_set_ui_notice(_tf("Control Group %d selected (%d).", [group_id, selected_count]))
	_play_feedback_tone("ground")

func _build_control_group_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for group_id in CONTROL_GROUP_COUNT:
		var count: int = _control_group_valid_count(group_id)
		if count <= 0:
			continue
		entries.append({
			"group_id": group_id,
			"count": count,
			"active": _is_control_group_active(group_id)
		})
	return entries

func _control_group_valid_count(group_id: int) -> int:
	var entry_value: Variant = _control_groups.get(group_id, null)
	if not (entry_value is Dictionary):
		return 0
	var entry: Dictionary = entry_value as Dictionary
	var count: int = 0

	var unit_paths: Array = entry.get("unit_paths", []) as Array
	for path_value in unit_paths:
		var path: NodePath = NodePath(str(path_value))
		if str(path) == "":
			continue
		var unit_node: Node = get_node_or_null(path)
		if unit_node == null or not is_instance_valid(unit_node):
			continue
		if not unit_node.is_in_group("selectable_unit"):
			continue
		if not _is_player_owned(unit_node):
			continue
		count += 1

	var building_paths: Array = entry.get("building_paths", []) as Array
	for path_value in building_paths:
		var path: NodePath = NodePath(str(path_value))
		if str(path) == "":
			continue
		var building_node: Node = get_node_or_null(path)
		if building_node == null or not is_instance_valid(building_node):
			continue
		if not building_node.is_in_group("selectable_building"):
			continue
		if not _is_player_owned(building_node):
			continue
		count += 1
	return count

func _is_control_group_active(group_id: int) -> bool:
	if group_id < 0 or group_id >= CONTROL_GROUP_COUNT:
		return false
	if _last_selected_group_id != group_id:
		return false
	return not _selected_units.is_empty() or not _selected_buildings.is_empty()

func _focus_camera_on_current_selection() -> void:
	if _camera == null:
		return
	var center: Vector3 = Vector3.ZERO
	var count: int = 0
	for selected_unit in _selected_units:
		var unit_3d: Node3D = selected_unit as Node3D
		if unit_3d == null or not is_instance_valid(unit_3d):
			continue
		center += unit_3d.global_position
		count += 1
	for selected_building in _selected_buildings:
		var building_3d: Node3D = selected_building as Node3D
		if building_3d == null or not is_instance_valid(building_3d):
			continue
		center += building_3d.global_position
		count += 1
	if count <= 0:
		return
	center /= float(count)
	var cam_pos: Vector3 = _camera.global_position
	cam_pos.x = center.x
	cam_pos.z = center.z
	var half_size_value: Variant = _camera.get("map_half_size")
	if half_size_value is Vector2:
		var half_size: Vector2 = half_size_value as Vector2
		cam_pos.x = clampf(cam_pos.x, -half_size.x, half_size.x)
		cam_pos.z = clampf(cam_pos.z, -half_size.y, half_size.y)
	_camera.global_position = cam_pos

func _show_control_group_assignment_feedback(group_id: int, append: bool) -> void:
	for selected_unit in _selected_units:
		var unit_3d: Node3D = selected_unit as Node3D
		_spawn_control_group_marker(unit_3d, group_id, append)
	for selected_building in _selected_buildings:
		var building_3d: Node3D = selected_building as Node3D
		_spawn_control_group_marker(building_3d, group_id, append)

func _spawn_control_group_marker(target_node: Node3D, group_id: int, append: bool) -> bool:
	if target_node == null or not is_instance_valid(target_node):
		return false
	_clear_control_group_marker_children(target_node)
	var marker_root: Node3D = Node3D.new()
	marker_root.name = "ControlGroupMarker"
	marker_root.add_to_group(str(CONTROL_GROUP_MARKER_GROUP))
	var is_building: bool = target_node.is_in_group("selectable_building")
	marker_root.position = Vector3(0.0, 2.35 if is_building else 1.35, 0.0)
	target_node.add_child(marker_root)

	var ring: MeshInstance3D = MeshInstance3D.new()
	var ring_mesh: CylinderMesh = CylinderMesh.new()
	ring_mesh.top_radius = 0.34
	ring_mesh.bottom_radius = 0.34
	ring_mesh.height = 0.06
	ring.mesh = ring_mesh
	var ring_material: StandardMaterial3D = StandardMaterial3D.new()
	ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_material.albedo_color = Color(0.32, 0.68, 0.98, 0.82) if append else Color(0.98, 0.9, 0.35, 0.82)
	ring.material_override = ring_material
	marker_root.add_child(ring)

	var number_label: Label3D = Label3D.new()
	number_label.text = str(group_id)
	number_label.position = Vector3(0.0, 0.32, 0.0)
	number_label.font_size = 42
	number_label.modulate = Color(1.0, 1.0, 1.0, 0.98)
	marker_root.add_child(number_label)

	var timer: Timer = Timer.new()
	timer.one_shot = true
	timer.wait_time = CONTROL_GROUP_MARKER_DURATION
	marker_root.add_child(timer)
	timer.timeout.connect(Callable(marker_root, "queue_free"))
	timer.start()
	return true

func _clear_control_group_marker_children(target_node: Node3D) -> void:
	if target_node == null or not is_instance_valid(target_node):
		return
	for child in target_node.get_children():
		var child_node: Node = child as Node
		if child_node == null or not is_instance_valid(child_node):
			continue
		if child_node.is_in_group(str(CONTROL_GROUP_MARKER_GROUP)):
			child_node.queue_free()

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
	_refresh_subgroup_state()

func _setup_queue_visual_root() -> void:
	_queue_visual_root = Node3D.new()
	_queue_visual_root.name = "CommandQueueVisuals"
	add_child(_queue_visual_root)

func _setup_ping_visual_root() -> void:
	_ping_visual_root = Node3D.new()
	_ping_visual_root.name = "PingVisuals"
	add_child(_ping_visual_root)

func _setup_construction_ghost_visual_root() -> void:
	_construction_ghost_visual_root = Node3D.new()
	_construction_ghost_visual_root.name = "PendingConstructionGhosts"
	add_child(_construction_ghost_visual_root)

func _setup_rally_visual_root() -> void:
	_rally_visual_root = Node3D.new()
	_rally_visual_root.name = "RallyPointVisuals"
	add_child(_rally_visual_root)

func _setup_feedback_audio() -> void:
	_feedback_audio_player = AudioStreamPlayer.new()
	_feedback_audio_player.name = "UIFeedbackAudio"
	_feedback_audio_player.bus = &"Master"
	_feedback_audio_player.volume_db = -10.0
	add_child(_feedback_audio_player)
	_feedback_tone_streams = {
		"ground": _make_tone_wav(392.0, 0.08, 0.26, false),
		"resource": _make_tone_wav(523.25, 0.08, 0.26, false),
		"attack": _make_tone_wav(659.25, 0.08, 0.26, false),
		"follow": _make_tone_wav(466.16, 0.08, 0.26, false),
		"relay": _make_tone_wav(587.33, 0.08, 0.26, false),
		"error": _make_tone_wav(200.0, 0.12, 0.28, true)
	}

func _make_tone_wav(frequency_hz: float, duration_sec: float, amplitude: float, square_wave: bool) -> AudioStreamWAV:
	var sample_count: int = maxi(1, int(round(duration_sec * float(FEEDBACK_TONE_SAMPLE_RATE))))
	var pcm: PackedByteArray = PackedByteArray()
	pcm.resize(sample_count * 2)
	var level: float = clampf(amplitude, 0.0, 1.0)
	for i in sample_count:
		var t: float = float(i) / float(FEEDBACK_TONE_SAMPLE_RATE)
		var sample: float = sin(TAU * frequency_hz * t)
		if square_wave:
			sample = 1.0 if sample >= 0.0 else -1.0
		var sample_i16: int = int(round(clampf(sample * level, -1.0, 1.0) * 32767.0))
		pcm[i * 2] = sample_i16 & 0xFF
		pcm[i * 2 + 1] = (sample_i16 >> 8) & 0xFF

	var wav: AudioStreamWAV = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = FEEDBACK_TONE_SAMPLE_RATE
	wav.stereo = false
	wav.data = pcm
	return wav

func _play_feedback_tone(mode: String) -> void:
	if _feedback_audio_player == null:
		return
	var normalized_mode: String = mode if mode != "" else "ground"
	var stream: AudioStream = _feedback_tone_streams.get(normalized_mode) as AudioStream
	if stream == null:
		stream = _feedback_tone_streams.get("ground") as AudioStream
	if stream == null:
		return
	_feedback_audio_player.stream = stream
	_feedback_audio_player.play()

func _set_ui_notice(text: String, duration: float = 1.4) -> void:
	_ui_notice_text = text
	_ui_notice_timer = maxf(0.0, duration)

func _on_worker_queue_transition(_worker_node: Node, event_type: String) -> void:
	match event_type:
		"queued_checkpoint":
			_set_ui_notice(_t("Worker queue accepted: will switch after current gather/return."), 1.1)
		"interrupt_checkpoint":
			_set_ui_notice(_t("Work interrupted: executing queued orders."), 1.0)
		"interrupt_immediate":
			_set_ui_notice(_t("Worker switched to queued orders."), 1.0)

func _process_queue_feedback(delta: float) -> void:
	if _queue_reject_feedback_timer > 0.0:
		_queue_reject_feedback_timer = maxf(0.0, _queue_reject_feedback_timer - delta)
	if _rally_reject_feedback_timer > 0.0:
		_rally_reject_feedback_timer = maxf(0.0, _rally_reject_feedback_timer - delta)
	if _ui_notice_timer > 0.0:
		_ui_notice_timer = maxf(0.0, _ui_notice_timer - delta)
		if _ui_notice_timer <= 0.0:
			_ui_notice_text = ""

func _process_ping_visuals(delta: float) -> void:
	if _active_pings.is_empty():
		return
	for i in range(_active_pings.size() - 1, -1, -1):
		var entry: Dictionary = _active_pings[i]
		var duration: float = maxf(0.01, float(entry.get("duration", PING_DURATION)))
		var remaining: float = maxf(0.0, float(entry.get("remaining", duration)) - delta)
		var progress: float = clampf(1.0 - (remaining / duration), 0.0, 1.0)
		var visual_node: Node3D = entry.get("visual_node") as Node3D
		if visual_node != null and is_instance_valid(visual_node):
			var pulse_scale: float = lerpf(0.55, 1.6, progress)
			visual_node.scale = Vector3.ONE * pulse_scale
		entry["remaining"] = remaining
		_active_pings[i] = entry
		if remaining <= 0.0:
			if visual_node != null and is_instance_valid(visual_node):
				visual_node.queue_free()
			_active_pings.remove_at(i)

func _process_under_attack_pings(delta: float) -> void:
	_attack_ping_check_accum += delta
	if _attack_ping_check_accum < ATTACK_PING_CHECK_INTERVAL:
		return
	_attack_ping_check_accum = 0.0

	var existing_ids: Dictionary = {}
	for node in _player_owned_building_nodes():
		var building: Node3D = node as Node3D
		if building == null:
			continue
		var id: int = building.get_instance_id()
		existing_ids[id] = true
		var current_hp: float = 0.0
		if building.has_method("get_health_points"):
			current_hp = float(building.call("get_health_points"))
		var previous_hp: float = float(_building_health_snapshot.get(id, current_hp))
		var cooldown_left: float = maxf(0.0, float(_building_attack_ping_cooldowns.get(id, 0.0)) - ATTACK_PING_CHECK_INTERVAL)
		if current_hp < previous_hp - 0.01 and cooldown_left <= 0.0:
			_emit_ping(building.global_position, "alert", false)
			cooldown_left = ATTACK_PING_PER_BUILDING_COOLDOWN
		_building_health_snapshot[id] = current_hp
		_building_attack_ping_cooldowns[id] = cooldown_left

	for key in _building_health_snapshot.keys():
		var id: int = int(key)
		if existing_ids.has(id):
			continue
		_building_health_snapshot.erase(id)
		_building_attack_ping_cooldowns.erase(id)

func _player_owned_building_nodes() -> Array[Node]:
	var result: Array[Node] = []
	var building_nodes: Array[Node] = get_tree().get_nodes_in_group("selectable_building")
	for node in building_nodes:
		if node == null or not is_instance_valid(node):
			continue
		if not _is_player_owned(node):
			continue
		if node.has_method("is_alive") and not bool(node.call("is_alive")):
			continue
		result.append(node)
	return result

func _refresh_building_health_snapshot() -> void:
	_building_health_snapshot.clear()
	_building_attack_ping_cooldowns.clear()
	for node in _player_owned_building_nodes():
		var building: Node3D = node as Node3D
		if building == null:
			continue
		var id: int = building.get_instance_id()
		var hp: float = 0.0
		if building.has_method("get_health_points"):
			hp = float(building.call("get_health_points"))
		_building_health_snapshot[id] = hp
		_building_attack_ping_cooldowns[id] = 0.0

func _update_queue_visuals() -> void:
	if _queue_visual_root == null:
		return
	var command_units: Array[Node] = _command_units()
	if command_units.is_empty():
		_last_queue_visual_signature = ""
		_clear_queue_visual_markers()
		return

	var entries: Array[Dictionary] = []
	var signature_parts: Array[String] = []
	for unit_node in command_units:
		if unit_node == null or not is_instance_valid(unit_node):
			continue
		if not unit_node.has_method("get_command_queue_points"):
			continue
		var unit_node_3d: Node3D = unit_node as Node3D
		if unit_node_3d == null:
			continue
		var queue_points_variant: Variant = unit_node.call("get_command_queue_points", true, QUEUE_MARKER_MAX_VISIBLE)
		if not (queue_points_variant is Array):
			continue
		var queue_points: Array = queue_points_variant as Array
		if queue_points.is_empty():
			continue
		var point_signature_parts: Array[String] = []
		for point_value in queue_points:
			if not (point_value is Dictionary):
				continue
			var point: Dictionary = point_value as Dictionary
			var position_value: Variant = point.get("position", Vector3.ZERO)
			if not (position_value is Vector3):
				continue
			var pos: Vector3 = position_value as Vector3
			var command_type: int = int(point.get("command_type", RTSCommand.CommandType.NONE))
			var queued: bool = bool(point.get("queued", true))
			var path_origin_suffix: String = ""
			var path_origin_value: Variant = point.get("path_origin", null)
			if path_origin_value is Vector3:
				var path_origin: Vector3 = path_origin_value as Vector3
				path_origin_suffix = "|o:%.2f,%.2f,%.2f" % [path_origin.x, path_origin.y, path_origin.z]
			point_signature_parts.append("%d:%s:%.2f,%.2f,%.2f%s" % [command_type, "1" if queued else "0", pos.x, pos.y, pos.z, path_origin_suffix])
		if point_signature_parts.is_empty():
			continue
		var unit_position: Vector3 = unit_node_3d.global_position
		signature_parts.append(
			"%d:%.2f,%.2f,%.2f|%s" % [unit_node.get_instance_id(), unit_position.x, unit_position.y, unit_position.z, ";".join(point_signature_parts)]
		)
		entries.append({
			"unit": unit_node,
			"points": queue_points
		})

	if entries.is_empty():
		_last_queue_visual_signature = ""
		_clear_queue_visual_markers()
		return
	var signature: String = "%d|%s" % [entries.size(), "#".join(signature_parts)]
	if signature == _last_queue_visual_signature:
		return
	_last_queue_visual_signature = signature
	_rebuild_queue_visual_markers(entries)

func _clear_queue_visual_markers() -> void:
	for marker_node in _queue_visible_marker_nodes:
		var node: Node = marker_node as Node
		if node != null and is_instance_valid(node):
			node.queue_free()
	_queue_visible_marker_nodes.clear()

func _rebuild_queue_visual_markers(entries: Array[Dictionary]) -> void:
	_clear_queue_visual_markers()
	for entry in entries:
		var unit_node: Node = entry.get("unit") as Node
		if unit_node == null or not is_instance_valid(unit_node):
			continue
		var unit_node_3d: Node3D = unit_node as Node3D
		if unit_node_3d == null:
			continue
		var queue_points_value: Variant = entry.get("points", [])
		if not (queue_points_value is Array):
			continue
		var queue_points: Array = queue_points_value as Array
		var prev_position: Vector3 = unit_node_3d.global_position + Vector3(0.0, QUEUE_LINK_HEIGHT, 0.0)
		var index: int = 0
		for point_value in queue_points:
			if not (point_value is Dictionary):
				continue
			var point: Dictionary = point_value as Dictionary
			var target_position: Vector3 = Vector3.ZERO
			var position_value: Variant = point.get("position", Vector3.ZERO)
			if position_value is Vector3:
				target_position = position_value as Vector3
			var command_type: int = int(point.get("command_type", RTSCommand.CommandType.MOVE))
			if index == 0:
				var path_origin_value: Variant = point.get("path_origin", null)
				if path_origin_value is Vector3:
					var path_origin: Vector3 = path_origin_value as Vector3
					prev_position = path_origin + Vector3(0.0, QUEUE_LINK_HEIGHT, 0.0)
			var marker: StaticBody3D = _create_queue_marker(unit_node, index, target_position, command_type)
			_queue_visual_root.add_child(marker)
			_queue_visible_marker_nodes.append(marker)
			var link: MeshInstance3D = _create_queue_link(prev_position, target_position + Vector3(0.0, QUEUE_LINK_HEIGHT, 0.0), command_type)
			if link != null:
				_queue_visual_root.add_child(link)
				_queue_visible_marker_nodes.append(link)
			prev_position = target_position + Vector3(0.0, QUEUE_LINK_HEIGHT, 0.0)
			index += 1
			if index >= QUEUE_MARKER_MAX_VISIBLE:
				break

func _create_queue_marker(unit_node: Node, queue_index: int, world_position: Vector3, command_type: int = RTSCommand.CommandType.MOVE) -> StaticBody3D:
	var marker: StaticBody3D = StaticBody3D.new()
	marker.name = "QueueMarker%d" % queue_index
	marker.add_to_group(str(QUEUE_MARKER_GROUP))
	marker.collision_layer = QUEUE_MARKER_LAYER
	marker.collision_mask = 0
	marker.global_position = world_position + Vector3(0.0, 0.06, 0.0)
	marker.set_meta("queue_index", queue_index)
	marker.set_meta("unit_path", unit_node.get_path())

	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: SphereShape3D = SphereShape3D.new()
	shape.radius = 0.32
	collision.shape = shape
	collision.position = Vector3(0.0, 0.14, 0.0)
	marker.add_child(collision)

	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = 0.24
	sphere.height = 0.48
	mesh_instance.mesh = sphere
	mesh_instance.position = Vector3(0.0, 0.14, 0.0)
	var marker_material: StandardMaterial3D = StandardMaterial3D.new()
	marker_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	marker_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var marker_color: Color = _queue_command_color(command_type)
	marker_material.albedo_color = Color(marker_color.r, marker_color.g, marker_color.b, 0.78)
	_configure_path_overlay_material(marker_material)
	mesh_instance.material_override = marker_material
	marker.add_child(mesh_instance)

	var label: Label3D = Label3D.new()
	label.text = str(queue_index + 1)
	label.position = Vector3(0.0, 0.56, 0.0)
	label.font_size = 32
	label.modulate = _queue_marker_label_color(command_type)
	_configure_path_overlay_label(label)
	marker.add_child(label)
	return marker

func _create_queue_link(from_position: Vector3, to_position: Vector3, command_type: int = RTSCommand.CommandType.MOVE) -> MeshInstance3D:
	var delta: Vector3 = to_position - from_position
	var length: float = delta.length()
	if length < 0.08:
		return null
	var link: MeshInstance3D = MeshInstance3D.new()
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = 0.03
	mesh.bottom_radius = 0.03
	mesh.height = length
	link.mesh = mesh
	var link_material: StandardMaterial3D = StandardMaterial3D.new()
	link_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	link_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var link_color: Color = _queue_command_color(command_type)
	link_material.albedo_color = Color(link_color.r, link_color.g, link_color.b, 0.4)
	_configure_path_overlay_material(link_material)
	link.material_override = link_material
	link.global_transform = Transform3D(_cylinder_basis_from_to(from_position, to_position), from_position + delta * 0.5)
	return link

func _queue_command_color(command_type: int) -> Color:
	match command_type:
		RTSCommand.CommandType.ATTACK, RTSCommand.CommandType.ATTACK_MOVE:
			return Color(0.95, 0.28, 0.24, 1.0)
		RTSCommand.CommandType.GATHER:
			return Color(0.34, 0.9, 0.38, 1.0)
		RTSCommand.CommandType.RETURN_RESOURCE:
			return Color(0.45, 0.78, 0.98, 1.0)
		RTSCommand.CommandType.REPAIR:
			return Color(0.35, 0.85, 0.95, 1.0)
		_:
			return Color(0.95, 0.95, 0.25, 1.0)

func _queue_marker_label_color(command_type: int) -> Color:
	match command_type:
		RTSCommand.CommandType.ATTACK, RTSCommand.CommandType.ATTACK_MOVE:
			return Color(1.0, 0.92, 0.92, 1.0)
		_:
			return Color(1.0, 0.98, 0.55, 1.0)

func _cylinder_basis_from_to(from_position: Vector3, to_position: Vector3) -> Basis:
	var delta: Vector3 = to_position - from_position
	if delta.length_squared() <= 0.000001:
		return Basis.IDENTITY
	var direction: Vector3 = delta.normalized()
	var up: Vector3 = Vector3.UP
	var dot: float = clampf(up.dot(direction), -1.0, 1.0)
	if dot > 0.9999:
		return Basis.IDENTITY
	if dot < -0.9999:
		return Basis(Vector3.RIGHT, PI)
	var axis: Vector3 = up.cross(direction).normalized()
	var angle: float = acos(dot)
	return Basis(axis, angle)

func _building_construction_paradigm(building_kind: String) -> String:
	if building_kind == "":
		return "garrisoned"
	var building_def: Dictionary = RTS_CATALOG.get_building_def(building_kind)
	var paradigm: String = str(building_def.get("construction_paradigm", "garrisoned")).strip_edges().to_lower()
	if paradigm != "summoning" and paradigm != "garrisoned" and paradigm != "incorporated":
		return "garrisoned"
	return paradigm

func _create_pending_construction_ghost(worker_node: Node3D, kind: String, world_position: Vector3, rotation_y: float, queued: bool) -> int:
	if worker_node == null or not is_instance_valid(worker_node):
		return -1
	if _construction_ghost_visual_root == null:
		return -1
	var ghost_id: int = _next_construction_ghost_id
	_next_construction_ghost_id += 1

	var ghost_node: Node3D = _create_pending_construction_ghost_node(ghost_id, kind, world_position, rotation_y)
	_construction_ghost_visual_root.add_child(ghost_node)

	_pending_construction_ghosts.append({
		"ghost_id": ghost_id,
		"worker_path": worker_node.get_path(),
		"position": Vector3(world_position.x, 0.0, world_position.z),
		"rotation_y": rotation_y,
		"building_kind": kind,
		"paradigm": _building_construction_paradigm(kind),
		"is_queued": queued,
		"status": "pending",
		"elapsed": 0.0,
		"node_path": ghost_node.get_path(),
		"created_at": float(Time.get_ticks_msec()) / 1000.0
	})
	return ghost_id

func _create_pending_construction_ghost_node(ghost_id: int, kind: String, world_position: Vector3, rotation_y: float) -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "ConstructionGhost%d" % ghost_id
	root.global_position = Vector3(world_position.x, 0.04, world_position.z)
	root.rotation.y = rotation_y

	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	mesh_instance.name = "GhostMesh"
	var mesh: BoxMesh = BoxMesh.new()
	var footprint: Vector2 = _build_footprint_for_kind(kind)
	mesh.size = Vector3(footprint.x, 0.12, footprint.y)
	mesh_instance.mesh = mesh
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.18, 0.95, 0.36, 0.42)
	mesh_instance.material_override = material
	root.add_child(mesh_instance)

	var label: Label3D = Label3D.new()
	label.name = "GhostLabel"
	label.text = _building_display_name(kind)
	label.position = Vector3(0.0, 0.7, 0.0)
	label.font_size = 28
	label.modulate = Color(0.9, 0.96, 0.92, 0.95)
	root.add_child(label)

	var nav_obstacle: NavigationObstacle3D = NavigationObstacle3D.new()
	nav_obstacle.name = "GhostObstacle3D"
	# Pending ghosts should not alter global navmesh, otherwise they affect
	# enemy units and can interfere with the assigned builder pathing.
	nav_obstacle.affect_navigation_mesh = false
	nav_obstacle.avoidance_enabled = false
	nav_obstacle.carve_navigation_mesh = false
	nav_obstacle.height = 4.0
	var half_x: float = maxf(0.05, footprint.x * 0.5 * PENDING_BUILD_FOOTPRINT_EXPAND_SCALE)
	var half_z: float = maxf(0.05, footprint.y * 0.5 * PENDING_BUILD_FOOTPRINT_EXPAND_SCALE)
	nav_obstacle.vertices = PackedVector3Array([
		Vector3(-half_x, 0.0, -half_z),
		Vector3(half_x, 0.0, -half_z),
		Vector3(half_x, 0.0, half_z),
		Vector3(-half_x, 0.0, half_z)
	])
	root.add_child(nav_obstacle)
	return root

func _pending_construction_ghost_index(ghost_id: int) -> int:
	for i in _pending_construction_ghosts.size():
		var ghost_value: Variant = _pending_construction_ghosts[i]
		if not (ghost_value is Dictionary):
			continue
		var ghost: Dictionary = ghost_value as Dictionary
		if int(ghost.get("ghost_id", -1)) == ghost_id:
			return i
	return -1

func _has_pending_construction_ghost(ghost_id: int) -> bool:
	return _pending_construction_ghost_index(ghost_id) >= 0

func _remove_pending_construction_ghost(ghost_id: int) -> bool:
	var index: int = _pending_construction_ghost_index(ghost_id)
	if index < 0:
		return false
	var ghost: Dictionary = _pending_construction_ghosts[index] as Dictionary
	var node_path: NodePath = ghost.get("node_path", NodePath("")) as NodePath
	if str(node_path) != "":
		var ghost_node: Node3D = get_node_or_null(node_path) as Node3D
		if ghost_node != null and is_instance_valid(ghost_node):
			ghost_node.queue_free()
	_pending_construction_ghosts.remove_at(index)
	return true

func _set_pending_construction_ghost_invalid(ghost_id: int, invalid: bool) -> void:
	var index: int = _pending_construction_ghost_index(ghost_id)
	if index < 0:
		return
	var ghost: Dictionary = _pending_construction_ghosts[index] as Dictionary
	ghost["status"] = "invalid" if invalid else "pending"
	_pending_construction_ghosts[index] = ghost

func _is_internal_build_order_command(command: RTSCommand) -> bool:
	if command == null:
		return false
	if not (command.payload is Dictionary):
		return false
	return bool(command.payload.get("internal_build_order", false))

func _cancel_pending_construction_for_worker(worker_node: Node, reason: String = "override") -> bool:
	if worker_node == null or not is_instance_valid(worker_node):
		return false
	var worker_path: NodePath = worker_node.get_path()
	var changed: bool = false

	for i in range(_pending_build_orders.size() - 1, -1, -1):
		var order_value: Variant = _pending_build_orders[i]
		if not (order_value is Dictionary):
			continue
		var order: Dictionary = order_value as Dictionary
		var builder_path: NodePath = order.get("builder_path", NodePath("")) as NodePath
		if builder_path != worker_path:
			continue
		var ghost_id: int = int(order.get("ghost_id", -1))
		if ghost_id >= 0:
			_remove_pending_construction_ghost(ghost_id)
		_pending_build_orders.remove_at(i)
		changed = true

	for i in range(_pending_construction_ghosts.size() - 1, -1, -1):
		var ghost_value: Variant = _pending_construction_ghosts[i]
		if not (ghost_value is Dictionary):
			continue
		var ghost: Dictionary = ghost_value as Dictionary
		var ghost_worker_path: NodePath = ghost.get("worker_path", NodePath("")) as NodePath
		if ghost_worker_path != worker_path:
			continue
		var ghost_id: int = int(ghost.get("ghost_id", -1))
		if ghost_id >= 0:
			_remove_pending_construction_ghost(ghost_id)
			changed = true

	if _cancel_pending_construction_resume_for_worker(worker_node, reason):
		changed = true

	if not changed:
		return false
	_set_ui_notice(_tf("Pending construction canceled (%s).", [reason]), 1.1)
	return true

func _cancel_pending_construction_for_selected_workers() -> bool:
	var changed: bool = false
	for selected_unit in _selected_units:
		if selected_unit == null or not is_instance_valid(selected_unit):
			continue
		if not selected_unit.has_method("is_worker_unit"):
			continue
		if not bool(selected_unit.call("is_worker_unit")):
			continue
		if _cancel_pending_construction_for_worker(selected_unit, "manual cancel"):
			changed = true
	if changed:
		_refresh_hint_label()
	return changed

func _process_pending_construction_ghosts(delta: float) -> void:
	if _pending_construction_ghosts.is_empty():
		return
	var now_sec: float = float(Time.get_ticks_msec()) / 1000.0
	for i in range(_pending_construction_ghosts.size() - 1, -1, -1):
		var ghost_value: Variant = _pending_construction_ghosts[i]
		if not (ghost_value is Dictionary):
			_pending_construction_ghosts.remove_at(i)
			continue
		var ghost: Dictionary = ghost_value as Dictionary
		var node_path: NodePath = ghost.get("node_path", NodePath("")) as NodePath
		var ghost_node: Node3D = get_node_or_null(node_path) as Node3D
		if ghost_node == null or not is_instance_valid(ghost_node):
			_pending_construction_ghosts.remove_at(i)
			continue
		var elapsed: float = float(ghost.get("elapsed", 0.0)) + delta
		ghost["elapsed"] = elapsed
		var base_position: Vector3 = Vector3.ZERO
		var base_position_value: Variant = ghost.get("position", Vector3.ZERO)
		if base_position_value is Vector3:
			base_position = base_position_value as Vector3
		var float_offset: float = sin(now_sec * CONSTRUCTION_GHOST_FLOAT_SPEED + float(i)) * CONSTRUCTION_GHOST_FLOAT_AMPLITUDE
		ghost_node.global_position = Vector3(base_position.x, 0.05 + float_offset, base_position.z)

		var mesh_instance: MeshInstance3D = ghost_node.get_node_or_null("GhostMesh") as MeshInstance3D
		if mesh_instance != null:
			var material: StandardMaterial3D = mesh_instance.material_override as StandardMaterial3D
			if material != null:
				var status: String = str(ghost.get("status", "pending"))
				if status == "invalid":
					var blink: float = 0.38 + 0.25 * absf(sin(now_sec * 9.0))
					material.albedo_color = Color(0.95, 0.24, 0.24, blink)
				else:
					material.albedo_color = Color(0.18, 0.95, 0.36, 0.42)
		_pending_construction_ghosts[i] = ghost

func _update_rally_visuals() -> void:
	if _rally_visual_root == null:
		return
	if not _selected_units.is_empty() or _selected_buildings.is_empty():
		_last_rally_visual_signature = ""
		_clear_rally_visual_markers()
		return

	var signature_parts: Array[String] = []
	var entries: Array[Dictionary] = []
	var blink_phase: int = int(Time.get_ticks_msec() / int(RALLY_ALERT_BLINK_INTERVAL_SEC * 1000.0)) % 2
	for selected_building in _selected_buildings:
		var building_node: Node3D = selected_building as Node3D
		if building_node == null or not is_instance_valid(building_node):
			continue
		if not _is_player_owned(building_node):
			continue
		if not building_node.has_method("supports_rally_point"):
			continue
		if not bool(building_node.call("supports_rally_point")):
			continue
		if not building_node.has_method("get_rally_point_data"):
			continue
		var rally_data_value: Variant = building_node.call("get_rally_point_data")
		if not (rally_data_value is Dictionary):
			continue
		var rally_data: Dictionary = rally_data_value as Dictionary
		var hops: Array[Dictionary] = _extract_rally_hops(rally_data)
		if hops.is_empty():
			continue
		var alerting: bool = building_node.has_method("is_rally_alerting") and bool(building_node.call("is_rally_alerting"))
		var alert_phase: bool = alerting and blink_phase == 0
		entries.append({
			"building": building_node,
			"hops": hops,
			"alerting": alerting,
			"alert_phase": alert_phase
		})
		var hop_parts: Array[String] = []
		for hop in hops:
			var position_value: Variant = hop.get("position", Vector3.ZERO)
			if not (position_value is Vector3):
				continue
			var position: Vector3 = position_value as Vector3
			var mode: String = str(hop.get("mode", "ground"))
			hop_parts.append("%s:%.2f,%.2f,%.2f" % [mode, position.x, position.y, position.z])
		var building_position: Vector3 = building_node.global_position
		signature_parts.append(
			"%d|%.2f,%.2f,%.2f|%s|%d|%d" % [
				building_node.get_instance_id(),
				building_position.x,
				building_position.y,
				building_position.z,
				",".join(hop_parts),
				1 if alerting else 0,
				1 if alert_phase else 0
			]
		)

	var signature: String = ";".join(signature_parts)
	if signature == _last_rally_visual_signature:
		return
	_last_rally_visual_signature = signature
	_rebuild_rally_visual_markers(entries)

func _clear_rally_visual_markers() -> void:
	for rally_node in _rally_visible_nodes:
		var node: Node = rally_node as Node
		if node != null and is_instance_valid(node):
			node.queue_free()
	_rally_visible_nodes.clear()

func _safe_node3d_from_variant(value: Variant) -> Node3D:
	if not (value is Object):
		return null
	if not is_instance_valid(value):
		return null
	return value as Node3D

func _extract_rally_hops(rally_data: Dictionary) -> Array[Dictionary]:
	var hops: Array[Dictionary] = []
	var raw_hops: Variant = rally_data.get("hops", [])
	if raw_hops is Array:
		var raw_hops_array: Array = raw_hops as Array
		for hop_value in raw_hops_array:
			if not (hop_value is Dictionary):
				continue
			var raw_hop: Dictionary = hop_value as Dictionary
			var mode: String = str(raw_hop.get("mode", "ground"))
			var target_node: Node3D = _safe_node3d_from_variant(raw_hop.get("target_node", null))
			var hop_position: Vector3 = Vector3.ZERO
			var position_value: Variant = raw_hop.get("position", Vector3.ZERO)
			if position_value is Vector3:
				hop_position = position_value as Vector3
			var valid_target: bool = target_node != null and is_instance_valid(target_node)
			if valid_target and target_node.has_method("is_alive") and not bool(target_node.call("is_alive")):
				valid_target = false
			if valid_target and mode == "resource" and not target_node.is_in_group("resource_node"):
				valid_target = false
			if valid_target and mode == "relay" and not target_node.is_in_group("selectable_building"):
				valid_target = false
			if valid_target:
				hop_position = target_node.global_position
			else:
				target_node = null
				mode = "ground"
			hops.append({
				"position": Vector3(hop_position.x, 0.0, hop_position.z),
				"target_node": target_node,
				"mode": mode
			})

	if hops.is_empty():
		var fallback_mode: String = str(rally_data.get("mode", "ground"))
		var fallback_target: Node3D = _safe_node3d_from_variant(rally_data.get("target_node", null))
		var fallback_position: Vector3 = Vector3.ZERO
		var fallback_position_value: Variant = rally_data.get("position", Vector3.ZERO)
		if fallback_position_value is Vector3:
			fallback_position = fallback_position_value as Vector3
		if fallback_target != null and is_instance_valid(fallback_target):
			if fallback_target.has_method("is_alive") and not bool(fallback_target.call("is_alive")):
				fallback_target = null
				fallback_mode = "ground"
			else:
				fallback_position = fallback_target.global_position
		else:
			fallback_target = null
			fallback_mode = "ground"
		hops.append({
			"position": Vector3(fallback_position.x, 0.0, fallback_position.z),
			"target_node": fallback_target,
			"mode": fallback_mode
		})

	while hops.size() > RALLY_MAX_HOPS:
		hops.pop_back()
	return hops

func _rebuild_rally_visual_markers(entries: Array[Dictionary]) -> void:
	_clear_rally_visual_markers()
	for entry in entries:
		var building_node: Node3D = entry.get("building") as Node3D
		if building_node == null or not is_instance_valid(building_node):
			continue
		var alerting: bool = bool(entry.get("alerting", false))
		var alert_phase: bool = bool(entry.get("alert_phase", false))
		var hops_value: Variant = entry.get("hops", [])
		if not (hops_value is Array):
			continue
		var hops: Array = hops_value as Array
		var previous_position: Vector3 = building_node.global_position + Vector3(0.0, RALLY_VISUAL_HEIGHT, 0.0)
		var hop_index: int = 0
		for hop_value in hops:
			if not (hop_value is Dictionary):
				continue
			var hop: Dictionary = hop_value as Dictionary
			var position_value: Variant = hop.get("position", Vector3.ZERO)
			if not (position_value is Vector3):
				continue
			var hop_position: Vector3 = position_value as Vector3
			var mode: String = str(hop.get("mode", "ground"))
			var link: MeshInstance3D = _create_rally_link(
				previous_position,
				hop_position + Vector3(0.0, RALLY_VISUAL_HEIGHT, 0.0),
				mode,
				alerting,
				alert_phase
			)
			if link != null:
				_rally_visual_root.add_child(link)
				_rally_visible_nodes.append(link)
			var flag: Node3D = _create_rally_flag(hop_position, mode, hop_index + 1, alerting, alert_phase)
			if flag != null:
				_rally_visual_root.add_child(flag)
				_rally_visible_nodes.append(flag)
			previous_position = hop_position + Vector3(0.0, RALLY_VISUAL_HEIGHT, 0.0)
			hop_index += 1

func _create_rally_flag(world_position: Vector3, mode: String, hop_index: int, alerting: bool = false, alert_phase: bool = false) -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "RallyFlag%d" % hop_index
	root.global_position = world_position + Vector3(0.0, RALLY_VISUAL_HEIGHT, 0.0)
	var color: Color = _rally_mode_color(mode)
	var mode_glyph: String = _rally_mode_glyph(mode)
	var alpha_scale: float = 0.28 if alerting and not alert_phase else 1.0

	var pole: MeshInstance3D = MeshInstance3D.new()
	var pole_mesh: CylinderMesh = CylinderMesh.new()
	pole_mesh.top_radius = 0.03
	pole_mesh.bottom_radius = 0.03
	pole_mesh.height = 0.7
	pole.mesh = pole_mesh
	pole.position = Vector3(0.0, 0.35, 0.0)
	var pole_material: StandardMaterial3D = StandardMaterial3D.new()
	pole_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pole_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pole_material.albedo_color = Color(color.r, color.g, color.b, 0.9 * alpha_scale)
	_configure_path_overlay_material(pole_material)
	pole.material_override = pole_material
	root.add_child(pole)

	var banner: MeshInstance3D = MeshInstance3D.new()
	var banner_mesh: BoxMesh = BoxMesh.new()
	banner_mesh.size = Vector3(0.42, 0.2, 0.05)
	banner.mesh = banner_mesh
	banner.position = Vector3(0.23, 0.62, 0.0)
	var banner_material: StandardMaterial3D = StandardMaterial3D.new()
	banner_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	banner_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	banner_material.albedo_color = Color(color.r, color.g, color.b, 0.75 * alpha_scale)
	_configure_path_overlay_material(banner_material)
	banner.material_override = banner_material
	root.add_child(banner)

	var index_label: Label3D = Label3D.new()
	index_label.text = str(hop_index)
	index_label.position = Vector3(-0.1, 0.76, 0.0)
	index_label.font_size = 28
	index_label.modulate = Color(1.0, 1.0, 1.0, 0.95 * alpha_scale)
	_configure_path_overlay_label(index_label)
	root.add_child(index_label)

	var mode_label: Label3D = Label3D.new()
	mode_label.text = mode_glyph
	mode_label.position = Vector3(0.23, 0.62, 0.04)
	mode_label.font_size = 24
	mode_label.modulate = Color(0.06, 0.06, 0.06, 0.95 * alpha_scale)
	_configure_path_overlay_label(mode_label)
	root.add_child(mode_label)
	return root

func _create_rally_link(from_position: Vector3, to_position: Vector3, mode: String, alerting: bool = false, alert_phase: bool = false) -> MeshInstance3D:
	var delta: Vector3 = to_position - from_position
	var length: float = delta.length()
	if length < 0.08:
		return null
	var link: MeshInstance3D = MeshInstance3D.new()
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = 0.025
	mesh.bottom_radius = 0.025
	mesh.height = length
	link.mesh = mesh
	var color: Color = _rally_mode_color(mode)
	var alpha_scale: float = 0.24 if alerting and not alert_phase else 1.0
	var link_material: StandardMaterial3D = StandardMaterial3D.new()
	link_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	link_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	link_material.albedo_color = Color(color.r, color.g, color.b, 0.45 * alpha_scale)
	_configure_path_overlay_material(link_material)
	link.material_override = link_material
	link.global_transform = Transform3D(_cylinder_basis_from_to(from_position, to_position), from_position + delta * 0.5)
	return link

func _configure_path_overlay_material(material: StandardMaterial3D) -> void:
	if material == null:
		return
	material.no_depth_test = true
	material.render_priority = PATH_VISUAL_RENDER_PRIORITY

func _configure_path_overlay_label(label: Label3D) -> void:
	if label == null:
		return
	label.no_depth_test = true

func _rally_mode_color(mode: String) -> Color:
	match mode:
		"attack":
			return Color(0.94, 0.25, 0.24, 1.0)
		"resource":
			return Color(0.3, 0.9, 0.38, 1.0)
		"follow":
			return Color(0.26, 0.62, 0.98, 1.0)
		"relay":
			return Color(0.78, 0.35, 0.95, 1.0)
		_:
			return Color(0.95, 0.86, 0.25, 1.0)

func _rally_mode_glyph(mode: String) -> String:
	match mode:
		"attack":
			return "A"
		"resource":
			return "G"
		"follow":
			return "F"
		"relay":
			return "R"
		_:
			return "M"

func _try_remove_queue_marker_at(screen_pos: Vector2) -> bool:
	var ray_result: Dictionary = _raycast_from_screen(screen_pos, true)
	if ray_result.is_empty():
		return false
	var collider: Node = ray_result.get("collider") as Node
	if collider == null:
		return false
	if not collider.is_in_group(str(QUEUE_MARKER_GROUP)):
		return false
	if not collider.has_meta("queue_index") or not collider.has_meta("unit_path"):
		return false
	var queue_index: int = int(collider.get_meta("queue_index"))
	var unit_path: NodePath = collider.get_meta("unit_path") as NodePath
	if str(unit_path) == "":
		return false
	var unit_node: Node = get_node_or_null(unit_path)
	if unit_node == null or not is_instance_valid(unit_node):
		return false
	if not unit_node.has_method("remove_queued_commands_from"):
		return false
	var removed: bool = bool(unit_node.call("remove_queued_commands_from", queue_index))
	if removed:
		_update_queue_visuals()
	return removed

func _schedule_unit_command(unit_node: Node, command: RTSCommand) -> void:
	if unit_node == null or not is_instance_valid(unit_node):
		return
	if command == null:
		return
	var forced_locked_queue: bool = false
	var is_internal_build_order: bool = _is_internal_build_order_command(command)
	if unit_node.has_method("is_construction_locked") and bool(unit_node.call("is_construction_locked")):
		if unit_node.has_method("get_construction_lock_mode"):
			var lock_mode: String = str(unit_node.call("get_construction_lock_mode"))
			if (lock_mode == "cast" or lock_mode == "garrisoned" or lock_mode == "incorporated") and not command.is_queue_command and not is_internal_build_order:
				command.is_queue_command = true
				forced_locked_queue = true
				_set_ui_notice(_t("Worker is building: command queued after construction."), 0.9)
	if not is_internal_build_order:
		if command.command_type == RTSCommand.CommandType.STOP:
			_cancel_pending_construction_for_worker(unit_node, "stop")
		elif not command.is_queue_command:
			_cancel_pending_construction_for_worker(unit_node, "override")
	if command.is_queue_command and unit_node.has_method("can_enqueue_command"):
		# Locked-mode non-Shift commands are "replace slot" semantics in unit.gd,
		# so they should not be blocked by queue-cap precheck here.
		if not forced_locked_queue and not bool(unit_node.call("can_enqueue_command")):
			_queue_reject_feedback_timer = 1.1
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
		RTSCommand.CommandType.REPAIR:
			var repair_target: Node3D = command.payload.get("building") as Node3D
			if repair_target == null:
				repair_target = command.target_unit as Node3D
			if repair_target != null and unit_node.has_method("command_repair"):
				unit_node.call("command_repair", repair_target)
		RTSCommand.CommandType.STOP:
			if unit_node.has_method("command_stop"):
				unit_node.call("command_stop")

func add_minerals(amount: int) -> void:
	add_minerals_for_team(PLAYER_TEAM_ID, amount)

func try_spend_minerals(cost: int) -> bool:
	return try_spend_minerals_for_team(PLAYER_TEAM_ID, cost)

func get_minerals() -> int:
	return get_minerals_for_team(PLAYER_TEAM_ID)

func add_minerals_for_team(team_id: int, amount: int) -> void:
	if amount <= 0:
		return
	_ensure_team_mineral_entry(team_id)
	var current: int = int(_team_minerals.get(team_id, 0))
	_team_minerals[team_id] = current + amount
	if team_id == PLAYER_TEAM_ID:
		_minerals = int(_team_minerals.get(PLAYER_TEAM_ID, _minerals))
		_refresh_resource_label()

func try_spend_minerals_for_team(team_id: int, cost: int) -> bool:
	if cost <= 0:
		return true
	_ensure_team_mineral_entry(team_id)
	var current: int = int(_team_minerals.get(team_id, 0))
	if current < cost:
		return false
	_team_minerals[team_id] = current - cost
	if team_id == PLAYER_TEAM_ID:
		_minerals = int(_team_minerals.get(PLAYER_TEAM_ID, _minerals))
		_refresh_resource_label()
	return true

func get_minerals_for_team(team_id: int) -> int:
	_ensure_team_mineral_entry(team_id)
	return int(_team_minerals.get(team_id, 0))

func _init_team_minerals() -> void:
	_team_minerals.clear()
	_team_minerals[PLAYER_TEAM_ID] = _minerals

	var discovered_teams: Dictionary = {}
	discovered_teams[PLAYER_TEAM_ID] = true

	var unit_nodes: Array[Node] = get_tree().get_nodes_in_group("selectable_unit")
	for node in unit_nodes:
		if node == null or not is_instance_valid(node):
			continue
		if not node.has_method("get_team_id"):
			continue
		discovered_teams[int(node.call("get_team_id"))] = true

	var building_nodes: Array[Node] = get_tree().get_nodes_in_group("selectable_building")
	for node in building_nodes:
		if node == null or not is_instance_valid(node):
			continue
		if not node.has_method("get_team_id"):
			continue
		discovered_teams[int(node.call("get_team_id"))] = true

	for team_key in discovered_teams.keys():
		_ensure_team_mineral_entry(int(team_key))

	_minerals = int(_team_minerals.get(PLAYER_TEAM_ID, _minerals))

func _ensure_team_mineral_entry(team_id: int) -> void:
	if team_id <= 0:
		return
	if _team_minerals.has(team_id):
		return
	var initial_value: int = _minerals if team_id == PLAYER_TEAM_ID else DEFAULT_TEAM_START_MINERALS
	_team_minerals[team_id] = initial_value

func _refresh_resource_label() -> void:
	_push_hud_update()

func _refresh_hint_label() -> void:
	_push_hud_update()

func _process_minimap_update(delta: float) -> void:
	if _hud == null or not _hud.has_method("update_minimap"):
		return
	var refresh_interval: float = maxf(0.02, minimap_update_interval)
	_minimap_update_accum += delta
	if _minimap_update_accum < refresh_interval:
		return
	_minimap_update_accum = 0.0
	_push_minimap_update()

func _push_minimap_update() -> void:
	if _hud == null or not _hud.has_method("update_minimap"):
		return
	_hud.call("update_minimap", _build_minimap_snapshot())

func _build_minimap_snapshot() -> Dictionary:
	var map_half_size: Vector2 = _camera_map_half_size()
	return {
		"map_half_size": map_half_size,
		"player_team_id": PLAYER_TEAM_ID,
		"camera_position": _camera.global_position if _camera != null else Vector3.ZERO,
		"camera_half_extent": _estimate_minimap_camera_half_extent(map_half_size),
		"units": _build_minimap_unit_entries(),
		"buildings": _build_minimap_building_entries(),
		"resources": _build_minimap_resource_entries(),
		"pings": _build_minimap_ping_entries()
	}

func _build_minimap_unit_entries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if _units_root == null:
		return result
	for node in _units_root.get_children():
		var unit_3d: Node3D = node as Node3D
		if unit_3d == null or not is_instance_valid(unit_3d):
			continue
		if node.has_method("is_alive") and not bool(node.call("is_alive")):
			continue
		result.append({
			"x": unit_3d.global_position.x,
			"z": unit_3d.global_position.z,
			"team": _node_team_id(node),
			"selected": _selected_units.has(node)
		})
	return result

func _build_minimap_building_entries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if _buildings_root == null:
		return result
	for node in _buildings_root.get_children():
		var building_3d: Node3D = node as Node3D
		if building_3d == null or not is_instance_valid(building_3d):
			continue
		if node.has_method("is_alive") and not bool(node.call("is_alive")):
			continue
		result.append({
			"x": building_3d.global_position.x,
			"z": building_3d.global_position.z,
			"team": _node_team_id(node),
			"selected": _selected_buildings.has(node)
		})
	return result

func _build_minimap_resource_entries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for node_value in get_tree().get_nodes_in_group("resource_node"):
		var resource_3d: Node3D = node_value as Node3D
		if resource_3d == null or not is_instance_valid(resource_3d):
			continue
		result.append({
			"x": resource_3d.global_position.x,
			"z": resource_3d.global_position.z
		})
	return result

func _build_minimap_ping_entries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for value in _active_pings:
		var entry: Dictionary = value as Dictionary
		var pos_value: Variant = entry.get("position", Vector3.ZERO)
		if not (pos_value is Vector3):
			continue
		var position: Vector3 = pos_value as Vector3
		var duration: float = maxf(0.01, float(entry.get("duration", PING_DURATION)))
		var remaining: float = clampf(float(entry.get("remaining", duration)), 0.0, duration)
		var progress: float = clampf(1.0 - (remaining / duration), 0.0, 1.0)
		result.append({
			"x": position.x,
			"z": position.z,
			"progress": progress,
			"kind": str(entry.get("kind", "manual"))
		})
	return result

func _camera_map_half_size() -> Vector2:
	if _camera != null:
		var half_size_value: Variant = _camera.get("map_half_size")
		if half_size_value is Vector2:
			var half_size: Vector2 = (half_size_value as Vector2).abs()
			if half_size.x > 0.0 and half_size.y > 0.0:
				return half_size
	return Vector2(58.0, 58.0)

func _estimate_minimap_camera_half_extent(map_half_size: Vector2) -> Vector2:
	var clamped_half_size: Vector2 = Vector2(maxf(1.0, map_half_size.x), maxf(1.0, map_half_size.y))
	if _camera == null:
		return clamped_half_size * 0.2
	var min_zoom: float = float(_camera.get("min_zoom"))
	var max_zoom: float = float(_camera.get("max_zoom"))
	var camera_height: float = _camera.global_position.y
	var zoom_ratio: float = 0.5
	if max_zoom - min_zoom > 0.001:
		zoom_ratio = clampf((camera_height - min_zoom) / (max_zoom - min_zoom), 0.0, 1.0)
	var extent_ratio: float = lerpf(0.12, 0.32, zoom_ratio)
	return Vector2(
		maxf(2.0, clamped_half_size.x * extent_ratio),
		maxf(2.0, clamped_half_size.y * extent_ratio)
	)

func _node_team_id(node: Node) -> int:
	if node != null and node.has_method("get_team_id"):
		return int(node.call("get_team_id"))
	return 0

func _set_ping_mode_active(active: bool) -> void:
	_ping_targeting_active = active
	if _hud != null and _hud.has_method("set_ping_mode_armed"):
		_hud.call("set_ping_mode_armed", active)
	if active:
		_set_ui_notice(_t("Ping mode: Left click world/minimap to place ping. RMB/ESC cancel."), 1.6)

func _emit_ping(world_position: Vector3, ping_kind: String = "manual", show_notice: bool = true) -> void:
	var map_half_size: Vector2 = _camera_map_half_size()
	var clamped_position: Vector3 = Vector3(
		clampf(world_position.x, -map_half_size.x, map_half_size.x),
		0.0,
		clampf(world_position.z, -map_half_size.y, map_half_size.y)
	)
	var normalized_kind: String = ping_kind.strip_edges().to_lower()
	if normalized_kind == "":
		normalized_kind = "manual"
	var visual_node: Node3D = _create_ping_visual(clamped_position, normalized_kind)
	if _ping_visual_root != null and visual_node != null:
		_ping_visual_root.add_child(visual_node)
	_active_pings.append({
		"position": clamped_position,
		"duration": PING_DURATION,
		"remaining": PING_DURATION,
		"kind": normalized_kind,
		"visual_node": visual_node
	})
	_push_minimap_update()
	if show_notice:
		_set_ui_notice(_t("Ping sent."), 0.8)

func _create_ping_visual(world_position: Vector3, ping_kind: String = "manual") -> Node3D:
	var root: Node3D = Node3D.new()
	root.position = Vector3(world_position.x, PING_VISUAL_HEIGHT, world_position.z)
	root.scale = Vector3.ONE * 0.55
	var is_alert: bool = ping_kind == "alert"
	var ring_color: Color = Color(1.0, 0.34, 0.32, 0.82) if is_alert else Color(1.0, 0.86, 0.35, 0.78)
	var core_color: Color = Color(1.0, 0.44, 0.42, 0.92) if is_alert else Color(1.0, 0.96, 0.62, 0.9)

	var ring: MeshInstance3D = MeshInstance3D.new()
	var ring_mesh: TorusMesh = TorusMesh.new()
	ring_mesh.inner_radius = 0.66
	ring_mesh.outer_radius = 0.9
	ring_mesh.rings = 20
	ring_mesh.ring_segments = 28
	ring.mesh = ring_mesh
	var ring_mat: StandardMaterial3D = StandardMaterial3D.new()
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_mat.albedo_color = ring_color
	ring_mat.emission_enabled = true
	ring_mat.emission = Color(ring_color.r, ring_color.g, ring_color.b, 1.0)
	ring.material_override = ring_mat
	root.add_child(ring)

	var core: MeshInstance3D = MeshInstance3D.new()
	var sphere_mesh: SphereMesh = SphereMesh.new()
	sphere_mesh.radius = 0.18
	sphere_mesh.height = 0.36
	core.mesh = sphere_mesh
	core.position = Vector3(0.0, 0.12, 0.0)
	var core_mat: StandardMaterial3D = StandardMaterial3D.new()
	core_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	core_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	core_mat.albedo_color = core_color
	core_mat.emission_enabled = true
	core_mat.emission = Color(core_color.r, core_color.g, core_color.b, 1.0)
	core.material_override = core_mat
	root.add_child(core)
	return root

func _push_hud_update() -> void:
	if _hud == null or not _hud.has_method("update_hud"):
		_gmhud_log("push_hud_update skipped: hud missing or no update_hud method.", true)
		return
	_debug_hud_push_seq += 1
	var push_seq: int = _debug_hud_push_seq
	var snapshot: Dictionary = _build_hud_snapshot()
	var mode: String = str(snapshot.get("mode", "none"))
	var roles_count: int = 0
	var roles_variant: Variant = snapshot.get("multi_roles", [])
	if roles_variant is Array:
		roles_count = (roles_variant as Array).size()
	_gmhud_log("push_hud_update#%d mode=%s selection_total=%d roles=%d page=%d/%d active_kind=%s" % [
		push_seq,
		mode,
		int(snapshot.get("selection_total", 0)),
		roles_count,
		int(snapshot.get("matrix_page_index", 0)) + 1,
		maxi(1, int(snapshot.get("matrix_page_count", 1))),
		str(snapshot.get("active_subgroup_kind", ""))
	])
	_hud.call("update_hud", snapshot)

func _build_hud_snapshot() -> Dictionary:
	_gmhud_log("build_hud_snapshot begin %s" % _selection_counts_text(), true)
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

	var single_title: String = _t("No Selection")
	var single_detail: String = _t("Select a unit or building to inspect details.")
	var single_armor: String = _t("Armor Type: --")
	var status_health: float = 1.0
	var status_shield: float = 0.0
	var status_energy: float = 0.0

	var show_production: bool = false
	var production_mode: String = "queue"
	var queue_size: int = 0
	var queue_progress: float = 0.0
	var queue_preview: Array[String] = []
	var construction_title: String = ""
	var construction_state_text: String = ""
	var construction_progress_value: float = 0.0
	var construction_icon_path: String = ""
	var construction_glyph: String = "B"

	var portrait_title: String = _t("No Selection")
	var portrait_subtitle: String = "-"
	var portrait_glyph: String = "?"
	var multi_roles: Array[String] = []
	var multi_role_kinds: Array[String] = []
	var multi_role_health_ratios: Array[float] = []
	var control_group_entries: Array[Dictionary] = _build_control_group_entries()
	var matrix_page_index: int = 0
	var matrix_page_count: int = 1

	if mode == "single":
		if _selected_units.size() == 1 and _selected_units[0] != null:
			var unit: Node = _selected_units[0]
			var unit_name: String = _t("Unit")
			if unit.has_method("get_unit_display_name"):
				unit_name = str(unit.call("get_unit_display_name"))
			single_title = unit_name

			var unit_state: String = _t("Idle")
			if unit.has_method("get_mode_label"):
				unit_state = str(unit.call("get_mode_label"))
			var unit_role: String = _t("Soldier")
			var is_worker: bool = false
			if unit.has_method("is_worker_unit"):
				is_worker = bool(unit.call("is_worker_unit"))
			if is_worker:
				unit_role = _t("Worker")
				status_energy = float(unit.call("get_carry_fill_ratio")) if unit.has_method("get_carry_fill_ratio") else 0.0
			status_health = float(unit.call("get_health_ratio")) if unit.has_method("get_health_ratio") else 1.0
			var unit_hp_text: String = "%d%%" % int(round(status_health * 100.0))
			var pending_commands: int = int(unit.call("get_pending_command_count")) if unit.has_method("get_pending_command_count") else 0
			single_detail = _tf("Role: %s\nState: %s\nHP: %s\nCmd Queue: %d", [unit_role, unit_state, unit_hp_text, pending_commands])
			single_armor = _t("Armor Type: Light")

			portrait_title = unit_name
			portrait_subtitle = unit_state
			portrait_glyph = "W" if is_worker else "S"
		elif _selected_buildings.size() == 1 and _selected_buildings[0] != null:
			var building: Node = _selected_buildings[0]
			var building_name: String = _t("Building")
			if building.has_method("get_building_display_name"):
				building_name = str(building.call("get_building_display_name"))
			single_title = building_name
			single_armor = _t("Armor Type: Structure")
			status_health = float(building.call("get_health_ratio")) if building.has_method("get_health_ratio") else 1.0
			var building_hp_text: String = "%d%%" % int(round(status_health * 100.0))
			var under_construction: bool = building.has_method("is_under_construction") and bool(building.call("is_under_construction"))
			if under_construction:
				var construction_paradigm: String = str(building.call("get_construction_paradigm")) if building.has_method("get_construction_paradigm") else "garrisoned"
				var construction_progress: float = clampf(float(building.call("get_construction_progress")) if building.has_method("get_construction_progress") else 0.0, 0.0, 1.0)
				var paused: bool = building.has_method("is_construction_paused") and bool(building.call("is_construction_paused"))
				single_detail = _tf("Construction: %s\nParadigm: %s\nProgress: %d%%\nHP: %s", [
					_t("Paused") if paused else _t("Building"),
					_t(construction_paradigm.capitalize()),
					int(round(construction_progress * 100.0)),
					building_hp_text
				])
				queue_size = 1
				queue_progress = construction_progress
				queue_preview.append(_t("Constructing"))
				show_production = true
				production_mode = "construction"
				construction_title = building_name
				construction_state_text = _t("Paused") if paused else _t("Building")
				construction_progress_value = construction_progress
				var building_kind: String = str(building.get("building_kind")).strip_edges().to_lower()
				construction_icon_path = _construction_icon_path_for_building_kind(building_kind)
				construction_glyph = building_name.substr(0, 1).to_upper() if building_name != "" else "B"
				portrait_subtitle = _tf("Constructing %d%%", [int(round(construction_progress * 100.0))])
			else:
				var can_train_worker: bool = bool(building.call("can_queue_worker_unit")) if building.has_method("can_queue_worker_unit") else false
				var can_train_soldier: bool = bool(building.call("can_queue_soldier_unit")) if building.has_method("can_queue_soldier_unit") else false
				single_detail = _tf("Train Worker: %s\nTrain Soldier: %s", [
					_t("Yes") if can_train_worker else _t("No"),
					_t("Yes") if can_train_soldier else _t("No")
				])
				single_detail += _tf("\nHP: %s", [building_hp_text])

				queue_size = int(building.call("get_queue_size")) if building.has_method("get_queue_size") else 0
				queue_progress = float(building.call("get_production_progress")) if building.has_method("get_production_progress") else 0.0
				if building.has_method("get_queue_preview"):
					var preview_variant: Variant = building.call("get_queue_preview", 5)
					if preview_variant is Array:
						for item in preview_variant:
							queue_preview.append(str(item))
				show_production = queue_size > 0

			portrait_title = building_name
			if not under_construction:
				portrait_subtitle = _tf("Queue %d", [queue_size])
			if building.has_method("get_building_role_tag"):
				portrait_glyph = str(building.call("get_building_role_tag")).substr(0, 1)
			else:
				portrait_glyph = "B"
	elif mode == "multi":
		var page_snapshot: Dictionary = _build_multi_role_page_snapshot(_active_subgroup_kind())
		var roles_value: Variant = page_snapshot.get("roles", [])
		if roles_value is Array:
			for role_value in roles_value:
				multi_roles.append(str(role_value))
		var kinds_value: Variant = page_snapshot.get("kinds", [])
		if kinds_value is Array:
			for kind_value in kinds_value:
				multi_role_kinds.append(str(kind_value))
		var health_ratios_value: Variant = page_snapshot.get("health_ratios", [])
		if health_ratios_value is Array:
			for ratio_value in health_ratios_value:
				multi_role_health_ratios.append(clampf(float(ratio_value), 0.0, 1.0))
		matrix_page_index = int(page_snapshot.get("page_index", 0))
		matrix_page_count = int(page_snapshot.get("page_count", 1))
		portrait_title = _tf("%d Selected", [selection_total])
		portrait_subtitle = _tf("W %d  S %d  B %d", [selected_worker_count, selected_soldier_count, selected_building_count])
		var active_subgroup_kind: String = _active_subgroup_kind()
		if active_subgroup_kind != "":
			portrait_subtitle += _tf(" | Active %s", [_subgroup_kind_label(active_subgroup_kind)])
		portrait_glyph = "%d" % selection_total

	var total_units: int = _count_total_units()
	var queued_units: int = _count_total_queued_units()
	var supply_used: int = total_units + queued_units
	var supply_cap: int = _current_supply_cap()
	var top_legacy_text: String = _tf("M: %d   G: 0   Supply: %d/%d", [_minerals, supply_used, supply_cap])
	var snapshot: Dictionary = {
		"minerals": _minerals,
		"gas": 0,
		"supply_used": supply_used,
		"supply_cap": supply_cap,
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
		"production_mode": production_mode,
		"queue_size": queue_size,
		"queue_progress": queue_progress,
		"queue_preview": queue_preview,
		"construction_title": construction_title,
		"construction_state_text": construction_state_text,
		"construction_progress": construction_progress_value,
		"construction_icon_path": construction_icon_path,
		"construction_glyph": construction_glyph,
		"multi_roles": multi_roles,
		"multi_role_kinds": multi_role_kinds,
		"multi_role_health_ratios": multi_role_health_ratios,
		"control_group_entries": control_group_entries,
		"matrix_page_index": matrix_page_index,
		"matrix_page_count": matrix_page_count,
		"portrait_glyph": portrait_glyph,
		"portrait_title": portrait_title,
		"portrait_subtitle": portrait_subtitle,
		"active_subgroup_kind": _active_subgroup_kind(),
		"subgroup_text": _build_subgroup_text(mode, selection_total),
		"selection_total": selection_total,
		"command_hint": _build_command_hint(),
		"command_entries": _build_command_entries(),
		"notifications": _build_notifications()
	}
	_gmhud_log("build_hud_snapshot end mode=%s selection_total=%d workers=%d soldiers=%d buildings=%d page=%d/%d multi_roles=%d" % [
		mode,
		selection_total,
		selected_worker_count,
		selected_soldier_count,
		selected_building_count,
		matrix_page_index + 1,
		matrix_page_count,
		multi_roles.size()
	], true)
	return snapshot

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
		var placement_state: String = _t("Valid") if _placement_can_place else _t("Invalid")
		var placing_name: String = _placing_kind.capitalize()
		var placing_def: Dictionary = RTS_CATALOG.get_building_def(_placing_kind)
		if not placing_def.is_empty():
			placing_name = str(placing_def.get("display_name", placing_name))
		return _tf("Placing %s (%d): %s | LMB Confirm | Shift+LMB Chain | R Rotate | RMB/ESC Cancel", [placing_name, _placing_cost, placement_state])
	if _build_menu_open:
		return _build_menu_hint_text()
	if _pending_target_skill != "":
		var skill_info: Dictionary = RTS_CATALOG.get_skill_def(_pending_target_skill)
		var skill_label: String = str(skill_info.get("label", _pending_target_skill.capitalize()))
		var target_mode: String = str(skill_info.get("target_mode", "none"))
		if target_mode == "resource":
			return _tf("Targeting %s | Left Click Resource | RMB/ESC Cancel", [skill_label])
		if target_mode == "ground":
			return _tf("Targeting %s | Left Click Ground | RMB/ESC Cancel", [skill_label])
		if target_mode == "friendly_building":
			return _tf("Targeting %s | Left Click Damaged Friendly Unit/Building | RMB/ESC Cancel", [skill_label])
		if target_mode == "unit_or_building":
			return _tf("Targeting %s | Left Click Enemy for focus fire, or Ground for attack-move | RMB/ESC Cancel", [skill_label])
		return _tf("Targeting %s | RMB/ESC Cancel", [skill_label])
	if _selected_units.is_empty() and _selected_buildings.is_empty():
		return _t("No selection | Select worker/builder to open Build Menu | Left drag: Box Select")
	if _selected_buildings.size() == 1 and _selected_units.is_empty():
		var selected_building: Node = _selected_buildings[0]
		if selected_building != null and is_instance_valid(selected_building):
			if selected_building.has_method("is_under_construction") and bool(selected_building.call("is_under_construction")):
				var paradigm: String = str(selected_building.call("get_construction_paradigm")) if selected_building.has_method("get_construction_paradigm") else "garrisoned"
				var progress: float = clampf(float(selected_building.call("get_construction_progress")) if selected_building.has_method("get_construction_progress") else 0.0, 0.0, 1.0)
				var paused: bool = selected_building.has_method("is_construction_paused") and bool(selected_building.call("is_construction_paused"))
				var state_label: String = _t("Paused") if paused else _t("Building")
				return _tf("Construction Site: %s %d%% | %s | Use command card to cancel/exit/select worker.", [state_label, int(round(progress * 100.0)), _t(paradigm.capitalize())])
		if _selection_has_rally_building():
			if _input_state == InputState.QUEUE_INPUT:
				return _tf("Selected Building: %d queue item(s) | Shift held: RMB append rally relay hop (max %d) | Flag: M/G/A/F/R", [queue_size, RALLY_MAX_HOPS])
			return _tf("Selected Building: %d queue item(s) | R/T Train | RMB Set Rally | Shift+RMB Append Relay | Flag: M/G/A/F/R", [queue_size])
		return _tf("Selected Building: %d queue item(s) | R/T: Train by building type", [queue_size])
	if _input_state == InputState.QUEUE_INPUT:
		return _tf("Queue Input: Shift held | Alt+LMB queue marker trims this and later points | W%d S%d B%d", [selected_worker_count, selected_soldier_count, selected_building_count])
	return _tf("Selected -> Worker %d | Soldier %d | Building %d", [selected_worker_count, selected_soldier_count, selected_building_count])

func _build_subgroup_text(mode: String, selection_total: int) -> String:
	var page_suffix: String = _multi_matrix_page_suffix()
	if mode == "multi":
		var subgroup_keys: Array[String] = _selected_unit_subgroup_keys()
		if subgroup_keys.size() > 1:
			var active_kind: String = _active_subgroup_kind()
			if active_kind != "":
				return _tf("Subgroup: %s (%d/%d) | Tab Cycle%s", [_subgroup_kind_label(active_kind), _active_subgroup_index + 1, subgroup_keys.size(), page_suffix])
			return _tf("Subgroup: All (%d types) | Tab Cycle%s", [subgroup_keys.size(), page_suffix])
		return _tf("Subgroup: %d Units%s", [selection_total, page_suffix])
	if mode == "single":
		return _t("Subgroup: Single")
	return _t("Subgroup: None")

func _refresh_subgroup_state(reset_to_all: bool = false) -> void:
	var subgroup_keys: Array[String] = _selected_unit_subgroup_keys()
	_gmhud_log("refresh_subgroup_state reset_to_all=%s subgroup_keys=%s before_index=%d before_page=%d" % [
		str(reset_to_all),
		str(subgroup_keys),
		_active_subgroup_index,
		_multi_matrix_page_index
	], true)
	if subgroup_keys.size() <= 1:
		_active_subgroup_index = -1
		_gmhud_log("refresh_subgroup_state -> no mixed subgroup. index reset to -1, page=%d" % _multi_matrix_page_index, true)
		return
	if reset_to_all:
		_active_subgroup_index = -1
		_multi_matrix_page_index = 0
		_gmhud_log("refresh_subgroup_state -> reset_to_all true, force page_index=0", true)
		return
	if _active_subgroup_index >= subgroup_keys.size():
		_active_subgroup_index = -1
		_gmhud_log("refresh_subgroup_state -> active index overflow, reset to -1", true)

func _cycle_unit_subgroup() -> bool:
	var subgroup_keys: Array[String] = _selected_unit_subgroup_keys()
	if subgroup_keys.size() <= 1:
		_active_subgroup_index = -1
		_set_ui_notice(_t("No mixed unit subgroup to cycle."))
		_play_feedback_tone("error")
		return false
	if _active_subgroup_index < 0:
		_active_subgroup_index = 0
	else:
		_active_subgroup_index = (_active_subgroup_index + 1) % subgroup_keys.size()
	var active_kind: String = _active_subgroup_kind()
	_focus_multi_matrix_page_for_subgroup(active_kind)
	_set_ui_notice(_tf("Subgroup active: %s (%d/%d).", [_subgroup_kind_label(active_kind), _active_subgroup_index + 1, subgroup_keys.size()]))
	_play_feedback_tone("follow")
	return true

func _multi_matrix_page_suffix() -> String:
	var page_count: int = _multi_role_page_count()
	if page_count <= 1:
		return ""
	var page_index: int = clampi(_multi_matrix_page_index, 0, page_count - 1)
	return _tf(" | Page %d/%d PgUp/PgDn", [page_index + 1, page_count])

func _cycle_multi_matrix_page(step: int) -> bool:
	if step == 0:
		return false
	var selection_total: int = _selected_units.size() + _selected_buildings.size()
	if _selection_mode(selection_total) != "multi":
		return false
	var page_count: int = _multi_role_page_count()
	if page_count <= 1:
		_multi_matrix_page_index = 0
		_set_ui_notice(_t("Selection matrix has only one page."))
		_play_feedback_tone("error")
		return true
	_multi_matrix_page_index += step
	while _multi_matrix_page_index < 0:
		_multi_matrix_page_index += page_count
	while _multi_matrix_page_index >= page_count:
		_multi_matrix_page_index -= page_count
	_set_ui_notice(_tf("Selection matrix page %d/%d.", [_multi_matrix_page_index + 1, page_count]), 1.1)
	_play_feedback_tone("ground")
	_push_hud_update()
	return true

func _set_multi_matrix_page(page_index: int) -> bool:
	var selection_total: int = _selected_units.size() + _selected_buildings.size()
	if _selection_mode(selection_total) != "multi":
		_gmhud_log("set_multi_matrix_page ignored: mode=%s selection_total=%d request=%d" % [
			_selection_mode(selection_total),
			selection_total,
			page_index
		], true)
		return false
	var page_count: int = _multi_role_page_count()
	if page_count <= 1:
		_multi_matrix_page_index = 0
		_gmhud_log("set_multi_matrix_page ignored: single page only.", true)
		return false
	var clamped_index: int = clampi(page_index, 0, page_count - 1)
	if clamped_index == _multi_matrix_page_index:
		_gmhud_log("set_multi_matrix_page no-op: already at page=%d/%d" % [_multi_matrix_page_index + 1, page_count], true)
		return false
	_gmhud_log("set_multi_matrix_page %d -> %d (page_count=%d)" % [_multi_matrix_page_index, clamped_index, page_count], true)
	_multi_matrix_page_index = clamped_index
	_set_ui_notice(_tf("Selection matrix page %d/%d.", [_multi_matrix_page_index + 1, page_count]), 1.1)
	_play_feedback_tone("ground")
	_push_hud_update()
	return true

func _active_subgroup_kind() -> String:
	var subgroup_keys: Array[String] = _selected_unit_subgroup_keys()
	if subgroup_keys.size() <= 1:
		return ""
	if _active_subgroup_index < 0 or _active_subgroup_index >= subgroup_keys.size():
		return ""
	return subgroup_keys[_active_subgroup_index]

func _subgroup_kind_label(kind: String) -> String:
	if kind == "":
		return _t("All")
	if kind == "worker":
		return _t("Worker")
	if kind == "soldier":
		return _t("Soldier")
	return _t(kind.capitalize())

func _selected_unit_subgroup_keys() -> Array[String]:
	var keys: Array[String] = []
	for selected_unit in _selected_units:
		if selected_unit == null or not is_instance_valid(selected_unit):
			continue
		if not _is_player_owned(selected_unit):
			continue
		var kind: String = _unit_kind_id(selected_unit)
		if kind == "":
			continue
		if keys.has(kind):
			continue
		keys.append(kind)
	return keys

func _selection_contains_non_player_units() -> bool:
	for selected_unit in _selected_units:
		if selected_unit == null or not is_instance_valid(selected_unit):
			continue
		if not _is_player_owned(selected_unit):
			return true
	return false

func _unit_kind_id(unit_node: Node) -> String:
	if unit_node == null or not is_instance_valid(unit_node):
		return ""
	if unit_node.has_method("get_unit_kind"):
		return str(unit_node.call("get_unit_kind"))
	if unit_node.has_method("is_worker_unit"):
		return "worker" if bool(unit_node.call("is_worker_unit")) else "soldier"
	return "unit"

func _building_kind_id(building_node: Node) -> String:
	if building_node == null or not is_instance_valid(building_node):
		return ""
	var building_kind: String = str(building_node.get("building_kind")).strip_edges().to_lower()
	if building_kind == "":
		return "building"
	return "building:%s" % building_kind

func _select_units_by_kind(unit_kind: String, global_scope: bool) -> int:
	if unit_kind == "":
		return 0
	var selected_count: int = 0
	if global_scope:
		var all_units: Array[Node] = get_tree().get_nodes_in_group("selectable_unit")
		for unit_node in all_units:
			if unit_node == null or not is_instance_valid(unit_node):
				continue
			if not _is_player_owned(unit_node):
				continue
			if _unit_kind_id(unit_node) != unit_kind:
				continue
			_add_selected_unit(unit_node)
			selected_count += 1
		_set_ui_notice(_tf("Global selected: %s x%d.", [_subgroup_kind_label(unit_kind), selected_count]))
		_play_feedback_tone("ground")
		return selected_count

	var viewport: Viewport = get_viewport()
	if viewport == null:
		return 0
	var visible_rect: Rect2 = viewport.get_visible_rect()
	var candidates: Array[Node]
	if _units_root != null:
		candidates = _units_root.get_children()
	else:
		candidates = get_tree().get_nodes_in_group("selectable_unit")
	for unit_node in candidates:
		var unit_3d: Node3D = unit_node as Node3D
		if unit_3d == null:
			continue
		if not _is_player_owned(unit_3d):
			continue
		if _unit_kind_id(unit_3d) != unit_kind:
			continue
		if _camera.is_position_behind(unit_3d.global_position):
			continue
		var screen_pos: Vector2 = _camera.unproject_position(unit_3d.global_position)
		if not visible_rect.has_point(screen_pos):
			continue
		_add_selected_unit(unit_3d)
		selected_count += 1
	_set_ui_notice(_tf("Screen selected: %s x%d.", [_subgroup_kind_label(unit_kind), selected_count]))
	_play_feedback_tone("ground")
	return selected_count

func _command_units() -> Array[Node]:
	var units: Array[Node] = []
	var active_kind: String = _active_subgroup_kind()
	for selected_unit in _selected_units:
		if selected_unit == null or not is_instance_valid(selected_unit):
			continue
		if not _is_player_owned(selected_unit):
			continue
		if active_kind != "" and _unit_kind_id(selected_unit) != active_kind:
			continue
		units.append(selected_unit)
	return units

func _skill_supports_queue_idle_dispatch(skill_id: String) -> bool:
	if skill_id == "":
		return false
	var skill_def: Dictionary = RTS_CATALOG.get_skill_def(skill_id)
	if skill_def.is_empty():
		return false
	return bool(skill_def.get("queue_idle_dispatch", false))

func _is_dispatch_candidate_valid(unit_node: Node) -> bool:
	if unit_node == null or not is_instance_valid(unit_node):
		return false
	if not _is_player_owned(unit_node):
		return false
	if unit_node.has_method("is_alive") and not bool(unit_node.call("is_alive")):
		return false
	return true

func _unit_pending_command_load(unit_node: Node) -> int:
	if not _is_dispatch_candidate_valid(unit_node):
		return 1000000
	if unit_node.has_method("get_pending_command_count"):
		return maxi(0, int(unit_node.call("get_pending_command_count")))
	return 0

func _is_unit_idle_for_queue_idle_dispatch(unit_node: Node) -> bool:
	if not _is_dispatch_candidate_valid(unit_node):
		return false
	if unit_node.has_method("is_construction_locked") and bool(unit_node.call("is_construction_locked")):
		return false
	if unit_node.has_method("is_command_idle"):
		return bool(unit_node.call("is_command_idle"))
	return _unit_pending_command_load(unit_node) <= 0

func _dispatch_distance_sq(unit_node: Node, preferred_position: Vector3, use_preferred_position: bool) -> float:
	if not use_preferred_position:
		return 0.0
	var unit_3d: Node3D = unit_node as Node3D
	if unit_3d == null or not is_instance_valid(unit_3d):
		return INF
	return unit_3d.global_position.distance_squared_to(preferred_position)

func _pick_idle_dispatch_unit(candidates: Array[Node], preferred_position: Vector3, use_preferred_position: bool = true) -> Node:
	var selected: Node = null
	var best_distance_sq: float = INF
	for unit_node in candidates:
		if not _is_unit_idle_for_queue_idle_dispatch(unit_node):
			continue
		var distance_sq: float = _dispatch_distance_sq(unit_node, preferred_position, use_preferred_position)
		if selected == null or distance_sq < best_distance_sq:
			selected = unit_node
			best_distance_sq = distance_sq
	return selected

func _pick_least_loaded_dispatch_unit(candidates: Array[Node], preferred_position: Vector3, use_preferred_position: bool = true) -> Node:
	var selected: Node = null
	var best_load: int = 1000000
	var best_distance_sq: float = INF
	for unit_node in candidates:
		if not _is_dispatch_candidate_valid(unit_node):
			continue
		var load: int = _unit_pending_command_load(unit_node)
		var distance_sq: float = _dispatch_distance_sq(unit_node, preferred_position, use_preferred_position)
		if selected == null or load < best_load or (load == best_load and distance_sq < best_distance_sq):
			selected = unit_node
			best_load = load
			best_distance_sq = distance_sq
	return selected

func _resolve_queue_idle_dispatch_target(
	skill_id: String,
	candidates: Array[Node],
	queue_command: bool,
	preferred_position: Vector3 = Vector3.ZERO,
	use_preferred_position: bool = true
) -> Dictionary:
	if not queue_command:
		return {}
	if not _skill_supports_queue_idle_dispatch(skill_id):
		return {}
	var idle_unit: Node = _pick_idle_dispatch_unit(candidates, preferred_position, use_preferred_position)
	if idle_unit != null:
		return {
			"unit": idle_unit,
			"queue_for_unit": false
		}
	var queued_unit: Node = _pick_least_loaded_dispatch_unit(candidates, preferred_position, use_preferred_position)
	if queued_unit == null:
		return {}
	return {
		"unit": queued_unit,
		"queue_for_unit": true
	}

func _selected_worker_units() -> Array[Node]:
	var workers: Array[Node] = []
	for unit_node in _command_units():
		if not unit_node.has_method("is_worker_unit"):
			continue
		if not bool(unit_node.call("is_worker_unit")):
			continue
		workers.append(unit_node)
	return workers

func _resolve_build_order_worker(target_position: Vector3, queue_command: bool) -> Dictionary:
	var workers: Array[Node] = _selected_worker_units()
	if workers.is_empty():
		return {}
	var dispatch_target: Dictionary = _resolve_queue_idle_dispatch_target(
		_placing_skill_id,
		workers,
		queue_command,
		target_position,
		true
	)
	if not dispatch_target.is_empty():
		return dispatch_target
	var nearest_worker: Node3D = _nearest_selected_worker(target_position)
	if nearest_worker == null:
		return {}
	return {
		"unit": nearest_worker,
		"queue_for_unit": queue_command
	}

func _build_command_hint() -> String:
	if _ui_notice_timer > 0.0 and _ui_notice_text != "":
		return _ui_notice_text
	if _queue_reject_feedback_timer > 0.0:
		return _t("Queue is full (max 32). Command rejected.")
	if _rally_reject_feedback_timer > 0.0:
		return _tf("Rally relay chain is full (max %d hops).", [RALLY_MAX_HOPS])
	if _match_notice != "":
		return _match_notice
	if _placing_building:
		return _t("Placement mode active. LMB confirm, Shift+LMB chain build, R rotate, RMB/ESC cancel.")
	if _build_menu_open:
		return _t("Build menu open. Select a building option or press ESC to close.")
	if _pending_target_skill != "":
		return _t("Targeted skill armed. Left click world target, RMB/ESC to cancel.")
	if _ping_targeting_active:
		return _t("Ping mode active. Left click world/minimap to ping, RMB/ESC cancel.")
	if _input_state == InputState.QUEUE_INPUT:
		return _t("Queue input active. Shift-held commands are appended.")
	if _selection_has_construction_exit_worker():
		return _t("Worker is garrisoned in construction. ESC or Exit Build releases worker; other commands are queued.")
	if not _selected_construction_sites().is_empty():
		return _t("Construction site selected. Use command card for cancel/eject/select-worker operations.")
	if not _pending_build_orders.is_empty():
		return _tf("Constructing: %d active worker build order(s).", [_pending_build_orders.size()])
	if not _active_research.is_empty():
		return _active_research_hint_text()
	if _selected_buildings.size() == 1 and _selected_units.is_empty():
		if _selection_has_rally_building():
			return _t("Click command cards / hotkeys for production. RMB sets rally point (M/G/A/F/R flag + tone).")
		return _t("Click command cards or use hotkeys for production/build commands.")
	if not _selected_units.is_empty():
		var active_kind: String = _active_subgroup_kind()
		if active_kind != "":
			return _tf("Subgroup active: %s | Tab cycles subgroup | Commands apply to active subgroup only.", [_subgroup_kind_label(active_kind)])
		return _t("RMB context command or click move/gather/stop in command card.")
	return _t("Select something to open context commands.")

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
		return _t("Research in progress.")
	var tech_name: String = _tech_display_name(best_tech_id)
	var rounded_remaining: int = int(ceil(best_remaining))
	if _active_research.size() > 1:
		return _tf("Researching %s (%ds). +%d more active.", [tech_name, rounded_remaining, _active_research.size() - 1])
	return _tf("Researching %s (%ds remaining).", [tech_name, rounded_remaining])

func _open_build_menu() -> void:
	_build_menu_open = true
	_build_menu_group = BUILD_MENU_GROUP_ROOT
	_pending_target_skill = ""

func _close_build_menu() -> void:
	_build_menu_open = false
	_build_menu_group = BUILD_MENU_GROUP_ROOT

func _set_build_menu_group(group: String) -> void:
	_build_menu_group = _normalize_build_menu_group(group)
	if _build_menu_group == BUILD_MENU_GROUP_ROOT:
		_build_menu_open = true
		return
	if _build_menu_skill_ids().is_empty():
		_build_menu_group = BUILD_MENU_GROUP_ROOT
		_build_menu_open = true
		return
	_build_menu_open = true

func _normalize_build_menu_group(group: String) -> String:
	var normalized: String = group.strip_edges().to_lower()
	if normalized == BUILD_MENU_GROUP_GARRISONED:
		return BUILD_MENU_GROUP_GARRISONED
	if normalized == BUILD_MENU_GROUP_SUMMONING:
		return BUILD_MENU_GROUP_SUMMONING
	if normalized == BUILD_MENU_GROUP_INCORPORATED:
		return BUILD_MENU_GROUP_INCORPORATED
	return BUILD_MENU_GROUP_ROOT

func _build_menu_group_command_id(group: String) -> String:
	match _normalize_build_menu_group(group):
		BUILD_MENU_GROUP_GARRISONED:
			return "build_menu_garrisoned"
		BUILD_MENU_GROUP_SUMMONING:
			return "build_menu_summoning"
		BUILD_MENU_GROUP_INCORPORATED:
			return "build_menu_incorporated"
		_:
			return ""

func _build_menu_group_for_skill(skill_id: String) -> String:
	var build_kind: String = RTS_CATALOG.get_build_kind_from_skill(skill_id)
	if build_kind == "":
		return BUILD_MENU_GROUP_ROOT
	var paradigm: String = _building_construction_paradigm(build_kind)
	match paradigm:
		"summoning":
			return BUILD_MENU_GROUP_SUMMONING
		"incorporated":
			return BUILD_MENU_GROUP_INCORPORATED
		_:
			return BUILD_MENU_GROUP_GARRISONED

func _build_skill_detail_text(skill_id: String) -> String:
	var build_kind: String = RTS_CATALOG.get_build_kind_from_skill(skill_id)
	if build_kind == "":
		return ""
	var building_def: Dictionary = RTS_CATALOG.get_building_def(build_kind)
	if building_def.is_empty():
		return ""
	var paradigm: String = str(building_def.get("construction_paradigm", "garrisoned")).strip_edges().to_lower()
	var paradigm_label: String = _t(paradigm.capitalize())
	var build_time: float = maxf(0.0, float(building_def.get("build_time", 0.0)))
	var refund_ratio: float = clampf(float(building_def.get("cancel_refund_ratio", 0.75)), 0.0, 1.0)
	var refund_percent: int = int(round(refund_ratio * 100.0))
	return _tf("Type: %s | Build: %.1fs | Cancel Refund: %d%%", [paradigm_label, build_time, refund_percent])

func _build_menu_hint_text() -> String:
	var parts: Array[String] = []
	var visible_skill_ids: Array[String] = _build_menu_skill_ids()
	for skill_id in visible_skill_ids:
		var skill_def: Dictionary = RTS_CATALOG.get_skill_def(skill_id)
		var label: String = str(skill_def.get("label", skill_id.capitalize()))
		var hotkey: String = str(skill_def.get("hotkey", "")).strip_edges().to_upper()
		var text: String = label
		if hotkey != "":
			text = "%s %s" % [hotkey, text]
		parts.append(text)
	if parts.is_empty():
		return _t("Build Menu: No available options | ESC Back")
	var section_label: String = _t("Categories")
	match _build_menu_group:
		BUILD_MENU_GROUP_GARRISONED:
			section_label = _t("Garrisoned")
		BUILD_MENU_GROUP_SUMMONING:
			section_label = _t("Summoning")
		BUILD_MENU_GROUP_INCORPORATED:
			section_label = _t("Incorporated")
	return _tf("Build Menu [%s]: %s | ESC Back", [section_label, ", ".join(parts)])

func _build_command_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	if _placing_building:
		entries.append(_command_entry("placement_confirm", {
			"enabled": _placement_can_place and _minerals >= _placing_cost,
			"cost_text": str(_placing_cost)
		}))
		entries.append(_command_entry("placement_rotate"))
		entries.append(_command_entry("placement_cancel"))
		return entries

	if _build_menu_open:
		if not _can_open_build_menu():
			_close_build_menu()
		else:
			var build_menu_entries: Array[String] = _build_menu_skill_ids()
			if build_menu_entries.is_empty() and _build_menu_group != BUILD_MENU_GROUP_ROOT:
				_build_menu_group = BUILD_MENU_GROUP_ROOT
				build_menu_entries = _build_menu_skill_ids()
			for skill_id in build_menu_entries:
				entries.append(_build_menu_command_entry(skill_id))
			if _build_menu_group != BUILD_MENU_GROUP_ROOT:
				entries.append(_command_entry("build_menu_back"))
			entries.append(_command_entry("close_menu"))
			return entries

	var skill_ids: Array[String] = _selection_skill_ids()
	for skill_id in skill_ids:
		entries.append(_command_entry(skill_id, _command_overrides_for(skill_id)))
	if not _collect_target_construction_sites(false, true, "", true).is_empty():
		_append_command_entry_if_missing(entries, "construction_cancel_destroy")
	return entries

func _command_entry(skill_id: String, overrides: Dictionary = {}) -> Dictionary:
	return RTS_CATALOG.make_command_entry(skill_id, overrides)

func _append_command_entry_if_missing(entries: Array[Dictionary], command_id: String) -> void:
	for entry in entries:
		if str(entry.get("id", "")) == command_id:
			return
	entries.append(_command_entry(command_id, _command_overrides_for(command_id)))

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
		"detail_text": _build_skill_detail_text(command_id),
		"disabled_reason": reason
	})

func _build_menu_skill_ids() -> Array[String]:
	var available_skills: Array[String] = _build_menu_available_skill_ids()
	if _build_menu_group == BUILD_MENU_GROUP_ROOT:
		var root_entries: Array[String] = []
		var has_garrisoned: bool = false
		var has_summoning: bool = false
		var has_incorporated: bool = false
		for skill_id in available_skills:
			match _build_menu_group_for_skill(skill_id):
				BUILD_MENU_GROUP_SUMMONING:
					has_summoning = true
				BUILD_MENU_GROUP_INCORPORATED:
					has_incorporated = true
				_:
					has_garrisoned = true
		if has_garrisoned:
			root_entries.append(_build_menu_group_command_id(BUILD_MENU_GROUP_GARRISONED))
		if has_summoning:
			root_entries.append(_build_menu_group_command_id(BUILD_MENU_GROUP_SUMMONING))
		if has_incorporated:
			root_entries.append(_build_menu_group_command_id(BUILD_MENU_GROUP_INCORPORATED))
		return root_entries

	var filtered: Array[String] = []
	for skill_id in available_skills:
		if _build_menu_group_for_skill(skill_id) == _build_menu_group:
			filtered.append(skill_id)
	return filtered

func _build_menu_available_skill_ids() -> Array[String]:
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
		for selected_unit in _command_units():
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
			overrides["detail_text"] = _t("Open categorized build options (Garrisoned / Summoning / Incorporated).")
			overrides["disabled_reason"] = "" if build_menu_enabled else _build_menu_disabled_reason()
		"gather":
			var gather_enabled: bool = _selection_has_worker()
			overrides["enabled"] = gather_enabled
			overrides["disabled_reason"] = "" if gather_enabled else _t("Requires at least one worker in selection.")
		"repair":
			var repair_enabled: bool = _selection_has_worker()
			overrides["enabled"] = repair_enabled
			overrides["disabled_reason"] = "" if repair_enabled else _t("Requires at least one worker in selection.")
		"return_resource":
			var has_worker_cargo: bool = _selection_has_worker_cargo()
			overrides["enabled"] = has_worker_cargo
			overrides["disabled_reason"] = "" if has_worker_cargo else _t("Selected workers are not carrying minerals.")
		"attack":
			var attack_enabled: bool = _selection_has_combat_unit()
			overrides["enabled"] = attack_enabled
			overrides["disabled_reason"] = "" if attack_enabled else _t("Requires at least one combat unit.")
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
		"construction_exit":
			var can_exit_construction: bool = _selection_has_construction_exit_worker()
			overrides["enabled"] = can_exit_construction
			overrides["disabled_reason"] = "" if can_exit_construction else _t("Select a garrisoned worker to exit construction.")
		"construction_cancel_destroy":
			var destroy_sites: Array[Node] = _collect_target_construction_sites(true, true)
			var has_construction_site: bool = false
			for site_node in destroy_sites:
				if _construction_site_paradigm(site_node) == "incorporated":
					continue
				has_construction_site = true
				break
			overrides["enabled"] = has_construction_site
			overrides["disabled_reason"] = "" if has_construction_site else _t("Select a construction site or a locked worker.")
		"construction_cancel_eject":
			var has_incorporated_site: bool = not _collect_target_construction_sites(true, true, "incorporated").is_empty()
			overrides["enabled"] = has_incorporated_site
			overrides["disabled_reason"] = "" if has_incorporated_site else _t("Select an incorporated construction site or a locked worker.")
		"construction_select_worker":
			var can_select_worker: bool = false
			if _selected_buildings.size() == 1:
				var selected_building: Node = _selected_buildings[0]
				if selected_building != null and is_instance_valid(selected_building) and selected_building.has_method("get_construction_assigned_worker_path"):
					var worker_path: NodePath = selected_building.call("get_construction_assigned_worker_path") as NodePath
					if str(worker_path) != "":
						var worker_node: Node = get_node_or_null(worker_path)
						can_select_worker = worker_node != null and is_instance_valid(worker_node)
			overrides["enabled"] = can_select_worker
			overrides["disabled_reason"] = "" if can_select_worker else _t("Assigned worker is unavailable.")
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
		_t("B: Build Menu | Open build options from selected builder"),
		_tf("R: Train Worker (%d) | T: Train Soldier (%d) | A: Attack/Attack-Move | S: Stop | Tab: Subgroup Cycle", [_worker_cost, _soldier_cost]),
		_t("RMB Smart: Attack>Gather>Return>Repair>Follow>Rally>Move | Shift+RMB Queue | Ctrl+0-9 Set Group | Shift+0-9 Append | 0-9 Select/DoubleTap Focus | Matrix: LMB isolate / Shift+LMB same type / Ctrl+LMB remove")
	]
	if _multi_role_page_count() > 1:
		lines[2] += _t(" | PgUp/PgDn Selection Page")
	if _queue_reject_feedback_timer > 0.0:
		lines[0] = _t("Queue full: max 32 commands per unit.")
	if _rally_reject_feedback_timer > 0.0:
		lines[0] = _tf("Rally relay full: max %d hops per building.", [RALLY_MAX_HOPS])
	if _ui_notice_timer > 0.0 and _ui_notice_text != "":
		lines[0] = _ui_notice_text
	if _match_notice != "":
		lines[0] = _match_notice
		lines[1] = _tf("Match Rule: %s", [_match_outcome_rule_id])
		lines[2] = _t("Notify-only mode for testing.")
		return lines
	if _placing_building:
		var state: String = _t("valid") if _placement_can_place else _t("invalid")
		lines[0] = _tf("Placement %s | Cost: %d | R Rotate | Shift+LMB Chain", [state, _placing_cost])
	elif not _pending_build_orders.is_empty():
		lines[0] = _tf("Worker construction active: %d order(s).", [_pending_build_orders.size()])
	elif _build_menu_open:
		lines[0] = _build_menu_hint_text()
	elif _pending_target_skill != "":
		var skill_info: Dictionary = RTS_CATALOG.get_skill_def(_pending_target_skill)
		lines[0] = _tf("Targeting: %s", [str(skill_info.get("label", _pending_target_skill))])
	elif not _active_research.is_empty():
		lines[0] = _active_research_hint_text()
		lines[1] = _tf("Unlocked Tech: %d | Active Research: %d", [_unlocked_techs.size(), _active_research.size()])
	return lines

func _build_multi_role_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for selected_unit in _selected_units:
		if selected_unit == null or not is_instance_valid(selected_unit):
			continue
		if not _is_player_owned(selected_unit):
			continue
		var role_tag: String = "U"
		if selected_unit.has_method("get_unit_role_tag"):
			role_tag = str(selected_unit.call("get_unit_role_tag"))
		entries.append({
			"role": role_tag,
			"kind": _unit_kind_id(selected_unit),
			"node": selected_unit
		})

	for selected_building in _selected_buildings:
		if selected_building == null or not is_instance_valid(selected_building):
			continue
		if not _is_player_owned(selected_building):
			continue
		var role: String = _t("Building")
		if selected_building.has_method("get_building_role_tag"):
			role = str(selected_building.call("get_building_role_tag"))
		entries.append({
			"role": role,
			"kind": _building_kind_id(selected_building),
			"node": selected_building
		})
	return entries

func _multi_role_page_count() -> int:
	var total_entries: int = _build_multi_role_entries().size()
	if total_entries <= 0:
		return 1
	return maxi(1, int(ceil(float(total_entries) / float(HUD_MULTI_MAX))))

func _focus_multi_matrix_page_for_subgroup(subgroup_kind: String) -> void:
	if subgroup_kind == "":
		return
	var entries: Array[Dictionary] = _build_multi_role_entries()
	for i in entries.size():
		var entry: Dictionary = entries[i]
		if str(entry.get("kind", "")) != subgroup_kind:
			continue
		_multi_matrix_page_index = i / HUD_MULTI_MAX
		return

func _build_multi_role_page_snapshot(active_subgroup_kind: String = "") -> Dictionary:
	var entries: Array[Dictionary] = _build_multi_role_entries()

	var total_entries: int = entries.size()
	var page_count: int = 1
	if total_entries > 0:
		page_count = maxi(1, int(ceil(float(total_entries) / float(HUD_MULTI_MAX))))
	var before_page_index: int = _multi_matrix_page_index
	_multi_matrix_page_index = clampi(_multi_matrix_page_index, 0, page_count - 1)
	if before_page_index != _multi_matrix_page_index:
		_gmhud_log("build_multi_role_page_snapshot clamped page_index %d -> %d (page_count=%d total_entries=%d)" % [
			before_page_index,
			_multi_matrix_page_index,
			page_count,
			total_entries
		], true)
	var start_index: int = _multi_matrix_page_index * HUD_MULTI_MAX
	var end_index: int = mini(total_entries, start_index + HUD_MULTI_MAX)
	var roles: Array[String] = []
	var kinds: Array[String] = []
	var health_ratios: Array[float] = []
	for i in range(start_index, end_index):
		var entry: Dictionary = entries[i]
		roles.append(str(entry.get("role", "")))
		kinds.append(str(entry.get("kind", "")))
		var health_ratio: float = 1.0
		var entry_node_value: Variant = entry.get("node", null)
		if entry_node_value is Node:
			var entry_node: Node = entry_node_value as Node
			if entry_node != null and is_instance_valid(entry_node) and entry_node.has_method("get_health_ratio"):
				health_ratio = clampf(float(entry_node.call("get_health_ratio")), 0.0, 1.0)
		health_ratios.append(health_ratio)

	var page_text: String = _tf("Page %d/%d", [_multi_matrix_page_index + 1, page_count])
	if total_entries > 0:
		page_text += _tf(" (%d-%d/%d)", [start_index + 1, end_index, total_entries])
	if page_count > 1:
		page_text += _t(" | PgUp/PgDn")
	if active_subgroup_kind != "":
		page_text += _tf(" | Active %s", [_subgroup_kind_label(active_subgroup_kind)])
	_gmhud_log("build_multi_role_page_snapshot page=%d/%d range=%d-%d total=%d active_kind=%s" % [
		_multi_matrix_page_index + 1,
		page_count,
		start_index + 1 if total_entries > 0 else 0,
		end_index,
		total_entries,
		active_subgroup_kind
	], true)
	return {
		"roles": roles,
		"kinds": kinds,
		"health_ratios": health_ratios,
		"page_text": page_text,
		"page_index": _multi_matrix_page_index,
		"total_entries": total_entries,
		"page_count": page_count
	}

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
		if building_node.has_method("get_queued_unit_count"):
			count += int(building_node.call("get_queued_unit_count"))
		elif building_node.has_method("get_queue_size"):
			count += int(building_node.call("get_queue_size"))
	return count

func _building_supply_bonus(building_kind: String) -> int:
	if building_kind == "":
		return 0
	var building_def: Dictionary = RTS_CATALOG.get_building_def(building_kind)
	return maxi(0, int(building_def.get("supply_bonus", 0)))

func _count_supply_bonus_from_buildings() -> int:
	var total_bonus: int = 0
	var buildings: Array[Node] = get_tree().get_nodes_in_group("selectable_building")
	for building_node in buildings:
		if building_node == null or not is_instance_valid(building_node):
			continue
		if not _is_player_owned(building_node):
			continue
		if building_node.has_method("is_alive") and not bool(building_node.call("is_alive")):
			continue
		if building_node.has_method("is_under_construction") and bool(building_node.call("is_under_construction")):
			continue
		var kind: String = str(building_node.get("building_kind"))
		total_bonus += _building_supply_bonus(kind)
	return maxi(0, total_bonus)

func _current_supply_cap() -> int:
	return maxi(1, SUPPLY_CAP + _count_supply_bonus_from_buildings())

func _has_supply_for(extra_units: int = 1) -> bool:
	if extra_units <= 0:
		return true
	return _count_total_units() + _count_total_queued_units() + extra_units <= _current_supply_cap()

func _selection_has_worker() -> bool:
	for selected_unit in _command_units():
		if selected_unit.has_method("is_worker_unit") and bool(selected_unit.call("is_worker_unit")):
			return true
	return false

func _selection_has_construction_exit_worker() -> bool:
	for selected_unit in _selected_units:
		if selected_unit == null or not is_instance_valid(selected_unit):
			continue
		if not _is_player_owned(selected_unit):
			continue
		if not selected_unit.has_method("is_construction_locked"):
			continue
		if not bool(selected_unit.call("is_construction_locked")):
			continue
		if not selected_unit.has_method("get_construction_lock_mode"):
			continue
		if str(selected_unit.call("get_construction_lock_mode")) == "garrisoned":
			return true
	return false

func _selection_has_worker_cargo() -> bool:
	for selected_unit in _command_units():
		if not selected_unit.has_method("is_worker_unit"):
			continue
		if not bool(selected_unit.call("is_worker_unit")):
			continue
		if selected_unit.has_method("has_cargo") and bool(selected_unit.call("has_cargo")):
			return true
	return false

func _selection_has_combat_unit() -> bool:
	for selected_unit in _command_units():
		if selected_unit.has_method("is_worker_unit") and not bool(selected_unit.call("is_worker_unit")):
			return true
	return false

func _selection_has_rally_building() -> bool:
	if not _selected_units.is_empty():
		return false
	for selected_building in _selected_buildings:
		if selected_building == null or not is_instance_valid(selected_building):
			continue
		if not _is_player_owned(selected_building):
			continue
		if selected_building.has_method("supports_rally_point") and bool(selected_building.call("supports_rally_point")):
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
		return _t("Finish or cancel current placement first.")
	if _selected_units.is_empty() and _selected_buildings.is_empty():
		return _t("Select a worker or builder building to open build commands.")
	if not _selected_units.is_empty() and not _selection_has_worker():
		return _t("Requires at least one worker in selection.")
	if _selected_units.is_empty() and not _selected_buildings.is_empty() and not _building_selection_has_skill("build_menu"):
		return _t("Selected buildings cannot build structures.")
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
		parts.append(_tf("Buildings: %s", [", ".join(missing_buildings)]))
	var missing_techs: Array[String] = _missing_required_techs(required_techs)
	if not missing_techs.is_empty():
		parts.append(_tf("Tech: %s", [", ".join(missing_techs)]))
	if parts.is_empty():
		return ""
	return _tf("Locked - %s", [" | ".join(parts)])

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
		missing.append(_tf("%s (%d/%d)", [display_name, current_count, required_count]))
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
	return str(building_def.get("display_name", _t(building_kind.capitalize())))

func _construction_icon_path_for_building_kind(building_kind: String) -> String:
	var normalized_kind: String = building_kind.strip_edges().to_lower()
	if normalized_kind == "":
		return ""
	var candidate_skill_ids: Array[String] = []
	candidate_skill_ids.append_array(RTS_CATALOG.get_unit_build_skill_ids("worker"))
	candidate_skill_ids.append_array(RTS_CATALOG.get_building_build_skill_ids("base"))
	for skill_id in candidate_skill_ids:
		if RTS_CATALOG.get_build_kind_from_skill(skill_id).strip_edges().to_lower() != normalized_kind:
			continue
		var skill_def: Dictionary = RTS_CATALOG.get_skill_def(skill_id)
		var icon_path: String = str(skill_def.get("icon_path", "")).strip_edges()
		if icon_path != "":
			return icon_path
	return ""

func _tech_display_name(tech_id: String) -> String:
	var tech_def: Dictionary = RTS_CATALOG.get_tech_def(tech_id)
	return str(tech_def.get("display_name", _t(tech_id.capitalize())))

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
	var normalized: String = tech_id.strip_edges()
	if normalized == "":
		return false
	var buildings: Array[Node] = get_tree().get_nodes_in_group("selectable_building")
	for building_node in buildings:
		if building_node == null or not is_instance_valid(building_node):
			continue
		if not _is_player_owned(building_node):
			continue
		if not building_node.has_method("has_tech_in_queue"):
			continue
		if bool(building_node.call("has_tech_in_queue", normalized)):
			return true
	return _active_research.has(normalized)

func _research_skill_block_reason(skill_id: String) -> String:
	var tech_id: String = RTS_CATALOG.get_tech_id_from_skill(skill_id)
	if tech_id == "":
		return _t("Unknown research command.")
	if not _selection_has_skill(skill_id):
		return _t("Selected buildings cannot perform this research.")
	if has_tech(tech_id):
		return _t("Already researched.")
	if _is_tech_researching(tech_id):
		return _t("Research in progress.")
	var requirement_reason: String = _requirements_reason_for_tech(tech_id)
	if requirement_reason != "":
		return requirement_reason
	var research_cost: int = RTS_CATALOG.get_tech_cost(tech_id)
	if research_cost <= 0:
		return _t("Invalid research cost.")
	if _minerals < research_cost:
		return _t("Not enough minerals.")
	if _find_selected_research_queue_building(tech_id) == null:
		return _t("All selected research queues are full.")
	return ""

func _find_selected_research_queue_building(tech_id: String) -> Node:
	var normalized: String = tech_id.strip_edges()
	if normalized == "":
		return null
	for selected_building in _selected_buildings:
		if selected_building == null or not is_instance_valid(selected_building):
			continue
		if not _is_player_owned(selected_building):
			continue
		if not selected_building.has_method("can_queue_research_tech"):
			continue
		if bool(selected_building.call("can_queue_research_tech", normalized)):
			return selected_building
	return null

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
	var source_building: Node = _find_selected_research_queue_building(tech_id)
	if source_building == null:
		return false
	var research_cost: int = RTS_CATALOG.get_tech_cost(tech_id)
	if not try_spend_minerals(research_cost):
		return false
	var research_time: float = RTS_CATALOG.get_tech_research_time(tech_id)
	if research_time <= 0.0:
		unlock_tech(tech_id)
		return true
	if not source_building.has_method("queue_research_tech"):
		add_minerals(research_cost)
		return false
	var queued: bool = bool(source_building.call("queue_research_tech", tech_id, research_time))
	if not queued:
		add_minerals(research_cost)
		return false
	_process_active_research(0.0)
	return true

func _can_start_build_skill(skill_id: String) -> bool:
	return _build_skill_block_reason(skill_id) == ""

func _build_skill_block_reason(skill_id: String) -> String:
	if not _can_open_build_menu():
		return _build_menu_disabled_reason()
	var build_kind: String = RTS_CATALOG.get_build_kind_from_skill(skill_id)
	if build_kind == "":
		return _t("Unknown build skill.")
	var requirement_reason: String = _requirements_reason_for_building_kind(build_kind)
	if requirement_reason != "":
		return requirement_reason
	var build_cost: int = _building_cost(build_kind)
	if build_cost <= 0:
		return _t("Invalid build cost.")
	if _minerals < build_cost:
		return _t("Not enough minerals.")
	return ""

func _can_train_worker_from_selection() -> bool:
	return _train_block_reason("worker", _t("Worker"), _worker_cost) == ""

func _can_train_soldier_from_selection() -> bool:
	return _train_block_reason("soldier", _t("Soldier"), _soldier_cost) == ""

func _train_worker_block_reason() -> String:
	return _train_block_reason("worker", _t("Worker"), _worker_cost)

func _train_soldier_block_reason() -> String:
	return _train_block_reason("soldier", _t("Soldier"), _soldier_cost)

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
		return _tf("No selected building can train %s.", [label])
	var requirement_reason: String = _requirements_reason_for_unit_kind(unit_kind)
	if requirement_reason != "":
		return requirement_reason
	if _all_trainers_queue_full(unit_kind):
		return _t("All production queues are full.")
	if _minerals < cost:
		return _t("Not enough minerals.")
	if not _has_supply_for(1):
		return _t("Supply is capped.")
	if not _has_available_trainer_for_kind(unit_kind):
		return _tf("No available trainer for %s.", [label])
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

func _is_repairable_friendly_target(node: Node) -> bool:
	if node == null or not is_instance_valid(node):
		return false
	var selectable: bool = node.is_in_group("selectable_unit") or node.is_in_group("selectable_building")
	if not selectable:
		return false
	if not _is_player_owned(node):
		return false
	if node.has_method("is_alive") and not bool(node.call("is_alive")):
		return false
	if not node.has_method("repair"):
		return false
	if node.has_method("is_damaged"):
		return bool(node.call("is_damaged"))
	if not node.has_method("get_health_points"):
		return false
	var max_hp: float = float(node.get("max_health"))
	if max_hp <= 0.0:
		return false
	var hp: float = float(node.call("get_health_points"))
	return hp < max_hp - 0.01

func _is_repairable_friendly_building(node: Node) -> bool:
	return _is_repairable_friendly_target(node)

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
	for i in range(_selected_buildings.size() - 1, -1, -1):
		var node: Node = _selected_buildings[i]
		if node == null or not is_instance_valid(node):
			_selected_buildings.remove_at(i)
			continue
		if not _is_player_owned(node):
			if node.has_method("set_selected"):
				node.call("set_selected", false)
			_selected_buildings.remove_at(i)
	if _hovered_unit != null and not is_instance_valid(_hovered_unit):
		_hovered_unit = null

func _on_hud_command_pressed(command_id: String) -> void:
	_execute_command(command_id)

func _on_hud_multi_role_cell_pressed(cell_index: int, shift_pressed: bool, ctrl_pressed: bool) -> void:
	_gmhud_log("hud_multi_role_cell_pressed cell=%d shift=%s ctrl=%s page=%d %s" % [
		cell_index,
		str(shift_pressed),
		str(ctrl_pressed),
		_multi_matrix_page_index,
		_selection_counts_text()
	], true)
	var entry: Dictionary = _resolve_multi_role_entry_from_cell(cell_index)
	if entry.is_empty():
		_gmhud_log("hud_multi_role_cell_pressed ignored: empty entry for cell=%d page=%d" % [cell_index, _multi_matrix_page_index], true)
		return
	var target_node: Node = entry.get("node") as Node
	if target_node == null or not is_instance_valid(target_node):
		return
	var entry_kind: String = str(entry.get("kind", ""))

	if ctrl_pressed:
		if _remove_multi_role_entry_from_selection(target_node):
			_set_ui_notice(_tf("Removed: %s.", [_multi_role_kind_label(entry_kind, target_node)]), 1.1)
			_play_feedback_tone("ground")
			_refresh_hint_label()
			_gmhud_log_selection("hud_multi_role_cell_pressed ctrl-remove")
		return

	if shift_pressed:
		var selected_count: int = _select_same_multi_role_kind(entry_kind)
		if selected_count > 0:
			_set_ui_notice(_tf("Selected: %s x%d.", [_multi_role_kind_label(entry_kind, target_node), selected_count]), 1.1)
			_play_feedback_tone("follow")
			_refresh_hint_label()
			_gmhud_log_selection("hud_multi_role_cell_pressed shift-select")
		return

	if _select_only_multi_role_entry(target_node):
		_set_ui_notice(_tf("Selected: %s.", [_multi_role_kind_label(entry_kind, target_node)]), 1.1)
		_play_feedback_tone("ground")
		_refresh_hint_label()
		_gmhud_log_selection("hud_multi_role_cell_pressed single-select")

func _resolve_multi_role_entry_from_cell(cell_index: int) -> Dictionary:
	if cell_index < 0 or cell_index >= HUD_MULTI_MAX:
		_gmhud_log("resolve_multi_role_entry_from_cell invalid cell_index=%d" % cell_index, true)
		return {}
	var entries: Array[Dictionary] = _build_multi_role_entries()
	var global_index: int = _multi_matrix_page_index * HUD_MULTI_MAX + cell_index
	if global_index < 0 or global_index >= entries.size():
		_gmhud_log("resolve_multi_role_entry_from_cell out of range: cell=%d global=%d page=%d entries=%d" % [
			cell_index,
			global_index,
			_multi_matrix_page_index,
			entries.size()
		], true)
		return {}
	_gmhud_log("resolve_multi_role_entry_from_cell cell=%d global=%d page=%d kind=%s role=%s" % [
		cell_index,
		global_index,
		_multi_matrix_page_index,
		str(entries[global_index].get("kind", "")),
		str(entries[global_index].get("role", ""))
	], true)
	return entries[global_index]

func _select_only_multi_role_entry(target_node: Node) -> bool:
	if target_node == null or not is_instance_valid(target_node):
		return false
	_clear_selection()
	if target_node.is_in_group("selectable_unit"):
		_add_selected_unit(target_node)
	elif target_node.is_in_group("selectable_building"):
		_add_selected_building(target_node)
	else:
		return false
	_refresh_subgroup_state(true)
	return not _selected_units.is_empty() or not _selected_buildings.is_empty()

func _select_same_multi_role_kind(entry_kind: String) -> int:
	var kind_key: String = entry_kind.strip_edges().to_lower()
	if kind_key == "":
		return 0
	var previous_page_index: int = _multi_matrix_page_index
	_gmhud_log("select_same_multi_role_kind kind=%s previous_page=%d %s" % [kind_key, previous_page_index, _selection_counts_text()], true)

	var matched_units: Array[Node] = []
	for selected_unit in _selected_units:
		if selected_unit == null or not is_instance_valid(selected_unit):
			continue
		if not _is_player_owned(selected_unit):
			continue
		if _unit_kind_id(selected_unit) != kind_key:
			continue
		matched_units.append(selected_unit)

	var matched_buildings: Array[Node] = []
	for selected_building in _selected_buildings:
		if selected_building == null or not is_instance_valid(selected_building):
			continue
		if not _is_player_owned(selected_building):
			continue
		if _building_kind_id(selected_building) != kind_key:
			continue
		matched_buildings.append(selected_building)

	_clear_selection()
	for matched_unit in matched_units:
		_add_selected_unit(matched_unit)
	for matched_building in matched_buildings:
		_add_selected_building(matched_building)
	_refresh_subgroup_state()
	var page_count: int = _multi_role_page_count()
	_multi_matrix_page_index = clampi(previous_page_index, 0, page_count - 1)
	_gmhud_log("select_same_multi_role_kind result units=%d buildings=%d new_page=%d page_count=%d" % [
		matched_units.size(),
		matched_buildings.size(),
		_multi_matrix_page_index,
		page_count
	], true)
	return matched_units.size() + matched_buildings.size()

func _remove_multi_role_entry_from_selection(target_node: Node) -> bool:
	if target_node == null or not is_instance_valid(target_node):
		return false
	var removed: bool = false
	var unit_index: int = _selected_units.find(target_node)
	if unit_index >= 0:
		_selected_units.remove_at(unit_index)
		removed = true
	else:
		var building_index: int = _selected_buildings.find(target_node)
		if building_index >= 0:
			_selected_buildings.remove_at(building_index)
			removed = true
	if not removed:
		return false
	if target_node.has_method("set_selected"):
		target_node.call("set_selected", false)
	_close_build_menu()
	_pending_target_skill = ""
	_refresh_subgroup_state()
	return true

func _multi_role_kind_label(entry_kind: String, target_node: Node = null) -> String:
	var normalized: String = entry_kind.strip_edges().to_lower()
	if normalized.begins_with("building:"):
		if target_node != null and target_node.has_method("get_building_display_name"):
			return str(target_node.call("get_building_display_name"))
		var suffix: String = normalized.trim_prefix("building:")
		return _t(suffix.capitalize())
	if normalized == "building":
		if target_node != null and target_node.has_method("get_building_display_name"):
			return str(target_node.call("get_building_display_name"))
		return _t("Building")
	return _subgroup_kind_label(normalized)

func _on_hud_control_group_pressed(group_id: int) -> void:
	_select_control_group(group_id)
	_refresh_hint_label()

func _on_hud_matrix_page_selected(page_index: int) -> void:
	_gmhud_log("hud_matrix_page_selected request=%d current=%d" % [page_index, _multi_matrix_page_index], true)
	if _set_multi_matrix_page(page_index):
		_refresh_hint_label()

func _on_hud_minimap_navigate_requested(world_position: Vector3) -> void:
	if _camera == null:
		return
	var map_half_size: Vector2 = _camera_map_half_size()
	var cam_pos: Vector3 = _camera.global_position
	cam_pos.x = clampf(world_position.x, -map_half_size.x, map_half_size.x)
	cam_pos.z = clampf(world_position.z, -map_half_size.y, map_half_size.y)
	_camera.global_position = cam_pos

func _on_hud_ping_button_pressed() -> void:
	_set_ping_mode_active(true)

func _on_hud_ping_requested(world_position: Vector3) -> void:
	_emit_ping(world_position)
	_set_ping_mode_active(false)
	_refresh_hint_label()

func _execute_command(command_id: String) -> void:
	_prune_invalid_selection()
	match command_id:
		"build_menu":
			if _can_open_build_menu():
				_open_build_menu()
				_refresh_hint_label()
			return
		"build_menu_garrisoned":
			_set_build_menu_group(BUILD_MENU_GROUP_GARRISONED)
			_refresh_hint_label()
			return
		"build_menu_summoning":
			_set_build_menu_group(BUILD_MENU_GROUP_SUMMONING)
			_refresh_hint_label()
			return
		"build_menu_incorporated":
			_set_build_menu_group(BUILD_MENU_GROUP_INCORPORATED)
			_refresh_hint_label()
			return
		"build_menu_back":
			_set_build_menu_group(BUILD_MENU_GROUP_ROOT)
			_refresh_hint_label()
			return
		"close_menu":
			_close_build_menu()
			_refresh_hint_label()
			return
		"placement_confirm":
			_confirm_building_placement(_is_queue_input_active())
		"placement_cancel":
			_cancel_building_placement()
		"placement_rotate":
			_rotate_building_placement()
		"train_worker":
			_queue_worker_from_selection()
		"train_soldier":
			_queue_soldier_from_selection()
		"move", "gather", "attack", "repair":
			_begin_target_skill(command_id)
		"return_resource":
			_issue_return_command(_is_queue_input_active())
		"stop":
			_issue_stop_command(_is_queue_input_active())
		"construction_exit":
			_issue_exit_construction_from_selection()
		"construction_cancel_destroy":
			_cancel_selected_construction_sites(false)
		"construction_cancel_eject":
			_cancel_selected_construction_sites(true)
		"construction_select_worker":
			_select_worker_from_construction_site()
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
			_close_build_menu()
			_start_building_placement(build_kind, command_id)
	_refresh_hint_label()

func _begin_target_skill(skill_id: String) -> void:
	if _selected_units.is_empty():
		return
	if skill_id == "attack" and not _selection_has_combat_unit():
		return
	if skill_id == "gather" and not _selection_has_worker():
		return
	if skill_id == "repair" and not _selection_has_worker():
		return
	_close_build_menu()
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
		"repair":
			var ray_result: Dictionary = _raycast_from_screen(screen_pos)
			if ray_result.is_empty():
				return false
			var collider: Node = ray_result.get("collider") as Node
			if collider == null or not _is_repairable_friendly_target(collider):
				_set_ui_notice(_t("Repair requires a damaged friendly unit/building."), 0.9)
				_play_feedback_tone("error")
				return false
			_issue_repair_command(collider as Node3D, screen_pos, queue_command)
			return true
		_:
			return false

func _issue_context_command(screen_pos: Vector2, queue_command: bool = false) -> void:
	_prune_invalid_selection()
	if _selected_units.is_empty() and _selected_buildings.is_empty():
		return

	var resolved: Dictionary = _resolve_smart_context_command(screen_pos)
	var resolved_command: String = str(resolved.get("command", "move"))
	var resolved_target: Node3D = resolved.get("target") as Node3D
	match resolved_command:
		"attack":
			_issue_attack_command(resolved_target, screen_pos, queue_command)
		"gather":
			_issue_gather_command(resolved_target, screen_pos, queue_command)
		"return":
			_issue_return_command_to_dropoff(resolved_target, queue_command)
		"repair":
			_issue_repair_command(resolved_target, screen_pos, queue_command)
		"follow":
			_issue_follow_command(resolved_target, queue_command)
		"resume_construction":
			_issue_resume_construction_command(resolved_target, queue_command)
		"rally":
			_apply_rally_point_command(resolved, screen_pos, queue_command)
			_refresh_hint_label()
		_:
			if _selected_units.is_empty() and _selection_has_rally_building():
				_apply_rally_point_command({"rally_mode": "ground"}, screen_pos, queue_command)
				_refresh_hint_label()
			else:
				_issue_move_command(screen_pos, queue_command)

func _resolve_smart_context_command(screen_pos: Vector2) -> Dictionary:
	var ray_result: Dictionary = _raycast_from_screen(screen_pos)
	var ground_point_variant: Variant = _ground_point_from_screen(screen_pos)
	var hit_position: Vector3 = Vector3.ZERO
	if ground_point_variant is Vector3:
		hit_position = ground_point_variant as Vector3
	if not ray_result.is_empty():
		var hit_value: Variant = ray_result.get("position", hit_position)
		if hit_value is Vector3:
			hit_position = hit_value as Vector3
	var candidates: Array[Node] = _collect_smart_candidates(ray_result, hit_position)

	if _selected_units.is_empty() and _selection_has_rally_building():
		return _resolve_rally_context_command(candidates, hit_position)

	var attack_target: Node3D = _find_nearest_smart_candidate(candidates, hit_position, "attack")
	if attack_target != null:
		return {"command": "attack", "target": attack_target}

	var gather_target: Node3D = _find_nearest_smart_candidate(candidates, hit_position, "gather")
	if gather_target != null:
		return {"command": "gather", "target": gather_target}

	var return_target: Node3D = _find_nearest_smart_candidate(candidates, hit_position, "return")
	if return_target != null:
		return {"command": "return", "target": return_target}

	var repair_target: Node3D = _find_nearest_smart_candidate(candidates, hit_position, "repair")
	if repair_target != null:
		return {"command": "repair", "target": repair_target}

	var follow_target: Node3D = _find_nearest_smart_candidate(candidates, hit_position, "follow")
	if follow_target != null:
		return {"command": "follow", "target": follow_target}

	var resume_target: Node3D = _find_nearest_smart_candidate(candidates, hit_position, "resume_construction")
	if resume_target != null:
		return {"command": "resume_construction", "target": resume_target}

	return {"command": "move"}

func _resolve_rally_context_command(candidates: Array[Node], hit_position: Vector3) -> Dictionary:
	var attack_target: Node3D = _find_nearest_smart_candidate(candidates, hit_position, "rally_enemy")
	if attack_target != null:
		return {"command": "rally", "target": attack_target, "rally_mode": "attack"}

	var resource_target: Node3D = _find_nearest_smart_candidate(candidates, hit_position, "rally_resource")
	if resource_target != null:
		return {"command": "rally", "target": resource_target, "rally_mode": "resource"}

	var follow_target: Node3D = _find_nearest_smart_candidate(candidates, hit_position, "rally_follow")
	if follow_target != null:
		return {"command": "rally", "target": follow_target, "rally_mode": "follow"}

	var building_target: Node3D = _find_nearest_smart_candidate(candidates, hit_position, "rally_building")
	if building_target != null:
		return {"command": "rally", "target": building_target, "rally_mode": "relay"}

	return {"command": "rally", "rally_mode": "ground"}

func _collect_smart_candidates(ray_result: Dictionary, hit_position: Vector3) -> Array[Node]:
	var candidates: Array[Node] = []
	var seen: Dictionary = {}
	var ray_collider: Node = ray_result.get("collider") as Node
	_append_smart_candidate(candidates, seen, ray_collider)
	if ray_result.is_empty() and hit_position == Vector3.ZERO:
		return candidates

	var world_3d: World3D = get_world_3d()
	if world_3d == null:
		return candidates
	var shape: SphereShape3D = SphereShape3D.new()
	shape.radius = SMART_COMMAND_PRIORITY_RANGE
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY, hit_position)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	query.collision_mask = 0x7fffffff & ~QUEUE_MARKER_LAYER
	var intersections: Array = world_3d.direct_space_state.intersect_shape(query, 24)
	for hit in intersections:
		var collider_value: Variant = hit.get("collider", null)
		var collider: Node = collider_value as Node
		_append_smart_candidate(candidates, seen, collider)
	return candidates

func _append_smart_candidate(candidates: Array[Node], seen: Dictionary, node: Node) -> void:
	if node == null or not is_instance_valid(node):
		return
	var id: int = node.get_instance_id()
	if seen.has(id):
		return
	seen[id] = true
	candidates.append(node)

func _find_nearest_smart_candidate(candidates: Array[Node], hit_position: Vector3, filter_mode: String) -> Node3D:
	var nearest: Node3D = null
	var best_distance_sq: float = INF
	for candidate in candidates:
		var node_3d: Node3D = candidate as Node3D
		if node_3d == null:
			continue
		if not _smart_candidate_matches(node_3d, filter_mode):
			continue
		var distance_sq: float = hit_position.distance_squared_to(node_3d.global_position)
		if nearest == null or distance_sq < best_distance_sq:
			nearest = node_3d
			best_distance_sq = distance_sq
	return nearest

func _smart_candidate_matches(node: Node3D, filter_mode: String) -> bool:
	match filter_mode:
		"attack":
			return _selection_has_combat_unit() and _is_attackable_enemy(node)
		"gather":
			return _selection_has_worker() and node.is_in_group("resource_node")
		"return":
			return _selection_has_worker_cargo() and _is_player_dropoff_node(node)
		"repair":
			return _selection_has_worker() and not _selection_has_worker_cargo() and _is_repairable_friendly_target(node)
		"follow":
			return not _selected_units.is_empty() and node.is_in_group("selectable_unit") and _is_player_owned(node)
		"resume_construction":
			if not node.is_in_group("selectable_building") or not _is_player_owned(node):
				return false
			if not node.has_method("is_under_construction") or not bool(node.call("is_under_construction")):
				return false
			if not node.has_method("get_construction_paradigm"):
				return false
			if str(node.call("get_construction_paradigm")).strip_edges().to_lower() != "garrisoned":
				return false
			if not node.has_method("is_construction_paused") or not bool(node.call("is_construction_paused")):
				return false
			for unit_node in _command_units():
				if unit_node == null or not is_instance_valid(unit_node):
					continue
				if not unit_node.has_method("is_worker_unit") or not bool(unit_node.call("is_worker_unit")):
					continue
				if unit_node.has_method("is_construction_locked") and bool(unit_node.call("is_construction_locked")):
					continue
				return true
			return false
		"rally_enemy":
			return _is_attackable_enemy(node)
		"rally_resource":
			return node.is_in_group("resource_node")
		"rally_follow":
			return node.is_in_group("selectable_unit") and _is_player_owned(node)
		"rally_building":
			return node.is_in_group("selectable_building") and _is_player_owned(node)
		_:
			return false

func _is_player_dropoff_node(node: Node) -> bool:
	if node == null or not is_instance_valid(node):
		return false
	if not node.is_in_group("resource_dropoff"):
		return false
	return _is_player_owned(node)

func _select_single(screen_pos: Vector2, additive: bool) -> void:
	_debug_selection_seq += 1
	var selection_seq: int = _debug_selection_seq
	_gmhud_log("select_single#%d begin pos=%s additive=%s before=%s" % [
		selection_seq,
		str(screen_pos),
		str(additive),
		_selection_counts_text()
	])
	_close_build_menu()
	_pending_target_skill = ""
	if not additive:
		_clear_selection()

	var result: Dictionary = _raycast_from_screen(screen_pos)
	if result.is_empty():
		_gmhud_log("select_single#%d no collider hit; after=%s" % [selection_seq, _selection_counts_text()])
		return

	var collider: Node = result.get("collider") as Node
	if collider == null:
		_last_click_unit_kind = ""
		_gmhud_log("select_single#%d collider is null; after=%s" % [selection_seq, _selection_counts_text()])
		return

	if collider.is_in_group("selectable_unit"):
		var is_owned_unit: bool = _is_player_owned(collider)
		if not is_owned_unit:
			# Enemy/neutral units are selectable for inspection, but always as single selection.
			_clear_selection()
			_add_selected_unit(collider, true)
			_last_click_unit_kind = ""
		else:
			if additive and _selection_contains_non_player_units():
				_clear_selection()
			var unit_kind: String = _unit_kind_id(collider)
			var now_sec: float = float(Time.get_ticks_msec()) / 1000.0
			var is_double_click: bool = unit_kind != "" and _last_click_unit_kind == unit_kind and (now_sec - _last_click_time_sec) <= SELECTION_DOUBLE_CLICK_WINDOW
			_last_click_unit_kind = unit_kind
			_last_click_time_sec = now_sec
			if is_double_click:
				_gmhud_log("select_single#%d double-click kind=%s ctrl=%s" % [selection_seq, unit_kind, str(Input.is_key_pressed(KEY_CTRL))], true)
				_select_units_by_kind(unit_kind, Input.is_key_pressed(KEY_CTRL))
			else:
				_add_selected_unit(collider)
		_refresh_subgroup_state(true)
		_gmhud_log_selection("select_single#%d unit hit result" % selection_seq)
		return

	if collider.is_in_group("selectable_building"):
		if _is_player_owned(collider):
			if additive and _selection_contains_non_player_units():
				_clear_selection()
			_add_selected_building(collider)
		_last_click_unit_kind = ""
		_refresh_subgroup_state(true)
		_gmhud_log_selection("select_single#%d building hit result" % selection_seq)
		return

	_last_click_unit_kind = ""
	_refresh_subgroup_state(true)
	_gmhud_log_selection("select_single#%d other collider result" % selection_seq)

func _select_by_rect(start_pos: Vector2, end_pos: Vector2, additive: bool) -> void:
	_debug_selection_seq += 1
	var selection_seq: int = _debug_selection_seq
	_gmhud_log("select_by_rect#%d begin start=%s end=%s additive=%s before=%s" % [
		selection_seq,
		str(start_pos),
		str(end_pos),
		str(additive),
		_selection_counts_text()
	])
	_close_build_menu()
	_pending_target_skill = ""
	if not additive:
		_clear_selection()

	var rect: Rect2 = Rect2(
		Vector2(minf(start_pos.x, end_pos.x), minf(start_pos.y, end_pos.y)),
		Vector2(absf(end_pos.x - start_pos.x), absf(end_pos.y - start_pos.y))
	)

	if additive and _selection_contains_non_player_units():
		# Enemy/neutral selection is single-only; drag selection switches back to player-owned group selection.
		_clear_selection()

	var unit_candidates: Array[Node]
	if _units_root != null:
		unit_candidates = _units_root.get_children()
	else:
		unit_candidates = get_tree().get_nodes_in_group("selectable_unit")
	var building_candidates: Array[Node]
	if _buildings_root != null:
		building_candidates = _buildings_root.get_children()
	else:
		building_candidates = get_tree().get_nodes_in_group("selectable_building")
	_gmhud_log("select_by_rect#%d rect=%s unit_candidates=%d building_candidates=%d" % [
		selection_seq,
		str(rect),
		unit_candidates.size(),
		building_candidates.size()
	], true)

	var selected_unit_hits: int = 0
	var selected_building_hits: int = 0
	var has_player_unit_overlap: bool = false
	var has_non_player_unit_overlap: bool = false
	for node in unit_candidates:
		var unit: Node3D = node as Node3D
		if unit == null:
			continue
		if not unit.is_in_group("selectable_unit"):
			continue
		if _camera.is_position_behind(unit.global_position):
			continue
		var projected_pos: Vector2 = _camera.unproject_position(unit.global_position)
		if not rect.has_point(projected_pos):
			continue
		if not _is_player_owned(unit):
			has_non_player_unit_overlap = true
			continue
		has_player_unit_overlap = true
		_add_selected_unit(unit)
		selected_unit_hits += 1
	if not has_player_unit_overlap:
		for node in building_candidates:
			var building: Node3D = node as Node3D
			if building == null:
				continue
			if not building.is_in_group("selectable_building"):
				continue
			if _camera.is_position_behind(building.global_position):
				continue
			if not _is_player_owned(building):
				continue
			var projected_pos: Vector2 = _camera.unproject_position(building.global_position)
			if rect.has_point(projected_pos):
				_add_selected_building(building)
				selected_building_hits += 1
	_refresh_subgroup_state(true)
	_gmhud_log("select_by_rect#%d selected_hits=%d (units=%d buildings=%d player_unit_overlap=%s enemy_or_neutral_overlap=%s) after=%s" % [
		selection_seq,
		selected_unit_hits + selected_building_hits,
		selected_unit_hits,
		selected_building_hits,
		str(has_player_unit_overlap),
		str(has_non_player_unit_overlap),
		_selection_counts_text()
	])
	_gmhud_log_selection("select_by_rect#%d snapshot" % selection_seq, true)

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

	var dropoff: Node3D = _nearest_dropoff(resource_node.global_position, PLAYER_TEAM_ID)
	if dropoff == null:
		_issue_move_command(fallback_screen_pos, queue_command)
		return

	var worker_units: Array[Node] = _selected_worker_units()
	var issued_count: int = 0
	var dispatch_target: Dictionary = _resolve_queue_idle_dispatch_target(
		"gather",
		worker_units,
		queue_command,
		resource_node.global_position
	)
	if not dispatch_target.is_empty():
		var target_unit: Node = dispatch_target.get("unit") as Node
		var queue_for_unit: bool = bool(dispatch_target.get("queue_for_unit", queue_command))
		if target_unit != null:
			var gather_command: RTSCommand = RTS_COMMAND.make_gather(resource_node, dropoff, queue_for_unit)
			_schedule_unit_command(target_unit, gather_command)
			issued_count = 1
	else:
		for unit_node in worker_units:
			var gather_command: RTSCommand = RTS_COMMAND.make_gather(resource_node, dropoff, queue_command)
			_schedule_unit_command(unit_node, gather_command)
			issued_count += 1

	if issued_count == 0:
		_issue_move_command(fallback_screen_pos, queue_command)

func _issue_repair_command(target_node: Node3D, _fallback_screen_pos: Vector2, queue_command: bool = false) -> void:
	if target_node == null or not is_instance_valid(target_node):
		return
	if not _is_repairable_friendly_target(target_node):
		return
	var worker_units: Array[Node] = _selected_worker_units()
	var issued_count: int = 0
	var dispatch_target: Dictionary = _resolve_queue_idle_dispatch_target(
		"repair",
		worker_units,
		queue_command,
		target_node.global_position
	)
	if not dispatch_target.is_empty():
		var target_unit: Node = dispatch_target.get("unit") as Node
		var queue_for_unit: bool = bool(dispatch_target.get("queue_for_unit", queue_command))
		if target_unit != null:
			var repair_command: RTSCommand = RTS_COMMAND.make_repair(target_node, queue_for_unit)
			_schedule_unit_command(target_unit, repair_command)
			issued_count = 1
	else:
		for unit_node in worker_units:
			var repair_command: RTSCommand = RTS_COMMAND.make_repair(target_node, queue_command)
			_schedule_unit_command(unit_node, repair_command)
			issued_count += 1
	if issued_count <= 0:
		_set_ui_notice(_t("No available worker to repair target."), 1.0)
		_play_feedback_tone("error")

func _issue_attack_command(target_node: Node3D, fallback_screen_pos: Vector2, queue_command: bool = false) -> void:
	if target_node == null or not is_instance_valid(target_node):
		return
	var command_units: Array[Node] = _command_units()
	var issued_count: int = 0
	for unit_node in command_units:
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
	var command_units: Array[Node] = _command_units()
	if command_units.is_empty():
		return false
	var target: Variant = _ground_point_from_screen(screen_pos)
	if target == null:
		return false
	var target_point: Vector3 = target as Vector3
	var issued_count: int = 0
	var count: int = command_units.size()
	var cols: int = int(ceil(sqrt(float(count))))
	var spacing: float = 1.6
	for i in count:
		var row: int = i / cols
		var col: int = i % cols
		var offset: Vector3 = Vector3((float(col) - float(cols - 1) * 0.5) * spacing, 0.0, (float(row) - float(cols - 1) * 0.5) * spacing)
		var unit_node: Node = command_units[i] as Node
		var destination: Vector3 = target_point + offset
		var attack_move_command: RTSCommand = RTS_COMMAND.make_attack_move(destination, queue_command)
		_schedule_unit_command(unit_node, attack_move_command)
		issued_count += 1
	return issued_count > 0

func _issue_move_command(screen_pos: Vector2, queue_command: bool = false) -> void:
	var command_units: Array[Node] = _command_units()
	if command_units.is_empty():
		return

	var target: Variant = _ground_point_from_screen(screen_pos)
	if target == null:
		return

	var target_point: Vector3 = target as Vector3
	var count: int = command_units.size()
	var cols: int = int(ceil(sqrt(float(count))))
	var spacing: float = 1.6

	for i in count:
		var row: int = i / cols
		var col: int = i % cols
		var offset: Vector3 = Vector3((float(col) - float(cols - 1) * 0.5) * spacing, 0.0, (float(row) - float(cols - 1) * 0.5) * spacing)
		var unit: Node = command_units[i] as Node
		var move_command: RTSCommand = RTS_COMMAND.make_move(target_point + offset, queue_command)
		_schedule_unit_command(unit, move_command)

func _issue_stop_command(queue_command: bool = false) -> void:
	for unit_node in _command_units():
		var stop_command: RTSCommand = RTS_COMMAND.make_stop(queue_command)
		_schedule_unit_command(unit_node, stop_command)

func _is_valid_garrisoned_paused_site(node: Node) -> bool:
	if node == null or not is_instance_valid(node):
		return false
	if not node.is_in_group("selectable_building"):
		return false
	if not _is_player_owned(node):
		return false
	if not node.has_method("is_under_construction") or not bool(node.call("is_under_construction")):
		return false
	if not node.has_method("get_construction_paradigm"):
		return false
	if str(node.call("get_construction_paradigm")).strip_edges().to_lower() != "garrisoned":
		return false
	if not node.has_method("is_construction_paused") or not bool(node.call("is_construction_paused")):
		return false
	return true

func _nearest_available_worker_for_construction(target_position: Vector3) -> Node3D:
	var nearest: Node3D = null
	var best_distance_sq: float = INF
	for unit_node in _command_units():
		var unit_3d: Node3D = unit_node as Node3D
		if unit_3d == null or not is_instance_valid(unit_3d):
			continue
		if not unit_3d.has_method("is_worker_unit") or not bool(unit_3d.call("is_worker_unit")):
			continue
		if unit_3d.has_method("is_construction_locked") and bool(unit_3d.call("is_construction_locked")):
			continue
		var distance_sq: float = unit_3d.global_position.distance_squared_to(target_position)
		if nearest == null or distance_sq < best_distance_sq:
			nearest = unit_3d
			best_distance_sq = distance_sq
	return nearest

func _schedule_construction_resume_order(worker_node: Node3D, site_node: Node3D, queue_command: bool = false) -> bool:
	if worker_node == null or not is_instance_valid(worker_node):
		return false
	if site_node == null or not is_instance_valid(site_node):
		return false
	if not _is_valid_garrisoned_paused_site(site_node):
		return false
	var worker_path: NodePath = worker_node.get_path()
	var site_path: NodePath = site_node.get_path()
	_cancel_pending_construction_resume_for_worker(worker_node, "replace")
	for order_value in _pending_construction_resume_orders:
		if not (order_value is Dictionary):
			continue
		var order: Dictionary = order_value as Dictionary
		var existing_site_path: NodePath = order.get("site_path", NodePath("")) as NodePath
		if existing_site_path == site_path:
			return false
	var target_position: Vector3 = site_node.global_position
	_pending_construction_resume_orders.append({
		"worker_path": worker_path,
		"site_path": site_path,
		"position": target_position,
		"queue_command": queue_command,
		"move_repath_timer": 0.0
	})
	var move_command: RTSCommand = RTS_COMMAND.make_move(target_position, queue_command)
	move_command.payload["internal_build_order"] = true
	_schedule_unit_command(worker_node, move_command)
	return true

func _cancel_pending_construction_resume_for_worker(worker_node: Node, _reason: String = "override") -> bool:
	if worker_node == null or not is_instance_valid(worker_node):
		return false
	var worker_path: NodePath = worker_node.get_path()
	var changed: bool = false
	for i in range(_pending_construction_resume_orders.size() - 1, -1, -1):
		var order_value: Variant = _pending_construction_resume_orders[i]
		if not (order_value is Dictionary):
			_pending_construction_resume_orders.remove_at(i)
			changed = true
			continue
		var order: Dictionary = order_value as Dictionary
		var order_worker_path: NodePath = order.get("worker_path", NodePath("")) as NodePath
		if order_worker_path != worker_path:
			continue
		_pending_construction_resume_orders.remove_at(i)
		changed = true
	return changed

func _issue_resume_construction_command(site_node: Node3D, queue_command: bool = false) -> void:
	if not _is_valid_garrisoned_paused_site(site_node):
		return
	var worker_node: Node3D = _nearest_available_worker_for_construction(site_node.global_position)
	if worker_node == null:
		_set_ui_notice(_t("No available worker to resume construction."), 1.0)
		_play_feedback_tone("error")
		return
	if not _schedule_construction_resume_order(worker_node, site_node, queue_command):
		return
	_set_ui_notice(_t("Worker assigned to resume construction."), 1.0)
	_play_feedback_tone("follow")

func _process_pending_construction_resume_orders(delta: float) -> void:
	if _pending_construction_resume_orders.is_empty():
		return
	for i in range(_pending_construction_resume_orders.size() - 1, -1, -1):
		var order_value: Variant = _pending_construction_resume_orders[i]
		if not (order_value is Dictionary):
			_pending_construction_resume_orders.remove_at(i)
			continue
		var order: Dictionary = order_value as Dictionary
		var worker_path: NodePath = order.get("worker_path", NodePath("")) as NodePath
		var site_path: NodePath = order.get("site_path", NodePath("")) as NodePath
		var worker_node: Node3D = get_node_or_null(worker_path) as Node3D
		var site_node: Node3D = get_node_or_null(site_path) as Node3D
		if worker_node == null or not is_instance_valid(worker_node):
			_pending_construction_resume_orders.remove_at(i)
			continue
		if worker_node.has_method("is_construction_locked") and bool(worker_node.call("is_construction_locked")):
			_pending_construction_resume_orders.remove_at(i)
			continue
		if site_node == null or not is_instance_valid(site_node):
			_pending_construction_resume_orders.remove_at(i)
			continue
		if not _is_valid_garrisoned_paused_site(site_node):
			_pending_construction_resume_orders.remove_at(i)
			continue
		var target_position: Vector3 = site_node.global_position
		var queue_mode: bool = bool(order.get("queue_command", false))
		if worker_node.global_position.distance_to(target_position) > BUILD_ORDER_START_DISTANCE:
			if not queue_mode:
				var repath_timer: float = float(order.get("move_repath_timer", 0.0)) - delta
				if repath_timer <= 0.0:
					repath_timer = BUILD_ORDER_MOVE_REFRESH
					var move_command: RTSCommand = RTS_COMMAND.make_move(target_position, false)
					move_command.payload["internal_build_order"] = true
					_schedule_unit_command(worker_node, move_command)
				order["move_repath_timer"] = repath_timer
			_pending_construction_resume_orders[i] = order
			continue
		var resumed: bool = false
		if site_node.has_method("assign_construction_worker"):
			resumed = bool(site_node.call("assign_construction_worker", worker_node))
		if not resumed:
			_pending_construction_resume_orders.remove_at(i)
			continue
		_bind_worker_to_construction(worker_node, site_node, "garrisoned")
		var stop_command: RTSCommand = RTS_COMMAND.make_stop(false)
		stop_command.payload["internal_build_order"] = true
		_schedule_unit_command(worker_node, stop_command)
		_set_ui_notice(_t("Construction resumed."), 1.0)
		_pending_construction_resume_orders.remove_at(i)

func _selected_construction_sites() -> Array[Node]:
	var sites: Array[Node] = []
	for selected_building in _selected_buildings:
		if selected_building == null or not is_instance_valid(selected_building):
			continue
		if not _is_player_owned(selected_building):
			continue
		if not selected_building.has_method("is_under_construction"):
			continue
		if not bool(selected_building.call("is_under_construction")):
			continue
		sites.append(selected_building)
	return sites

func _construction_site_paradigm(site_node: Node) -> String:
	if site_node == null or not is_instance_valid(site_node):
		return ""
	if not site_node.has_method("get_construction_paradigm"):
		return ""
	return str(site_node.call("get_construction_paradigm")).strip_edges().to_lower()

func _selected_worker_linked_construction_sites(paradigm_filter: String = "", non_sacrificial_only: bool = false) -> Array[Node]:
	var normalized_filter: String = paradigm_filter.strip_edges().to_lower()
	var sites: Array[Node] = []
	var seen_site_paths: Dictionary = {}
	for selected_unit in _selected_units:
		if selected_unit == null or not is_instance_valid(selected_unit):
			continue
		if not _is_player_owned(selected_unit):
			continue
		if not selected_unit.has_method("is_construction_locked") or not bool(selected_unit.call("is_construction_locked")):
			continue
		var lock_mode: String = ""
		if selected_unit.has_method("get_construction_lock_mode"):
			lock_mode = str(selected_unit.call("get_construction_lock_mode")).strip_edges().to_lower()
		if non_sacrificial_only and lock_mode != "garrisoned" and lock_mode != "cast":
			continue
		if not selected_unit.has_method("get_construction_building_path"):
			continue
		var site_path: NodePath = selected_unit.call("get_construction_building_path") as NodePath
		if str(site_path) == "":
			continue
		var site_node: Node = get_node_or_null(site_path)
		if site_node == null or not is_instance_valid(site_node):
			continue
		if not _is_player_owned(site_node):
			continue
		if not site_node.has_method("is_under_construction") or not bool(site_node.call("is_under_construction")):
			continue
		var site_paradigm: String = _construction_site_paradigm(site_node)
		if normalized_filter != "" and site_paradigm != normalized_filter:
			continue
		var site_key: String = str(site_node.get_path())
		if seen_site_paths.has(site_key):
			continue
		seen_site_paths[site_key] = true
		sites.append(site_node)
	return sites

func _collect_target_construction_sites(include_selected_sites: bool = true, include_worker_linked_sites: bool = true, paradigm_filter: String = "", non_sacrificial_worker_only: bool = false) -> Array[Node]:
	var normalized_filter: String = paradigm_filter.strip_edges().to_lower()
	var sites: Array[Node] = []
	var seen_site_paths: Dictionary = {}
	if include_selected_sites:
		for site_node in _selected_construction_sites():
			var selected_paradigm: String = _construction_site_paradigm(site_node)
			if normalized_filter != "" and selected_paradigm != normalized_filter:
				continue
			var selected_key: String = str(site_node.get_path())
			if seen_site_paths.has(selected_key):
				continue
			seen_site_paths[selected_key] = true
			sites.append(site_node)
	if include_worker_linked_sites:
		for site_node in _selected_worker_linked_construction_sites(normalized_filter, non_sacrificial_worker_only):
			var linked_key: String = str(site_node.get_path())
			if seen_site_paths.has(linked_key):
				continue
			seen_site_paths[linked_key] = true
			sites.append(site_node)
	return sites

func _selected_construction_site_count(paradigm_filter: String = "") -> int:
	var normalized_filter: String = paradigm_filter.strip_edges().to_lower()
	var count: int = 0
	for site_node in _selected_construction_sites():
		if normalized_filter == "":
			count += 1
			continue
		if not site_node.has_method("get_construction_paradigm"):
			continue
		if str(site_node.call("get_construction_paradigm")).strip_edges().to_lower() != normalized_filter:
			continue
		count += 1
	return count

func _issue_exit_construction_from_selection() -> void:
	var exited_count: int = 0
	for selected_unit in _selected_units:
		if selected_unit == null or not is_instance_valid(selected_unit):
			continue
		if not _is_player_owned(selected_unit):
			continue
		if not selected_unit.has_method("is_construction_locked"):
			continue
		if not bool(selected_unit.call("is_construction_locked")):
			continue
		if not selected_unit.has_method("get_construction_lock_mode"):
			continue
		if str(selected_unit.call("get_construction_lock_mode")) != "garrisoned":
			continue
		var building_path: NodePath = selected_unit.call("get_construction_building_path") as NodePath
		var site_node: Node = get_node_or_null(building_path)
		if site_node != null and is_instance_valid(site_node) and site_node.has_method("exit_construction"):
			var exit_value: Variant = site_node.call("exit_construction")
			if exit_value is Dictionary and not bool((exit_value as Dictionary).get("ok", false)):
				continue
		if selected_unit.has_method("exit_construction_lock"):
			selected_unit.call("exit_construction_lock")
		exited_count += 1
	if exited_count <= 0:
		return
	_set_ui_notice(_tf("Construction exit: %d worker(s) released.", [exited_count]), 1.1)
	_play_feedback_tone("ground")
	_refresh_hint_label()

func _cancel_selected_construction_sites(eject_worker: bool) -> void:
	var canceled_count: int = 0
	var total_refund: int = 0
	for site_node in _collect_target_construction_sites(true, true):
		if site_node == null or not is_instance_valid(site_node):
			continue
		var site_paradigm: String = ""
		if site_node.has_method("get_construction_paradigm"):
			site_paradigm = str(site_node.call("get_construction_paradigm")).strip_edges().to_lower()
		if eject_worker and site_paradigm != "incorporated":
			continue
		if not eject_worker and site_paradigm == "incorporated":
			continue
		if not site_node.has_method("cancel_construction_and_destroy"):
			continue
		var result_value: Variant = site_node.call("cancel_construction_and_destroy", eject_worker)
		if not (result_value is Dictionary):
			continue
		var result: Dictionary = result_value as Dictionary
		if not bool(result.get("ok", false)):
			continue
		var worker_path: NodePath = result.get("worker_path", NodePath("")) as NodePath
		_release_worker_from_construction(worker_path, 0.0)
		var build_cost: int = maxi(0, int(result.get("cost", 0)))
		var refund_ratio: float = clampf(float(result.get("refund_ratio", 0.75)), 0.0, 1.0)
		var refund_amount: int = maxi(0, int(floor(float(build_cost) * refund_ratio)))
		if refund_amount > 0:
			add_minerals(refund_amount)
		total_refund += refund_amount
		canceled_count += 1
	_prune_invalid_selection()
	if canceled_count <= 0:
		_set_ui_notice(_t("No matching construction site for this command."), 1.0)
		_play_feedback_tone("error")
		return
	if total_refund > 0:
		_set_ui_notice(_tf("Construction canceled: %d site(s), +%d minerals.", [canceled_count, total_refund]), 1.2)
	else:
		_set_ui_notice(_tf("Construction canceled: %d site(s).", [canceled_count]), 1.2)
	_play_feedback_tone("error")
	_refresh_hint_label()

func _select_worker_from_construction_site() -> void:
	if _selected_buildings.is_empty():
		return
	var site: Node = _selected_buildings[0]
	if site == null or not is_instance_valid(site):
		return
	if not site.has_method("get_construction_assigned_worker_path"):
		return
	var worker_path: NodePath = site.call("get_construction_assigned_worker_path") as NodePath
	if str(worker_path) == "":
		_set_ui_notice(_t("No assigned worker."))
		_play_feedback_tone("error")
		return
	var worker_node: Node = get_node_or_null(worker_path)
	if worker_node == null or not is_instance_valid(worker_node):
		_set_ui_notice(_t("Assigned worker is unavailable."))
		_play_feedback_tone("error")
		return
	_clear_selection()
	_add_selected_unit(worker_node)
	_refresh_subgroup_state(true)
	_set_ui_notice(_t("Selected construction worker."), 1.1)
	_play_feedback_tone("follow")
	_refresh_hint_label()

func _issue_follow_command(target_node: Node3D, queue_command: bool = false) -> void:
	if target_node == null or not is_instance_valid(target_node):
		return
	var command_units: Array[Node] = _command_units()
	var unit_count: int = command_units.size()
	if unit_count <= 0:
		return
	var desired_distance: float = 3.8
	for i in unit_count:
		var unit_node: Node = command_units[i] as Node
		if unit_node == target_node:
			continue
		var angle: float = TAU * float(i) / float(maxi(1, unit_count))
		var offset: Vector3 = Vector3(cos(angle) * desired_distance, 0.0, sin(angle) * desired_distance)
		var follow_command: RTSCommand = RTS_COMMAND.make_move(target_node.global_position + offset, queue_command)
		_schedule_unit_command(unit_node, follow_command)

func _issue_return_command_to_dropoff(dropoff_node: Node3D, queue_command: bool = false) -> void:
	if dropoff_node == null or not is_instance_valid(dropoff_node):
		return
	var worker_units: Array[Node] = _selected_worker_units()
	var dispatch_target: Dictionary = _resolve_queue_idle_dispatch_target(
		"return_resource",
		worker_units,
		queue_command,
		dropoff_node.global_position
	)
	if not dispatch_target.is_empty():
		var target_unit: Node = dispatch_target.get("unit") as Node
		var queue_for_unit: bool = bool(dispatch_target.get("queue_for_unit", queue_command))
		if target_unit != null:
			var return_command: RTSCommand = RTS_COMMAND.make_return(dropoff_node, queue_for_unit)
			_schedule_unit_command(target_unit, return_command)
			return
	for unit_node in worker_units:
		var return_command: RTSCommand = RTS_COMMAND.make_return(dropoff_node, queue_command)
		_schedule_unit_command(unit_node, return_command)

func _issue_return_command(queue_command: bool = false) -> void:
	var worker_units: Array[Node] = _selected_worker_units()
	var dispatch_target: Dictionary = _resolve_queue_idle_dispatch_target(
		"return_resource",
		worker_units,
		queue_command,
		Vector3.ZERO,
		false
	)
	if not dispatch_target.is_empty():
		var target_unit_3d: Node3D = dispatch_target.get("unit") as Node3D
		if target_unit_3d != null:
			var target_team_id: int = PLAYER_TEAM_ID
			if target_unit_3d.has_method("get_team_id"):
				target_team_id = int(target_unit_3d.call("get_team_id"))
			var target_dropoff: Node3D = _nearest_dropoff(target_unit_3d.global_position, target_team_id)
			if target_dropoff != null:
				var queue_for_unit: bool = bool(dispatch_target.get("queue_for_unit", queue_command))
				var queued_return_command: RTSCommand = RTS_COMMAND.make_return(target_dropoff, queue_for_unit)
				_schedule_unit_command(target_unit_3d, queued_return_command)
				return
	for unit_node in worker_units:
		var unit_3d: Node3D = unit_node as Node3D
		if unit_3d == null:
			continue
		var unit_team_id: int = PLAYER_TEAM_ID
		if unit_3d.has_method("get_team_id"):
			unit_team_id = int(unit_3d.call("get_team_id"))
		var dropoff: Node3D = _nearest_dropoff(unit_3d.global_position, unit_team_id)
		if dropoff == null:
			continue
		var return_command: RTSCommand = RTS_COMMAND.make_return(dropoff, queue_command)
		_schedule_unit_command(unit_node, return_command)

func _apply_rally_point_command(resolved: Dictionary, screen_pos: Vector2, append_hop: bool = false) -> void:
	if not _selection_has_rally_building():
		return
	var target_node: Node3D = resolved.get("target") as Node3D
	var rally_mode: String = str(resolved.get("rally_mode", "ground"))
	var applied_count: int = 0
	var rejected_count: int = 0
	var rally_position: Vector3 = Vector3.ZERO
	if target_node != null and is_instance_valid(target_node):
		rally_position = target_node.global_position
	else:
		var ground_variant: Variant = _ground_point_from_screen(screen_pos)
		if not (ground_variant is Vector3):
			return
		rally_position = ground_variant as Vector3

	for selected_building in _selected_buildings:
		if selected_building == null or not is_instance_valid(selected_building):
			continue
		if not _is_player_owned(selected_building):
			continue
		if not selected_building.has_method("supports_rally_point"):
			continue
		if not bool(selected_building.call("supports_rally_point")):
			continue
		if selected_building.has_method("set_rally_point"):
			var ok: bool = bool(selected_building.call("set_rally_point", rally_position, target_node, rally_mode, append_hop))
			if not ok:
				rejected_count += 1
				_rally_reject_feedback_timer = 1.1
			else:
				applied_count += 1

	if applied_count > 0:
		_play_feedback_tone(rally_mode)
	elif rejected_count > 0:
		_play_feedback_tone("error")

func _nearest_dropoff(from_position: Vector3, team_filter: int = -1) -> Node3D:
	var nearest: Node3D = null
	var best_distance_sq: float = INF
	var dropoff_nodes: Array[Node] = get_tree().get_nodes_in_group("resource_dropoff")
	for node in dropoff_nodes:
		var dropoff: Node3D = node as Node3D
		if dropoff == null:
			continue
		if dropoff.has_method("is_alive") and not bool(dropoff.call("is_alive")):
			continue
		if team_filter >= 0 and dropoff.has_method("get_team_id"):
			if int(dropoff.call("get_team_id")) != team_filter:
				continue
		var distance_sq: float = from_position.distance_squared_to(dropoff.global_position)
		if distance_sq < best_distance_sq:
			best_distance_sq = distance_sq
			nearest = dropoff
	return nearest

func _nearest_resource_node(from_position: Vector3, max_distance: float = INF) -> Node3D:
	var nearest: Node3D = null
	var best_distance_sq: float = max_distance * max_distance
	var resource_nodes: Array[Node] = get_tree().get_nodes_in_group("resource_node")
	for node in resource_nodes:
		var resource_node: Node3D = node as Node3D
		if resource_node == null or not is_instance_valid(resource_node):
			continue
		if resource_node.has_method("is_depleted") and bool(resource_node.call("is_depleted")):
			continue
		var distance_sq: float = from_position.distance_squared_to(resource_node.global_position)
		if distance_sq < best_distance_sq:
			best_distance_sq = distance_sq
			nearest = resource_node
	return nearest

func _start_building_placement(kind: String, source_skill_id: String = "") -> void:
	var build_cost: int = _building_cost(kind)
	if build_cost <= 0:
		return
	_placing_building = true
	_pending_target_skill = ""
	_close_build_menu()
	_placing_kind = kind
	_placing_skill_id = source_skill_id.strip_edges()
	_placing_cost = build_cost
	_placement_rotation_y = 0.0
	_placement_footprint = _build_footprint_for_kind(kind)
	_set_placement_preview_footprint(_placement_footprint)
	_placement_preview.visible = true
	_set_build_grid_visible(true)
	_sync_build_grid_occupancy()
	_update_placement_preview()
	_refresh_hint_label()

func _cancel_building_placement() -> void:
	_placing_building = false
	_placing_kind = ""
	_placing_skill_id = ""
	_placing_cost = 0
	_placement_footprint = DEFAULT_BUILD_FOOTPRINT
	_placement_can_place = false
	if _placement_preview != null:
		_placement_preview.visible = false
	_set_build_grid_visible(false)
	_clear_build_grid_preview()
	_refresh_hint_label()

func _rotate_building_placement() -> void:
	if not _placing_building:
		return
	_placement_rotation_y = wrapf(_placement_rotation_y + PI * 0.5, 0.0, TAU)
	_update_placement_preview()
	_refresh_hint_label()

func _create_placement_preview() -> void:
	_placement_preview = MeshInstance3D.new()
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = Vector3(DEFAULT_BUILD_FOOTPRINT.x, 0.08, DEFAULT_BUILD_FOOTPRINT.y)
	_placement_preview.mesh = mesh

	_placement_preview_material = StandardMaterial3D.new()
	_placement_preview_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_placement_preview_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_placement_preview_material.albedo_color = Color(0.15, 0.95, 0.3, 0.35)
	_placement_preview.material_override = _placement_preview_material
	_placement_preview.visible = false
	add_child(_placement_preview)

func _build_footprint_for_kind(kind: String) -> Vector2:
	var fallback: Vector2 = DEFAULT_BUILD_FOOTPRINT
	if kind == "":
		return fallback
	var building_def: Dictionary = RTS_CATALOG.get_building_def(kind)
	var footprint_value: Variant = building_def.get("footprint_size", building_def.get("footprint", fallback))
	if footprint_value is Vector2:
		var footprint: Vector2 = footprint_value as Vector2
		if footprint.x > 0.01 and footprint.y > 0.01:
			return footprint
	return fallback

func _set_placement_preview_footprint(footprint: Vector2) -> void:
	if _placement_preview == null:
		return
	var box: BoxMesh = _placement_preview.mesh as BoxMesh
	if box == null:
		return
	box.size = Vector3(maxf(0.05, footprint.x), box.size.y, maxf(0.05, footprint.y))

func _setup_build_placement_grid() -> void:
	var grid_node: Node = BUILD_PLACEMENT_GRID_SCRIPT.new()
	_build_placement_grid = grid_node
	if _build_placement_grid == null:
		return
	if _build_placement_grid is Node:
		(_build_placement_grid as Node).name = "BuildPlacementGrid"
		add_child(_build_placement_grid as Node)
	if _build_placement_grid.has_method("set"):
		_build_placement_grid.call("set", "default_building_footprint", DEFAULT_BUILD_FOOTPRINT)
	_set_build_grid_visible(false)
	_sync_build_grid_occupancy()

func _set_build_grid_visible(visible: bool) -> void:
	if _build_placement_grid == null:
		return
	if _build_placement_grid.has_method("set_build_mode_enabled"):
		_build_placement_grid.call("set_build_mode_enabled", visible)

func _clear_build_grid_preview() -> void:
	if _build_placement_grid == null:
		return
	if _build_placement_grid.has_method("clear_preview"):
		_build_placement_grid.call("clear_preview")

func _update_build_grid_preview(snapped_position: Vector3, can_place: bool) -> void:
	if _build_placement_grid == null:
		return
	if _build_placement_grid.has_method("set_preview_footprint"):
		_build_placement_grid.call(
			"set_preview_footprint",
			snapped_position,
			_placement_rotation_y,
			_placement_footprint,
			can_place
		)

func _sync_build_grid_occupancy(ignored_units: Array[Node] = []) -> void:
	if _build_placement_grid == null:
		return
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	var building_nodes: Array[Node] = tree.get_nodes_in_group("selectable_building")
	var resource_nodes: Array[Node] = tree.get_nodes_in_group("resource_node")
	var all_unit_nodes: Array[Node] = tree.get_nodes_in_group("selectable_unit")
	var unit_nodes: Array[Node] = []
	if ignored_units.is_empty():
		unit_nodes = all_unit_nodes
	else:
		for unit_node in all_unit_nodes:
			if ignored_units.has(unit_node):
				continue
			unit_nodes.append(unit_node)
	if _build_placement_grid.has_method("sync_occupancy"):
		_build_placement_grid.call(
			"sync_occupancy",
			building_nodes,
			resource_nodes,
			unit_nodes,
			_pending_build_order_entries()
		)

func _pending_build_order_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for order_value in _pending_build_orders:
		if not (order_value is Dictionary):
			continue
		var order: Dictionary = order_value as Dictionary
		var position_value: Variant = order.get("position", Vector3.ZERO)
		if not (position_value is Vector3):
			continue
		var kind: String = str(order.get("kind", ""))
		var footprint_value: Variant = order.get("footprint_size", _build_footprint_for_kind(kind))
		var footprint: Vector2 = footprint_value as Vector2 if footprint_value is Vector2 else _build_footprint_for_kind(kind)
		entries.append({
			"position": position_value as Vector3,
			"rotation_y": float(order.get("rotation_y", 0.0)),
			"footprint_size": footprint
		})
	return entries

func _snap_build_grid_position(raw_position: Vector3) -> Vector3:
	if _build_placement_grid != null:
		if _build_placement_grid.has_method("snap_world_position"):
			var snapped_value: Variant = _build_placement_grid.call("snap_world_position", raw_position)
			if snapped_value is Vector3:
				return snapped_value as Vector3
	return Vector3(roundf(raw_position.x * 2.0) * 0.5, 0.04, roundf(raw_position.z * 2.0) * 0.5)

func _update_placement_preview() -> void:
	var screen_pos: Vector2 = get_viewport().get_mouse_position()
	_update_placement_preview_from_screen(screen_pos)

func _update_placement_preview_from_screen(screen_pos: Vector2) -> void:
	var point: Variant = _ground_point_from_screen(screen_pos)
	if point == null:
		_placement_preview.visible = false
		_placement_can_place = false
		_clear_build_grid_preview()
		return

	var raw_position: Vector3 = point as Vector3
	var snapped: Vector3 = _snap_build_grid_position(raw_position)
	_placement_current_position = snapped
	var preview_builder: Node3D = _nearest_selected_worker(Vector3(snapped.x, 0.0, snapped.z))
	if preview_builder != null and is_instance_valid(preview_builder):
		var builder_team: int = _team_id_from_node(preview_builder, PLAYER_TEAM_ID)
		var ignored_units: Array[Node] = _collect_allied_units(builder_team)
		_sync_build_grid_occupancy(ignored_units)
	else:
		_sync_build_grid_occupancy()

	var is_valid_spot: bool = _is_build_spot_valid(snapped)
	var can_afford: bool = _minerals >= _placing_cost
	_placement_can_place = is_valid_spot and can_afford

	_placement_preview.visible = true
	_placement_preview.global_position = snapped
	_placement_preview.rotation.y = _placement_rotation_y
	if _placement_can_place:
		_placement_preview_material.albedo_color = Color(0.15, 0.95, 0.3, 0.35)
	else:
		_placement_preview_material.albedo_color = Color(0.95, 0.2, 0.2, 0.35)
	_update_build_grid_preview(snapped, _placement_can_place)

func _try_place_building(screen_pos: Vector2, keep_mode: bool = false) -> void:
	_update_placement_preview_from_screen(screen_pos)
	_confirm_building_placement(keep_mode)

func _confirm_building_placement(keep_mode: bool = false) -> void:
	if not _placement_can_place:
		return
	var target_position: Vector3 = Vector3(_placement_current_position.x, 0.0, _placement_current_position.z)
	var builder_dispatch: Dictionary = _resolve_build_order_worker(target_position, keep_mode)
	var builder: Node3D = builder_dispatch.get("unit") as Node3D
	var queue_for_builder: bool = bool(builder_dispatch.get("queue_for_unit", keep_mode))
	if builder != null:
		var ghost_id: int = _create_pending_construction_ghost(builder, _placing_kind, target_position, _placement_rotation_y, keep_mode)
		_schedule_worker_build_order(builder, _placing_kind, target_position, _placement_rotation_y, _placing_cost, ghost_id, queue_for_builder)
	else:
		if not try_spend_minerals(_placing_cost):
			return
		var spawned_building: Node3D = _spawn_building_instance(_placing_kind, target_position, _placement_rotation_y)
		if spawned_building == null:
			add_minerals(_placing_cost)
			return

	var continue_placement: bool = keep_mode and _minerals >= _placing_cost
	if continue_placement:
		_update_placement_preview()
		_refresh_hint_label()
		return
	_cancel_building_placement()

func _nearest_selected_worker(world_position: Vector3) -> Node3D:
	var nearest: Node3D = null
	var best_distance_sq: float = INF
	for unit_node in _selected_units:
		var unit_3d: Node3D = unit_node as Node3D
		if unit_3d == null or not is_instance_valid(unit_3d):
			continue
		if not _is_player_owned(unit_3d):
			continue
		if not unit_3d.has_method("is_worker_unit"):
			continue
		if not bool(unit_3d.call("is_worker_unit")):
			continue
		var distance_sq: float = unit_3d.global_position.distance_squared_to(world_position)
		if nearest == null or distance_sq < best_distance_sq:
			nearest = unit_3d
			best_distance_sq = distance_sq
	return nearest

func _worker_build_time_for(kind: String) -> float:
	var def: Dictionary = RTS_CATALOG.get_building_def(kind)
	return maxf(0.25, float(def.get("build_time", DEFAULT_WORKER_BUILD_TIME)))

func _building_cancel_refund_ratio(kind: String) -> float:
	if kind == "":
		return 0.75
	var def: Dictionary = RTS_CATALOG.get_building_def(kind)
	return clampf(float(def.get("cancel_refund_ratio", 0.75)), 0.0, 1.0)

func _rotate_xz_vector(v: Vector2, angle: float) -> Vector2:
	var c: float = cos(angle)
	var s: float = sin(angle)
	return Vector2(v.x * c - v.y * s, v.x * s + v.y * c)

func _team_id_from_node(node: Node, fallback: int = PLAYER_TEAM_ID) -> int:
	if node == null or not is_instance_valid(node):
		return fallback
	if not node.has_method("get_team_id"):
		return fallback
	return int(node.call("get_team_id"))

func _collect_allied_units(team_id: int) -> Array[Node]:
	var result: Array[Node] = []
	var tree: SceneTree = get_tree()
	if tree == null:
		return result
	var unit_nodes: Array[Node] = tree.get_nodes_in_group("selectable_unit")
	for node in unit_nodes:
		if node == null or not is_instance_valid(node):
			continue
		if node.has_method("is_alive") and not bool(node.call("is_alive")):
			continue
		if _team_id_from_node(node, team_id) != team_id:
			continue
		result.append(node)
	return result

func _is_point_inside_build_footprint(point: Vector3, center: Vector3, rotation_y: float, footprint: Vector2, padding: float = 0.0) -> bool:
	var half_x: float = maxf(0.05, footprint.x * 0.5 + maxf(0.0, padding))
	var half_z: float = maxf(0.05, footprint.y * 0.5 + maxf(0.0, padding))
	var local: Vector2 = _rotate_xz_vector(Vector2(point.x - center.x, point.z - center.z), -rotation_y)
	return absf(local.x) <= half_x and absf(local.y) <= half_z

func _compute_build_order_escape_target(builder_position: Vector3, build_center: Vector3, rotation_y: float, footprint: Vector2) -> Vector3:
	var half_x: float = maxf(0.05, footprint.x * 0.5)
	var half_z: float = maxf(0.05, footprint.y * 0.5)
	var local: Vector2 = _rotate_xz_vector(Vector2(builder_position.x - build_center.x, builder_position.z - build_center.z), -rotation_y)
	if local.length_squared() <= 0.0001:
		local = Vector2(1.0, 0.0)
	var x_ratio: float = absf(local.x) / maxf(0.01, half_x)
	var z_ratio: float = absf(local.y) / maxf(0.01, half_z)
	var escape_local: Vector2 = local
	var target_distance_x: float = (half_x + BUILD_ORDER_FOOTPRINT_EXIT_PADDING) * PENDING_BUILD_FOOTPRINT_EXPAND_SCALE
	var target_distance_z: float = (half_z + BUILD_ORDER_FOOTPRINT_EXIT_PADDING) * PENDING_BUILD_FOOTPRINT_EXPAND_SCALE
	if x_ratio >= z_ratio:
		var direction_x: float = 1.0 if local.x >= 0.0 else -1.0
		escape_local.x = direction_x * target_distance_x
	else:
		var direction_z: float = 1.0 if local.y >= 0.0 else -1.0
		escape_local.y = direction_z * target_distance_z
	var world_offset: Vector2 = _rotate_xz_vector(escape_local, rotation_y)
	var target: Vector3 = Vector3(build_center.x + world_offset.x, 0.0, build_center.z + world_offset.y)
	target.x = clampf(target.x, -55.8, 55.8)
	target.z = clampf(target.z, -55.8, 55.8)
	return target

func _issue_unit_evacuation_move(unit_node: Node3D, target_position: Vector3) -> void:
	if unit_node == null or not is_instance_valid(unit_node):
		return
	if unit_node.has_method("insert_temporary_move_then_resume"):
		var inserted: bool = bool(unit_node.call("insert_temporary_move_then_resume", target_position, "pending_build_evacuate"))
		if inserted:
			return
	var move_command: RTSCommand = RTS_COMMAND.make_move(target_position, false)
	if unit_node.has_method("submit_command"):
		unit_node.call("submit_command", move_command)

func _evacuate_allied_units_from_pending_build(
	order: Dictionary,
	builder_node: Node3D,
	target_position: Vector3,
	rotation_y: float,
	footprint_size: Vector2,
	delta: float
) -> Dictionary:
	var cooldowns: Dictionary = {}
	var builder_path: NodePath = builder_node.get_path()
	var cooldowns_value: Variant = order.get("evac_unit_cooldowns", {})
	if cooldowns_value is Dictionary:
		cooldowns = (cooldowns_value as Dictionary).duplicate(true)
	for key in cooldowns.keys():
		var remaining: float = float(cooldowns.get(key, 0.0)) - delta
		if remaining <= 0.0:
			cooldowns.erase(key)
		else:
			cooldowns[key] = remaining

	var team_id: int = _team_id_from_node(builder_node, PLAYER_TEAM_ID)
	var allied_units: Array[Node] = _collect_allied_units(team_id)
	var any_inside: bool = false
	for unit_value in allied_units:
		var unit_node: Node3D = unit_value as Node3D
		if unit_node == null or not is_instance_valid(unit_node):
			continue
		if unit_node == builder_node:
			continue
		if unit_node.get_path() == builder_path:
			continue
		if not _is_point_inside_build_footprint(
			unit_node.global_position,
			target_position,
			rotation_y,
			footprint_size,
			BUILD_ORDER_FOOTPRINT_INSIDE_EPSILON
		):
			continue
		any_inside = true
		var unit_key: String = str(unit_node.get_path())
		if float(cooldowns.get(unit_key, 0.0)) > 0.0:
			continue
		var escape_target: Vector3 = _compute_build_order_escape_target(
			unit_node.global_position,
			target_position,
			rotation_y,
			footprint_size
		)
		_issue_unit_evacuation_move(unit_node, escape_target)
		cooldowns[unit_key] = maxf(0.25, BUILD_ORDER_MOVE_REFRESH)
	order["evac_unit_cooldowns"] = cooldowns
	order["allied_units_inside"] = any_inside
	return order

func _is_worker_ready_for_pending_build(builder_node: Node3D, target_position: Vector3) -> bool:
	if builder_node == null or not is_instance_valid(builder_node):
		return false
	if builder_node.has_method("_is_near"):
		return bool(builder_node.call("_is_near", target_position, BUILD_ORDER_START_DISTANCE))
	return builder_node.global_position.distance_to(target_position) <= BUILD_ORDER_START_DISTANCE

func _pending_build_has_hard_blockers(
	_order_index: int,
	builder_node: Node3D,
	target_position: Vector3,
	rotation_y: float,
	footprint_size: Vector2
) -> bool:
	var tree: SceneTree = get_tree()
	if tree == null:
		return false
	var builder_team_id: int = _team_id_from_node(builder_node, PLAYER_TEAM_ID)
	var builder_path: NodePath = builder_node.get_path()

	var unit_nodes: Array[Node] = tree.get_nodes_in_group("selectable_unit")
	for unit_value in unit_nodes:
		var unit_node: Node3D = unit_value as Node3D
		if unit_node == null or not is_instance_valid(unit_node):
			continue
		if unit_node == builder_node:
			continue
		if unit_node.get_path() == builder_path:
			continue
		if unit_node.has_method("is_alive") and not bool(unit_node.call("is_alive")):
			continue
		if _team_id_from_node(unit_node, builder_team_id) == builder_team_id:
			continue
		if _is_point_inside_build_footprint(
			unit_node.global_position,
			target_position,
			rotation_y,
			footprint_size,
			BUILD_ORDER_FOOTPRINT_INSIDE_EPSILON
		):
			return true

	var building_nodes: Array[Node] = tree.get_nodes_in_group("selectable_building")
	for building_value in building_nodes:
		var building_node: Node3D = building_value as Node3D
		if building_node == null or not is_instance_valid(building_node):
			continue
		if building_node.has_method("is_alive") and not bool(building_node.call("is_alive")):
			continue
		if _is_point_inside_build_footprint(
			building_node.global_position,
			target_position,
			rotation_y,
			footprint_size,
			BUILD_ORDER_FOOTPRINT_INSIDE_EPSILON
		):
			return true

	var resource_nodes: Array[Node] = tree.get_nodes_in_group("resource_node")
	for resource_value in resource_nodes:
		var resource_node: Node3D = resource_value as Node3D
		if resource_node == null or not is_instance_valid(resource_node):
			continue
		if resource_node.has_method("is_depleted") and bool(resource_node.call("is_depleted")):
			continue
		if _is_point_inside_build_footprint(
			resource_node.global_position,
			target_position,
			rotation_y,
			footprint_size,
			BUILD_ORDER_FOOTPRINT_INSIDE_EPSILON
		):
			return true
	return false

func _has_earlier_pending_build_order_for_builder(builder_path: NodePath, current_index: int) -> bool:
	if str(builder_path) == "":
		return false
	var normalized_index: int = clampi(current_index, 0, _pending_build_orders.size())
	for idx in range(normalized_index):
		var order_value: Variant = _pending_build_orders[idx]
		if not (order_value is Dictionary):
			continue
		var order: Dictionary = order_value as Dictionary
		var other_path: NodePath = order.get("builder_path", NodePath("")) as NodePath
		if other_path == builder_path:
			return true
	return false

func _schedule_worker_build_order(builder: Node3D, kind: String, world_position: Vector3, rotation_y: float, build_cost: int, ghost_id: int, queue_command: bool = false) -> void:
	if builder == null or not is_instance_valid(builder):
		return
	var paradigm: String = _building_construction_paradigm(kind)
	var build_time: float = _worker_build_time_for(kind)
	var cancel_refund_ratio: float = _building_cancel_refund_ratio(kind)
	var footprint_size: Vector2 = _build_footprint_for_kind(kind)
	var phase: String = "approach"
	var evacuate_target: Vector3 = world_position
	if _is_point_inside_build_footprint(builder.global_position, world_position, rotation_y, footprint_size, BUILD_ORDER_FOOTPRINT_INSIDE_EPSILON):
		phase = "evacuate"
		evacuate_target = _compute_build_order_escape_target(builder.global_position, world_position, rotation_y, footprint_size)
	_pending_build_orders.append({
		"builder_path": builder.get_path(),
		"kind": kind,
		"position": world_position,
		"rotation_y": rotation_y,
		"footprint_size": footprint_size,
		"phase": phase,
		"evacuate_target": evacuate_target,
		"evac_unit_cooldowns": {},
		"allied_units_inside": false,
		"cost": build_cost,
		"ghost_id": ghost_id,
		"spent": false,
		"paradigm": paradigm,
		"build_time": build_time,
		"cancel_refund_ratio": cancel_refund_ratio,
		"queue_command": queue_command,
		"queue_activated": not queue_command,
		"move_repath_timer": 0.0,
		"clear_zone_elapsed": 0.0,
		"clear_zone_timeout": BUILD_ORDER_CLEAR_ZONE_TIMEOUT,
		"retry_timer": 0.0
	})
	var new_order_index: int = _pending_build_orders.size() - 1
	# Keep per-worker build queue strictly FIFO. Later queued orders should not
	# issue movement until all earlier orders for the same worker are done.
	if _has_earlier_pending_build_order_for_builder(builder.get_path(), new_order_index):
		return
	# If worker is currently locked in construction, defer movement until lock release.
	if builder.has_method("is_construction_locked") and bool(builder.call("is_construction_locked")):
		return
	if queue_command:
		return
	var first_target: Vector3 = evacuate_target if phase == "evacuate" else world_position
	var move_command: RTSCommand = RTS_COMMAND.make_move(first_target, false)
	move_command.payload["internal_build_order"] = true
	_schedule_unit_command(builder, move_command)

func _process_pending_build_orders(delta: float) -> void:
	if _pending_build_orders.is_empty():
		return
	for i in range(_pending_build_orders.size() - 1, -1, -1):
		var order_value: Variant = _pending_build_orders[i]
		if not (order_value is Dictionary):
			_pending_build_orders.remove_at(i)
			continue
		var order: Dictionary = order_value as Dictionary
		var builder_path: NodePath = order.get("builder_path", NodePath("")) as NodePath
		# Same worker's queued build orders must execute in strict insertion order.
		if _has_earlier_pending_build_order_for_builder(builder_path, i):
			continue
		var builder_node: Node3D = get_node_or_null(builder_path) as Node3D
		var kind: String = str(order.get("kind", ""))
		var ghost_id: int = int(order.get("ghost_id", -1))
		var build_cost: int = maxi(0, int(order.get("cost", _building_cost(kind))))
		var spent: bool = bool(order.get("spent", false))
		var rotation_y: float = float(order.get("rotation_y", 0.0))
		var footprint_value: Variant = order.get("footprint_size", _build_footprint_for_kind(kind))
		var footprint_size: Vector2 = footprint_value as Vector2 if footprint_value is Vector2 else _build_footprint_for_kind(kind)
		if builder_node == null or not is_instance_valid(builder_node):
			if spent and build_cost > 0:
				add_minerals(build_cost)
			if ghost_id >= 0:
				_remove_pending_construction_ghost(ghost_id)
			_pending_build_orders.remove_at(i)
			continue
		if not _is_player_owned(builder_node):
			if ghost_id >= 0:
				_remove_pending_construction_ghost(ghost_id)
			_pending_build_orders.remove_at(i)
			continue
		var target_position_value: Variant = order.get("position", Vector3.ZERO)
		if not (target_position_value is Vector3):
			if ghost_id >= 0:
				_remove_pending_construction_ghost(ghost_id)
			_pending_build_orders.remove_at(i)
			continue
		var target_position: Vector3 = target_position_value as Vector3
		if ghost_id >= 0 and not _has_pending_construction_ghost(ghost_id):
			_pending_build_orders.remove_at(i)
			continue
		# When worker is locked to an active construction site (especially garrisoned),
		# queued follow-up build orders must wait until that lock is released.
		if builder_node.has_method("is_construction_locked") and bool(builder_node.call("is_construction_locked")):
			_pending_build_orders[i] = order
			continue
		var queue_mode: bool = bool(order.get("queue_command", false))
		var queue_activated: bool = bool(order.get("queue_activated", not queue_mode))
		if queue_mode and not queue_activated:
			if not _is_unit_idle_for_queue_idle_dispatch(builder_node):
				_pending_build_orders[i] = order
				continue
			order["queue_activated"] = true

		var phase: String = str(order.get("phase", "approach"))
		if phase == "evacuate":
			var still_inside: bool = _is_point_inside_build_footprint(
				builder_node.global_position,
				target_position,
				rotation_y,
				footprint_size,
				BUILD_ORDER_FOOTPRINT_INSIDE_EPSILON
			)
			if still_inside:
				var escape_repath_timer: float = float(order.get("move_repath_timer", 0.0)) - delta
				if escape_repath_timer <= 0.0:
					escape_repath_timer = BUILD_ORDER_MOVE_REFRESH
					var escape_target: Vector3 = _compute_build_order_escape_target(
						builder_node.global_position,
						target_position,
						rotation_y,
						footprint_size
					)
					order["evacuate_target"] = escape_target
					var escape_command: RTSCommand = RTS_COMMAND.make_move(escape_target, false)
					escape_command.payload["internal_build_order"] = true
					_schedule_unit_command(builder_node, escape_command)
				order["move_repath_timer"] = escape_repath_timer
				_pending_build_orders[i] = order
				continue

			order["phase"] = "approach"
			order["move_repath_timer"] = 0.0
			var return_command: RTSCommand = RTS_COMMAND.make_move(target_position, false)
			return_command.payload["internal_build_order"] = true
			_schedule_unit_command(builder_node, return_command)
			_pending_build_orders[i] = order
			continue

		if phase == "approach":
			var approach_repath_timer: float = float(order.get("move_repath_timer", 0.0)) - delta
			if approach_repath_timer <= 0.0:
				approach_repath_timer = BUILD_ORDER_MOVE_REFRESH
				var approach_command: RTSCommand = RTS_COMMAND.make_move(target_position, false)
				approach_command.payload["internal_build_order"] = true
				_schedule_unit_command(builder_node, approach_command)
			order["move_repath_timer"] = approach_repath_timer
			if not _is_worker_ready_for_pending_build(builder_node, target_position):
				_pending_build_orders[i] = order
				continue
			order["phase"] = "clear_zone"
			order["move_repath_timer"] = 0.0
			order["clear_zone_elapsed"] = 0.0
			_pending_build_orders[i] = order
			continue

		if phase != "clear_zone":
			order["phase"] = "approach"
			order["move_repath_timer"] = 0.0
			_pending_build_orders[i] = order
			continue

		if not _is_worker_ready_for_pending_build(builder_node, target_position):
			order["phase"] = "approach"
			order["move_repath_timer"] = 0.0
			_pending_build_orders[i] = order
			continue

		# Worker reached interaction range: keep nearby and repeatedly clear the footprint.
		var clear_repath_timer: float = float(order.get("move_repath_timer", 0.0)) - delta
		if clear_repath_timer <= 0.0:
			clear_repath_timer = BUILD_ORDER_MOVE_REFRESH
			var clear_hold_command: RTSCommand = RTS_COMMAND.make_move(target_position, false)
			clear_hold_command.payload["internal_build_order"] = true
			_schedule_unit_command(builder_node, clear_hold_command)
		order["move_repath_timer"] = clear_repath_timer

		order = _evacuate_allied_units_from_pending_build(
			order,
			builder_node,
			target_position,
			rotation_y,
			footprint_size,
			delta
		)
		var allied_units_inside: bool = bool(order.get("allied_units_inside", false))
		var hard_blocked: bool = _pending_build_has_hard_blockers(
			i,
			builder_node,
			target_position,
			rotation_y,
			footprint_size
		)
		if allied_units_inside or hard_blocked:
			var clear_zone_elapsed: float = float(order.get("clear_zone_elapsed", 0.0)) + delta
			var clear_zone_timeout: float = maxf(0.5, float(order.get("clear_zone_timeout", BUILD_ORDER_CLEAR_ZONE_TIMEOUT)))
			order["clear_zone_elapsed"] = clear_zone_elapsed
			if ghost_id >= 0:
				_set_pending_construction_ghost_invalid(ghost_id, true)
			if clear_zone_elapsed >= clear_zone_timeout:
				if spent and build_cost > 0:
					add_minerals(build_cost)
				if ghost_id >= 0:
					_remove_pending_construction_ghost(ghost_id)
				_pending_build_orders.remove_at(i)
				_set_ui_notice(_tf("Construction canceled: %s blocked for too long.", [_building_display_name(kind)]), 1.3)
				continue
			_pending_build_orders[i] = order
			continue

		order["clear_zone_elapsed"] = 0.0
		if ghost_id >= 0:
			_set_pending_construction_ghost_invalid(ghost_id, false)

		if build_cost > 0 and _minerals < build_cost:
			var retry_timer: float = float(order.get("retry_timer", 0.0)) - delta
			if retry_timer <= 0.0:
				retry_timer = CONSTRUCTION_GHOST_RETRY_INTERVAL
				_set_ui_notice(_tf("Not enough minerals for %s.", [_building_display_name(kind)]), 1.1)
				var stop_for_wait: RTSCommand = RTS_COMMAND.make_stop(false)
				stop_for_wait.payload["internal_build_order"] = true
				_schedule_unit_command(builder_node, stop_for_wait)
			order["retry_timer"] = retry_timer
			if ghost_id >= 0:
				_set_pending_construction_ghost_invalid(ghost_id, true)
			_pending_build_orders[i] = order
			continue

		if build_cost > 0 and not spent:
			if not try_spend_minerals(build_cost):
				order["retry_timer"] = CONSTRUCTION_GHOST_RETRY_INTERVAL
				if ghost_id >= 0:
					_set_pending_construction_ghost_invalid(ghost_id, true)
				_pending_build_orders[i] = order
				continue
			spent = true
			order["spent"] = true

		order["retry_timer"] = 0.0
		order["move_repath_timer"] = 0.0
		if ghost_id >= 0:
			_remove_pending_construction_ghost(ghost_id)

		var site: Node3D = _spawn_building_instance(kind, target_position, rotation_y)
		if site == null:
			if spent and build_cost > 0:
				add_minerals(build_cost)
			_pending_build_orders.remove_at(i)
			continue

		var paradigm: String = str(order.get("paradigm", _building_construction_paradigm(kind)))
		var build_time: float = maxf(0.25, float(order.get("build_time", _worker_build_time_for(kind))))
		var cancel_refund_ratio: float = clampf(float(order.get("cancel_refund_ratio", _building_cancel_refund_ratio(kind))), 0.0, 1.0)
		if site.has_method("start_construction"):
			site.call("start_construction", paradigm, build_time, builder_node, build_cost, cancel_refund_ratio)
		_bind_worker_to_construction(builder_node, site, paradigm)
		var stop_command: RTSCommand = RTS_COMMAND.make_stop(false)
		stop_command.payload["internal_build_order"] = true
		_schedule_unit_command(builder_node, stop_command)
		if site.has_method("is_under_construction") and bool(site.call("is_under_construction")):
			_set_ui_notice(_tf("Construction started: %s.", [_building_display_name(kind)]), 1.0)

		_pending_build_orders.remove_at(i)

func _bind_worker_to_construction(builder_node: Node3D, site_node: Node3D, paradigm: String) -> void:
	if builder_node == null or not is_instance_valid(builder_node):
		return
	if not builder_node.has_method("enter_construction_lock"):
		return
	var normalized: String = paradigm.strip_edges().to_lower()
	var site_path: NodePath = NodePath("")
	if site_node != null and is_instance_valid(site_node):
		site_path = site_node.get_path()
	if normalized == "garrisoned":
		builder_node.call("enter_construction_lock", "garrisoned", site_path, false)
	elif normalized == "incorporated":
		builder_node.call("enter_construction_lock", "incorporated", site_path, true)
		if _selected_units.has(builder_node):
			_selected_units.erase(builder_node)
			if builder_node.has_method("set_selected"):
				builder_node.call("set_selected", false)
	elif normalized == "summoning":
		builder_node.call("enter_construction_lock", "cast", site_path, false)
	else:
		if builder_node.has_method("exit_construction_lock"):
			builder_node.call("exit_construction_lock")

func _release_worker_from_construction(worker_path: NodePath, hp_penalty_ratio: float = 0.0) -> Node3D:
	if str(worker_path) == "":
		return null
	var worker_node: Node3D = get_node_or_null(worker_path) as Node3D
	if worker_node == null or not is_instance_valid(worker_node):
		return null
	if worker_node.has_method("exit_construction_lock"):
		worker_node.call("exit_construction_lock")
	var penalty: float = clampf(hp_penalty_ratio, 0.0, 1.0)
	if penalty > 0.0 and worker_node.has_method("get_health_points") and worker_node.has_method("apply_damage"):
		var max_hp: float = maxf(1.0, float(worker_node.get("max_health")))
		var current_hp: float = float(worker_node.call("get_health_points"))
		var target_hp: float = maxf(1.0, max_hp * (1.0 - penalty))
		if current_hp > target_hp:
			worker_node.call("apply_damage", current_hp - target_hp, null)
	return worker_node

func _spawn_building_instance(kind: String, world_position: Vector3, rotation_y: float) -> Node3D:
	var instance: Node = BUILDING_SCENE.instantiate()
	var building: Node3D = instance as Node3D
	if building == null:
		return null
	if _buildings_root != null:
		_buildings_root.add_child(building)
	else:
		add_child(building)
	building.global_position = Vector3(world_position.x, 0.0, world_position.z)
	building.rotation.y = rotation_y
	if building.has_method("configure_by_kind"):
		building.call("configure_by_kind", kind)
	elif kind == "barracks" and building.has_method("configure_as_barracks"):
		building.call("configure_as_barracks")
	elif kind == "tower" and building.has_method("configure_as_tower"):
		building.call("configure_as_tower")
	_register_building(building)
	_request_navmesh_rebake("building_placed")
	return building

func _is_build_spot_valid(world_pos: Vector3) -> bool:
	if _build_placement_grid == null:
		return false
	if not _build_placement_grid.has_method("can_place_building"):
		return false
	var can_place_value: Variant = _build_placement_grid.call(
		"can_place_building",
		world_pos,
		_placement_rotation_y,
		_placement_footprint
	)
	if can_place_value is bool:
		return can_place_value as bool
	return false

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
	if building_node.has_signal("production_finished"):
		var callback: Callable = Callable(self , "_on_building_production_finished").bind(building_node)
		if not building_node.is_connected("production_finished", callback):
			building_node.connect("production_finished", callback)
	if building_node.has_signal("research_finished"):
		var research_callback: Callable = Callable(self, "_on_building_research_finished").bind(building_node)
		if not building_node.is_connected("research_finished", research_callback):
			building_node.connect("research_finished", research_callback)
	if building_node.has_signal("construction_state_changed"):
		var construction_callback: Callable = Callable(self , "_on_building_construction_state_changed").bind(building_node)
		if not building_node.is_connected("construction_state_changed", construction_callback):
			building_node.connect("construction_state_changed", construction_callback)

func _track_navigation_dynamic_node(nav_node: Node) -> void:
	if nav_node == null:
		return
	var callback: Callable = Callable(self , "_on_navigation_dynamic_node_exited").bind(nav_node)
	if not nav_node.is_connected("tree_exited", callback):
		nav_node.connect("tree_exited", callback)

func _on_navigation_dynamic_node_exited(_node: Node) -> void:
	if not is_inside_tree():
		return
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	if tree.current_scene == null or not is_instance_valid(tree.current_scene):
		return
	if _placing_building:
		_sync_build_grid_occupancy()
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
	var callback: Callable = Callable(self , "_on_nav_region_bake_finished")
	if not _nav_region.is_connected("bake_finished", callback):
		_nav_region.connect("bake_finished", callback)

func _request_navmesh_rebake(_reason: String = "") -> void:
	if not is_inside_tree():
		return
	if not nav_rebake_on_runtime:
		return
	if _nav_region == null:
		return
	if not _nav_region.is_inside_tree():
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

func _on_building_research_finished(tech_id: String, _source_building: Node = null) -> void:
	var normalized: String = tech_id.strip_edges()
	if normalized == "":
		return
	if unlock_tech(normalized):
		_set_ui_notice(_tf("Research complete: %s.", [_tech_display_name(normalized)]), 1.2)
	_process_active_research(0.0)
	_refresh_hint_label()

func _on_building_construction_state_changed(event_type: String, payload: Dictionary, source_building: Node = null) -> void:
	if source_building == null or not is_instance_valid(source_building):
		return
	var worker_path: NodePath = payload.get("worker_path", NodePath("")) as NodePath
	match event_type:
		"summoning_cast_complete":
			_release_worker_from_construction(worker_path)
			_set_ui_notice(_t("Summoning cast complete: worker released."), 1.0)
			_refresh_hint_label()
		"completed":
			_release_worker_from_construction(worker_path)
			_refresh_hint_label()
		"forced_destroyed":
			var penalty: float = clampf(float(payload.get("hp_penalty_ratio", 0.0)), 0.0, 1.0)
			_release_worker_from_construction(worker_path, penalty)
			if penalty > 0.0:
				_set_ui_notice(_t("Incorporated worker ejected at 50% HP."), 1.1)
			_prune_invalid_selection()
			_refresh_hint_label()

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
	_apply_rally_to_spawned_unit(unit, source_building)

func _apply_rally_to_spawned_unit(unit_node: Node, source_building: Node) -> void:
	if unit_node == null or not is_instance_valid(unit_node):
		return
	if source_building == null or not is_instance_valid(source_building):
		return
	if not source_building.has_method("get_rally_point_data"):
		return
	var rally_data_value: Variant = source_building.call("get_rally_point_data")
	if not (rally_data_value is Dictionary):
		return
	var rally_data: Dictionary = rally_data_value as Dictionary
	if rally_data.is_empty():
		return
	var hops: Array[Dictionary] = _extract_rally_hops(rally_data)
	if hops.is_empty():
		return
	var issued_count: int = 0
	for hop in hops:
		var rally_command_value: Variant = _build_rally_command_from_hop(unit_node, source_building, hop, issued_count > 0)
		var rally_command: RTSCommand = rally_command_value as RTSCommand
		if rally_command == null:
			continue
		_schedule_unit_command(unit_node, rally_command)
		issued_count += 1

func _build_rally_command_from_hop(unit_node: Node, source_building: Node, hop: Dictionary, queue_command: bool) -> Variant:
	var mode: String = str(hop.get("mode", "ground"))
	var target_node: Node3D = _safe_node3d_from_variant(hop.get("target_node", null))
	var target_position: Vector3 = Vector3.ZERO
	var has_target_position: bool = false
	var position_value: Variant = hop.get("position", Vector3.ZERO)
	if position_value is Vector3:
		target_position = position_value as Vector3
		has_target_position = true
	if target_node != null and is_instance_valid(target_node):
		target_position = target_node.global_position
		has_target_position = true
	var is_worker: bool = unit_node.has_method("is_worker_unit") and bool(unit_node.call("is_worker_unit"))

	match mode:
		"attack":
			if target_node != null and is_instance_valid(target_node):
				if is_worker:
					return _tag_rally_path_origin(RTS_COMMAND.make_move(target_position, queue_command), source_building, queue_command)
				return _tag_rally_path_origin(RTS_COMMAND.make_attack(target_node, queue_command), source_building, queue_command)
		"resource":
			var mineral_target: Node3D = null
			if target_node != null and is_instance_valid(target_node) and target_node.is_in_group("resource_node"):
				mineral_target = target_node
			elif has_target_position:
				mineral_target = _nearest_resource_node(target_position, 9.0)
			if is_worker and mineral_target != null:
				var dropoff: Node3D = null
				var source_building_3d: Node3D = source_building as Node3D
				var unit_team_id: int = PLAYER_TEAM_ID
				if unit_node.has_method("get_team_id"):
					unit_team_id = int(unit_node.call("get_team_id"))
				if source_building_3d != null and source_building_3d.is_in_group("resource_dropoff"):
					dropoff = source_building_3d
				elif unit_node is Node3D:
					dropoff = _nearest_dropoff((unit_node as Node3D).global_position, unit_team_id)
				if dropoff != null:
					var gather_command: RTSCommand = RTS_COMMAND.make_gather(mineral_target, dropoff, queue_command)
					gather_command.payload["from_rally"] = true
					return _tag_rally_path_origin(gather_command, source_building, queue_command)
		"follow":
			if target_node != null and is_instance_valid(target_node):
				var follow_offset: Vector3 = Vector3(3.8, 0.0, 0.0)
				return _tag_rally_path_origin(RTS_COMMAND.make_move(target_node.global_position + follow_offset, queue_command), source_building, queue_command)

	if not has_target_position:
		return null
	return _tag_rally_path_origin(RTS_COMMAND.make_move(target_position, queue_command), source_building, queue_command)

func _tag_rally_path_origin(command: RTSCommand, source_building: Node, queue_command: bool) -> RTSCommand:
	if command == null:
		return null
	if queue_command:
		return command
	var source_building_3d: Node3D = source_building as Node3D
	if source_building_3d == null or not is_instance_valid(source_building_3d):
		return command
	command.payload["path_origin"] = source_building_3d.global_position
	return command

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

func _raycast_from_screen(screen_pos: Vector2, include_queue_markers: bool = false) -> Dictionary:
	var origin: Vector3 = _camera.project_ray_origin(screen_pos)
	var normal: Vector3 = _camera.project_ray_normal(screen_pos)
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(origin, origin + normal * 4000.0)
	query.collide_with_areas = true
	var collision_mask: int = 0x7fffffff
	if not include_queue_markers:
		collision_mask &= ~QUEUE_MARKER_LAYER
	query.collision_mask = collision_mask
	return get_world_3d().direct_space_state.intersect_ray(query)

func _add_selected_unit(unit: Node, allow_non_player: bool = false) -> void:
	if not allow_non_player and not _is_player_owned(unit):
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
	_active_subgroup_index = -1
	_multi_matrix_page_index = 0
	_close_build_menu()
	_pending_target_skill = ""
