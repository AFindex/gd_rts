extends Node3D
class_name TileTerrainRuntime

const TERRAIN_GROUP: StringName = &"terrain_runtime"
const RAMP_NONE: int = 0
const RAMP_NORTH_UP: int = 1
const RAMP_SOUTH_UP: int = 2
const RAMP_EAST_UP: int = 3
const RAMP_WEST_UP: int = 4
const SPLAT_LAYER_COUNT: int = 4
const SPLAT_SHADER_CODE: String = """
shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform sampler2D control_map : source_color, filter_linear, repeat_disable;
uniform sampler2D tex0 : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D tex1 : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D tex2 : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D tex3 : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D nrm0 : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D nrm1 : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D nrm2 : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D nrm3 : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D orm0 : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D orm1 : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D orm2 : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D orm3 : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D hgt0 : hint_default_black, filter_linear_mipmap, repeat_enable;
uniform sampler2D hgt1 : hint_default_black, filter_linear_mipmap, repeat_enable;
uniform sampler2D hgt2 : hint_default_black, filter_linear_mipmap, repeat_enable;
uniform sampler2D hgt3 : hint_default_black, filter_linear_mipmap, repeat_enable;

uniform sampler2D cliff_tex0 : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D cliff_tex1 : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D cliff_tex2 : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D cliff_nrm0 : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D cliff_nrm1 : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D cliff_nrm2 : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D cliff_orm0 : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D cliff_orm1 : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D cliff_orm2 : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D cliff_hgt0 : hint_default_black, filter_linear_mipmap, repeat_enable;
uniform sampler2D cliff_hgt1 : hint_default_black, filter_linear_mipmap, repeat_enable;
uniform sampler2D cliff_hgt2 : hint_default_black, filter_linear_mipmap, repeat_enable;

uniform sampler2D macro_color_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D macro_roughness_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D detail_noise_a_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D detail_noise_b_tex : hint_default_white, filter_linear_mipmap, repeat_enable;

uniform float blend_sharpness : hint_range(0.5, 4.0) = 1.0;
uniform float macro_uv_scale : hint_range(0.25, 8.0) = 0.8;
uniform float macro_color_strength : hint_range(0.0, 1.0) = 0.24;
uniform float macro_roughness_strength : hint_range(0.0, 1.0) = 0.32;
uniform float detail_noise_strength : hint_range(0.0, 1.0) = 0.15;
uniform float cliff_start : hint_range(0.0, 1.0) = 0.38;
uniform float cliff_end : hint_range(0.0, 1.0) = 0.78;
uniform float cliff_blend_sharpness : hint_range(0.5, 4.0) = 1.4;
uniform float normal_strength : hint_range(0.0, 2.0) = 1.0;
uniform float surface_roughness : hint_range(0.0, 1.0) = 0.96;
uniform float surface_metallic : hint_range(0.0, 1.0) = 0.0;

vec4 _normalize_weights(vec4 raw_weights, float sharpness) {
	vec4 weights = raw_weights;
	weights = max(weights, vec4(0.0001));
	weights = pow(weights, vec4(sharpness));
	float sum_w = max(weights.r + weights.g + weights.b + weights.a, 0.0001);
	return weights / sum_w;
}

float _hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

vec3 _blend_normal_maps(vec3 n0, vec3 n1, float blend_t) {
	vec3 a = normalize(n0 * 2.0 - 1.0);
	vec3 b = normalize(n1 * 2.0 - 1.0);
	vec3 m = normalize(mix(a, b, clamp(blend_t, 0.0, 1.0)));
	return m * 0.5 + 0.5;
}

void fragment() {
	vec4 weights = _normalize_weights(texture(control_map, UV2), blend_sharpness);

	vec3 c0 = texture(tex0, UV).rgb;
	vec3 c1 = texture(tex1, UV).rgb;
	vec3 c2 = texture(tex2, UV).rgb;
	vec3 c3 = texture(tex3, UV).rgb;
	vec3 top_albedo = c0 * weights.r + c1 * weights.g + c2 * weights.b + c3 * weights.a;

	vec3 n0 = texture(nrm0, UV).rgb;
	vec3 n1 = texture(nrm1, UV).rgb;
	vec3 n2 = texture(nrm2, UV).rgb;
	vec3 n3 = texture(nrm3, UV).rgb;
	vec3 top_normal_rgb = n0 * weights.r + n1 * weights.g + n2 * weights.b + n3 * weights.a;
	vec3 top_normal_ts = normalize(top_normal_rgb * 2.0 - 1.0) * 0.5 + 0.5;

	vec3 o0 = texture(orm0, UV).rgb;
	vec3 o1 = texture(orm1, UV).rgb;
	vec3 o2 = texture(orm2, UV).rgb;
	vec3 o3 = texture(orm3, UV).rgb;
	vec3 top_orm = o0 * weights.r + o1 * weights.g + o2 * weights.b + o3 * weights.a;

	float h0 = texture(hgt0, UV).r;
	float h1 = texture(hgt1, UV).r;
	float h2 = texture(hgt2, UV).r;
	float h3 = texture(hgt3, UV).r;
	float top_height = h0 * weights.r + h1 * weights.g + h2 * weights.b + h3 * weights.a;

	float slope = 1.0 - clamp(abs(NORMAL.y), 0.0, 1.0);
	float slope_curve = pow(clamp(slope, 0.0, 1.0), max(0.25, cliff_blend_sharpness));
	float cliff_factor = smoothstep(cliff_start, cliff_end, slope_curve);
	float cliff_selector = _hash12(floor(UV2 * 512.0));

	vec3 cliff_albedo = texture(cliff_tex0, UV).rgb;
	vec3 cliff_normal = texture(cliff_nrm0, UV).rgb;
	vec3 cliff_orm = texture(cliff_orm0, UV).rgb;
	float cliff_height = texture(cliff_hgt0, UV).r;
	if (cliff_selector > 0.66) {
		cliff_albedo = texture(cliff_tex2, UV).rgb;
		cliff_normal = texture(cliff_nrm2, UV).rgb;
		cliff_orm = texture(cliff_orm2, UV).rgb;
		cliff_height = texture(cliff_hgt2, UV).r;
	} else if (cliff_selector > 0.33) {
		cliff_albedo = texture(cliff_tex1, UV).rgb;
		cliff_normal = texture(cliff_nrm1, UV).rgb;
		cliff_orm = texture(cliff_orm1, UV).rgb;
		cliff_height = texture(cliff_hgt1, UV).r;
	}
	cliff_factor = clamp(cliff_factor + (cliff_height - top_height) * 0.1, 0.0, 1.0);

	vec2 macro_uv = UV2 * max(0.25, macro_uv_scale);
	vec3 macro_color = texture(macro_color_tex, macro_uv).rgb;
	float macro_roughness = texture(macro_roughness_tex, macro_uv).r;
	float detail_a = texture(detail_noise_a_tex, UV * 0.57).r;
	float detail_b = texture(detail_noise_b_tex, UV * 1.31).r;
	float detail_mix = (detail_a + detail_b) * 0.5;

	vec3 albedo = mix(top_albedo, cliff_albedo, cliff_factor);
	vec3 macro_tint = mix(vec3(1.0), macro_color * 2.0, macro_color_strength);
	float detail_tint = mix(1.0, detail_mix * 2.0, detail_noise_strength);
	albedo *= macro_tint * detail_tint * COLOR.rgb;

	vec3 mixed_normal = _blend_normal_maps(top_normal_ts, cliff_normal, cliff_factor);
	NORMAL_MAP = mix(vec3(0.5, 0.5, 1.0), mixed_normal, clamp(normal_strength, 0.0, 2.0));

	vec3 orm = mix(top_orm, cliff_orm, cliff_factor);
	float roughness = clamp(orm.g, 0.0, 1.0);
	float roughness_variation = mix(1.0, mix(0.75, 1.25, macro_roughness), macro_roughness_strength);
	roughness = clamp(roughness * roughness_variation, 0.02, 1.0);

	ALBEDO = albedo;
	AO = clamp(orm.r, 0.0, 1.0);
	ROUGHNESS = mix(surface_roughness, roughness, 0.85);
	METALLIC = clamp(mix(surface_metallic, orm.b, 0.85), 0.0, 1.0);
}
"""

@export var map_data: TerrainMapData
@export var layer_set: TerrainLayerSet
@export var generate_collision: bool = true
@export var generate_side_walls: bool = true
@export var side_wall_floor_level: int = 0
@export var side_shade_strength: float = 0.2
@export var rebuild_on_ready: bool = true
@export var collision_layer_value: int = 1
@export var collision_mask_value: int = 0
@export var material_roughness: float = 0.96
@export var material_metallic: float = 0.0
@export var nearest_tile_search_max_radius: int = 10
@export var use_splat_material: bool = true

var _mesh_instance: MeshInstance3D
var _body: StaticBody3D
var _collision_shape: CollisionShape3D
var _material: StandardMaterial3D
var _splat_shader: Shader
var _splat_material: ShaderMaterial
var _control_map_texture: ImageTexture
var _fallback_textures_by_layer: Dictionary = {}

var _compiled_size: Vector2i = Vector2i.ONE
var _compiled_tile_size: float = 1.0
var _compiled_height_step: float = 0.6
var _compiled_min_corner: Vector2 = Vector2.ZERO
var _compiled_height_levels: PackedInt32Array = PackedInt32Array()
var _compiled_walkable: PackedByteArray = PackedByteArray()
var _compiled_buildable: PackedByteArray = PackedByteArray()
var _compiled_layers: PackedByteArray = PackedByteArray()
var _compiled_ramps: PackedByteArray = PackedByteArray()

func _ready() -> void:
	add_to_group(TERRAIN_GROUP)
	_ensure_runtime_nodes()
	if rebuild_on_ready:
		rebuild_terrain()

func rebuild_terrain() -> void:
	_ensure_runtime_nodes()
	_compile_data()
	var mesh: ArrayMesh = _build_mesh()
	_mesh_instance.mesh = mesh
	_rebuild_control_map_texture()
	_apply_material()
	if not generate_collision or mesh == null:
		_collision_shape.shape = null
		return
	_collision_shape.shape = mesh.create_trimesh_shape()

func get_map_half_extents() -> Vector2:
	return Vector2(
		float(_compiled_size.x) * _compiled_tile_size * 0.5,
		float(_compiled_size.y) * _compiled_tile_size * 0.5
	)

func is_inside_tile(tile: Vector2i) -> bool:
	return tile.x >= 0 and tile.y >= 0 and tile.x < _compiled_size.x and tile.y < _compiled_size.y

func world_to_tile(world_position: Vector3) -> Vector2i:
	var x_idx: int = int(floor((world_position.x - _compiled_min_corner.x) / maxf(0.01, _compiled_tile_size)))
	var y_idx: int = int(floor((world_position.z - _compiled_min_corner.y) / maxf(0.01, _compiled_tile_size)))
	return Vector2i(
		clampi(x_idx, 0, _compiled_size.x - 1),
		clampi(y_idx, 0, _compiled_size.y - 1)
	)

func tile_to_world_center(tile: Vector2i, sample_surface: bool = true) -> Vector3:
	var clamped: Vector2i = Vector2i(
		clampi(tile.x, 0, _compiled_size.x - 1),
		clampi(tile.y, 0, _compiled_size.y - 1)
	)
	var world_y: float = 0.0
	var center_world: Vector3 = Vector3(
		_compiled_min_corner.x + (float(clamped.x) + 0.5) * _compiled_tile_size,
		0.0,
		_compiled_min_corner.y + (float(clamped.y) + 0.5) * _compiled_tile_size
	)
	if sample_surface:
		world_y = _tile_world_height(clamped, center_world, 0.0)
	else:
		world_y = _height_from_level(_height_level_at_tile(clamped))
	center_world.y = world_y
	return center_world

func sample_height_at_world(world_position: Vector3, fallback: float = 0.0) -> float:
	if _compiled_height_levels.is_empty():
		return fallback
	var tile: Vector2i = world_to_tile(world_position)
	if not is_inside_tile(tile):
		return fallback
	return _tile_world_height(tile, world_position, fallback)

func get_tile_flags(tile: Vector2i) -> Dictionary:
	if not is_inside_tile(tile):
		return {
			"inside": false,
			"walkable": false,
			"buildable": false,
			"height_level": side_wall_floor_level,
			"layer_id": 0,
			"ramp_code": RAMP_NONE,
			"ramp_dir": "",
			"is_ramp": false
		}
	var idx: int = _tile_to_index(tile)
	var ramp_code: int = _byte_value(_compiled_ramps, idx, RAMP_NONE)
	return {
		"inside": true,
		"walkable": _byte_flag(_compiled_walkable, idx, 1),
		"buildable": _byte_flag(_compiled_buildable, idx, 1),
		"height_level": _height_level_at_tile(tile),
		"layer_id": _byte_value(_compiled_layers, idx, 0),
		"ramp_code": ramp_code,
		"ramp_dir": _ramp_code_to_name(ramp_code),
		"is_ramp": ramp_code != RAMP_NONE
	}

func get_height_level_at_world(world_position: Vector3, fallback_level: int = 0) -> int:
	if _compiled_height_levels.is_empty():
		return fallback_level
	var tile: Vector2i = world_to_tile(world_position)
	if not is_inside_tile(tile):
		return fallback_level
	return _height_level_at_tile(tile)

func get_ramp_dir_at_world(world_position: Vector3) -> String:
	if _compiled_ramps.is_empty():
		return ""
	var tile: Vector2i = world_to_tile(world_position)
	if not is_inside_tile(tile):
		return ""
	var ramp_code: int = _byte_value(_compiled_ramps, _tile_to_index(tile), RAMP_NONE)
	return _ramp_code_to_name(ramp_code)

func get_world_flags(world_position: Vector3) -> Dictionary:
	var tile: Vector2i = world_to_tile(world_position)
	return get_tile_flags(tile)

func is_walkable_world(world_position: Vector3) -> bool:
	if _compiled_walkable.is_empty():
		return true
	var tile: Vector2i = world_to_tile(world_position)
	if not is_inside_tile(tile):
		return false
	return _byte_flag(_compiled_walkable, _tile_to_index(tile), 1)

func is_buildable_world(world_position: Vector3) -> bool:
	if _compiled_buildable.is_empty():
		return true
	var tile: Vector2i = world_to_tile(world_position)
	if not is_inside_tile(tile):
		return false
	return _byte_flag(_compiled_buildable, _tile_to_index(tile), 1)

func find_nearest_walkable_world(world_position: Vector3, max_radius_tiles: int = -1) -> Vector3:
	var fallback: Vector3 = world_position
	fallback.y = sample_height_at_world(world_position, world_position.y)
	var tile: Vector2i = world_to_tile(world_position)
	var nearest_tile: Vector2i = _find_nearest_tile_by_flag(tile, true, false, max_radius_tiles)
	if nearest_tile.x < 0:
		return fallback
	return tile_to_world_center(nearest_tile, true)

func find_nearest_walkable_world_filtered(
	world_position: Vector3,
	max_radius_tiles: int = -1,
	allowed_height_levels: PackedInt32Array = PackedInt32Array(),
	allow_ramp_tiles: bool = true
) -> Vector3:
	var fallback: Vector3 = world_position
	fallback.y = sample_height_at_world(world_position, world_position.y)
	var source_tile: Vector2i = world_to_tile(world_position)
	if not is_inside_tile(source_tile):
		return fallback
	var max_radius: int = nearest_tile_search_max_radius if max_radius_tiles < 0 else max_radius_tiles
	max_radius = clampi(max_radius, 0, 256)
	if _walk_tile_matches_rules(source_tile, allowed_height_levels, allow_ramp_tiles):
		return tile_to_world_center(source_tile, true)
	for radius in range(1, max_radius + 1):
		var best_tile: Vector2i = Vector2i(-1, -1)
		var best_distance_sq: int = 2147483647
		for y in range(source_tile.y - radius, source_tile.y + radius + 1):
			for x in range(source_tile.x - radius, source_tile.x + radius + 1):
				var tile: Vector2i = Vector2i(x, y)
				if not is_inside_tile(tile):
					continue
				var edge_sample: bool = x == source_tile.x - radius or x == source_tile.x + radius or y == source_tile.y - radius or y == source_tile.y + radius
				if not edge_sample:
					continue
				if not _walk_tile_matches_rules(tile, allowed_height_levels, allow_ramp_tiles):
					continue
				var delta_x: int = tile.x - source_tile.x
				var delta_y: int = tile.y - source_tile.y
				var distance_sq: int = delta_x * delta_x + delta_y * delta_y
				if distance_sq < best_distance_sq:
					best_distance_sq = distance_sq
					best_tile = tile
		if best_tile.x >= 0:
			return tile_to_world_center(best_tile, true)
	return fallback

func find_nearest_buildable_world(world_position: Vector3, max_radius_tiles: int = -1) -> Vector3:
	var fallback: Vector3 = world_position
	fallback.y = sample_height_at_world(world_position, world_position.y)
	var tile: Vector2i = world_to_tile(world_position)
	var nearest_tile: Vector2i = _find_nearest_tile_by_flag(tile, false, true, max_radius_tiles)
	if nearest_tile.x < 0:
		return fallback
	return tile_to_world_center(nearest_tile, true)

func _compile_data() -> void:
	if map_data == null:
		_compiled_size = Vector2i.ONE
		_compiled_tile_size = 1.0
		_compiled_height_step = 0.6
		_compiled_min_corner = Vector2.ZERO
		_compiled_height_levels = PackedInt32Array([0])
		_compiled_walkable = PackedByteArray([1])
		_compiled_buildable = PackedByteArray([1])
		_compiled_layers = PackedByteArray([0])
		_compiled_ramps = PackedByteArray([RAMP_NONE])
		return

	_compiled_size = map_data.get_normalized_size()
	_compiled_tile_size = maxf(0.01, map_data.tile_size)
	_compiled_height_step = maxf(0.01, map_data.height_step)
	_compiled_min_corner = map_data.get_min_world_corner()
	var tile_count: int = map_data.get_tile_count()

	_compiled_height_levels.resize(tile_count)
	_compiled_walkable.resize(tile_count)
	_compiled_buildable.resize(tile_count)
	_compiled_layers.resize(tile_count)
	_compiled_ramps.resize(tile_count)
	for idx in tile_count:
		_compiled_height_levels[idx] = map_data.default_height_level
		_compiled_walkable[idx] = 1 if map_data.default_walkable else 0
		_compiled_buildable[idx] = 1 if map_data.default_buildable else 0
		_compiled_layers[idx] = maxi(0, map_data.default_layer_id)
		_compiled_ramps[idx] = RAMP_NONE

	_apply_flat_data_arrays()
	_apply_height_brushes()
	_apply_layer_brushes()
	_apply_ramp_brushes()
	_apply_overrides()

func _apply_flat_data_arrays() -> void:
	var tile_count: int = map_data.get_tile_count()
	if map_data.height_levels.size() == tile_count:
		for idx in tile_count:
			_compiled_height_levels[idx] = map_data.height_levels[idx]
	if map_data.walkable_flags.size() == tile_count:
		for idx in tile_count:
			_compiled_walkable[idx] = 1 if map_data.walkable_flags[idx] > 0 else 0
	if map_data.buildable_flags.size() == tile_count:
		for idx in tile_count:
			_compiled_buildable[idx] = 1 if map_data.buildable_flags[idx] > 0 else 0
	if map_data.layer_ids.size() == tile_count:
		for idx in tile_count:
			_compiled_layers[idx] = maxi(0, map_data.layer_ids[idx])
	if map_data.ramp_dirs.size() == tile_count:
		for idx in tile_count:
			_compiled_ramps[idx] = _normalized_ramp_code(map_data.ramp_dirs[idx])

func _find_nearest_tile_by_flag(
	source_tile: Vector2i,
	require_walkable: bool,
	require_buildable: bool,
	max_radius_tiles: int
) -> Vector2i:
	if not is_inside_tile(source_tile):
		return Vector2i(-1, -1)
	if _tile_matches_flags(source_tile, require_walkable, require_buildable):
		return source_tile
	var max_radius: int = nearest_tile_search_max_radius if max_radius_tiles < 0 else max_radius_tiles
	max_radius = clampi(max_radius, 0, 256)
	for radius in range(1, max_radius + 1):
		var best_tile: Vector2i = Vector2i(-1, -1)
		var best_distance_sq: int = 2147483647
		for y in range(source_tile.y - radius, source_tile.y + radius + 1):
			for x in range(source_tile.x - radius, source_tile.x + radius + 1):
				var tile: Vector2i = Vector2i(x, y)
				if not is_inside_tile(tile):
					continue
				var edge_sample: bool = x == source_tile.x - radius or x == source_tile.x + radius or y == source_tile.y - radius or y == source_tile.y + radius
				if not edge_sample:
					continue
				if not _tile_matches_flags(tile, require_walkable, require_buildable):
					continue
				var delta_x: int = tile.x - source_tile.x
				var delta_y: int = tile.y - source_tile.y
				var distance_sq: int = delta_x * delta_x + delta_y * delta_y
				if distance_sq < best_distance_sq:
					best_distance_sq = distance_sq
					best_tile = tile
		if best_tile.x >= 0:
			return best_tile
	return Vector2i(-1, -1)

func _tile_matches_flags(tile: Vector2i, require_walkable: bool, require_buildable: bool) -> bool:
	if not is_inside_tile(tile):
		return false
	var idx: int = _tile_to_index(tile)
	if require_walkable and not _byte_flag(_compiled_walkable, idx, 1):
		return false
	if require_buildable and not _byte_flag(_compiled_buildable, idx, 1):
		return false
	return true

func _walk_tile_matches_rules(tile: Vector2i, allowed_height_levels: PackedInt32Array, allow_ramp_tiles: bool) -> bool:
	if not _tile_matches_flags(tile, true, false):
		return false
	var flags: Dictionary = get_tile_flags(tile)
	if not allow_ramp_tiles and bool(flags.get("is_ramp", false)):
		return false
	if not allowed_height_levels.is_empty():
		var height_level: int = int(flags.get("height_level", side_wall_floor_level))
		if not allowed_height_levels.has(height_level):
			return false
	return true

func _apply_height_brushes() -> void:
	for brush_value in map_data.height_brushes:
		if not (brush_value is Dictionary):
			continue
		var brush: Dictionary = brush_value as Dictionary
		var center: Vector2i = _brush_center(brush)
		var radius: int = maxi(0, int(brush.get("radius", 0)))
		var falloff: int = maxi(0, int(brush.get("falloff", 0)))
		var height_level: int = int(brush.get("height_level", brush.get("level", map_data.default_height_level)))
		var shape: String = str(brush.get("shape", "circle")).strip_edges().to_lower()
		var range_radius: int = radius + falloff
		for y in range(center.y - range_radius, center.y + range_radius + 1):
			for x in range(center.x - range_radius, center.x + range_radius + 1):
				var tile: Vector2i = Vector2i(x, y)
				if not is_inside_tile(tile):
					continue
				var distance: float = _brush_distance(tile, center, shape)
				if distance > float(range_radius):
					continue
				var idx: int = _tile_to_index(tile)
				if distance <= float(radius):
					_compiled_height_levels[idx] = maxi(_compiled_height_levels[idx], height_level)
					continue
				if falloff <= 0:
					continue
				var decay: int = int(ceil(distance - float(radius)))
				var candidate: int = height_level - decay
				_compiled_height_levels[idx] = maxi(_compiled_height_levels[idx], candidate)

func _apply_layer_brushes() -> void:
	for brush_value in map_data.layer_brushes:
		if not (brush_value is Dictionary):
			continue
		var brush: Dictionary = brush_value as Dictionary
		var center: Vector2i = _brush_center(brush)
		var radius: int = maxi(0, int(brush.get("radius", 0)))
		var layer_id: int = maxi(0, int(brush.get("layer_id", brush.get("layer", 0))))
		var shape: String = str(brush.get("shape", "circle")).strip_edges().to_lower()
		for y in range(center.y - radius, center.y + radius + 1):
			for x in range(center.x - radius, center.x + radius + 1):
				var tile: Vector2i = Vector2i(x, y)
				if not is_inside_tile(tile):
					continue
				var distance: float = _brush_distance(tile, center, shape)
				if distance > float(radius):
					continue
				_compiled_layers[_tile_to_index(tile)] = layer_id

func _apply_overrides() -> void:
	_apply_int_overrides(_compiled_height_levels, map_data.height_overrides)
	_apply_int_overrides(_compiled_layers, map_data.layer_overrides)
	_apply_bool_overrides(_compiled_walkable, map_data.walkable_overrides)
	_apply_bool_overrides(_compiled_buildable, map_data.buildable_overrides)
	_apply_ramp_overrides(_compiled_ramps, map_data.ramp_overrides)

func _apply_ramp_brushes() -> void:
	for brush_value in map_data.ramp_brushes:
		if not (brush_value is Dictionary):
			continue
		var brush: Dictionary = brush_value as Dictionary
		var center: Vector2i = _brush_center(brush)
		var radius: int = maxi(0, int(brush.get("radius", 0)))
		var shape: String = str(brush.get("shape", "circle")).strip_edges().to_lower()
		var ramp_code: int = _normalized_ramp_code(brush.get("ramp_dir", brush.get("direction", brush.get("ramp", RAMP_NONE))))
		if ramp_code == RAMP_NONE:
			continue
		for y in range(center.y - radius, center.y + radius + 1):
			for x in range(center.x - radius, center.x + radius + 1):
				var tile: Vector2i = Vector2i(x, y)
				if not is_inside_tile(tile):
					continue
				var distance: float = _brush_distance(tile, center, shape)
				if distance > float(radius):
					continue
				_compiled_ramps[_tile_to_index(tile)] = ramp_code

func _apply_int_overrides(target, overrides: Dictionary) -> void:
	for key_value in overrides.keys():
		var tile: Vector2i = map_data.parse_tile_key(key_value)
		if not is_inside_tile(tile):
			continue
		var idx: int = _tile_to_index(tile)
		target[idx] = int(overrides.get(key_value, target[idx]))

func _apply_bool_overrides(target: PackedByteArray, overrides: Dictionary) -> void:
	for key_value in overrides.keys():
		var tile: Vector2i = map_data.parse_tile_key(key_value)
		if not is_inside_tile(tile):
			continue
		var idx: int = _tile_to_index(tile)
		target[idx] = 1 if bool(overrides.get(key_value, true)) else 0

func _apply_ramp_overrides(target: PackedByteArray, overrides: Dictionary) -> void:
	for key_value in overrides.keys():
		var tile: Vector2i = map_data.parse_tile_key(key_value)
		if not is_inside_tile(tile):
			continue
		var idx: int = _tile_to_index(tile)
		target[idx] = _normalized_ramp_code(overrides.get(key_value, RAMP_NONE))

func _build_mesh() -> ArrayMesh:
	if _compiled_size.x <= 0 or _compiled_size.y <= 0:
		return null
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for y in _compiled_size.y:
		for x in _compiled_size.x:
			var tile: Vector2i = Vector2i(x, y)
			_append_tile_top(st, tile)
			if generate_side_walls:
				_append_tile_side_walls(st, tile)
	st.generate_normals()
	return st.commit()

func _append_tile_top(st: SurfaceTool, tile: Vector2i) -> void:
	var idx: int = _tile_to_index(tile)
	var layer_id: int = _byte_value(_compiled_layers, idx, 0)
	var height_level: int = _height_level_at_index(idx)
	var corners: Dictionary = _tile_corner_heights(tile)
	var color: Color = _top_color(layer_id, height_level)

	var x0: float = _compiled_min_corner.x + float(tile.x) * _compiled_tile_size
	var x1: float = x0 + _compiled_tile_size
	var z0: float = _compiled_min_corner.y + float(tile.y) * _compiled_tile_size
	var z1: float = z0 + _compiled_tile_size
	var uv_scale: float = _uv_scale()

	var a: Vector3 = Vector3(x0, float(corners.get("nw", 0.0)), z0)
	var b: Vector3 = Vector3(x1, float(corners.get("ne", 0.0)), z0)
	var c: Vector3 = Vector3(x1, float(corners.get("se", 0.0)), z1)
	var d: Vector3 = Vector3(x0, float(corners.get("sw", 0.0)), z1)
	var uv2_a: Vector2 = _control_uv_from_world(x0, z0)
	var uv2_b: Vector2 = _control_uv_from_world(x1, z0)
	var uv2_c: Vector2 = _control_uv_from_world(x1, z1)
	var uv2_d: Vector2 = _control_uv_from_world(x0, z1)
	_add_triangle(
		st,
		a,
		b,
		c,
		color,
		Vector2(x0 * uv_scale, z0 * uv_scale),
		Vector2(x1 * uv_scale, z0 * uv_scale),
		Vector2(x1 * uv_scale, z1 * uv_scale),
		uv2_a,
		uv2_b,
		uv2_c
	)
	_add_triangle(
		st,
		a,
		c,
		d,
		color,
		Vector2(x0 * uv_scale, z0 * uv_scale),
		Vector2(x1 * uv_scale, z1 * uv_scale),
		Vector2(x0 * uv_scale, z1 * uv_scale),
		uv2_a,
		uv2_c,
		uv2_d
	)

func _append_tile_side_walls(st: SurfaceTool, tile: Vector2i) -> void:
	var idx: int = _tile_to_index(tile)
	var current_level: int = _height_level_at_index(idx)
	var current_corners: Dictionary = _tile_corner_heights(tile)
	var layer_id: int = _byte_value(_compiled_layers, idx, 0)
	var side_color: Color = _top_color(layer_id, current_level).darkened(clampf(side_shade_strength, 0.0, 0.8))

	var x0: float = _compiled_min_corner.x + float(tile.x) * _compiled_tile_size
	var x1: float = x0 + _compiled_tile_size
	var z0: float = _compiled_min_corner.y + float(tile.y) * _compiled_tile_size
	var z1: float = z0 + _compiled_tile_size
	var uv_scale: float = _uv_scale()

	var north_corners: Dictionary = _tile_corner_heights_or_floor(tile + Vector2i(0, -1))
	var north_current_left: float = float(current_corners.get("nw", 0.0))
	var north_current_right: float = float(current_corners.get("ne", 0.0))
	var north_neighbor_left: float = float(north_corners.get("sw", 0.0))
	var north_neighbor_right: float = float(north_corners.get("se", 0.0))
	if north_current_left > north_neighbor_left + 0.0001 or north_current_right > north_neighbor_right + 0.0001:
		_add_vertical_quad(
			st,
			Vector3(x0, north_current_left, z0),
			Vector3(x1, north_current_right, z0),
			Vector3(x1, minf(north_current_right, north_neighbor_right), z0),
			Vector3(x0, minf(north_current_left, north_neighbor_left), z0),
			side_color,
			Vector2(x0 * uv_scale, north_current_left * uv_scale),
			Vector2(x1 * uv_scale, north_current_right * uv_scale),
			Vector2(x1 * uv_scale, north_neighbor_right * uv_scale),
			Vector2(x0 * uv_scale, north_neighbor_left * uv_scale)
		)

	var south_corners: Dictionary = _tile_corner_heights_or_floor(tile + Vector2i(0, 1))
	var south_current_left: float = float(current_corners.get("sw", 0.0))
	var south_current_right: float = float(current_corners.get("se", 0.0))
	var south_neighbor_left: float = float(south_corners.get("nw", 0.0))
	var south_neighbor_right: float = float(south_corners.get("ne", 0.0))
	if south_current_left > south_neighbor_left + 0.0001 or south_current_right > south_neighbor_right + 0.0001:
		_add_vertical_quad(
			st,
			Vector3(x1, south_current_right, z1),
			Vector3(x0, south_current_left, z1),
			Vector3(x0, minf(south_current_left, south_neighbor_left), z1),
			Vector3(x1, minf(south_current_right, south_neighbor_right), z1),
			side_color,
			Vector2(x1 * uv_scale, south_current_right * uv_scale),
			Vector2(x0 * uv_scale, south_current_left * uv_scale),
			Vector2(x0 * uv_scale, south_neighbor_left * uv_scale),
			Vector2(x1 * uv_scale, south_neighbor_right * uv_scale)
		)

	var west_corners: Dictionary = _tile_corner_heights_or_floor(tile + Vector2i(-1, 0))
	var west_current_top: float = float(current_corners.get("nw", 0.0))
	var west_current_bottom: float = float(current_corners.get("sw", 0.0))
	var west_neighbor_top: float = float(west_corners.get("ne", 0.0))
	var west_neighbor_bottom: float = float(west_corners.get("se", 0.0))
	if west_current_top > west_neighbor_top + 0.0001 or west_current_bottom > west_neighbor_bottom + 0.0001:
		_add_vertical_quad(
			st,
			Vector3(x0, west_current_bottom, z1),
			Vector3(x0, west_current_top, z0),
			Vector3(x0, minf(west_current_top, west_neighbor_top), z0),
			Vector3(x0, minf(west_current_bottom, west_neighbor_bottom), z1),
			side_color,
			Vector2(z1 * uv_scale, west_current_bottom * uv_scale),
			Vector2(z0 * uv_scale, west_current_top * uv_scale),
			Vector2(z0 * uv_scale, west_neighbor_top * uv_scale),
			Vector2(z1 * uv_scale, west_neighbor_bottom * uv_scale)
		)

	var east_corners: Dictionary = _tile_corner_heights_or_floor(tile + Vector2i(1, 0))
	var east_current_top: float = float(current_corners.get("ne", 0.0))
	var east_current_bottom: float = float(current_corners.get("se", 0.0))
	var east_neighbor_top: float = float(east_corners.get("nw", 0.0))
	var east_neighbor_bottom: float = float(east_corners.get("sw", 0.0))
	if east_current_top > east_neighbor_top + 0.0001 or east_current_bottom > east_neighbor_bottom + 0.0001:
		_add_vertical_quad(
			st,
			Vector3(x1, east_current_top, z0),
			Vector3(x1, east_current_bottom, z1),
			Vector3(x1, minf(east_current_bottom, east_neighbor_bottom), z1),
			Vector3(x1, minf(east_current_top, east_neighbor_top), z0),
			side_color,
			Vector2(z0 * uv_scale, east_current_top * uv_scale),
			Vector2(z1 * uv_scale, east_current_bottom * uv_scale),
			Vector2(z1 * uv_scale, east_neighbor_bottom * uv_scale),
			Vector2(z0 * uv_scale, east_neighbor_top * uv_scale)
		)

func _add_vertical_quad(
	st: SurfaceTool,
	a_top: Vector3,
	b_top: Vector3,
	b_bottom: Vector3,
	a_bottom: Vector3,
	color: Color,
	uv_a: Vector2,
	uv_b: Vector2,
	uv_c: Vector2,
	uv_d: Vector2
) -> void:
	var uv2_a: Vector2 = _control_uv_from_world(a_top.x, a_top.z)
	var uv2_b: Vector2 = _control_uv_from_world(b_top.x, b_top.z)
	var uv2_c: Vector2 = _control_uv_from_world(b_bottom.x, b_bottom.z)
	var uv2_d: Vector2 = _control_uv_from_world(a_bottom.x, a_bottom.z)
	_add_triangle(st, a_top, b_top, b_bottom, color, uv_a, uv_b, uv_c, uv2_a, uv2_b, uv2_c)
	_add_triangle(st, a_top, b_bottom, a_bottom, color, uv_a, uv_c, uv_d, uv2_a, uv2_c, uv2_d)
	# Keep explicit back faces so cliff walls stay visible even if culling is enabled elsewhere.
	_add_triangle(st, b_bottom, b_top, a_top, color, uv_c, uv_b, uv_a, uv2_c, uv2_b, uv2_a)
	_add_triangle(st, a_bottom, b_bottom, a_top, color, uv_d, uv_c, uv_a, uv2_d, uv2_c, uv2_a)

func _add_triangle(
	st: SurfaceTool,
	a: Vector3,
	b: Vector3,
	c: Vector3,
	color: Color,
	uv_a: Vector2,
	uv_b: Vector2,
	uv_c: Vector2,
	uv2_a: Vector2,
	uv2_b: Vector2,
	uv2_c: Vector2
) -> void:
	st.set_color(color)
	st.set_uv(uv_a)
	st.set_uv2(uv2_a)
	st.add_vertex(a)
	st.set_color(color)
	st.set_uv(uv_b)
	st.set_uv2(uv2_b)
	st.add_vertex(b)
	st.set_color(color)
	st.set_uv(uv_c)
	st.set_uv2(uv2_c)
	st.add_vertex(c)

func _brush_center(brush: Dictionary) -> Vector2i:
	var center_value: Variant = brush.get("center", brush.get("tile", Vector2i.ZERO))
	if center_value is Vector2i:
		return center_value as Vector2i
	if center_value is Vector2:
		var center_2d: Vector2 = center_value as Vector2
		return Vector2i(roundi(center_2d.x), roundi(center_2d.y))
	if center_value is Vector3:
		var center_3d: Vector3 = center_value as Vector3
		return Vector2i(roundi(center_3d.x), roundi(center_3d.z))
	return Vector2i.ZERO

func _brush_distance(tile: Vector2i, center: Vector2i, shape: String) -> float:
	var delta: Vector2 = Vector2(absi(tile.x - center.x), absi(tile.y - center.y))
	if shape == "square":
		return maxf(delta.x, delta.y)
	return delta.length()

func _tile_to_index(tile: Vector2i) -> int:
	return tile.y * _compiled_size.x + tile.x

func _height_level_at_tile(tile: Vector2i) -> int:
	if not is_inside_tile(tile):
		return side_wall_floor_level
	return _height_level_at_index(_tile_to_index(tile))

func _height_level_at_index(idx: int) -> int:
	if idx < 0 or idx >= _compiled_height_levels.size():
		return side_wall_floor_level
	return _compiled_height_levels[idx]

func _height_from_level(level: int) -> float:
	return float(level) * _compiled_height_step

func _tile_corner_heights(tile: Vector2i) -> Dictionary:
	var height_level: int = _height_level_at_tile(tile)
	var base_height: float = _height_from_level(height_level)
	var high_height: float = base_height + _compiled_height_step
	var ramp_code: int = _byte_value(_compiled_ramps, _tile_to_index(tile), RAMP_NONE)
	match ramp_code:
		RAMP_NORTH_UP:
			return {"nw": high_height, "ne": high_height, "se": base_height, "sw": base_height}
		RAMP_SOUTH_UP:
			return {"nw": base_height, "ne": base_height, "se": high_height, "sw": high_height}
		RAMP_EAST_UP:
			return {"nw": base_height, "ne": high_height, "se": high_height, "sw": base_height}
		RAMP_WEST_UP:
			return {"nw": high_height, "ne": base_height, "se": base_height, "sw": high_height}
		_:
			return {"nw": base_height, "ne": base_height, "se": base_height, "sw": base_height}

func _tile_corner_heights_or_floor(tile: Vector2i) -> Dictionary:
	if is_inside_tile(tile):
		return _tile_corner_heights(tile)
	var floor_height: float = _height_from_level(side_wall_floor_level)
	return {"nw": floor_height, "ne": floor_height, "se": floor_height, "sw": floor_height}

func _tile_world_height(tile: Vector2i, world_position: Vector3, fallback: float = 0.0) -> float:
	if not is_inside_tile(tile):
		return fallback
	var corners: Dictionary = _tile_corner_heights(tile)
	var x0: float = _compiled_min_corner.x + float(tile.x) * _compiled_tile_size
	var z0: float = _compiled_min_corner.y + float(tile.y) * _compiled_tile_size
	var safe_size: float = maxf(0.01, _compiled_tile_size)
	var u: float = clampf((world_position.x - x0) / safe_size, 0.0, 1.0)
	var v: float = clampf((world_position.z - z0) / safe_size, 0.0, 1.0)
	var ramp_code: int = _byte_value(_compiled_ramps, _tile_to_index(tile), RAMP_NONE)
	var base_height: float = float(corners.get("nw", fallback))
	match ramp_code:
		RAMP_NORTH_UP:
			base_height = float(corners.get("sw", fallback))
			return lerpf(base_height + _compiled_height_step, base_height, v)
		RAMP_SOUTH_UP:
			base_height = float(corners.get("nw", fallback))
			return lerpf(base_height, base_height + _compiled_height_step, v)
		RAMP_EAST_UP:
			base_height = float(corners.get("sw", fallback))
			return lerpf(base_height, base_height + _compiled_height_step, u)
		RAMP_WEST_UP:
			base_height = float(corners.get("se", fallback))
			return lerpf(base_height, base_height + _compiled_height_step, 1.0 - u)
		_:
			return float(corners.get("nw", fallback))

func _byte_value(buffer: PackedByteArray, idx: int, fallback: int) -> int:
	if idx < 0 or idx >= buffer.size():
		return fallback
	return int(buffer[idx])

func _byte_flag(buffer: PackedByteArray, idx: int, fallback: int) -> bool:
	return _byte_value(buffer, idx, fallback) > 0

func _normalized_ramp_code(raw_value: Variant) -> int:
	if raw_value is int:
		return clampi(int(raw_value), RAMP_NONE, RAMP_WEST_UP)
	var text: String = str(raw_value).strip_edges().to_lower()
	match text:
		"north", "n", "north_up", "up_north":
			return RAMP_NORTH_UP
		"south", "s", "south_up", "up_south":
			return RAMP_SOUTH_UP
		"east", "e", "east_up", "up_east":
			return RAMP_EAST_UP
		"west", "w", "west_up", "up_west":
			return RAMP_WEST_UP
		_:
			return RAMP_NONE

func _ramp_code_to_name(ramp_code: int) -> String:
	match ramp_code:
		RAMP_NORTH_UP:
			return "north"
		RAMP_SOUTH_UP:
			return "south"
		RAMP_EAST_UP:
			return "east"
		RAMP_WEST_UP:
			return "west"
		_:
			return ""

func _top_color(layer_id: int, height_level: int) -> Color:
	var base_color: Color = Color(0.33, 0.46, 0.3, 1.0)
	if layer_set != null:
		base_color = layer_set.get_debug_color(layer_id)
	else:
		var fallback_palette: Array[Color] = [
			Color(0.30, 0.46, 0.30, 1.0),
			Color(0.45, 0.36, 0.24, 1.0),
			Color(0.39, 0.39, 0.42, 1.0),
			Color(0.56, 0.52, 0.34, 1.0)
		]
		base_color = fallback_palette[posmod(layer_id, fallback_palette.size())]
	var tint: float = clampf(0.92 + float(height_level) * 0.035, 0.72, 1.24)
	return Color(base_color.r * tint, base_color.g * tint, base_color.b * tint, 1.0)

func _uv_scale() -> float:
	if layer_set == null:
		return 0.25
	return maxf(0.0001, layer_set.uv_scale)

func _control_uv_from_world(world_x: float, world_z: float) -> Vector2:
	var total_w: float = maxf(0.01, float(_compiled_size.x) * _compiled_tile_size)
	var total_h: float = maxf(0.01, float(_compiled_size.y) * _compiled_tile_size)
	var u: float = clampf((world_x - _compiled_min_corner.x) / total_w, 0.0, 1.0)
	var v: float = clampf((world_z - _compiled_min_corner.y) / total_h, 0.0, 1.0)
	return Vector2(u, v)

func _rebuild_control_map_texture() -> void:
	var width: int = maxi(1, _compiled_size.x)
	var height: int = maxi(1, _compiled_size.y)
	var image: Image = Image.create(width, height, false, Image.FORMAT_RGBA8)
	for y in height:
		for x in width:
			var idx: int = y * width + x
			var layer_id: int = _byte_value(_compiled_layers, idx, 0)
			var channel_idx: int = posmod(layer_id, SPLAT_LAYER_COUNT)
			var control_pixel: Color = Color(0.0, 0.0, 0.0, 0.0)
			match channel_idx:
				0:
					control_pixel.r = 1.0
				1:
					control_pixel.g = 1.0
				2:
					control_pixel.b = 1.0
				_:
					control_pixel.a = 1.0
			var image_y: int = height - 1 - y
			image.set_pixel(x, image_y, control_pixel)
	_control_map_texture = ImageTexture.create_from_image(image)

func _apply_material() -> void:
	if _should_use_splat_material():
		_apply_splat_material()
		return
	_apply_vertex_color_material()

func _should_use_splat_material() -> bool:
	if not use_splat_material:
		return false
	if layer_set == null:
		return false
	return layer_set.use_texture_blending

func _apply_vertex_color_material() -> void:
	if _material == null:
		_material = StandardMaterial3D.new()
		_material.vertex_color_use_as_albedo = true
		_material.roughness = material_roughness
		_material.metallic = material_metallic
		_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_material.roughness = material_roughness
	_material.metallic = material_metallic
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mesh_instance.material_override = _material

func _apply_splat_material() -> void:
	_ensure_splat_material()
	if _splat_material == null:
		_apply_vertex_color_material()
		return
	if _control_map_texture == null:
		_apply_vertex_color_material()
		return
	_splat_material.set_shader_parameter("control_map", _control_map_texture)
	_splat_material.set_shader_parameter("tex0", _layer_albedo_or_fallback(0))
	_splat_material.set_shader_parameter("tex1", _layer_albedo_or_fallback(1))
	_splat_material.set_shader_parameter("tex2", _layer_albedo_or_fallback(2))
	_splat_material.set_shader_parameter("tex3", _layer_albedo_or_fallback(3))
	_splat_material.set_shader_parameter("nrm0", _layer_normal_or_fallback(0))
	_splat_material.set_shader_parameter("nrm1", _layer_normal_or_fallback(1))
	_splat_material.set_shader_parameter("nrm2", _layer_normal_or_fallback(2))
	_splat_material.set_shader_parameter("nrm3", _layer_normal_or_fallback(3))
	_splat_material.set_shader_parameter("orm0", _layer_orm_or_fallback(0))
	_splat_material.set_shader_parameter("orm1", _layer_orm_or_fallback(1))
	_splat_material.set_shader_parameter("orm2", _layer_orm_or_fallback(2))
	_splat_material.set_shader_parameter("orm3", _layer_orm_or_fallback(3))
	_splat_material.set_shader_parameter("hgt0", _layer_height_or_fallback(0))
	_splat_material.set_shader_parameter("hgt1", _layer_height_or_fallback(1))
	_splat_material.set_shader_parameter("hgt2", _layer_height_or_fallback(2))
	_splat_material.set_shader_parameter("hgt3", _layer_height_or_fallback(3))
	_splat_material.set_shader_parameter("cliff_tex0", _cliff_albedo_or_fallback(0))
	_splat_material.set_shader_parameter("cliff_tex1", _cliff_albedo_or_fallback(1))
	_splat_material.set_shader_parameter("cliff_tex2", _cliff_albedo_or_fallback(2))
	_splat_material.set_shader_parameter("cliff_nrm0", _cliff_normal_or_fallback(0))
	_splat_material.set_shader_parameter("cliff_nrm1", _cliff_normal_or_fallback(1))
	_splat_material.set_shader_parameter("cliff_nrm2", _cliff_normal_or_fallback(2))
	_splat_material.set_shader_parameter("cliff_orm0", _cliff_orm_or_fallback(0))
	_splat_material.set_shader_parameter("cliff_orm1", _cliff_orm_or_fallback(1))
	_splat_material.set_shader_parameter("cliff_orm2", _cliff_orm_or_fallback(2))
	_splat_material.set_shader_parameter("cliff_hgt0", _cliff_height_or_fallback(0))
	_splat_material.set_shader_parameter("cliff_hgt1", _cliff_height_or_fallback(1))
	_splat_material.set_shader_parameter("cliff_hgt2", _cliff_height_or_fallback(2))
	_splat_material.set_shader_parameter("macro_color_tex", _macro_color_or_fallback())
	_splat_material.set_shader_parameter("macro_roughness_tex", _macro_roughness_or_fallback())
	_splat_material.set_shader_parameter("detail_noise_a_tex", _detail_noise_a_or_fallback())
	_splat_material.set_shader_parameter("detail_noise_b_tex", _detail_noise_b_or_fallback())
	var sharpness: float = 1.0
	var macro_uv_scale: float = 0.8
	var macro_color_strength: float = 0.24
	var macro_roughness_strength: float = 0.32
	var detail_noise_strength: float = 0.15
	var cliff_start: float = 0.38
	var cliff_end: float = 0.78
	var cliff_blend_sharpness: float = 1.4
	var normal_strength: float = 1.0
	if layer_set != null:
		sharpness = clampf(layer_set.blend_sharpness, 0.5, 4.0)
		macro_uv_scale = clampf(layer_set.macro_uv_scale, 0.25, 8.0)
		macro_color_strength = clampf(layer_set.macro_color_strength, 0.0, 1.0)
		macro_roughness_strength = clampf(layer_set.macro_roughness_strength, 0.0, 1.0)
		detail_noise_strength = clampf(layer_set.detail_noise_strength, 0.0, 1.0)
		cliff_start = clampf(layer_set.cliff_start, 0.0, 1.0)
		cliff_end = clampf(layer_set.cliff_end, cliff_start + 0.01, 1.0)
		cliff_blend_sharpness = clampf(layer_set.cliff_blend_sharpness, 0.5, 4.0)
		normal_strength = clampf(layer_set.normal_strength, 0.0, 2.0)
	_splat_material.set_shader_parameter("blend_sharpness", sharpness)
	_splat_material.set_shader_parameter("macro_uv_scale", macro_uv_scale)
	_splat_material.set_shader_parameter("macro_color_strength", macro_color_strength)
	_splat_material.set_shader_parameter("macro_roughness_strength", macro_roughness_strength)
	_splat_material.set_shader_parameter("detail_noise_strength", detail_noise_strength)
	_splat_material.set_shader_parameter("cliff_start", cliff_start)
	_splat_material.set_shader_parameter("cliff_end", cliff_end)
	_splat_material.set_shader_parameter("cliff_blend_sharpness", cliff_blend_sharpness)
	_splat_material.set_shader_parameter("normal_strength", normal_strength)
	_splat_material.set_shader_parameter("surface_roughness", clampf(material_roughness, 0.0, 1.0))
	_splat_material.set_shader_parameter("surface_metallic", clampf(material_metallic, 0.0, 1.0))
	_mesh_instance.material_override = _splat_material

func _ensure_splat_material() -> void:
	if _splat_shader == null:
		_splat_shader = Shader.new()
		_splat_shader.code = SPLAT_SHADER_CODE
	if _splat_material == null:
		_splat_material = ShaderMaterial.new()
		_splat_material.shader = _splat_shader

func _layer_albedo_or_fallback(layer_index: int) -> Texture2D:
	if layer_set != null:
		return _texture_from_array_or_fallback(
			layer_set.albedo_textures,
			layer_index,
			"layer_albedo_%d" % layer_index,
			layer_set.get_debug_color(layer_index)
		)
	return _fallback_texture("layer_albedo_%d" % layer_index, Color(0.32, 0.42, 0.32, 1.0))

func _layer_normal_or_fallback(layer_index: int) -> Texture2D:
	if layer_set != null:
		return _texture_from_array_or_fallback(
			layer_set.normal_textures,
			layer_index,
			"layer_normal_%d" % layer_index,
			Color(0.5, 0.5, 1.0, 1.0)
		)
	return _fallback_texture("layer_normal_%d" % layer_index, Color(0.5, 0.5, 1.0, 1.0))

func _layer_orm_or_fallback(layer_index: int) -> Texture2D:
	if layer_set != null:
		return _texture_from_array_or_fallback(
			layer_set.orm_textures,
			layer_index,
			"layer_orm_%d" % layer_index,
			Color(1.0, 1.0, 0.0, 1.0)
		)
	return _fallback_texture("layer_orm_%d" % layer_index, Color(1.0, 1.0, 0.0, 1.0))

func _layer_height_or_fallback(layer_index: int) -> Texture2D:
	if layer_set != null:
		return _texture_from_array_or_fallback(
			layer_set.height_textures,
			layer_index,
			"layer_height_%d" % layer_index,
			Color(0.5, 0.5, 0.5, 1.0)
		)
	return _fallback_texture("layer_height_%d" % layer_index, Color(0.5, 0.5, 0.5, 1.0))

func _cliff_albedo_or_fallback(cliff_index: int) -> Texture2D:
	if layer_set != null:
		return _texture_from_array_or_fallback(
			layer_set.cliff_albedo_textures,
			cliff_index,
			"cliff_albedo_%d" % cliff_index,
			Color(0.36, 0.33, 0.31, 1.0)
		)
	return _fallback_texture("cliff_albedo_%d" % cliff_index, Color(0.36, 0.33, 0.31, 1.0))

func _cliff_normal_or_fallback(cliff_index: int) -> Texture2D:
	if layer_set != null:
		return _texture_from_array_or_fallback(
			layer_set.cliff_normal_textures,
			cliff_index,
			"cliff_normal_%d" % cliff_index,
			Color(0.5, 0.5, 1.0, 1.0)
		)
	return _fallback_texture("cliff_normal_%d" % cliff_index, Color(0.5, 0.5, 1.0, 1.0))

func _cliff_orm_or_fallback(cliff_index: int) -> Texture2D:
	if layer_set != null:
		return _texture_from_array_or_fallback(
			layer_set.cliff_orm_textures,
			cliff_index,
			"cliff_orm_%d" % cliff_index,
			Color(1.0, 1.0, 0.0, 1.0)
		)
	return _fallback_texture("cliff_orm_%d" % cliff_index, Color(1.0, 1.0, 0.0, 1.0))

func _cliff_height_or_fallback(cliff_index: int) -> Texture2D:
	if layer_set != null:
		return _texture_from_array_or_fallback(
			layer_set.cliff_height_textures,
			cliff_index,
			"cliff_height_%d" % cliff_index,
			Color(0.5, 0.5, 0.5, 1.0)
		)
	return _fallback_texture("cliff_height_%d" % cliff_index, Color(0.5, 0.5, 0.5, 1.0))

func _macro_color_or_fallback() -> Texture2D:
	if layer_set != null and layer_set.macro_color_texture != null:
		return layer_set.macro_color_texture
	return _fallback_texture("macro_color", Color(0.5, 0.5, 0.5, 1.0))

func _macro_roughness_or_fallback() -> Texture2D:
	if layer_set != null and layer_set.macro_roughness_texture != null:
		return layer_set.macro_roughness_texture
	return _fallback_texture("macro_roughness", Color(0.5, 0.5, 0.5, 1.0))

func _detail_noise_a_or_fallback() -> Texture2D:
	if layer_set != null and layer_set.detail_noise_a_texture != null:
		return layer_set.detail_noise_a_texture
	return _fallback_texture("detail_noise_a", Color(0.5, 0.5, 0.5, 1.0))

func _detail_noise_b_or_fallback() -> Texture2D:
	if layer_set != null and layer_set.detail_noise_b_texture != null:
		return layer_set.detail_noise_b_texture
	return _fallback_texture("detail_noise_b", Color(0.5, 0.5, 0.5, 1.0))

func _texture_from_array_or_fallback(
	textures: Array[Texture2D],
	texture_index: int,
	fallback_key: String,
	fallback_color: Color
) -> Texture2D:
	if texture_index >= 0 and texture_index < textures.size():
		var tex: Texture2D = textures[texture_index]
		if tex != null:
			return tex
	return _fallback_texture(fallback_key, fallback_color)

func _fallback_texture(key: String, color: Color) -> Texture2D:
	if _fallback_textures_by_layer.has(key):
		return _fallback_textures_by_layer[key] as Texture2D
	var texture: ImageTexture = _make_solid_texture(color)
	_fallback_textures_by_layer[key] = texture
	return texture

func _make_solid_texture(color: Color) -> ImageTexture:
	var image: Image = Image.create(4, 4, false, Image.FORMAT_RGBA8)
	image.fill(color)
	return ImageTexture.create_from_image(image)

func _ensure_runtime_nodes() -> void:
	if _mesh_instance == null:
		_mesh_instance = get_node_or_null("TerrainMesh") as MeshInstance3D
	if _mesh_instance == null:
		_mesh_instance = MeshInstance3D.new()
		_mesh_instance.name = "TerrainMesh"
		add_child(_mesh_instance)

	if _body == null:
		_body = get_node_or_null("TerrainBody") as StaticBody3D
	if _body == null:
		_body = StaticBody3D.new()
		_body.name = "TerrainBody"
		add_child(_body)
	_body.collision_layer = collision_layer_value
	_body.collision_mask = collision_mask_value

	if _collision_shape == null:
		_collision_shape = _body.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if _collision_shape == null:
		_collision_shape = CollisionShape3D.new()
		_collision_shape.name = "CollisionShape3D"
		_body.add_child(_collision_shape)
