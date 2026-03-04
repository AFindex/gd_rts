extends Control

signal command_pressed(command_id: String)
signal multi_role_cell_pressed(cell_index: int, shift_pressed: bool, ctrl_pressed: bool)
signal control_group_pressed(group_id: int)
signal matrix_page_selected(page_index: int)
signal minimap_navigate_requested(world_position: Vector3)
signal ping_button_pressed
signal ping_requested(world_position: Vector3)

const COMMAND_SLOTS: int = 15
const MULTI_SLOTS: int = 30
const QUEUE_SLOTS: int = 5
const COMMAND_ITEM_SCENE: PackedScene = preload("res://scenes/ui/skill_command_item.tscn")
const COMMAND_HOVER_DEFAULT_TEXT: String = "Hover command for details."

@export var use_manual_bottom_layout: bool = true
@export var manual_bottom_gap: float = 8.0
@export var manual_bottom_padding: Vector2 = Vector2(0.0, 0.0)
@export var manual_bottom_section_ratios: Vector4 = Vector4(18.0, 40.0, 10.0, 32.0)
@export var manual_queue_top_height: float = 84.0
@export var manual_queue_gap: float = 0.0
@export var manual_queue_content_padding: Vector2 = Vector2(6.0, 6.0)
@export var manual_queue_content_right_extra_width: float = 58.0
@export var manual_queue_content_gap: float = 6.0
@export var manual_queue_hint_height: float = 26.0
@export var manual_single_container_padding: Vector2 = Vector2(0.0, 0.0)
@export var manual_single_container_gap: float = 6.0
@export var manual_single_status_ratio: float = 1.25
@export var manual_single_aux_ratio: float = 1.0
@export var manual_single_status_min_width: float = 200.0
@export var manual_single_aux_min_width: float = 220.0
@export var manual_single_status_padding: Vector2 = Vector2(6.0, 6.0)
@export var manual_single_status_gap: float = 4.0
@export var manual_single_name_height: float = 20.0
@export var manual_single_bar_height: float = 18.0
@export var manual_single_detail_padding: Vector2 = Vector2(6.0, 6.0)
@export var manual_single_detail_gap: float = 4.0
@export var manual_single_detail_title_height: float = 18.0
@export var manual_single_detail_armor_height: float = 18.0
@export var manual_production_padding: Vector2 = Vector2(6.0, 6.0)
@export var manual_production_gap: float = 4.0
@export var manual_queue_summary_height: float = 20.0
@export var manual_queue_progress_height: float = 18.0
@export var manual_queue_slots_height: float = 26.0
@export var manual_matrix_content_padding: Vector2 = Vector2(6.0, 6.0)
@export var manual_matrix_body_gap: float = 6.0
@export var manual_matrix_footer_width: float = 52.0
@export var manual_matrix_footer_padding: Vector2 = Vector2(0.0, 0.0)
@export var manual_matrix_page_button_height: float = 24.0
@export var manual_matrix_page_button_gap: float = 4.0
@export var manual_matrix_page_button_min_width: float = 52.0
@export var manual_matrix_columns: int = 10
@export var manual_matrix_h_gap: float = 3.0
@export var manual_matrix_v_gap: float = 3.0
@export var manual_matrix_cell_min_size: Vector2 = Vector2(50.0, 50.0)
@export var manual_portrait_top_height: float = 84.0
@export var manual_portrait_gap: float = 0.0
@export var manual_command_hover_height: float = 64.0
@export var manual_command_hover_extra_padding: float = 6.0
@export var manual_command_gap: float = 6.0
@export var manual_command_content_padding: Vector2 = Vector2(4.0, 4.0)
@export var manual_command_content_gap: float = 4.0
@export var manual_command_subgroup_height: float = 20.0
@export var manual_command_hint_height: float = 24.0
@export var manual_command_grid_columns: int = 5
@export var manual_command_grid_h_gap: float = 4.0
@export var manual_command_grid_v_gap: float = 4.0
@export var manual_command_grid_cell_min_size: Vector2 = Vector2(58.0, 58.0)
@export var use_manual_top_layout: bool = true
@export var manual_top_gap: float = 8.0
@export var manual_top_padding: Vector2 = Vector2(0.0, 0.0)
@export var manual_top_section_ratios: Vector3 = Vector3(7.4, 1.2, 1.4)
@export var enable_multi_mode_transition_guard: bool = true
@export var debug_matrix_jitter_logs: bool = false
@export var debug_matrix_jitter_verbose: bool = false
@export var debug_matrix_cells_to_log: int = 8
@export var debug_matrix_log_burst_only: bool = true
@export var debug_matrix_log_burst_seconds: float = 5.0

@onready var _top_bar: PanelContainer = $TopBar
@onready var _top_bar_row: Control = $TopBar/TopBarRow
@onready var _resource_panel: PanelContainer = $TopBar/TopBarRow/ResourcePanel
@onready var _center_top: PanelContainer = $TopBar/TopBarRow/CenterTop
@onready var _system_panel: PanelContainer = $TopBar/TopBarRow/SystemPanel
@onready var _bottom_hud: Control = $BottomHUD
@onready var _bottom_row: Control = $BottomHUD/BottomRow
@onready var _selection_panel: PanelContainer = $BottomHUD/BottomRow/SelectionPanel
@onready var _minimap_panel: PanelContainer = $BottomHUD/BottomRow/SelectionPanel/SelectionContent/MinimapPanel
@onready var _minimap_view: Control = $BottomHUD/BottomRow/SelectionPanel/SelectionContent/MinimapPanel/MiniMapView
@onready var _ping_button: Button = $BottomHUD/BottomRow/SelectionPanel/SelectionContent/BottomButtonRow/PingButton
@onready var _queue_column: Control = $BottomHUD/BottomRow/QueueColumn
@onready var _queue_panel: PanelContainer = $BottomHUD/BottomRow/QueueColumn/QueuePanel
@onready var _queue_content: Control = $BottomHUD/BottomRow/QueueColumn/QueuePanel/QueueContent
@onready var _portrait_column: Control = $BottomHUD/BottomRow/PortraitColumn
@onready var _portrait_top_spacer: Control = $BottomHUD/BottomRow/PortraitColumn/PortraitTopSpacer
@onready var _portrait_panel: PanelContainer = $BottomHUD/BottomRow/PortraitColumn/PortraitPanel
@onready var _command_column: Control = $BottomHUD/BottomRow/CommandColumn
@onready var _command_hover_panel: PanelContainer = $BottomHUD/BottomRow/CommandColumn/CommandHoverPanel
@onready var _command_panel: PanelContainer = $BottomHUD/BottomRow/CommandColumn/CommandPanel
@onready var _notification_panel: PanelContainer = $NotificationPanel

@onready var _minerals_value: Label = $TopBar/TopBarRow/ResourcePanel/ResourceContent/ResourceTopRow/MineralsValue
@onready var _gas_value: Label = $TopBar/TopBarRow/ResourcePanel/ResourceContent/ResourceTopRow/GasValue
@onready var _supply_value: Label = $TopBar/TopBarRow/ResourcePanel/ResourceContent/ResourceTopRow/SupplyValue
@onready var _legacy_info_text: Label = $TopBar/TopBarRow/ResourcePanel/ResourceContent/LegacyInfoText
@onready var _time_text: Label = $TopBar/TopBarRow/CenterTop/CenterTopContent/TimeText

@onready var _selection_hint_text: Label = $BottomHUD/BottomRow/QueueColumn/QueuePanel/QueueContent/SelectionHintText
@onready var _queue_top_spacer: Control = $BottomHUD/BottomRow/QueueColumn/QueueTopSpacer
@onready var _control_group_bar: HBoxContainer = $BottomHUD/BottomRow/QueueColumn/QueueTopSpacer/ControlGroupBar
@onready var _single_container: Control = $BottomHUD/BottomRow/QueueColumn/QueuePanel/QueueContent/SingleContainer
@onready var _single_status_root: PanelContainer = $BottomHUD/BottomRow/QueueColumn/QueuePanel/QueueContent/SingleContainer/SingleStatusRoot
@onready var _single_status_content: Control = $BottomHUD/BottomRow/QueueColumn/QueuePanel/QueueContent/SingleContainer/SingleStatusRoot/SingleStatusContent
@onready var _single_detail_root: PanelContainer = $BottomHUD/BottomRow/QueueColumn/QueuePanel/QueueContent/SingleContainer/SingleDetailRoot
@onready var _single_detail_content: Control = $BottomHUD/BottomRow/QueueColumn/QueuePanel/QueueContent/SingleContainer/SingleDetailRoot/SingleDetailContent
@onready var _production_queue_root: PanelContainer = $BottomHUD/BottomRow/QueueColumn/QueuePanel/QueueContent/SingleContainer/ProductionQueueRoot
@onready var _production_content: Control = $BottomHUD/BottomRow/QueueColumn/QueuePanel/QueueContent/SingleContainer/ProductionQueueRoot/ProductionContent
@onready var _single_name_text: Label = $BottomHUD/BottomRow/QueueColumn/QueuePanel/QueueContent/SingleContainer/SingleStatusRoot/SingleStatusContent/SingleNameText
@onready var _health_bar: ProgressBar = $BottomHUD/BottomRow/QueueColumn/QueuePanel/QueueContent/SingleContainer/SingleStatusRoot/SingleStatusContent/HealthBar
@onready var _health_value_label: Label = $BottomHUD/BottomRow/QueueColumn/QueuePanel/QueueContent/SingleContainer/SingleStatusRoot/SingleStatusContent/HealthBar/HealthValueLabel
@onready var _shield_bar: ProgressBar = $BottomHUD/BottomRow/QueueColumn/QueuePanel/QueueContent/SingleContainer/SingleStatusRoot/SingleStatusContent/ShieldBar
@onready var _shield_value_label: Label = $BottomHUD/BottomRow/QueueColumn/QueuePanel/QueueContent/SingleContainer/SingleStatusRoot/SingleStatusContent/ShieldBar/ShieldValueLabel
@onready var _energy_bar: ProgressBar = $BottomHUD/BottomRow/QueueColumn/QueuePanel/QueueContent/SingleContainer/SingleStatusRoot/SingleStatusContent/EnergyBar
@onready var _energy_value_label: Label = $BottomHUD/BottomRow/QueueColumn/QueuePanel/QueueContent/SingleContainer/SingleStatusRoot/SingleStatusContent/EnergyBar/EnergyValueLabel
@onready var _single_detail_title: Label = $BottomHUD/BottomRow/QueueColumn/QueuePanel/QueueContent/SingleContainer/SingleDetailRoot/SingleDetailContent/SingleDetailTitle
@onready var _single_detail_text: Label = $BottomHUD/BottomRow/QueueColumn/QueuePanel/QueueContent/SingleContainer/SingleDetailRoot/SingleDetailContent/SingleDetailText
@onready var _armor_type_text: Label = $BottomHUD/BottomRow/QueueColumn/QueuePanel/QueueContent/SingleContainer/SingleDetailRoot/SingleDetailContent/ArmorTypeText
@onready var _queue_summary_text: Label = $BottomHUD/BottomRow/QueueColumn/QueuePanel/QueueContent/SingleContainer/ProductionQueueRoot/ProductionContent/QueueSummaryText
@onready var _queue_progress_bar: ProgressBar = $BottomHUD/BottomRow/QueueColumn/QueuePanel/QueueContent/SingleContainer/ProductionQueueRoot/ProductionContent/QueueProgressBar
@onready var _queue_slots: HBoxContainer = $BottomHUD/BottomRow/QueueColumn/QueuePanel/QueueContent/SingleContainer/ProductionQueueRoot/ProductionContent/QueueSlots
@onready var _multi_matrix_root: PanelContainer = $BottomHUD/BottomRow/QueueColumn/QueuePanel/QueueContent/MultiMatrixRoot
@onready var _multi_matrix_content: Control = $BottomHUD/BottomRow/QueueColumn/QueuePanel/QueueContent/MultiMatrixRoot/MultiMatrixContent
@onready var _matrix_body: Control = $BottomHUD/BottomRow/QueueColumn/QueuePanel/QueueContent/MultiMatrixRoot/MultiMatrixContent/MatrixBody
@onready var _matrix_grid: Control = $BottomHUD/BottomRow/QueueColumn/QueuePanel/QueueContent/MultiMatrixRoot/MultiMatrixContent/MatrixBody/MatrixGrid
@onready var _matrix_footer: Control = $BottomHUD/BottomRow/QueueColumn/QueuePanel/QueueContent/MultiMatrixRoot/MultiMatrixContent/MatrixBody/MatrixFooter
@onready var _matrix_page_buttons_root: Control = $BottomHUD/BottomRow/QueueColumn/QueuePanel/QueueContent/MultiMatrixRoot/MultiMatrixContent/MatrixBody/MatrixFooter/MatrixPageButtons

@onready var _portrait_glyph: Label = $BottomHUD/BottomRow/PortraitColumn/PortraitPanel/PortraitContent/PortraitViewport/PortraitCenter/PortraitGlyph
@onready var _portrait_name_text: Label = $BottomHUD/BottomRow/PortraitColumn/PortraitPanel/PortraitContent/PortraitNameText
@onready var _portrait_role_text: Label = $BottomHUD/BottomRow/PortraitColumn/PortraitPanel/PortraitContent/PortraitRoleText
@onready var _command_hover_text: Label = $BottomHUD/BottomRow/CommandColumn/CommandHoverPanel/CommandHoverText
@onready var _command_content: Control = $BottomHUD/BottomRow/CommandColumn/CommandPanel/CommandContent
@onready var _subgroup_text: Label = $BottomHUD/BottomRow/CommandColumn/CommandPanel/CommandContent/SubgroupText
@onready var _command_grid: Control = $BottomHUD/BottomRow/CommandColumn/CommandPanel/CommandContent/CommandGrid
@onready var _command_hint_text: Label = $BottomHUD/BottomRow/CommandColumn/CommandPanel/CommandContent/CommandHintText
@onready var _notification_list: VBoxContainer = $NotificationPanel/NotificationList

var _elapsed_seconds: float = 0.0
var _command_items: Array[Control] = []
var _matrix_panels: Array[PanelContainer] = []
var _matrix_labels: Array[Label] = []
var _queue_slot_labels: Array[Label] = []
var _notification_labels: Array[Label] = []
var _current_multi_role_kinds: Array[String] = []
var _control_group_buttons: Array[Button] = []
var _matrix_page_buttons: Array[Button] = []
var _manual_layout_refresh_pending: bool = false
var _is_applying_manual_layout: bool = false
var _manual_layout_warmup_frames: int = 0
var _last_hud_mode: String = "none"
var _multi_matrix_reveal_pending: bool = false
var _multi_matrix_guard_hidden: bool = false
var _debug_hud_update_seq: int = 0
var _debug_layout_seq: int = 0
var _debug_log_burst_until_msec: float = 0.0
var _minimap_ping_armed: bool = false

func _ready() -> void:
	_cache_control_group_buttons()
	_setup_static_styles()
	_connect_ping_button()
	_connect_minimap_view()
	_configure_bottom_layout_nodes()
	_apply_bottom_helper_transparency()
	_apply_bottom_helper_mouse_filters()
	_collect_notification_labels()
	_build_queue_slot_labels()
	_build_command_items()
	_build_matrix_cells()
	_apply_default_hud()
	_apply_fixed_button_theme()
	_set_command_hover_default()
	_request_manual_bottom_layout_refresh()
	_manual_layout_warmup_frames = 3
	if _subgroup_text != null:
		_subgroup_text.visible = false

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_request_manual_bottom_layout_refresh()

func _process(delta: float) -> void:
	_elapsed_seconds += delta
	_time_text.text = _format_clock(_elapsed_seconds)
	if _manual_layout_warmup_frames > 0:
		_manual_layout_warmup_frames -= 1
		_request_manual_bottom_layout_refresh()

func update_hud(snapshot: Dictionary) -> void:
	_debug_hud_update_seq += 1
	var update_seq: int = _debug_hud_update_seq
	var snapshot_mode: String = str(snapshot.get("mode", "none"))
	var snapshot_multi_roles_count: int = 0
	var snapshot_multi_roles_variant: Variant = snapshot.get("multi_roles", [])
	if snapshot_multi_roles_variant is Array:
		snapshot_multi_roles_count = (snapshot_multi_roles_variant as Array).size()
	var snapshot_page_index: int = int(snapshot.get("matrix_page_index", 0))
	var snapshot_page_count: int = int(snapshot.get("matrix_page_count", 1))
	_hudjit_log("update_hud#%d begin mode=%s last_mode=%s entering_multi=%s roles=%d page=%d/%d hint_len=%d cmd_hint_len=%d" % [
		update_seq,
		snapshot_mode,
		_last_hud_mode,
		str(snapshot_mode == "multi" and _last_hud_mode != "multi"),
		snapshot_multi_roles_count,
		snapshot_page_index + 1,
		maxi(1, snapshot_page_count),
		str(snapshot.get("selection_hint", "")).length(),
		str(snapshot.get("command_hint", "")).length()
	])

	_minerals_value.text = "%d" % int(snapshot.get("minerals", 0))
	_gas_value.text = "%d" % int(snapshot.get("gas", 0))
	var supply_used: int = int(snapshot.get("supply_used", 0))
	var supply_cap: int = maxi(1, int(snapshot.get("supply_cap", 1)))
	_supply_value.text = "%d / %d" % [supply_used, supply_cap]
	_supply_value.modulate = Color(1.0, 0.42, 0.35) if supply_used >= supply_cap else Color(0.72, 0.96, 1.0)
	_legacy_info_text.text = str(snapshot.get("top_legacy_text", ""))

	_selection_hint_text.text = str(snapshot.get("selection_hint", "No selection."))
	_command_hint_text.text = str(snapshot.get("command_hint", ""))

	var mode: String = snapshot_mode
	var entering_multi: bool = mode == "multi" and _last_hud_mode != "multi"
	_last_hud_mode = mode
	_single_container.visible = mode == "single"
	if mode == "multi":
		_multi_matrix_root.visible = true
		_set_multi_matrix_guard_hidden(enable_multi_mode_transition_guard and entering_multi)
	else:
		_set_multi_matrix_guard_hidden(false)
		_multi_matrix_root.visible = false
	if mode == "multi" and enable_multi_mode_transition_guard and entering_multi:
		_hudjit_log("update_hud#%d schedule multi reveal (guard enabled)." % update_seq)
		_schedule_multi_matrix_reveal()

	_single_name_text.text = str(snapshot.get("single_title", "No Selection"))
	_single_detail_text.text = str(snapshot.get("single_detail", "-"))
	_armor_type_text.text = str(snapshot.get("single_armor", "Armor Type: --"))
	_health_bar.value = clampf(float(snapshot.get("status_health", 1.0)) * 100.0, 0.0, 100.0)
	_shield_bar.value = clampf(float(snapshot.get("status_shield", 0.0)) * 100.0, 0.0, 100.0)
	_energy_bar.value = clampf(float(snapshot.get("status_energy", 0.0)) * 100.0, 0.0, 100.0)
	_health_value_label.text = "HP %d%%" % int(round(_health_bar.value))
	_shield_value_label.text = "SH %d%%" % int(round(_shield_bar.value))
	_energy_value_label.text = "EN %d%%" % int(round(_energy_bar.value))

	var show_production: bool = bool(snapshot.get("show_production", false))
	_single_detail_root.visible = _single_container.visible and not show_production
	_production_queue_root.visible = _single_container.visible and show_production
	var queue_size: int = int(snapshot.get("queue_size", 0))
	var queue_progress: float = clampf(float(snapshot.get("queue_progress", 0.0)), 0.0, 1.0)
	_queue_summary_text.text = "Queue Size: %d" % queue_size
	_queue_progress_bar.value = queue_progress * 100.0
	_apply_queue_preview(_to_string_array(snapshot.get("queue_preview", [])))

	_apply_multi_roles(
		_to_string_array(snapshot.get("multi_roles", [])),
		_to_string_array(snapshot.get("multi_role_kinds", [])),
		str(snapshot.get("active_subgroup_kind", ""))
	)
	var matrix_page_index: int = int(snapshot.get("matrix_page_index", 0))
	var matrix_page_count: int = maxi(1, int(snapshot.get("matrix_page_count", 1)))
	_apply_matrix_page_buttons(matrix_page_index, matrix_page_count, mode == "multi")
	_apply_control_group_entries(snapshot.get("control_group_entries", []))

	_portrait_glyph.text = str(snapshot.get("portrait_glyph", "?"))
	_portrait_name_text.text = str(snapshot.get("portrait_title", "No Selection"))
	_portrait_role_text.text = str(snapshot.get("portrait_subtitle", "-"))

	_apply_command_entries(snapshot.get("command_entries", []))
	_apply_notifications(_to_string_array(snapshot.get("notifications", [])))
	_refresh_manual_layout_after_hud_update()
	if mode == "multi" or entering_multi:
		_hudjit_dump_matrix_state("update_hud#%d end" % update_seq, true)
	else:
		_hudjit_dump_matrix_state("update_hud#%d end" % update_seq, false)

func _apply_default_hud() -> void:
	update_hud({
		"minerals": 0,
		"gas": 0,
		"supply_used": 0,
		"supply_cap": 40,
		"selection_hint": "Left click to select, drag for box selection, right click to move.",
		"top_legacy_text": "M: 0   G: 0   Supply: 0/40",
		"mode": "none",
		"single_title": "No Selection",
		"single_detail": "Select a unit or building to inspect details.",
		"single_armor": "Armor Type: --",
		"show_production": false,
		"queue_size": 0,
		"queue_progress": 0.0,
		"queue_preview": [],
		"multi_roles": [],
		"control_group_entries": [],
		"portrait_glyph": "?",
		"portrait_title": "No Selection",
		"portrait_subtitle": "-",
		"command_hint": "No active command card.",
		"command_entries": [],
		"notifications": [
			"B: Build Menu",
			"R: Train Worker / T: Train Soldier",
			"A: Attack / S: Stop"
		]
	})

func _setup_static_styles() -> void:
	_style_panel(_top_bar, Color(0.03, 0.08, 0.14, 0.92), Color(0.16, 0.42, 0.58, 0.95))
	_style_panel(_selection_panel, Color(0.06, 0.12, 0.2, 0.88), Color(0.18, 0.42, 0.56, 0.95))
	_style_panel(_minimap_panel, Color(0.03, 0.08, 0.14, 0.95), Color(0.19, 0.42, 0.58, 0.95))
	_style_panel(_queue_panel, Color(0.04, 0.1, 0.18, 0.9), Color(0.16, 0.38, 0.54, 0.95))
	_style_panel(_portrait_panel, Color(0.05, 0.11, 0.18, 0.9), Color(0.16, 0.38, 0.52, 0.95))
	_style_panel(_command_hover_panel, Color(0.03, 0.09, 0.16, 0.92), Color(0.21, 0.5, 0.68, 0.98))
	_style_panel(_command_panel, Color(0.04, 0.09, 0.16, 0.9), Color(0.16, 0.39, 0.56, 0.95))
	_style_panel(_resource_panel, Color(0.04, 0.1, 0.18, 0.84), Color(0.18, 0.42, 0.58, 0.95))
	_style_panel(_center_top, Color(0.05, 0.12, 0.2, 0.84), Color(0.18, 0.42, 0.58, 0.95))
	_style_panel(_system_panel, Color(0.05, 0.12, 0.2, 0.84), Color(0.18, 0.42, 0.58, 0.95))
	_style_panel(_notification_panel, Color(0.02, 0.07, 0.14, 0.75), Color(0.14, 0.34, 0.5, 0.85))
	_style_panel(_single_status_root, Color(0.03, 0.09, 0.16, 0.85), Color(0.14, 0.34, 0.5, 0.92))
	_style_panel(_single_detail_root, Color(0.03, 0.09, 0.16, 0.85), Color(0.14, 0.34, 0.5, 0.92))
	_style_panel(_production_queue_root, Color(0.03, 0.09, 0.16, 0.85), Color(0.14, 0.34, 0.5, 0.92))
	_style_panel(_multi_matrix_root, Color(0.03, 0.09, 0.16, 0.85), Color(0.14, 0.34, 0.5, 0.92))

	_style_progress_bar(_health_bar, Color(0.26, 0.87, 0.43))
	_style_progress_bar(_shield_bar, Color(0.21, 0.64, 0.98))
	_style_progress_bar(_energy_bar, Color(0.95, 0.76, 0.22))
	_style_progress_bar(_queue_progress_bar, Color(0.92, 0.62, 0.22))
	_style_bar_overlay_label(_health_value_label)
	_style_bar_overlay_label(_shield_value_label)
	_style_bar_overlay_label(_energy_value_label)

func _connect_minimap_view() -> void:
	if _minimap_view == null or not is_instance_valid(_minimap_view):
		return
	if _minimap_view.has_signal("navigate_requested"):
		var callback: Callable = Callable(self, "_on_minimap_view_navigate_requested")
		if not _minimap_view.is_connected("navigate_requested", callback):
			_minimap_view.connect("navigate_requested", callback)
	if _minimap_view.has_signal("ping_requested"):
		var ping_callback: Callable = Callable(self, "_on_minimap_view_ping_requested")
		if not _minimap_view.is_connected("ping_requested", ping_callback):
			_minimap_view.connect("ping_requested", ping_callback)

func _connect_ping_button() -> void:
	if _ping_button == null or not is_instance_valid(_ping_button):
		return
	var callback: Callable = Callable(self, "_on_ping_button_pressed")
	if not _ping_button.pressed.is_connected(callback):
		_ping_button.pressed.connect(callback)

func _on_ping_button_pressed() -> void:
	set_ping_mode_armed(true)
	emit_signal("ping_button_pressed")

func _on_minimap_view_navigate_requested(world_position: Vector3) -> void:
	emit_signal("minimap_navigate_requested", world_position)

func _on_minimap_view_ping_requested(world_position: Vector3) -> void:
	set_ping_mode_armed(false)
	emit_signal("ping_requested", world_position)

func set_ping_mode_armed(armed: bool) -> void:
	_minimap_ping_armed = armed
	if _minimap_view != null and is_instance_valid(_minimap_view) and _minimap_view.has_method("set_ping_mode"):
		_minimap_view.call("set_ping_mode", armed)

func update_minimap(snapshot: Dictionary) -> void:
	if _minimap_view == null or not is_instance_valid(_minimap_view):
		return
	if _minimap_view.has_method("apply_snapshot"):
		_minimap_view.call("apply_snapshot", snapshot)

func _apply_fixed_button_theme() -> void:
	for node in find_children("*", "Button", true, false):
		var button: Button = node as Button
		if button == null:
			continue
		button.focus_mode = Control.FOCUS_NONE
		_apply_button_style(button)

func _build_queue_slot_labels() -> void:
	_queue_slot_labels.clear()
	for child in _queue_slots.get_children():
		child.queue_free()

	for i in QUEUE_SLOTS:
		var slot_panel: PanelContainer = PanelContainer.new()
		slot_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slot_panel.custom_minimum_size = Vector2(0.0, 24.0)
		slot_panel.add_theme_stylebox_override("panel", _build_stylebox(Color(0.05, 0.12, 0.2, 0.9), Color(0.16, 0.38, 0.54, 0.95), 1, 4))

		var label: Label = Label.new()
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.text = "--"
		slot_panel.add_child(label)
		_queue_slots.add_child(slot_panel)
		_queue_slot_labels.append(label)

func _build_command_items() -> void:
	_command_items.clear()
	for child in _command_grid.get_children():
		child.queue_free()

	for i in COMMAND_SLOTS:
		var item: Control = COMMAND_ITEM_SCENE.instantiate() as Control
		if item == null:
			continue
		item.layout_mode = 0
		item.anchor_left = 0.0
		item.anchor_top = 0.0
		item.anchor_right = 0.0
		item.anchor_bottom = 0.0
		item.size_flags_horizontal = 0
		item.size_flags_vertical = 0
		item.custom_minimum_size = Vector2.ZERO
		if item.has_signal("pressed"):
			item.connect("pressed", Callable(self, "_on_command_item_pressed"))
		if item.has_signal("hover_started"):
			item.connect("hover_started", Callable(self, "_on_command_item_hover_started"))
		if item.has_signal("hover_ended"):
			item.connect("hover_ended", Callable(self, "_on_command_item_hover_ended"))
		_command_grid.add_child(item)
		_command_items.append(item)
	_apply_manual_command_grid_layout()

func _cache_control_group_buttons() -> void:
	_control_group_buttons.clear()
	if _control_group_bar == null:
		return
	var button_index: int = 0
	for child in _control_group_bar.get_children():
		var button: Button = child as Button
		if button == null:
			continue
		_control_group_buttons.append(button)
		button.focus_mode = Control.FOCUS_NONE
		button.self_modulate = Color(1.0, 1.0, 1.0, 0.0)
		button.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.text = ""
		button.tooltip_text = ""
		button.set_meta("group_id", button_index)
		var callback: Callable = Callable(self, "_on_control_group_button_pressed").bind(button)
		if not button.pressed.is_connected(callback):
			button.pressed.connect(callback)
		button_index += 1

func _apply_control_group_entries(entries_variant: Variant) -> void:
	var entry_map: Dictionary = {}
	if entries_variant is Array:
		var entries: Array = entries_variant as Array
		for entry_value in entries:
			if not (entry_value is Dictionary):
				continue
			var entry: Dictionary = entry_value as Dictionary
			var group_id: int = int(entry.get("group_id", -1))
			if group_id < 0:
				continue
			entry_map[group_id] = entry

	for button in _control_group_buttons:
		if button == null or not is_instance_valid(button):
			continue
		var group_id: int = int(button.get_meta("group_id"))
		if not entry_map.has(group_id):
			_set_control_group_button_state(button, group_id, 0, false, false)
			continue
		var entry: Dictionary = entry_map[group_id] as Dictionary
		var count: int = int(entry.get("count", 0))
		var active: bool = bool(entry.get("active", false))
		_set_control_group_button_state(button, group_id, count, true, active)

func _set_control_group_button_state(button: Button, group_id: int, count: int, enabled: bool, active: bool) -> void:
	if button == null:
		return
	if not enabled:
		button.text = ""
		button.tooltip_text = ""
		button.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.self_modulate = Color(1.0, 1.0, 1.0, 0.0)
		_apply_control_group_button_style(button, false)
		return
	button.text = "%d(%d)" % [group_id, count]
	button.tooltip_text = "Control Group %d (%d)" % [group_id, count]
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.self_modulate = Color(1.0, 1.0, 1.0, 1.0)
	_apply_control_group_button_style(button, active)

func _apply_control_group_button_style(button: Button, active: bool) -> void:
	if button == null:
		return
	var border: Color = Color(0.2, 0.44, 0.62, 0.95)
	var background: Color = Color(0.05, 0.11, 0.18, 0.92)
	if active:
		border = Color(1.0, 0.95, 0.55, 0.98)
		background = Color(0.12, 0.21, 0.3, 0.98)
	button.add_theme_stylebox_override("normal", _build_stylebox(background, border, 1 if not active else 2, 5))
	button.add_theme_stylebox_override("hover", _build_stylebox(background.lightened(0.08), border.lightened(0.1), 1 if not active else 2, 5))
	button.add_theme_stylebox_override("pressed", _build_stylebox(background.darkened(0.08), border, 1 if not active else 2, 5))
	button.add_theme_color_override("font_color", Color(0.92, 0.97, 1.0))

func _on_control_group_button_pressed(button: Button) -> void:
	if button == null:
		return
	var group_id: int = int(button.get_meta("group_id"))
	emit_signal("control_group_pressed", group_id)

func _apply_matrix_page_buttons(page_index: int, page_count: int, matrix_visible: bool) -> void:
	if _matrix_footer == null or _matrix_page_buttons_root == null:
		return
	var show_pages: bool = matrix_visible and page_count > 1
	_hudjit_log("apply_matrix_page_buttons visible=%s page=%d/%d show_pages=%s existing_buttons=%d" % [
		str(matrix_visible),
		page_index + 1,
		maxi(1, page_count),
		str(show_pages),
		_matrix_page_buttons.size()
	], true)
	_matrix_footer.visible = show_pages
	if not show_pages:
		for button in _matrix_page_buttons:
			if button != null and is_instance_valid(button):
				button.queue_free()
		_matrix_page_buttons.clear()
		_apply_manual_matrix_footer_layout()
		return

	if _matrix_page_buttons.size() != page_count:
		for button in _matrix_page_buttons:
			if button != null and is_instance_valid(button):
				button.queue_free()
		_matrix_page_buttons.clear()
		for i in page_count:
			var page_button: Button = Button.new()
			page_button.custom_minimum_size = Vector2(manual_matrix_page_button_min_width, manual_matrix_page_button_height)
			page_button.text = str(i + 1)
			page_button.focus_mode = Control.FOCUS_NONE
			page_button.pressed.connect(Callable(self, "_on_matrix_page_button_pressed").bind(i))
			_matrix_page_buttons_root.add_child(page_button)
			_matrix_page_buttons.append(page_button)

	for i in _matrix_page_buttons.size():
		var page_button: Button = _matrix_page_buttons[i]
		if page_button == null or not is_instance_valid(page_button):
			continue
		page_button.text = str(i + 1)
		page_button.tooltip_text = "Selection Page %d" % [i + 1]
		var active: bool = i == page_index
		page_button.disabled = active
		_apply_matrix_page_button_style(page_button, active)
	_apply_manual_matrix_footer_layout()

func _apply_matrix_page_button_style(button: Button, active: bool) -> void:
	if button == null:
		return
	var border: Color = Color(0.2, 0.44, 0.62, 0.95)
	var background: Color = Color(0.05, 0.11, 0.18, 0.9)
	if active:
		border = Color(1.0, 0.95, 0.55, 0.98)
		background = Color(0.14, 0.24, 0.36, 0.98)
	button.add_theme_stylebox_override("normal", _build_stylebox(background, border, 1 if not active else 2, 4))
	button.add_theme_stylebox_override("hover", _build_stylebox(background.lightened(0.08), border.lightened(0.1), 1 if not active else 2, 4))
	button.add_theme_stylebox_override("pressed", _build_stylebox(background.darkened(0.08), border, 1 if not active else 2, 4))
	button.add_theme_stylebox_override("disabled", _build_stylebox(background, border, 1 if not active else 2, 4))
	button.add_theme_color_override("font_color", Color(0.92, 0.97, 1.0))
	button.add_theme_color_override("font_disabled_color", Color(0.98, 0.98, 0.98))

func _on_matrix_page_button_pressed(page_index: int) -> void:
	emit_signal("matrix_page_selected", page_index)

func _build_matrix_cells() -> void:
	_matrix_panels.clear()
	_matrix_labels.clear()
	for child in _matrix_grid.get_children():
		child.queue_free()

	for i in MULTI_SLOTS:
		var cell: PanelContainer = PanelContainer.new()
		cell.layout_mode = 0
		cell.anchor_left = 0.0
		cell.anchor_top = 0.0
		cell.anchor_right = 0.0
		cell.anchor_bottom = 0.0
		cell.size_flags_horizontal = 0
		cell.size_flags_vertical = 0
		cell.custom_minimum_size = Vector2.ZERO
		cell.add_theme_stylebox_override("panel", _matrix_style("empty"))
		cell.mouse_filter = Control.MOUSE_FILTER_STOP
		cell.gui_input.connect(Callable(self, "_on_matrix_cell_gui_input").bind(i))

		var label: Label = Label.new()
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_OFF
		label.clip_text = true
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.size_flags_vertical = Control.SIZE_EXPAND_FILL
		label.text = "--"
		cell.add_child(label)
		_matrix_grid.add_child(cell)
		_matrix_panels.append(cell)
		_matrix_labels.append(label)
	_hudjit_log("build_matrix_cells done total=%d" % _matrix_panels.size(), true)
	_apply_manual_matrix_grid_layout()

func _collect_notification_labels() -> void:
	_notification_labels.clear()
	for child in _notification_list.get_children():
		var label: Label = child as Label
		if label != null:
			_notification_labels.append(label)

func _apply_queue_preview(queue_preview: Array[String]) -> void:
	for i in _queue_slot_labels.size():
		var value: String = "--"
		if i < queue_preview.size():
			value = queue_preview[i]
		_queue_slot_labels[i].text = value

func _apply_multi_roles(multi_roles: Array[String], multi_role_kinds: Array[String], active_subgroup_kind: String = "") -> void:
	_hudjit_log("apply_multi_roles roles=%d kinds=%d active_subgroup=%s" % [
		multi_roles.size(),
		multi_role_kinds.size(),
		active_subgroup_kind
	], true)
	_current_multi_role_kinds = multi_role_kinds.duplicate()
	for i in _matrix_labels.size():
		if i < multi_roles.size():
			var role: String = multi_roles[i]
			_matrix_labels[i].text = role
			var role_kind: String = ""
			if i < multi_role_kinds.size():
				role_kind = multi_role_kinds[i]
			var highlighted: bool = _role_matches_subgroup(role, role_kind, active_subgroup_kind)
			_matrix_panels[i].add_theme_stylebox_override("panel", _matrix_style_with_highlight(role, highlighted))
		else:
			_matrix_labels[i].text = "--"
			_matrix_panels[i].add_theme_stylebox_override("panel", _matrix_style("empty"))

func _on_matrix_cell_gui_input(event: InputEvent, index: int) -> void:
	var mouse_button: InputEventMouseButton = event as InputEventMouseButton
	if mouse_button == null:
		return
	if mouse_button.button_index != MOUSE_BUTTON_LEFT or not mouse_button.pressed:
		return
	if index < 0 or index >= _current_multi_role_kinds.size():
		return
	var role_kind: String = _current_multi_role_kinds[index]
	if role_kind == "":
		return
	_hudjit_log("matrix_cell_click index=%d kind=%s shift=%s ctrl=%s" % [
		index,
		role_kind,
		str(mouse_button.shift_pressed),
		str(mouse_button.ctrl_pressed)
	], true)
	emit_signal("multi_role_cell_pressed", index, mouse_button.shift_pressed, mouse_button.ctrl_pressed)

func _role_matches_subgroup(role: String, role_kind: String, subgroup_kind: String) -> bool:
	if subgroup_kind == "":
		return false
	var kind_key: String = role_kind.to_lower().strip_edges()
	if kind_key != "":
		return kind_key == subgroup_kind
	var role_key: String = role.to_lower()
	match subgroup_kind:
		"worker":
			return role_key == "w" or role_key.contains("worker")
		"soldier":
			return role_key == "s" or role_key.contains("soldier")
		_:
			return false

func _matrix_style_with_highlight(role: String, highlighted: bool) -> StyleBoxFlat:
	var style: StyleBoxFlat = _matrix_style(role)
	if not highlighted:
		return style
	style.border_color = Color(1.0, 0.95, 0.55, 0.98)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	return style

func _apply_command_entries(entries_variant: Variant) -> void:
	var entries: Array = []
	if entries_variant is Array:
		entries = entries_variant

	if entries.is_empty():
		_set_command_hover_default()

	for i in _command_items.size():
		var item: Control = _command_items[i]
		if i < entries.size() and entries[i] is Dictionary:
			if item.has_method("apply_entry"):
				item.call("apply_entry", entries[i])
		else:
			if item.has_method("clear_slot"):
				item.call("clear_slot")

func _on_command_item_pressed(command_id: String) -> void:
	emit_signal("command_pressed", command_id)

func _on_command_item_hover_started(hover_data: Dictionary) -> void:
	if _command_hover_text == null or _command_hover_panel == null:
		return
	_command_hover_panel.visible = true
	_command_hover_text.text = _format_command_hover_text(hover_data)
	_refresh_command_hover_layout_for_text_change()

func _on_command_item_hover_ended() -> void:
	_set_command_hover_default()

func _apply_notifications(notifications: Array[String]) -> void:
	for i in _notification_labels.size():
		if i < notifications.size():
			_notification_labels[i].text = notifications[i]
		else:
			_notification_labels[i].text = ""

func _set_command_hover_default() -> void:
	if _command_hover_text == null or _command_hover_panel == null:
		return
	_command_hover_panel.visible = false
	_command_hover_text.text = ""
	_refresh_command_hover_layout_for_text_change()

func _refresh_command_hover_layout_for_text_change() -> void:
	if not use_manual_bottom_layout:
		return
	if _command_column == null or not is_instance_valid(_command_column):
		return
	if _command_column.size.x <= 1.0 or _command_column.size.y <= 1.0:
		_request_manual_bottom_layout_refresh()
		return
	if _is_applying_manual_layout:
		_request_manual_bottom_layout_refresh()
		return
	_apply_manual_command_column_layout()

func _format_command_hover_text(hover_data: Dictionary) -> String:
	var label: String = str(hover_data.get("label", ""))
	var command_id: String = str(hover_data.get("id", ""))
	var cost_text: String = str(hover_data.get("cost_text", ""))
	var detail_text: String = str(hover_data.get("detail_text", ""))
	var hotkey: String = str(hover_data.get("hotkey", ""))
	var disabled_reason: String = str(hover_data.get("disabled_reason", ""))
	var enabled: bool = bool(hover_data.get("enabled", true))

	var lines: Array[String] = []
	var header: String = label if label != "" else command_id
	if header != "":
		lines.append(header)
	if cost_text != "":
		lines.append("Cost: %s" % cost_text)
	if detail_text != "":
		lines.append(detail_text)
	if hotkey != "":
		lines.append("Hotkey: %s" % hotkey)
	if not enabled and disabled_reason != "":
		lines.append(disabled_reason)
	if lines.is_empty():
		return COMMAND_HOVER_DEFAULT_TEXT
	return "\n".join(lines)

func _style_panel(panel: PanelContainer, background: Color, border: Color) -> void:
	panel.add_theme_stylebox_override("panel", _build_stylebox(background, border, 2, 8))

func _style_progress_bar(progress_bar: ProgressBar, fill_color: Color) -> void:
	progress_bar.show_percentage = false
	progress_bar.min_value = 0.0
	progress_bar.max_value = 100.0
	progress_bar.add_theme_stylebox_override("background", _build_stylebox(Color(0.01, 0.05, 0.09, 0.85), Color(0.16, 0.36, 0.52, 0.88), 1, 3))
	progress_bar.add_theme_stylebox_override("fill", _build_stylebox(fill_color, fill_color.darkened(0.25), 1, 3))

func _style_bar_overlay_label(label: Label) -> void:
	if label == null:
		return
	label.add_theme_color_override("font_color", Color(0.96, 0.99, 1.0))
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.75))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)

func _configure_bottom_layout_nodes() -> void:
	var manual_nodes: Array[Control] = []
	if use_manual_top_layout:
		manual_nodes.append_array([_resource_panel, _center_top, _system_panel])
	if use_manual_bottom_layout:
		manual_nodes.append_array([_selection_panel, _queue_column, _portrait_column, _command_column])
	for node in manual_nodes:
		if node == null:
			continue
		node.layout_mode = 0
		node.anchor_left = 0.0
		node.anchor_top = 0.0
		node.anchor_right = 0.0
		node.anchor_bottom = 0.0
	if _queue_content != null:
		_queue_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_queue_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if _command_content != null:
		_command_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_command_content.size_flags_vertical = Control.SIZE_EXPAND_FILL

func _request_manual_bottom_layout_refresh() -> void:
	if not use_manual_bottom_layout and not use_manual_top_layout:
		_hudjit_log("request_layout_refresh skipped: manual top/bottom disabled.", true)
		return
	if _is_applying_manual_layout:
		_hudjit_log("request_layout_refresh skipped: currently applying manual layout.", true)
		return
	if _manual_layout_refresh_pending:
		_hudjit_log("request_layout_refresh skipped: already pending.", true)
		return
	_manual_layout_refresh_pending = true
	_hudjit_log("request_layout_refresh scheduled (deferred apply).", true)
	call_deferred("_apply_manual_bottom_layout")

func _refresh_manual_layout_after_hud_update() -> void:
	if not use_manual_bottom_layout and not use_manual_top_layout:
		_hudjit_log("refresh_layout_after_hud_update skipped: manual top/bottom disabled.", true)
		return
	if _is_applying_manual_layout:
		_hudjit_log("refresh_layout_after_hud_update delayed: currently applying.", true)
		_request_manual_bottom_layout_refresh()
		return
	_manual_layout_refresh_pending = false
	_hudjit_log("refresh_layout_after_hud_update applying immediately.", true)
	_apply_manual_bottom_layout()

func _schedule_multi_matrix_reveal() -> void:
	if _multi_matrix_reveal_pending:
		_hudjit_log("schedule_multi_matrix_reveal skipped: already pending.", true)
		return
	_multi_matrix_reveal_pending = true
	_hudjit_log("schedule_multi_matrix_reveal deferred.", true)
	call_deferred("_apply_multi_matrix_reveal")

func _set_multi_matrix_guard_hidden(hidden: bool) -> void:
	if _multi_matrix_root == null:
		return
	if _multi_matrix_guard_hidden == hidden:
		return
	_multi_matrix_guard_hidden = hidden
	if hidden:
		_multi_matrix_root.self_modulate = Color(1.0, 1.0, 1.0, 0.0)
		_multi_matrix_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_hudjit_log("multi_matrix_guard_hidden=true (layout kept, visual hidden).", true)
	else:
		_multi_matrix_root.self_modulate = Color(1.0, 1.0, 1.0, 1.0)
		_multi_matrix_root.mouse_filter = Control.MOUSE_FILTER_STOP
		_hudjit_log("multi_matrix_guard_hidden=false (visual restore).", true)

func _apply_multi_matrix_reveal() -> void:
	_multi_matrix_reveal_pending = false
	if _last_hud_mode != "multi":
		_hudjit_log("apply_multi_matrix_reveal skipped: last mode is %s." % _last_hud_mode, true)
		return
	_hudjit_log("apply_multi_matrix_reveal guard release, forcing layout refresh.")
	_set_multi_matrix_guard_hidden(false)
	_multi_matrix_root.visible = true
	_refresh_manual_layout_after_hud_update()
	_hudjit_dump_matrix_state("after_multi_matrix_reveal", true)

func _apply_manual_bottom_layout() -> void:
	if _is_applying_manual_layout:
		_hudjit_log("apply_manual_bottom_layout skipped: re-entry blocked.", true)
		return
	_debug_layout_seq += 1
	var layout_seq: int = _debug_layout_seq
	_hudjit_log("layout#%d begin bottom_row=%s queue_content=%s mode=%s" % [
		layout_seq,
		_hudjit_vec2(_bottom_row.size if _bottom_row != null else Vector2.ZERO),
		_hudjit_vec2(_queue_content.size if _queue_content != null else Vector2.ZERO),
		_last_hud_mode
	], true)
	_manual_layout_refresh_pending = false
	_is_applying_manual_layout = true
	if use_manual_top_layout:
		_apply_manual_top_layout()
	if use_manual_bottom_layout:
		_apply_manual_bottom_row_layout()
	_is_applying_manual_layout = false
	if _last_hud_mode == "multi":
		_hudjit_dump_matrix_state("layout#%d end" % layout_seq, true)
	else:
		_hudjit_dump_matrix_state("layout#%d end" % layout_seq, false)

func _apply_manual_top_layout() -> void:
	if _top_bar_row == null:
		return
	var area_size: Vector2 = _top_bar_row.size
	if area_size.x <= 1.0 or area_size.y <= 1.0:
		return

	var ratios: PackedFloat32Array = PackedFloat32Array([
		maxf(0.001, manual_top_section_ratios.x),
		maxf(0.001, manual_top_section_ratios.y),
		maxf(0.001, manual_top_section_ratios.z)
	])
	var ratio_total: float = 0.0
	for ratio in ratios:
		ratio_total += ratio

	var section_count: int = 3
	var gap: float = maxf(0.0, manual_top_gap)
	var pad_x: float = maxf(0.0, manual_top_padding.x)
	var pad_y: float = maxf(0.0, manual_top_padding.y)
	var usable_width: float = maxf(0.0, area_size.x - pad_x * 2.0 - gap * float(section_count - 1))
	var usable_height: float = maxf(0.0, area_size.y - pad_y * 2.0)

	var section_widths: PackedFloat32Array = PackedFloat32Array()
	var consumed_width: float = 0.0
	for i in section_count:
		var section_width: float = 0.0
		if i == section_count - 1:
			section_width = maxf(0.0, usable_width - consumed_width)
		else:
			section_width = floor(usable_width * (ratios[i] / ratio_total))
			consumed_width += section_width
		section_widths.append(section_width)

	var x: float = pad_x
	var y: float = pad_y
	_set_manual_rect(_resource_panel, Vector2(x, y), Vector2(section_widths[0], usable_height))
	x += section_widths[0] + gap
	_set_manual_rect(_center_top, Vector2(x, y), Vector2(section_widths[1], usable_height))
	x += section_widths[1] + gap
	_set_manual_rect(_system_panel, Vector2(x, y), Vector2(section_widths[2], usable_height))

func _apply_manual_bottom_row_layout() -> void:
	if _bottom_row == null:
		return
	var area_size: Vector2 = _bottom_row.size
	if area_size.x <= 1.0 or area_size.y <= 1.0:
		return

	var ratios: PackedFloat32Array = PackedFloat32Array([
		maxf(0.001, manual_bottom_section_ratios.x),
		maxf(0.001, manual_bottom_section_ratios.y),
		maxf(0.001, manual_bottom_section_ratios.z),
		maxf(0.001, manual_bottom_section_ratios.w)
	])
	var ratio_total: float = 0.0
	for ratio in ratios:
		ratio_total += ratio

	var section_count: int = 4
	var gap: float = maxf(0.0, manual_bottom_gap)
	var pad_x: float = maxf(0.0, manual_bottom_padding.x)
	var pad_y: float = maxf(0.0, manual_bottom_padding.y)
	var usable_width: float = maxf(0.0, area_size.x - pad_x * 2.0 - gap * float(section_count - 1))
	var usable_height: float = maxf(0.0, area_size.y - pad_y * 2.0)

	var section_widths: PackedFloat32Array = PackedFloat32Array()
	var consumed_width: float = 0.0
	for i in section_count:
		var section_width: float = 0.0
		if i == section_count - 1:
			section_width = maxf(0.0, usable_width - consumed_width)
		else:
			section_width = floor(usable_width * (ratios[i] / ratio_total))
			consumed_width += section_width
		section_widths.append(section_width)

	# Expand QueueColumn based on matrix extra columns and shrink CommandColumn accordingly.
	# Portrait keeps width and only shifts right; Command keeps right edge anchored.
	var extra_matrix_columns: int = maxi(0, manual_matrix_columns - 8)
	var queue_right_expand: float = maxf(0.0, manual_queue_content_right_extra_width) * float(extra_matrix_columns)
	if queue_right_expand > 0.0 and section_widths.size() >= 4:
		var command_width: float = section_widths[3]
		var applied_expand: float = minf(queue_right_expand, maxf(0.0, command_width - 1.0))
		section_widths[1] += applied_expand
		section_widths[3] -= applied_expand

	var x: float = pad_x
	var y: float = pad_y
	_set_manual_rect(_selection_panel, Vector2(x, y), Vector2(section_widths[0], usable_height))
	x += section_widths[0] + gap
	_set_manual_rect(_queue_column, Vector2(x, y), Vector2(section_widths[1], usable_height))
	x += section_widths[1] + gap
	_set_manual_rect(_portrait_column, Vector2(x, y), Vector2(section_widths[2], usable_height))
	x += section_widths[2] + gap
	_set_manual_rect(_command_column, Vector2(x, y), Vector2(section_widths[3], usable_height))

	_apply_manual_queue_column_layout()
	_apply_manual_portrait_column_layout()
	_apply_manual_command_column_layout()

func _apply_manual_queue_column_layout() -> void:
	if _queue_column == null:
		return
	var area_size: Vector2 = _queue_column.size
	if area_size.x <= 1.0 or area_size.y <= 1.0:
		return
	var top_height: float = clampf(manual_queue_top_height, 0.0, area_size.y)
	var gap: float = maxf(0.0, manual_queue_gap)
	var panel_height: float = maxf(0.0, area_size.y - top_height - gap)
	_set_manual_rect(_queue_top_spacer, Vector2(0.0, 0.0), Vector2(area_size.x, top_height))
	_set_manual_rect(_queue_panel, Vector2(0.0, top_height + gap), Vector2(area_size.x, panel_height))
	var queue_content_rect: Rect2 = _get_panel_content_rect(_queue_panel)
	_set_manual_rect(_queue_content, queue_content_rect.position, queue_content_rect.size)
	_apply_manual_queue_content_layout()

func _apply_manual_queue_content_layout() -> void:
	if _queue_content == null:
		return
	var area_size: Vector2 = _queue_content.size
	if area_size.x <= 1.0 or area_size.y <= 1.0:
		_hudjit_log("queue_content_layout retry: invalid size=%s mode=%s" % [_hudjit_vec2(area_size), _last_hud_mode], true)
		_request_manual_bottom_layout_refresh()
		return
	if _last_hud_mode == "multi":
		_hudjit_log("queue_content_layout mode=multi size=%s single_vis=%s multi_vis=%s" % [
			_hudjit_vec2(area_size),
			str(_single_container.visible),
			str(_multi_matrix_root.visible)
		], true)

	var pad_x: float = maxf(0.0, manual_queue_content_padding.x)
	var pad_y: float = maxf(0.0, manual_queue_content_padding.y)
	var gap: float = maxf(0.0, manual_queue_content_gap)
	var content_width: float = maxf(0.0, area_size.x - pad_x * 2.0)
	var content_height: float = maxf(0.0, area_size.y - pad_y * 2.0)

	var hint_height: float = clampf(manual_queue_hint_height, 0.0, content_height)
	if _selection_hint_text != null:
		_set_manual_rect(_selection_hint_text, Vector2(pad_x, pad_y), Vector2(content_width, hint_height))

	var y: float = pad_y + hint_height
	if hint_height > 0.0:
		y += gap
	var remaining_height: float = maxf(0.0, pad_y + content_height - y)

	if _single_container.visible:
		_set_manual_rect(_single_container, Vector2(pad_x, y), Vector2(content_width, remaining_height))
	else:
		_set_manual_rect(_single_container, Vector2(pad_x, y), Vector2(content_width, 0.0))

	if _multi_matrix_root.visible:
		_set_manual_rect(_multi_matrix_root, Vector2(pad_x, y), Vector2(content_width, remaining_height))
	else:
		_set_manual_rect(_multi_matrix_root, Vector2(pad_x, y), Vector2(content_width, 0.0))
	_apply_manual_single_container_layout()
	_apply_manual_multi_matrix_layout()

func _apply_manual_single_container_layout() -> void:
	if _single_container == null:
		return
	var area_size: Vector2 = _single_container.size
	if area_size.x <= 1.0 or area_size.y <= 1.0:
		_request_manual_bottom_layout_refresh()
		return

	var pad_x: float = maxf(0.0, manual_single_container_padding.x)
	var pad_y: float = maxf(0.0, manual_single_container_padding.y)
	var gap: float = maxf(0.0, manual_single_container_gap)
	var content_width: float = maxf(0.0, area_size.x - pad_x * 2.0)
	var content_height: float = maxf(0.0, area_size.y - pad_y * 2.0)

	var status_ratio: float = maxf(0.001, manual_single_status_ratio)
	var aux_ratio: float = maxf(0.001, manual_single_aux_ratio)
	var right_visible: bool = _single_detail_root.visible or _production_queue_root.visible

	if not right_visible:
		_set_manual_rect(_single_status_root, Vector2(pad_x, pad_y), Vector2(content_width, content_height))
		_set_manual_rect(_single_detail_root, Vector2(pad_x, pad_y), Vector2(0.0, 0.0))
		_set_manual_rect(_production_queue_root, Vector2(pad_x, pad_y), Vector2(0.0, 0.0))
		var status_content_rect_full: Rect2 = _get_panel_content_rect(_single_status_root)
		_set_manual_rect(_single_status_content, status_content_rect_full.position, status_content_rect_full.size)
		_set_manual_rect(_single_detail_content, Vector2.ZERO, Vector2.ZERO)
		_set_manual_rect(_production_content, Vector2.ZERO, Vector2.ZERO)
		_apply_manual_single_status_content_layout()
		_apply_manual_single_detail_content_layout()
		_apply_manual_production_content_layout()
		return

	var split_width: float = maxf(0.0, content_width - gap)
	var status_width: float = floor(split_width * (status_ratio / (status_ratio + aux_ratio)))
	var min_status_width: float = maxf(0.0, manual_single_status_min_width)
	var min_aux_width: float = maxf(0.0, manual_single_aux_min_width)
	if split_width >= min_status_width + min_aux_width:
		status_width = clampf(status_width, min_status_width, split_width - min_aux_width)
	else:
		status_width = floor(split_width * 0.5)
	var aux_width: float = maxf(0.0, split_width - status_width)
	var aux_x: float = pad_x + status_width + gap
	_set_manual_rect(_single_status_root, Vector2(pad_x, pad_y), Vector2(status_width, content_height))

	if _single_detail_root.visible:
		_set_manual_rect(_single_detail_root, Vector2(aux_x, pad_y), Vector2(aux_width, content_height))
	else:
		_set_manual_rect(_single_detail_root, Vector2(aux_x, pad_y), Vector2(0.0, 0.0))

	if _production_queue_root.visible:
		_set_manual_rect(_production_queue_root, Vector2(aux_x, pad_y), Vector2(aux_width, content_height))
	else:
		_set_manual_rect(_production_queue_root, Vector2(aux_x, pad_y), Vector2(0.0, 0.0))
	var status_content_rect: Rect2 = _get_panel_content_rect(_single_status_root)
	_set_manual_rect(_single_status_content, status_content_rect.position, status_content_rect.size)
	if _single_detail_root.visible:
		var detail_content_rect: Rect2 = _get_panel_content_rect(_single_detail_root)
		_set_manual_rect(_single_detail_content, detail_content_rect.position, detail_content_rect.size)
	else:
		_set_manual_rect(_single_detail_content, Vector2.ZERO, Vector2.ZERO)
	if _production_queue_root.visible:
		var production_content_rect: Rect2 = _get_panel_content_rect(_production_queue_root)
		_set_manual_rect(_production_content, production_content_rect.position, production_content_rect.size)
	else:
		_set_manual_rect(_production_content, Vector2.ZERO, Vector2.ZERO)
	_apply_manual_single_status_content_layout()
	_apply_manual_single_detail_content_layout()
	_apply_manual_production_content_layout()

func _apply_manual_single_status_content_layout() -> void:
	if _single_status_content == null:
		return
	var area_size: Vector2 = _single_status_content.size
	if area_size.x <= 1.0 or area_size.y <= 1.0:
		_request_manual_bottom_layout_refresh()
		return

	var pad_x: float = maxf(0.0, manual_single_status_padding.x)
	var pad_y: float = maxf(0.0, manual_single_status_padding.y)
	var gap: float = maxf(0.0, manual_single_status_gap)
	var content_width: float = maxf(0.0, area_size.x - pad_x * 2.0)
	var content_height: float = maxf(0.0, area_size.y - pad_y * 2.0)

	var name_height: float = clampf(manual_single_name_height, 0.0, content_height)
	var name_min_height: float = _single_name_text.get_combined_minimum_size().y
	name_height = clampf(maxf(name_height, name_min_height), 0.0, content_height)
	_set_manual_rect(_single_name_text, Vector2(pad_x, pad_y), Vector2(content_width, name_height))

	var y: float = pad_y + name_height
	var remaining: float = maxf(0.0, content_height - name_height)
	if remaining > 0.0:
		y += gap
		remaining = maxf(0.0, remaining - gap)

	var preferred_bar_height: float = maxf(0.0, manual_single_bar_height)
	var bar_gap_total: float = gap * 2.0
	var bar_height: float = 0.0
	if preferred_bar_height * 3.0 + bar_gap_total <= remaining:
		bar_height = preferred_bar_height
	else:
		bar_height = maxf(0.0, (remaining - bar_gap_total) / 3.0)

	_set_manual_rect(_health_bar, Vector2(pad_x, y), Vector2(content_width, bar_height))
	y += bar_height + gap
	_set_manual_rect(_shield_bar, Vector2(pad_x, y), Vector2(content_width, bar_height))
	y += bar_height + gap
	_set_manual_rect(_energy_bar, Vector2(pad_x, y), Vector2(content_width, bar_height))

func _apply_manual_single_detail_content_layout() -> void:
	if _single_detail_content == null:
		return
	var area_size: Vector2 = _single_detail_content.size
	if area_size.x <= 1.0 or area_size.y <= 1.0:
		_request_manual_bottom_layout_refresh()
		return

	var pad_x: float = maxf(0.0, manual_single_detail_padding.x)
	var pad_y: float = maxf(0.0, manual_single_detail_padding.y)
	var gap: float = maxf(0.0, manual_single_detail_gap)
	var content_width: float = maxf(0.0, area_size.x - pad_x * 2.0)
	var content_height: float = maxf(0.0, area_size.y - pad_y * 2.0)

	var title_height: float = clampf(manual_single_detail_title_height, 0.0, content_height)
	var title_min_height: float = _single_detail_title.get_combined_minimum_size().y
	title_height = clampf(maxf(title_height, title_min_height), 0.0, content_height)
	_set_manual_rect(_single_detail_title, Vector2(pad_x, pad_y), Vector2(content_width, title_height))

	var y: float = pad_y + title_height + gap
	var remaining: float = maxf(0.0, content_height - title_height - gap)
	var armor_height: float = clampf(manual_single_detail_armor_height, 0.0, remaining)
	var armor_min_height: float = _armor_type_text.get_combined_minimum_size().y
	armor_height = clampf(maxf(armor_height, armor_min_height), 0.0, remaining)
	var detail_height: float = maxf(0.0, remaining - armor_height - gap)
	_set_manual_rect(_single_detail_text, Vector2(pad_x, y), Vector2(content_width, detail_height))
	_set_manual_rect(_armor_type_text, Vector2(pad_x, y + detail_height + gap), Vector2(content_width, armor_height))

func _apply_manual_production_content_layout() -> void:
	if _production_content == null:
		return
	var area_size: Vector2 = _production_content.size
	if area_size.x <= 1.0 or area_size.y <= 1.0:
		_request_manual_bottom_layout_refresh()
		return

	var pad_x: float = maxf(0.0, manual_production_padding.x)
	var pad_y: float = maxf(0.0, manual_production_padding.y)
	var gap: float = maxf(0.0, manual_production_gap)
	var content_width: float = maxf(0.0, area_size.x - pad_x * 2.0)
	var content_height: float = maxf(0.0, area_size.y - pad_y * 2.0)

	var summary_height: float = clampf(manual_queue_summary_height, 0.0, content_height)
	var summary_min_height: float = _queue_summary_text.get_combined_minimum_size().y
	summary_height = clampf(maxf(summary_height, summary_min_height), 0.0, content_height)
	_set_manual_rect(_queue_summary_text, Vector2(pad_x, pad_y), Vector2(content_width, summary_height))

	var y: float = pad_y + summary_height + gap
	var remaining: float = maxf(0.0, content_height - summary_height - gap)
	var progress_height: float = clampf(manual_queue_progress_height, 0.0, remaining)
	_set_manual_rect(_queue_progress_bar, Vector2(pad_x, y), Vector2(content_width, progress_height))

	y += progress_height + gap
	remaining = maxf(0.0, content_height - summary_height - progress_height - gap * 2.0)
	var slots_height: float = clampf(manual_queue_slots_height, 0.0, remaining)
	var slots_min_height: float = _queue_slots.get_combined_minimum_size().y
	slots_height = clampf(maxf(slots_height, slots_min_height), 0.0, remaining)
	_set_manual_rect(_queue_slots, Vector2(pad_x, y), Vector2(content_width, slots_height))

func _apply_manual_multi_matrix_layout() -> void:
	if _multi_matrix_content == null or _matrix_body == null:
		return
	var root_panel_rect: Rect2 = _get_panel_content_rect(_multi_matrix_root)
	var root_size: Vector2 = root_panel_rect.size
	if root_size.x <= 1.0 or root_size.y <= 1.0:
		_hudjit_log("multi_matrix_layout retry: root_size=%s root_visible=%s" % [
			_hudjit_vec2(root_size),
			str(_multi_matrix_root.visible)
		], true)
		_request_manual_bottom_layout_refresh()
		return
	_hudjit_log("multi_matrix_layout root_size=%s root_pos=%s footer_visible=%s" % [
		_hudjit_vec2(root_size),
		_hudjit_vec2(root_panel_rect.position),
		str(_matrix_footer.visible)
	], true)

	var pad_x: float = maxf(0.0, manual_matrix_content_padding.x)
	var pad_y: float = maxf(0.0, manual_matrix_content_padding.y)
	var content_width: float = maxf(0.0, root_size.x - pad_x * 2.0)
	var content_height: float = maxf(0.0, root_size.y - pad_y * 2.0)
	_set_manual_rect(_multi_matrix_content, root_panel_rect.position + Vector2(pad_x, pad_y), Vector2(content_width, content_height))
	_set_manual_rect(_matrix_body, Vector2(0.0, 0.0), Vector2(content_width, content_height))

	var gap: float = maxf(0.0, manual_matrix_body_gap)
	if _matrix_footer.visible:
		var footer_width: float = clampf(manual_matrix_footer_width, 0.0, content_width)
		var grid_width: float = maxf(0.0, content_width - footer_width - gap)
		_set_manual_rect(_matrix_footer, Vector2(0.0, 0.0), Vector2(footer_width, content_height))
		_set_manual_rect(_matrix_grid, Vector2(footer_width + gap, 0.0), Vector2(grid_width, content_height))
	else:
		_set_manual_rect(_matrix_footer, Vector2(0.0, 0.0), Vector2(0.0, 0.0))
		_set_manual_rect(_matrix_grid, Vector2(0.0, 0.0), Vector2(content_width, content_height))
	_apply_manual_matrix_footer_layout()
	_apply_manual_matrix_grid_layout()
	if _last_hud_mode == "multi":
		_hudjit_dump_matrix_state("after_multi_matrix_layout", true)

func _apply_manual_matrix_footer_layout() -> void:
	if _matrix_footer == null or _matrix_page_buttons_root == null:
		return
	var footer_size: Vector2 = _matrix_footer.size
	if footer_size.x <= 1.0 or footer_size.y <= 1.0:
		_hudjit_log("matrix_footer_layout skipped: footer_size=%s" % _hudjit_vec2(footer_size), true)
		return

	var pad_x: float = maxf(0.0, manual_matrix_footer_padding.x)
	var pad_y: float = maxf(0.0, manual_matrix_footer_padding.y)
	var content_width: float = maxf(0.0, footer_size.x - pad_x * 2.0)
	var content_height: float = maxf(0.0, footer_size.y - pad_y * 2.0)
	_set_manual_rect(_matrix_page_buttons_root, Vector2(pad_x, pad_y), Vector2(content_width, content_height))

	var button_count: int = _matrix_page_buttons.size()
	if button_count <= 0:
		_hudjit_log("matrix_footer_layout no page buttons.", true)
		return
	var gap: float = maxf(0.0, manual_matrix_page_button_gap)
	var gaps_total: float = gap * float(maxi(0, button_count - 1))
	var available_height: float = maxf(0.0, content_height - gaps_total)
	var max_button_height: float = maxf(1.0, floor(available_height / float(button_count)))
	var desired_button_height: float = maxf(1.0, manual_matrix_page_button_height)
	var button_height: float = minf(desired_button_height, max_button_height)
	var min_button_width: float = maxf(1.0, manual_matrix_page_button_min_width)
	var button_width: float = minf(content_width, min_button_width) if content_width > 0.0 else 1.0
	_hudjit_log("matrix_footer_layout size=%s button_count=%d button_size=(%.1f,%.1f)" % [
		_hudjit_vec2(footer_size),
		button_count,
		button_width,
		button_height
	], true)

	var y: float = 0.0
	for page_button in _matrix_page_buttons:
		if page_button == null or not is_instance_valid(page_button):
			continue
		_set_manual_rect(page_button, Vector2(0.0, y), Vector2(button_width, button_height))
		y += button_height + gap

func _apply_manual_matrix_grid_layout() -> void:
	if _matrix_grid == null:
		return
	var grid_size: Vector2 = _matrix_grid.size
	if grid_size.x <= 1.0 or grid_size.y <= 1.0:
		_hudjit_log("matrix_grid_layout skipped: grid_size=%s" % _hudjit_vec2(grid_size), true)
		return
	var cell_count: int = _matrix_panels.size()
	if cell_count <= 0:
		_hudjit_log("matrix_grid_layout skipped: no cells.", true)
		return

	var columns: int = maxi(1, manual_matrix_columns)
	var rows: int = int(ceil(float(cell_count) / float(columns)))
	var h_gap: float = maxf(0.0, manual_matrix_h_gap)
	var v_gap: float = maxf(0.0, manual_matrix_v_gap)
	var available_width: float = maxf(0.0, grid_size.x - h_gap * float(columns - 1))
	var available_height: float = maxf(0.0, grid_size.y - v_gap * float(rows - 1))

	var cell_width: float = maxf(1.0, floor(available_width / float(columns)))
	var cell_height: float = maxf(1.0, floor(available_height / float(rows)))
	var used_width: float = cell_width * float(columns) + h_gap * float(columns - 1)
	var used_height: float = cell_height * float(rows) + v_gap * float(rows - 1)
	var start_x: float = floor(maxf(0.0, (grid_size.x - used_width) * 0.5))
	var start_y: float = floor(maxf(0.0, (grid_size.y - used_height) * 0.5))
	_hudjit_log("matrix_grid_layout grid=%s cols=%d rows=%d cell=(%.1f,%.1f) start=(%.1f,%.1f) gaps=(%.1f,%.1f)" % [
		_hudjit_vec2(grid_size),
		columns,
		rows,
		cell_width,
		cell_height,
		start_x,
		start_y,
		h_gap,
		v_gap
	], true)

	for i in cell_count:
		var panel: PanelContainer = _matrix_panels[i]
		if panel == null:
			continue
		var col: int = i % columns
		var row: int = i / columns
		var x: float = start_x + float(col) * (cell_width + h_gap)
		var y: float = start_y + float(row) * (cell_height + v_gap)
		_set_manual_rect(panel, Vector2(x, y), Vector2(cell_width, cell_height))
	if _last_hud_mode == "multi":
		_hudjit_dump_matrix_state("after_matrix_grid_layout", true)

func _apply_manual_portrait_column_layout() -> void:
	if _portrait_column == null:
		return
	var area_size: Vector2 = _portrait_column.size
	if area_size.x <= 1.0 or area_size.y <= 1.0:
		return
	var top_height: float = clampf(manual_portrait_top_height, 0.0, area_size.y)
	var gap: float = maxf(0.0, manual_portrait_gap)
	var panel_height: float = maxf(0.0, area_size.y - top_height - gap)
	_set_manual_rect(_portrait_top_spacer, Vector2(0.0, 0.0), Vector2(area_size.x, top_height))
	_set_manual_rect(_portrait_panel, Vector2(0.0, top_height + gap), Vector2(area_size.x, panel_height))

func _apply_manual_command_column_layout() -> void:
	if _command_column == null:
		return
	var area_size: Vector2 = _command_column.size
	if area_size.x <= 1.0 or area_size.y <= 1.0:
		return
	var gap: float = maxf(0.0, manual_command_gap)
	var max_hover_height: float = maxf(0.0, area_size.y - gap)
	var base_hover_height: float = clampf(manual_command_hover_height, 0.0, max_hover_height)
	var hover_height: float = clampf(_compute_command_hover_panel_height(area_size.x, base_hover_height), base_hover_height, max_hover_height)
	# Keep hover panel bottom anchored to base height, so extra height expands upward.
	var hover_bottom_y: float = base_hover_height
	var hover_y: float = hover_bottom_y - hover_height
	var command_y: float = hover_bottom_y + gap
	var panel_height: float = maxf(0.0, area_size.y - command_y)
	_set_manual_rect(_command_hover_panel, Vector2(0.0, hover_y), Vector2(area_size.x, hover_height))
	_set_manual_rect(_command_panel, Vector2(0.0, command_y), Vector2(area_size.x, panel_height))
	var command_content_rect: Rect2 = _get_panel_content_rect(_command_panel)
	_set_manual_rect(_command_content, command_content_rect.position, command_content_rect.size)
	_apply_manual_command_content_layout()

func _compute_command_hover_panel_height(panel_width: float, min_height: float) -> float:
	if _command_hover_panel == null or _command_hover_text == null:
		return min_height
	var hover_text: String = _command_hover_text.text.strip_edges()
	if hover_text == "":
		return min_height
	var style: StyleBox = _command_hover_panel.get_theme_stylebox("panel")
	var content_width: float = maxf(1.0, panel_width)
	var extra_vertical: float = 0.0
	if style != null:
		content_width = maxf(1.0, panel_width - style.get_margin(SIDE_LEFT) - style.get_margin(SIDE_RIGHT))
		extra_vertical = style.get_margin(SIDE_TOP) + style.get_margin(SIDE_BOTTOM)

	var font: Font = _command_hover_text.get_theme_font("font")
	var font_size: int = _command_hover_text.get_theme_font_size("font_size")
	var line_height: float = 16.0
	if font != null:
		line_height = maxf(1.0, font.get_height(font_size))

	var line_spacing: float = 0.0
	if _command_hover_text.has_theme_constant("line_spacing"):
		line_spacing = float(_command_hover_text.get_theme_constant("line_spacing"))

	var raw_lines: PackedStringArray = hover_text.split("\n", false)
	if raw_lines.is_empty():
		raw_lines.append("")
	var estimated_line_count: int = 0
	for raw_line in raw_lines:
		var segment: String = raw_line
		if segment == "":
			segment = " "
		var wrapped_lines: int = 1
		if font != null:
			var line_width: float = font.get_string_size(segment, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
			wrapped_lines = maxi(1, int(ceil(line_width / content_width)))
		else:
			var approx_chars_per_line: int = maxi(4, int(floor(content_width / 8.0)))
			wrapped_lines = maxi(1, int(ceil(float(segment.length()) / float(approx_chars_per_line))))
		estimated_line_count += wrapped_lines

	var text_height: float = float(estimated_line_count) * line_height + float(maxi(0, estimated_line_count - 1)) * line_spacing
	var safety_extra: float = line_height + maxf(0.0, manual_command_hover_extra_padding)
	return ceil(maxf(min_height, text_height + extra_vertical + safety_extra))

func _apply_manual_command_content_layout() -> void:
	if _command_content == null:
		return
	var area_size: Vector2 = _command_content.size
	if area_size.x <= 1.0 or area_size.y <= 1.0:
		_request_manual_bottom_layout_refresh()
		return

	var pad_x: float = maxf(0.0, manual_command_content_padding.x)
	var pad_y: float = maxf(0.0, manual_command_content_padding.y)
	var gap: float = maxf(0.0, manual_command_content_gap)
	var content_width: float = maxf(0.0, area_size.x - pad_x * 2.0)
	var content_height: float = maxf(0.0, area_size.y - pad_y * 2.0)

	var y: float = pad_y
	var subgroup_height: float = 0.0
	if _subgroup_text.visible:
		subgroup_height = clampf(manual_command_subgroup_height, 0.0, content_height)
		var min_subgroup_height: float = _subgroup_text.get_combined_minimum_size().y
		subgroup_height = clampf(maxf(subgroup_height, min_subgroup_height), 0.0, content_height)
		_set_manual_rect(_subgroup_text, Vector2(pad_x, y), Vector2(content_width, subgroup_height))
		y += subgroup_height + gap
	else:
		_set_manual_rect(_subgroup_text, Vector2(pad_x, y), Vector2(content_width, 0.0))

	var used_height: float = y - pad_y
	var hint_height: float = clampf(manual_command_hint_height, 0.0, maxf(0.0, content_height - used_height))
	var grid_height: float = maxf(0.0, content_height - used_height - hint_height - gap)

	_set_manual_rect(_command_grid, Vector2(pad_x, y), Vector2(content_width, grid_height))
	_set_manual_rect(_command_hint_text, Vector2(pad_x, y + grid_height + gap), Vector2(content_width, hint_height))
	_apply_manual_command_grid_layout()

func _apply_manual_command_grid_layout() -> void:
	if _command_grid == null:
		return
	var grid_size: Vector2 = _command_grid.size
	if grid_size.x <= 1.0 or grid_size.y <= 1.0:
		return
	var cell_count: int = _command_items.size()
	if cell_count <= 0:
		return

	var columns: int = maxi(1, manual_command_grid_columns)
	var rows: int = int(ceil(float(cell_count) / float(columns)))
	var h_gap: float = maxf(0.0, manual_command_grid_h_gap)
	var v_gap: float = maxf(0.0, manual_command_grid_v_gap)
	var available_width: float = maxf(0.0, grid_size.x - h_gap * float(columns - 1))
	var available_height: float = maxf(0.0, grid_size.y - v_gap * float(rows - 1))

	var cell_width: float = maxf(1.0, floor(available_width / float(columns)))
	var cell_height: float = maxf(1.0, floor(available_height / float(rows)))
	var used_width: float = cell_width * float(columns) + h_gap * float(columns - 1)
	var used_height: float = cell_height * float(rows) + v_gap * float(rows - 1)
	var start_x: float = floor(maxf(0.0, (grid_size.x - used_width) * 0.5))
	var start_y: float = floor(maxf(0.0, (grid_size.y - used_height) * 0.5))

	for i in cell_count:
		var item: Control = _command_items[i]
		if item == null:
			continue
		var col: int = i % columns
		var row: int = i / columns
		var x: float = start_x + float(col) * (cell_width + h_gap)
		var y: float = start_y + float(row) * (cell_height + v_gap)
		_set_manual_rect(item, Vector2(x, y), Vector2(cell_width, cell_height))

func _get_panel_content_rect(panel: PanelContainer) -> Rect2:
	if panel == null or not is_instance_valid(panel):
		return Rect2(Vector2.ZERO, Vector2.ZERO)
	var panel_size: Vector2 = panel.size
	var style: StyleBox = panel.get_theme_stylebox("panel")
	if style == null:
		return Rect2(Vector2.ZERO, panel_size)
	var left: float = style.get_margin(SIDE_LEFT)
	var top: float = style.get_margin(SIDE_TOP)
	var right: float = style.get_margin(SIDE_RIGHT)
	var bottom: float = style.get_margin(SIDE_BOTTOM)
	var content_size: Vector2 = Vector2(
		maxf(0.0, panel_size.x - left - right),
		maxf(0.0, panel_size.y - top - bottom)
	)
	return Rect2(Vector2(left, top), content_size)

func _set_manual_rect(control: Control, position: Vector2, size: Vector2) -> void:
	if control == null or not is_instance_valid(control):
		return
	if control.is_queued_for_deletion():
		return
	var trace_rect: bool = debug_matrix_jitter_logs and debug_matrix_jitter_verbose and _hudjit_should_trace_rect(control)
	var prev_position: Vector2 = control.position
	var prev_size: Vector2 = control.size
	if control.anchor_left != 0.0:
		control.anchor_left = 0.0
	if control.anchor_top != 0.0:
		control.anchor_top = 0.0
	if control.anchor_right != 0.0:
		control.anchor_right = 0.0
	if control.anchor_bottom != 0.0:
		control.anchor_bottom = 0.0
	var clamped_size: Vector2 = Vector2(maxf(0.0, size.x), maxf(0.0, size.y))
	if control.position != position:
		control.position = position
	if control.size != clamped_size:
		control.size = clamped_size
	if trace_rect and (prev_position != control.position or prev_size != control.size):
		_hudjit_log("set_rect %s pos %s -> %s size %s -> %s" % [
			control.name,
			_hudjit_vec2(prev_position),
			_hudjit_vec2(control.position),
			_hudjit_vec2(prev_size),
			_hudjit_vec2(control.size)
		], true)

func _apply_bottom_helper_transparency() -> void:
	_bottom_row.self_modulate = Color(1.0, 1.0, 1.0, 0.0)
	for node in _bottom_hud.find_children("*", "", true, false):
		var control: Control = node as Control
		if control == null:
			continue
		if control == _selection_panel or control == _queue_panel or control == _portrait_panel or control == _command_panel or control == _command_hover_panel:
			control.self_modulate = Color(1.0, 1.0, 1.0, 1.0)
			continue
		if _is_queue_control_group_ui(control):
			control.self_modulate = Color(1.0, 1.0, 1.0, 0.0)
			continue
		if _is_bottom_layout_helper(control):
			control.self_modulate = Color(1.0, 1.0, 1.0, 0.0)

func _apply_bottom_helper_mouse_filters() -> void:
	_bottom_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bottom_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for node in _bottom_hud.find_children("*", "", true, false):
		var control: Control = node as Control
		if control == null:
			continue
		if control == _selection_panel or control == _queue_panel or control == _portrait_panel or control == _command_panel:
			control.mouse_filter = Control.MOUSE_FILTER_STOP
			continue
		if control == _command_hover_panel:
			control.mouse_filter = Control.MOUSE_FILTER_IGNORE
			continue
		if _is_queue_control_group_ui(control):
			control.mouse_filter = Control.MOUSE_FILTER_IGNORE
			continue
		if _is_bottom_layout_helper(control):
			control.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _is_bottom_layout_helper(control: Control) -> bool:
	return control is BoxContainer \
		or control is GridContainer \
		or control is CenterContainer \
		or control.name.contains("Spacer") \
		or control.name.ends_with("Column") \
		or control.name.ends_with("Row") \
		or control.name.ends_with("Content")

func _is_queue_control_group_ui(control: Control) -> bool:
	if control == _queue_top_spacer or control == _control_group_bar:
		return true
	for button in _control_group_buttons:
		if control == button:
			return true
	return false

func _apply_button_style(button: Button) -> void:
	button.add_theme_stylebox_override("normal", _build_stylebox(Color(0.07, 0.15, 0.23, 0.95), Color(0.17, 0.41, 0.56, 0.95), 1, 5))
	button.add_theme_stylebox_override("hover", _build_stylebox(Color(0.1, 0.2, 0.3, 0.98), Color(0.26, 0.58, 0.76, 0.98), 1, 5))
	button.add_theme_stylebox_override("pressed", _build_stylebox(Color(0.04, 0.1, 0.16, 1.0), Color(0.2, 0.46, 0.64, 1.0), 1, 5))
	button.add_theme_stylebox_override("disabled", _build_stylebox(Color(0.04, 0.08, 0.12, 0.85), Color(0.12, 0.24, 0.34, 0.85), 1, 5))
	button.add_theme_color_override("font_color", Color(0.86, 0.95, 1.0))
	button.add_theme_color_override("font_hover_color", Color(0.95, 1.0, 1.0))
	button.add_theme_color_override("font_disabled_color", Color(0.45, 0.56, 0.64))

func _matrix_style(role: String) -> StyleBoxFlat:
	var role_key: String = role.to_lower()
	if role_key.contains("worker") or role_key == "w":
		return _build_stylebox(Color(0.14, 0.34, 0.2, 0.92), Color(0.34, 0.78, 0.48, 0.95), 1, 4)
	if role_key.contains("soldier") or role_key == "s":
		return _build_stylebox(Color(0.35, 0.16, 0.16, 0.92), Color(0.92, 0.42, 0.34, 0.95), 1, 4)
	if role_key.contains("base"):
		return _build_stylebox(Color(0.18, 0.2, 0.36, 0.92), Color(0.54, 0.6, 0.92, 0.95), 1, 4)
	if role_key.contains("barracks"):
		return _build_stylebox(Color(0.32, 0.2, 0.12, 0.92), Color(0.94, 0.64, 0.3, 0.95), 1, 4)
	return _build_stylebox(Color(0.05, 0.1, 0.16, 0.88), Color(0.16, 0.34, 0.5, 0.9), 1, 4)

func _build_stylebox(background: Color, border: Color, border_width: int, corner_radius: int) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.corner_radius_top_left = corner_radius
	style.corner_radius_top_right = corner_radius
	style.corner_radius_bottom_left = corner_radius
	style.corner_radius_bottom_right = corner_radius
	return style

func _to_string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for item in value:
			result.append(str(item))
	return result

func begin_debug_log_burst(duration_sec: float = -1.0, reason: String = "") -> void:
	var burst_seconds: float = duration_sec if duration_sec > 0.0 else maxf(0.1, debug_matrix_log_burst_seconds)
	_debug_log_burst_until_msec = float(Time.get_ticks_msec()) + burst_seconds * 1000.0
	_hudjit_log("begin_debug_log_burst duration=%.2fs reason=%s" % [burst_seconds, reason], false, true)

func _is_debug_log_burst_active() -> bool:
	return float(Time.get_ticks_msec()) <= _debug_log_burst_until_msec

func _hudjit_log(message: String, verbose_only: bool = false, force: bool = false) -> void:
	if not debug_matrix_jitter_logs:
		return
	if not force and debug_matrix_log_burst_only and not _is_debug_log_burst_active():
		return
	if verbose_only and not debug_matrix_jitter_verbose:
		return
	var frame: int = Engine.get_process_frames()
	var timestamp_sec: float = float(Time.get_ticks_msec()) / 1000.0
	print("[HUDJIT][f=%d][t=%.3f] %s" % [frame, timestamp_sec, message])

func _hudjit_vec2(value: Vector2) -> String:
	return "(%.1f, %.1f)" % [value.x, value.y]

func _hudjit_should_trace_rect(control: Control) -> bool:
	if control == null:
		return false
	if control == _multi_matrix_root or control == _multi_matrix_content or control == _matrix_body:
		return true
	if control == _matrix_grid or control == _matrix_footer or control == _matrix_page_buttons_root:
		return true
	if control is PanelContainer:
		var panel_control: PanelContainer = control as PanelContainer
		var cell_index: int = _matrix_panels.find(panel_control)
		if cell_index >= 0 and cell_index < maxi(0, debug_matrix_cells_to_log):
			return true
	return false

func _hudjit_dump_matrix_state(tag: String, include_cells: bool = false) -> void:
	if not debug_matrix_jitter_logs:
		return
	if _multi_matrix_root == null or _multi_matrix_content == null or _matrix_grid == null:
		return
	var matrix_root_size: Vector2 = _multi_matrix_root.size
	var matrix_root_pos: Vector2 = _multi_matrix_root.position
	var matrix_content_size: Vector2 = _multi_matrix_content.size
	var matrix_content_pos: Vector2 = _multi_matrix_content.position
	var matrix_grid_size: Vector2 = _matrix_grid.size
	var matrix_grid_pos: Vector2 = _matrix_grid.position
	var matrix_footer_size: Vector2 = _matrix_footer.size if _matrix_footer != null else Vector2.ZERO
	var matrix_footer_pos: Vector2 = _matrix_footer.position if _matrix_footer != null else Vector2.ZERO
	_hudjit_log("%s mode=%s root_vis=%s root_pos=%s root_size=%s content_pos=%s content_size=%s grid_pos=%s grid_size=%s footer_vis=%s footer_pos=%s footer_size=%s page_buttons=%d" % [
		tag,
		_last_hud_mode,
		str(_multi_matrix_root.visible),
		_hudjit_vec2(matrix_root_pos),
		_hudjit_vec2(matrix_root_size),
		_hudjit_vec2(matrix_content_pos),
		_hudjit_vec2(matrix_content_size),
		_hudjit_vec2(matrix_grid_pos),
		_hudjit_vec2(matrix_grid_size),
		str(_matrix_footer.visible if _matrix_footer != null else false),
		_hudjit_vec2(matrix_footer_pos),
		_hudjit_vec2(matrix_footer_size),
		_matrix_page_buttons.size()
	])
	if not include_cells:
		return
	var limit: int = clampi(debug_matrix_cells_to_log, 0, _matrix_panels.size())
	for i in limit:
		var panel: PanelContainer = _matrix_panels[i]
		var label: Label = _matrix_labels[i] if i < _matrix_labels.size() else null
		if panel == null or not is_instance_valid(panel):
			_hudjit_log("%s cell[%d] panel=null" % [tag, i], true)
			continue
		var label_text: String = ""
		var label_min_size: Vector2 = Vector2.ZERO
		var label_size: Vector2 = Vector2.ZERO
		var label_pos: Vector2 = Vector2.ZERO
		if label != null and is_instance_valid(label):
			label_text = label.text
			label_min_size = label.get_combined_minimum_size()
			label_size = label.size
			label_pos = label.position
		_hudjit_log("%s cell[%d] panel_pos=%s panel_size=%s panel_min=%s label_pos=%s label_size=%s label_min=%s text='%s'" % [
			tag,
			i,
			_hudjit_vec2(panel.position),
			_hudjit_vec2(panel.size),
			_hudjit_vec2(panel.get_combined_minimum_size()),
			_hudjit_vec2(label_pos),
			_hudjit_vec2(label_size),
			_hudjit_vec2(label_min_size),
			label_text
		], true)

func _format_clock(seconds: float) -> String:
	var total_seconds: int = maxi(0, int(seconds))
	var minutes: int = total_seconds / 60
	var remaining_seconds: int = total_seconds % 60
	return "%02d:%02d" % [minutes, remaining_seconds]
