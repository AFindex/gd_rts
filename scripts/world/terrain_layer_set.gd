class_name TerrainLayerSet
extends Resource

@export var layer_names: PackedStringArray = PackedStringArray(["Grass", "Dirt", "Rock", "Sand"])
@export var debug_colors: PackedColorArray = PackedColorArray([
	Color(0.26, 0.45, 0.26, 1.0),
	Color(0.45, 0.35, 0.22, 1.0),
	Color(0.40, 0.40, 0.42, 1.0),
	Color(0.58, 0.52, 0.34, 1.0)
])
@export var uv_scale: float = 0.25
@export var use_texture_blending: bool = true
@export_range(0.5, 4.0, 0.05) var blend_sharpness: float = 1.0
@export var albedo_textures: Array[Texture2D] = []
@export var normal_textures: Array[Texture2D] = []
@export var orm_textures: Array[Texture2D] = []
@export var height_textures: Array[Texture2D] = []

@export var cliff_albedo_textures: Array[Texture2D] = []
@export var cliff_normal_textures: Array[Texture2D] = []
@export var cliff_orm_textures: Array[Texture2D] = []
@export var cliff_height_textures: Array[Texture2D] = []

@export var macro_color_texture: Texture2D
@export var macro_roughness_texture: Texture2D
@export var detail_noise_a_texture: Texture2D
@export var detail_noise_b_texture: Texture2D

@export_range(0.25, 8.0, 0.05) var macro_uv_scale: float = 0.8
@export_range(0.0, 1.0, 0.01) var macro_color_strength: float = 0.24
@export_range(0.0, 1.0, 0.01) var macro_roughness_strength: float = 0.32
@export_range(0.0, 1.0, 0.01) var detail_noise_strength: float = 0.15
@export_range(0.0, 1.0, 0.01) var cliff_start: float = 0.38
@export_range(0.0, 1.0, 0.01) var cliff_end: float = 0.78
@export_range(0.5, 4.0, 0.05) var cliff_blend_sharpness: float = 1.4
@export_range(0.0, 2.0, 0.01) var normal_strength: float = 1.0

func get_layer_count() -> int:
	if not debug_colors.is_empty():
		return debug_colors.size()
	if not layer_names.is_empty():
		return layer_names.size()
	return 1

func get_debug_color(layer_id: int) -> Color:
	if debug_colors.is_empty():
		return Color(0.34, 0.44, 0.34, 1.0)
	var wrapped: int = posmod(layer_id, debug_colors.size())
	return debug_colors[wrapped]
