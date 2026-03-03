extends Control

var _active: bool = false
var _start: Vector2 = Vector2.ZERO
var _current: Vector2 = Vector2.ZERO

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func begin_drag(screen_pos: Vector2) -> void:
	_active = true
	_start = screen_pos
	_current = screen_pos
	queue_redraw()

func update_drag(screen_pos: Vector2) -> void:
	if not _active:
		return
	_current = screen_pos
	queue_redraw()

func end_drag() -> void:
	_active = false
	queue_redraw()

func get_selection_rect() -> Rect2:
	var min_x := minf(_start.x, _current.x)
	var min_y := minf(_start.y, _current.y)
	var max_x := maxf(_start.x, _current.x)
	var max_y := maxf(_start.y, _current.y)
	return Rect2(Vector2(min_x, min_y), Vector2(max_x - min_x, max_y - min_y))

func _draw() -> void:
	if not _active:
		return
	var rect := get_selection_rect()
	draw_rect(rect, Color(0.2, 0.8, 1.0, 0.16), true)
	draw_rect(rect, Color(0.2, 0.8, 1.0, 0.85), false, 2.0)
