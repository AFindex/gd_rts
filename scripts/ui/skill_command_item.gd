extends Control

signal pressed(command_id: String)

@onready var _button: Button = $Button
@onready var _icon: TextureRect = $Button/Icon
@onready var _fallback_glyph: Label = $Button/FallbackGlyph
@onready var _hotkey_label: Label = $Button/HotkeyLabel
@onready var _title_label: Label = $Button/TitleLabel
@onready var _cost_label: Label = $Button/CostLabel
@onready var _disabled_mask: ColorRect = $Button/DisabledMask
@onready var _cooldown_mask: ColorRect = $Button/CooldownMask

var _command_id: String = ""

func _ready() -> void:
	_button.pressed.connect(_on_button_pressed)
	_button.focus_mode = Control.FOCUS_NONE
	clear_slot()

func apply_entry(entry: Dictionary) -> void:
	_command_id = str(entry.get("id", ""))
	var label: String = str(entry.get("label", ""))
	var hotkey: String = str(entry.get("hotkey", ""))
	var cost_text: String = str(entry.get("cost_text", ""))
	var icon_path: String = str(entry.get("icon_path", ""))
	var enabled: bool = bool(entry.get("enabled", true))
	var cooldown_ratio: float = clampf(float(entry.get("cooldown_ratio", 0.0)), 0.0, 1.0)
	var disabled_reason: String = str(entry.get("disabled_reason", ""))

	_title_label.text = label
	_hotkey_label.text = hotkey
	_hotkey_label.visible = hotkey != ""
	_cost_label.text = cost_text
	_cost_label.visible = cost_text != ""

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

	var tooltip_lines: Array[String] = [label]
	if hotkey != "":
		tooltip_lines.append("Hotkey: %s" % hotkey)
	if disabled_reason != "":
		tooltip_lines.append(disabled_reason)
	_button.tooltip_text = "\n".join(tooltip_lines)

func clear_slot() -> void:
	_command_id = ""
	_button.disabled = true
	_button.tooltip_text = ""
	_icon.texture = null
	_icon.visible = false
	_fallback_glyph.visible = true
	_fallback_glyph.text = "--"
	_hotkey_label.visible = false
	_hotkey_label.text = ""
	_title_label.text = ""
	_cost_label.visible = false
	_cost_label.text = ""
	_disabled_mask.visible = true
	_cooldown_mask.visible = false

func _on_button_pressed() -> void:
	if _command_id == "" or _button.disabled:
		return
	emit_signal("pressed", _command_id)
