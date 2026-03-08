class_name TerrainMapData
extends Resource

@export var map_size: Vector2i = Vector2i(120, 120)
@export var tile_size: float = 1.0
@export var height_step: float = 0.6
@export var centered_origin: bool = true

@export var default_height_level: int = 0
@export var default_walkable: bool = true
@export var default_buildable: bool = true
@export var default_layer_id: int = 0

@export var height_levels: PackedInt32Array = PackedInt32Array()
@export var walkable_flags: PackedByteArray = PackedByteArray()
@export var buildable_flags: PackedByteArray = PackedByteArray()
@export var layer_ids: PackedByteArray = PackedByteArray()
@export var ramp_dirs: PackedByteArray = PackedByteArray()

@export var height_brushes: Array[Dictionary] = []
@export var layer_brushes: Array[Dictionary] = []
@export var ramp_brushes: Array[Dictionary] = []

@export var height_overrides: Dictionary = {}
@export var walkable_overrides: Dictionary = {}
@export var buildable_overrides: Dictionary = {}
@export var layer_overrides: Dictionary = {}
@export var ramp_overrides: Dictionary = {}

func get_normalized_size() -> Vector2i:
	return Vector2i(maxi(1, map_size.x), maxi(1, map_size.y))

func get_tile_count() -> int:
	var size: Vector2i = get_normalized_size()
	return size.x * size.y

func is_inside_tile(tile: Vector2i) -> bool:
	var size: Vector2i = get_normalized_size()
	return tile.x >= 0 and tile.y >= 0 and tile.x < size.x and tile.y < size.y

func to_index(tile: Vector2i) -> int:
	if not is_inside_tile(tile):
		return -1
	var size: Vector2i = get_normalized_size()
	return tile.y * size.x + tile.x

func tile_key(tile: Vector2i) -> String:
	return "%d:%d" % [tile.x, tile.y]

func parse_tile_key(key_value: Variant) -> Vector2i:
	var text: String = str(key_value).strip_edges()
	if text == "":
		return Vector2i(-1, -1)
	var parts: PackedStringArray = text.split(":", false, 2)
	if parts.size() != 2:
		return Vector2i(-1, -1)
	if not parts[0].is_valid_int() or not parts[1].is_valid_int():
		return Vector2i(-1, -1)
	return Vector2i(parts[0].to_int(), parts[1].to_int())

func get_half_extents() -> Vector2:
	var size: Vector2i = get_normalized_size()
	var safe_tile: float = maxf(0.01, tile_size)
	return Vector2(float(size.x) * safe_tile * 0.5, float(size.y) * safe_tile * 0.5)

func get_min_world_corner() -> Vector2:
	if centered_origin:
		var half: Vector2 = get_half_extents()
		return Vector2(-half.x, -half.y)
	return Vector2.ZERO

func world_to_tile(world_position: Vector3) -> Vector2i:
	var safe_tile: float = maxf(0.01, tile_size)
	var min_corner: Vector2 = get_min_world_corner()
	var x_idx: int = int(floor((world_position.x - min_corner.x) / safe_tile))
	var y_idx: int = int(floor((world_position.z - min_corner.y) / safe_tile))
	var size: Vector2i = get_normalized_size()
	return Vector2i(
		clampi(x_idx, 0, size.x - 1),
		clampi(y_idx, 0, size.y - 1)
	)

func tile_to_world_center(tile: Vector2i, world_y: float = 0.0) -> Vector3:
	var clamped_tile: Vector2i = tile
	var size: Vector2i = get_normalized_size()
	clamped_tile.x = clampi(clamped_tile.x, 0, size.x - 1)
	clamped_tile.y = clampi(clamped_tile.y, 0, size.y - 1)
	var safe_tile: float = maxf(0.01, tile_size)
	var min_corner: Vector2 = get_min_world_corner()
	return Vector3(
		min_corner.x + (float(clamped_tile.x) + 0.5) * safe_tile,
		world_y,
		min_corner.y + (float(clamped_tile.y) + 0.5) * safe_tile
	)
