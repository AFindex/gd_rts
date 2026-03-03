@tool
extends EditorPlugin

const IMAGE_RESIZER_DOCK_SCRIPT: Script = preload("res://editor/image_resizer_dock.gd")

var _dock: Control = null

func _enter_tree() -> void:
	_dock = IMAGE_RESIZER_DOCK_SCRIPT.new()
	_dock.name = "Image Resizer"
	if _dock.has_method("setup"):
		_dock.call("setup", self)
	add_control_to_dock(EditorPlugin.DOCK_SLOT_RIGHT_UL, _dock)

func _exit_tree() -> void:
	if _dock:
		remove_control_from_docks(_dock)
		_dock.queue_free()
		_dock = null
