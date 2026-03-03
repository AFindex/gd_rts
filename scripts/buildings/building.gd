extends StaticBody3D

@onready var _selection_ring: MeshInstance3D = $SelectionRing

func _ready() -> void:
	add_to_group("selectable_building")
	_selection_ring.visible = false

func set_selected(selected: bool) -> void:
	_selection_ring.visible = selected
