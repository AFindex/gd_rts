extends Control

signal pressed(command_id: String)
signal hover_started(hover_data: Dictionary)
signal hover_ended

@onready var _button: Button = $Button
@onready var _icon: TextureRect = $Button/Icon
@onready var _fallback_glyph: Label = $Button/FallbackGlyph
@onready var _hotkey_label: Label = $Button/HotkeyLabel
@onready var _title_label: Label = $Button/TitleLabel
@onready var _cost_label: Label = $Button/CostLabel
@onready var _disabled_mask: ColorRect = $Button/DisabledMask
@onready var _cooldown_mask: ColorRect = $Button/CooldownMask

var _command_id: String = ""
var _hover_payload: Dictionary = {}
var _is_hovering: bool = false

func _ready() -> void:
	_button.pressed.connect(_on_button_pressed)
	_button.mouse_entered.connect(_on_button_mouse_entered)
	_button.mouse_exited.connect(_on_button_mouse_exited)
	_button.focus_mode = Control.FOCUS_NONE
	_title_label.visible = false
	_cost_label.visible = false
	clear_slot()

func apply_entry(entry: Dictionary) -> void:
	_command_id = str(entry.get("id", ""))
	var label: String = str(entry.get("label", ""))
	var hotkey: String = str(entry.get("hotkey", ""))
	var cost_text: String = str(entry.get("cost_text", ""))
	var detail_text: String = str(entry.get("detail_text", entry.get("description", "")))
	var icon_path: String = str(entry.get("icon_path", ""))
	var enabled: bool = bool(entry.get("enabled", true))
	var cooldown_ratio: float = clampf(float(entry.get("cooldown_ratio", 0.0)), 0.0, 1.0)
	var disabled_reason: String = str(entry.get("disabled_reason", ""))

	_title_label.text = label
	_title_label.visible = false
	_hotkey_label.text = hotkey
	_hotkey_label.visible = hotkey != ""
	_cost_label.text = cost_text
	_cost_label.visible = false

	var texture: Texture2D = null
	if icon_path != "" and ResourceLoader.exists(icon_path):
		texture = load(icon_path) as Texture2D
	_icon.texture = texture
	_icon.visible = texture != null
	_icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH

	_fallback_glyph.visible = texture == null
	_fallback_glyph.text = label.substr(0, 1).to_upper() if label != "" else "?"

	_button.disabled = not enabled
	_disabled_mask.visible = not enabled

	_cooldown_mask.visible = cooldown_ratio > 0.001
	_cooldown_mask.anchor_top = 1.0 - cooldown_ratio
	_cooldown_mask.anchor_bottom = 1.0
	_cooldown_mask.offset_top = 0.0
	_cooldown_mask.offset_bottom = 0.0

	_hover_payload = {
		"id": _command_id,
		"label": label,
		"cost_text": cost_text,
		"detail_text": detail_text,
		"hotkey": hotkey,
		"enabled": enabled,
		"disabled_reason": disabled_reason
	}
	_button.tooltip_text = ""
	if _is_hovering:
		emit_signal("hover_started", _hover_payload.duplicate(true))

func clear_slot() -> void:
	_command_id = ""
	_hover_payload = {}
	_button.disabled = true
	_button.tooltip_text = ""
	_icon.texture = null
	_icon.visible = false
	_fallback_glyph.visible = true
	_fallback_glyph.text = "--"
	_hotkey_label.visible = false
	_hotkey_label.text = ""
	_title_label.text = ""
	_title_label.visible = false
	_cost_label.visible = false
	_cost_label.text = ""
	_disabled_mask.visible = true
	_cooldown_mask.visible = false
	if _is_hovering:
		_is_hovering = false
		emit_signal("hover_ended")

func _on_button_pressed() -> void:
	if _command_id == "" or _button.disabled:
		return
	emit_signal("pressed", _command_id)

func _on_button_mouse_entered() -> void:
	if _command_id == "":
		return
	_is_hovering = true
	emit_signal("hover_started", _hover_payload.duplicate(true))

func _on_button_mouse_exited() -> void:
	if not _is_hovering:
		return
	_is_hovering = false
	emit_signal("hover_ended")
