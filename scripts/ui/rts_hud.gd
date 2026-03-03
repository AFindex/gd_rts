extends Control

signal command_pressed(command_id: String)
signal multi_role_cell_pressed(role_kind: String)
signal subgroup_entry_pressed(kind: String)
signal multi_page_navigate(step: int)

const COMMAND_SLOTS: int = 15
const MULTI_SLOTS: int = 24
const QUEUE_SLOTS: int = 5
const COMMAND_ITEM_SCENE: PackedScene = preload("res://scenes/ui/skill_command_item.tscn")

@onready var _top_bar: PanelContainer = $TopBar
@onready var _resource_panel: PanelContainer = $TopBar/TopBarRow/ResourcePanel
@onready var _center_top: PanelContainer = $TopBar/TopBarRow/CenterTop
@onready var _system_panel: PanelContainer = $TopBar/TopBarRow/SystemPanel
@onready var _bottom_hud: Control = $BottomHUD
@onready var _bottom_row: HBoxContainer = $BottomHUD/BottomRow
@onready var _selection_panel: PanelContainer = $BottomHUD/BottomRow/SelectionPanel
@onready var _queue_panel: PanelContainer = $BottomHUD/BottomRow/QueueColumn/QueuePanel
@onready var _portrait_panel: PanelContainer = $BottomHUD/BottomRow/PortraitColumn/PortraitPanel
@onready var _command_panel: PanelContainer = $BottomHUD/BottomRow/CommandPanel
@onready var _notification_panel: PanelContainer = $NotificationPanel

@onready var _minerals_value: Label = $TopBar/TopBarRow/ResourcePanel/ResourceContent/ResourceTopRow/MineralsValue
@onready var _gas_value: Label = $TopBar/TopBarRow/ResourcePanel/ResourceContent/ResourceTopRow/GasValue
@onready var _supply_value: Label = $TopBar/TopBarRow/ResourcePanel/ResourceContent/ResourceTopRow/SupplyValue
@onready var _legacy_info_text: Label = $TopBar/TopBarRow/ResourcePanel/ResourceContent/LegacyInfoText
@onready var _time_text: Label = $TopBar/TopBarRow/CenterTop/CenterTopContent/TimeText

@onready var _selection_hint_text: Label = $BottomHUD/BottomRow/QueueColumn/QueuePanel/QueueContent/SelectionHintText
@onready var _single_container: HBoxContainer = $BottomHUD/BottomRow/QueueColumn/QueuePanel/QueueContent/SingleContainer
@onready var _single_status_root: PanelContainer = $BottomHUD/BottomRow/QueueColumn/QueuePanel/QueueContent/SingleContainer/SingleStatusRoot
@onready var _single_detail_root: PanelContainer = $BottomHUD/BottomRow/QueueColumn/QueuePanel/QueueContent/SingleContainer/SingleDetailRoot
@onready var _production_queue_root: PanelContainer = $BottomHUD/BottomRow/QueueColumn/QueuePanel/QueueContent/SingleContainer/ProductionQueueRoot
@onready var _single_name_text: Label = $BottomHUD/BottomRow/QueueColumn/QueuePanel/QueueContent/SingleContainer/SingleStatusRoot/SingleStatusContent/SingleNameText
@onready var _health_bar: ProgressBar = $BottomHUD/BottomRow/QueueColumn/QueuePanel/QueueContent/SingleContainer/SingleStatusRoot/SingleStatusContent/HealthBar
@onready var _shield_bar: ProgressBar = $BottomHUD/BottomRow/QueueColumn/QueuePanel/QueueContent/SingleContainer/SingleStatusRoot/SingleStatusContent/ShieldBar
@onready var _energy_bar: ProgressBar = $BottomHUD/BottomRow/QueueColumn/QueuePanel/QueueContent/SingleContainer/SingleStatusRoot/SingleStatusContent/EnergyBar
@onready var _single_detail_text: Label = $BottomHUD/BottomRow/QueueColumn/QueuePanel/QueueContent/SingleContainer/SingleDetailRoot/SingleDetailContent/SingleDetailText
@onready var _armor_type_text: Label = $BottomHUD/BottomRow/QueueColumn/QueuePanel/QueueContent/SingleContainer/SingleDetailRoot/SingleDetailContent/ArmorTypeText
@onready var _queue_summary_text: Label = $BottomHUD/BottomRow/QueueColumn/QueuePanel/QueueContent/SingleContainer/ProductionQueueRoot/ProductionContent/QueueSummaryText
@onready var _queue_progress_bar: ProgressBar = $BottomHUD/BottomRow/QueueColumn/QueuePanel/QueueContent/SingleContainer/ProductionQueueRoot/ProductionContent/QueueProgressBar
@onready var _queue_slots: HBoxContainer = $BottomHUD/BottomRow/QueueColumn/QueuePanel/QueueContent/SingleContainer/ProductionQueueRoot/ProductionContent/QueueSlots
@onready var _multi_matrix_root: PanelContainer = $BottomHUD/BottomRow/QueueColumn/QueuePanel/QueueContent/MultiMatrixRoot
@onready var _matrix_grid: GridContainer = $BottomHUD/BottomRow/QueueColumn/QueuePanel/QueueContent/MultiMatrixRoot/MultiMatrixContent/MatrixGrid
@onready var _matrix_page_text: Label = $BottomHUD/BottomRow/QueueColumn/QueuePanel/QueueContent/MultiMatrixRoot/MultiMatrixContent/MatrixFooter/MatrixPageText
@onready var _matrix_prev_button: Button = $BottomHUD/BottomRow/QueueColumn/QueuePanel/QueueContent/MultiMatrixRoot/MultiMatrixContent/MatrixFooter/PrevPageButton
@onready var _matrix_next_button: Button = $BottomHUD/BottomRow/QueueColumn/QueuePanel/QueueContent/MultiMatrixRoot/MultiMatrixContent/MatrixFooter/NextPageButton

@onready var _portrait_glyph: Label = $BottomHUD/BottomRow/PortraitColumn/PortraitPanel/PortraitContent/PortraitViewport/PortraitCenter/PortraitGlyph
@onready var _portrait_name_text: Label = $BottomHUD/BottomRow/PortraitColumn/PortraitPanel/PortraitContent/PortraitNameText
@onready var _portrait_role_text: Label = $BottomHUD/BottomRow/PortraitColumn/PortraitPanel/PortraitContent/PortraitRoleText
@onready var _command_content: VBoxContainer = $BottomHUD/BottomRow/CommandPanel/CommandContent
@onready var _subgroup_text: Label = $BottomHUD/BottomRow/CommandPanel/CommandContent/SubgroupText
@onready var _command_grid: GridContainer = $BottomHUD/BottomRow/CommandPanel/CommandContent/CommandGrid
@onready var _command_hint_text: Label = $BottomHUD/BottomRow/CommandPanel/CommandContent/CommandHintText
@onready var _notification_list: VBoxContainer = $NotificationPanel/NotificationList

var _elapsed_seconds: float = 0.0
var _command_items: Array[Control] = []
var _matrix_panels: Array[PanelContainer] = []
var _matrix_labels: Array[Label] = []
var _queue_slot_labels: Array[Label] = []
var _notification_labels: Array[Label] = []
var _current_multi_role_kinds: Array[String] = []
var _subgroup_bar: HBoxContainer
var _subgroup_buttons: Array[Button] = []

func _ready() -> void:
	_setup_matrix_footer_buttons()
	_setup_static_styles()
	_apply_bottom_helper_transparency()
	_apply_bottom_helper_mouse_filters()
	_build_subgroup_bar()
	_collect_notification_labels()
	_build_queue_slot_labels()
	_build_command_items()
	_build_matrix_cells()
	_apply_default_hud()
	_apply_fixed_button_theme()

func _process(delta: float) -> void:
	_elapsed_seconds += delta
	_time_text.text = _format_clock(_elapsed_seconds)

func update_hud(snapshot: Dictionary) -> void:
	_minerals_value.text = "%d" % int(snapshot.get("minerals", 0))
	_gas_value.text = "%d" % int(snapshot.get("gas", 0))
	var supply_used: int = int(snapshot.get("supply_used", 0))
	var supply_cap: int = maxi(1, int(snapshot.get("supply_cap", 1)))
	_supply_value.text = "%d / %d" % [supply_used, supply_cap]
	_supply_value.modulate = Color(1.0, 0.42, 0.35) if supply_used >= supply_cap else Color(0.72, 0.96, 1.0)
	_legacy_info_text.text = str(snapshot.get("top_legacy_text", ""))

	_selection_hint_text.text = str(snapshot.get("selection_hint", "No selection."))
	_subgroup_text.text = str(snapshot.get("subgroup_text", "Subgroup -"))
	_command_hint_text.text = str(snapshot.get("command_hint", ""))

	var mode: String = str(snapshot.get("mode", "none"))
	_single_container.visible = mode == "single"
	_multi_matrix_root.visible = mode == "multi"

	_single_name_text.text = str(snapshot.get("single_title", "No Selection"))
	_single_detail_text.text = str(snapshot.get("single_detail", "-"))
	_armor_type_text.text = str(snapshot.get("single_armor", "Armor Type: --"))
	_health_bar.value = clampf(float(snapshot.get("status_health", 1.0)) * 100.0, 0.0, 100.0)
	_shield_bar.value = clampf(float(snapshot.get("status_shield", 0.0)) * 100.0, 0.0, 100.0)
	_energy_bar.value = clampf(float(snapshot.get("status_energy", 0.0)) * 100.0, 0.0, 100.0)

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
	_matrix_page_text.text = str(snapshot.get("matrix_page_text", "Page 1/1"))
	var matrix_page_index: int = int(snapshot.get("matrix_page_index", 0))
	var matrix_page_count: int = maxi(1, int(snapshot.get("matrix_page_count", 1)))
	_matrix_prev_button.disabled = matrix_page_count <= 1
	_matrix_next_button.disabled = matrix_page_count <= 1
	if matrix_page_count > 1:
		_matrix_prev_button.disabled = matrix_page_index <= 0
		_matrix_next_button.disabled = matrix_page_index >= matrix_page_count - 1
	_apply_subgroup_entries(
		snapshot.get("subgroup_entries", []),
		str(snapshot.get("active_subgroup_kind", "")),
		mode
	)

	_portrait_glyph.text = str(snapshot.get("portrait_glyph", "?"))
	_portrait_name_text.text = str(snapshot.get("portrait_title", "No Selection"))
	_portrait_role_text.text = str(snapshot.get("portrait_subtitle", "-"))

	_apply_command_entries(snapshot.get("command_entries", []))
	_apply_notifications(_to_string_array(snapshot.get("notifications", [])))

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
		"portrait_glyph": "?",
		"portrait_title": "No Selection",
		"portrait_subtitle": "-",
		"subgroup_text": "Subgroup -",
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
	_style_panel(_queue_panel, Color(0.04, 0.1, 0.18, 0.9), Color(0.16, 0.38, 0.54, 0.95))
	_style_panel(_portrait_panel, Color(0.05, 0.11, 0.18, 0.9), Color(0.16, 0.38, 0.52, 0.95))
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
		if item.has_signal("pressed"):
			item.connect("pressed", Callable(self, "_on_command_item_pressed"))
		_command_grid.add_child(item)
		_command_items.append(item)

func _setup_matrix_footer_buttons() -> void:
	if _matrix_prev_button != null:
		_matrix_prev_button.focus_mode = Control.FOCUS_NONE
		var prev_callback: Callable = Callable(self, "_on_prev_matrix_page_pressed")
		if not _matrix_prev_button.pressed.is_connected(prev_callback):
			_matrix_prev_button.pressed.connect(prev_callback)
	if _matrix_next_button != null:
		_matrix_next_button.focus_mode = Control.FOCUS_NONE
		var next_callback: Callable = Callable(self, "_on_next_matrix_page_pressed")
		if not _matrix_next_button.pressed.is_connected(next_callback):
			_matrix_next_button.pressed.connect(next_callback)

func _on_prev_matrix_page_pressed() -> void:
	emit_signal("multi_page_navigate", -1)

func _on_next_matrix_page_pressed() -> void:
	emit_signal("multi_page_navigate", 1)

func _build_subgroup_bar() -> void:
	if _command_content == null:
		return
	_subgroup_bar = HBoxContainer.new()
	_subgroup_bar.name = "SubgroupBar"
	_subgroup_bar.add_theme_constant_override("separation", 4)
	_subgroup_bar.visible = false
	_command_content.add_child(_subgroup_bar)
	var desired_index: int = _subgroup_text.get_index() + 1 if _subgroup_text != null else 0
	_command_content.move_child(_subgroup_bar, desired_index)

func _apply_subgroup_entries(entries_variant: Variant, active_kind: String, mode: String) -> void:
	if _subgroup_bar == null:
		return
	for button in _subgroup_buttons:
		if button != null and is_instance_valid(button):
			button.queue_free()
	_subgroup_buttons.clear()

	if mode != "multi":
		_subgroup_bar.visible = false
		return
	if not (entries_variant is Array):
		_subgroup_bar.visible = false
		return
	var entries: Array = entries_variant as Array
	if entries.size() <= 1:
		_subgroup_bar.visible = false
		return
	_subgroup_bar.visible = true

	for entry_value in entries:
		if not (entry_value is Dictionary):
			continue
		var entry: Dictionary = entry_value as Dictionary
		var kind: String = str(entry.get("kind", ""))
		var label: String = str(entry.get("label", ""))
		var count: int = int(entry.get("count", 0))
		var button: Button = Button.new()
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(0.0, 24.0)
		button.text = _subgroup_button_text(label, count)
		button.tooltip_text = "Subgroup: %s (%d)" % [label, count]
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(Callable(self, "_on_subgroup_button_pressed").bind(kind))
		_apply_subgroup_button_style(button, kind == active_kind, kind)
		_subgroup_bar.add_child(button)
		_subgroup_buttons.append(button)

func _subgroup_button_text(label: String, count: int) -> String:
	if count <= 0:
		return label
	return "%s %d" % [label, count]

func _subgroup_kind_color(kind: String) -> Color:
	match kind:
		"worker":
			return Color(0.34, 0.78, 0.48, 0.95)
		"soldier":
			return Color(0.92, 0.42, 0.34, 0.95)
		"":
			return Color(0.72, 0.88, 1.0, 0.95)
		_:
			return Color(0.64, 0.72, 0.9, 0.95)

func _apply_subgroup_button_style(button: Button, active: bool, kind: String) -> void:
	if button == null:
		return
	var border: Color = _subgroup_kind_color(kind)
	var background: Color = Color(0.06, 0.13, 0.2, 0.92)
	if active:
		background = Color(0.12, 0.21, 0.3, 0.98)
		border = Color(1.0, 0.95, 0.55, 0.98)
	button.add_theme_stylebox_override("normal", _build_stylebox(background, border, 1 if not active else 2, 6))
	button.add_theme_stylebox_override("hover", _build_stylebox(background.lightened(0.08), border.lightened(0.1), 1 if not active else 2, 6))
	button.add_theme_stylebox_override("pressed", _build_stylebox(background.darkened(0.08), border, 1 if not active else 2, 6))
	button.add_theme_color_override("font_color", Color(0.92, 0.97, 1.0))
	button.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0))
	button.add_theme_color_override("font_pressed_color", Color(0.95, 1.0, 1.0))

func _on_subgroup_button_pressed(kind: String) -> void:
	emit_signal("subgroup_entry_pressed", kind)

func _build_matrix_cells() -> void:
	_matrix_panels.clear()
	_matrix_labels.clear()
	for child in _matrix_grid.get_children():
		child.queue_free()

	for i in MULTI_SLOTS:
		var cell: PanelContainer = PanelContainer.new()
		cell.custom_minimum_size = Vector2(50.0, 50.0)
		cell.add_theme_stylebox_override("panel", _matrix_style("empty"))
		cell.mouse_filter = Control.MOUSE_FILTER_STOP
		cell.gui_input.connect(Callable(self, "_on_matrix_cell_gui_input").bind(i))

		var label: Label = Label.new()
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.text = "--"
		cell.add_child(label)
		_matrix_grid.add_child(cell)
		_matrix_panels.append(cell)
		_matrix_labels.append(label)

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
	if role_kind == "" or role_kind == "building":
		return
	emit_signal("multi_role_cell_pressed", role_kind)

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

func _apply_notifications(notifications: Array[String]) -> void:
	for i in _notification_labels.size():
		if i < notifications.size():
			_notification_labels[i].text = notifications[i]
		else:
			_notification_labels[i].text = ""

func _style_panel(panel: PanelContainer, background: Color, border: Color) -> void:
	panel.add_theme_stylebox_override("panel", _build_stylebox(background, border, 2, 8))

func _style_progress_bar(progress_bar: ProgressBar, fill_color: Color) -> void:
	progress_bar.show_percentage = false
	progress_bar.min_value = 0.0
	progress_bar.max_value = 100.0
	progress_bar.add_theme_stylebox_override("background", _build_stylebox(Color(0.01, 0.05, 0.09, 0.85), Color(0.16, 0.36, 0.52, 0.88), 1, 3))
	progress_bar.add_theme_stylebox_override("fill", _build_stylebox(fill_color, fill_color.darkened(0.25), 1, 3))

func _apply_bottom_helper_transparency() -> void:
	_bottom_row.self_modulate = Color(1.0, 1.0, 1.0, 0.0)
	for node in _bottom_hud.find_children("*", "", true, false):
		var control: Control = node as Control
		if control == null:
			continue
		if control == _selection_panel or control == _queue_panel or control == _portrait_panel or control == _command_panel:
			control.self_modulate = Color(1.0, 1.0, 1.0, 1.0)
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

func _format_clock(seconds: float) -> String:
	var total_seconds: int = maxi(0, int(seconds))
	var minutes: int = total_seconds / 60
	var remaining_seconds: int = total_seconds % 60
	return "%02d:%02d" % [minutes, remaining_seconds]
