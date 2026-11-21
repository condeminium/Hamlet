@tool
extends Node2D

@export var randomize_seed_on_generate: bool = true

@export var regenerate_terrain: bool = false:
	set(value):
		if value:
			GenerateTerrain()
		regenerate_terrain = false

@export var randomize_and_regenerate: bool = false:
	set(value):
		if value:
			reroll_noise_seeds()
			GenerateTerrain()
		randomize_and_regenerate = false

@export var auto_generate_in_editor: bool = true

@export var width: int = 80:
	set(value):
		width = maxi(4, value)
		if Engine.is_editor_hint() and auto_generate_in_editor and is_node_ready():
			GenerateTerrain()

@export var height: int = 80:
	set(value):
		height = maxi(4, value)
		if Engine.is_editor_hint() and auto_generate_in_editor and is_node_ready():
			GenerateTerrain()

@export var island_falloff: bool = false:
	set(value):
		island_falloff = value
		if Engine.is_editor_hint() and auto_generate_in_editor and is_node_ready():
			GenerateTerrain()

@export var falloff_strength: float = 0.45:
	set(value):
		falloff_strength = value
		if Engine.is_editor_hint() and auto_generate_in_editor and is_node_ready():
			GenerateTerrain()

@export var center_clearing_radius: float = 5.0:
	set(value):
		center_clearing_radius = maxf(0.0, value)
		if Engine.is_editor_hint() and auto_generate_in_editor and is_node_ready():
			GenerateTerrain()

@export var enable_rivers: bool = true:
	set(value):
		enable_rivers = value
		if Engine.is_editor_hint() and auto_generate_in_editor and is_node_ready():
			GenerateTerrain()

@export var river_width: float = 0.045:
	set(value):
		river_width = value
		if Engine.is_editor_hint() and auto_generate_in_editor and is_node_ready():
			GenerateTerrain()

@export_range(0.0, 0.25, 0.005) var blend_jitter: float = 0.06:
	set(value):
		blend_jitter = value
		if Engine.is_editor_hint() and auto_generate_in_editor and is_node_ready():
			GenerateTerrain()

@export_range(0.0, 1.0, 0.05) var blend_moisture_weight: float = 0.5:
	set(value):
		blend_moisture_weight = value
		if Engine.is_editor_hint() and auto_generate_in_editor and is_node_ready():
			GenerateTerrain()

@export var water_threshold: float = -0.36:
	set(value):
		water_threshold = value
		if Engine.is_editor_hint() and auto_generate_in_editor and is_node_ready():
			GenerateTerrain()

@export var sand_threshold: float = -0.22:
	set(value):
		sand_threshold = value
		if Engine.is_editor_hint() and auto_generate_in_editor and is_node_ready():
			GenerateTerrain()

@export var grassThreshold: float = -0.05:
	set(value):
		grassThreshold = value
		if Engine.is_editor_hint() and auto_generate_in_editor and is_node_ready():
			GenerateTerrain()

@export var forestThreshold: float = 0.35:
	set(value):
		forestThreshold = value
		if Engine.is_editor_hint() and auto_generate_in_editor and is_node_ready():
			GenerateTerrain()

@export var mountain_threshold: float = 0.52:
	set(value):
		mountain_threshold = value
		if Engine.is_editor_hint() and auto_generate_in_editor and is_node_ready():
			GenerateTerrain()

# Movement & navigation settings across all terrain types
@export var water_is_wall: bool = true
@export_range(0.0, 2.0, 0.05) var light_grass_speed_multiplier: float = 1.0
@export_range(0.0, 2.0, 0.05) var dark_grass_speed_multiplier: float = 0.9
@export_range(0.0, 2.0, 0.05) var dirt_speed_multiplier: float = 0.85
@export_range(0.0, 2.0, 0.05) var sand_speed_multiplier: float = 0.75
@export_range(0.0, 2.0, 0.05) var water_speed_multiplier: float = 0.45
@export_range(0.0, 2.0, 0.05) var deep_water_speed_multiplier: float = 0.25
@export_range(0.0, 2.0, 0.05) var plant_speed_multiplier: float = 0.75
@export_range(0.0, 2.0, 0.05) var mountain_speed_multiplier: float = 0.0
@export_range(0.0, 2.0, 0.05) var default_ground_speed_multiplier: float = 1.0

@export var clamp_camera: bool = false
@export var align_colony_to_map: bool = true

# Atlas coordinates in terrain_tileset - sheet.png (cols 0..3, rows 0..2)
@export var light_grass_coords: Vector2i = Vector2i(0, 0)
@export var dark_grass_coords: Vector2i = Vector2i(1, 0)
@export var dirt_coords: Vector2i = Vector2i(2, 0)
@export var sand_coords: Vector2i = Vector2i(0, 2)
@export var water_coords: Vector2i = Vector2i(1, 1)
@export var deep_water_coords: Vector2i = Vector2i(2, 1)

# Mountain TileMapLayer tile settings
@export var mountain_source_id: int = 0:
	set(value):
		mountain_source_id = value
		if Engine.is_editor_hint() and auto_generate_in_editor and is_node_ready():
			GenerateTerrain()

@export var mountain_tile_coords: Vector2i = Vector2i(0, 0):
	set(value):
		mountain_tile_coords = value
		if Engine.is_editor_hint() and auto_generate_in_editor and is_node_ready():
			GenerateTerrain()

@export var noise: FastNoiseLite:
	set(value):
		noise = value
		if Engine.is_editor_hint() and auto_generate_in_editor and is_node_ready():
			GenerateTerrain()

@export var moisture_noise: FastNoiseLite:
	set(value):
		moisture_noise = value
		if Engine.is_editor_hint() and auto_generate_in_editor and is_node_ready():
			GenerateTerrain()

@export var river_noise: FastNoiseLite:
	set(value):
		river_noise = value
		if Engine.is_editor_hint() and auto_generate_in_editor and is_node_ready():
			GenerateTerrain()

@export var custom_scene: PackedScene
@export var grass_anim: PackedScene

@onready var ground: TileMapLayer = _find_layer_anywhere(["Ground", "ground"])
@onready var plants: TileMapLayer = _find_layer_anywhere(["Plants", "plants"])
@onready var mountain_layer: TileMapLayer = _find_layer_anywhere(["Mountain", "mountain", "Mountains", "mountains"])

var _cell_noise: Dictionary = {}
var map_world_rect: Rect2 = Rect2(Vector2(-640, -640), Vector2(1280, 1280))

func _find_layer_anywhere(names: Array[String]) -> TileMapLayer:
	for n_name in names:
		var found := find_child(n_name, true, false)
		if found is TileMapLayer:
			return found
	if get_parent() != null:
		for n_name in names:
			var parent_found := get_parent().find_child(n_name, true, false)
			if parent_found is TileMapLayer:
				return parent_found
	return null

func reroll_noise_seeds() -> void:
	_ensure_noise()
	var base_seed := randi()
	if noise != null:
		noise.seed = base_seed
	if moisture_noise != null:
		moisture_noise.seed = base_seed + 1337
	if river_noise != null:
		river_noise.seed = base_seed + 4242

func _ensure_noise() -> void:
	var initial_seed := randi()
	if noise == null:
		noise = FastNoiseLite.new()
		noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		noise.fractal_octaves = 4
		noise.frequency = 0.03
		noise.seed = initial_seed

	if moisture_noise == null:
		moisture_noise = FastNoiseLite.new()
		moisture_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		moisture_noise.fractal_octaves = 3
		moisture_noise.frequency = 0.05
		moisture_noise.seed = noise.seed + 1337

	if river_noise == null:
		river_noise = FastNoiseLite.new()
		river_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		river_noise.fractal_octaves = 2
		river_noise.frequency = 0.018
		river_noise.seed = noise.seed + 4242

func _ready() -> void:
	if not Engine.is_editor_hint() and not is_in_group("terrain"):
		add_to_group("terrain")
	if ground == null:
		ground = _find_layer_anywhere(["Ground", "ground"])
	if plants == null:
		plants = _find_layer_anywhere(["Plants", "plants"])
	if mountain_layer == null:
		mountain_layer = _find_layer_anywhere(["Mountain", "mountain", "Mountains", "mountains"])
	_ensure_noise()
	if randomize_seed_on_generate and not Engine.is_editor_hint():
		reroll_noise_seeds()
	GenerateTerrain()

func _clear_spawned_props() -> void:
	for child in get_children():
		if child.is_in_group("spawned_prop") and is_instance_valid(child):
			child.queue_free()

	if is_inside_tree() and get_tree() != null:
		for prop in get_tree().get_nodes_in_group("spawned_prop"):
			if is_instance_valid(prop):
				prop.queue_free()

func _get_tile_size() -> Vector2:
	if ground != null and ground.tile_set != null:
		return Vector2(ground.tile_set.tile_size)
	return Vector2(16.0, 16.0)

func _compute_map_bounds() -> Rect2:
	var half_w := int(width / 2)
	var half_h := int(height / 2)
	var min_cell := Vector2i(-half_w, -half_h)
	var max_cell := Vector2i(-half_w + width, -half_h + height)

	if ground != null:
		var top_left: Vector2 = ground.to_global(ground.map_to_local(min_cell)) - (_get_tile_size() * 0.5)
		var bottom_right: Vector2 = ground.to_global(ground.map_to_local(max_cell)) - (_get_tile_size() * 0.5)
		return Rect2(top_left, bottom_right - top_left)

	var tile_sz := _get_tile_size()
	var full_size := Vector2(width * tile_sz.x, height * tile_sz.y)
	return Rect2(-full_size * 0.5, full_size)

func is_world_pos_in_map(world_pos: Vector2, margin: float = 0.0) -> bool:
	return map_world_rect.grow(-margin).has_point(world_pos)

func clamp_world_pos_to_map(world_pos: Vector2, margin: float = 16.0) -> Vector2:
	var safe_rect := map_world_rect.grow(-margin)
	if safe_rect.size.x <= 0.0 or safe_rect.size.y <= 0.0:
		return map_world_rect.get_center()
	return Vector2(
		clampf(world_pos.x, safe_rect.position.x, safe_rect.end.x),
		clampf(world_pos.y, safe_rect.position.y, safe_rect.end.y)
	)

func is_wall_at(world_pos: Vector2) -> bool:
	if not is_world_pos_in_map(world_pos, 0.0):
		return true

	if mountain_layer != null and mountain_layer.tile_set != null:
		var m_cell: Vector2i = mountain_layer.local_to_map(mountain_layer.to_local(world_pos))
		if mountain_layer.get_cell_source_id(m_cell) != -1:
			return true

	if water_is_wall and ground != null:
		var g_cell: Vector2i = ground.local_to_map(ground.to_local(world_pos))
		var atlas: Vector2i = ground.get_cell_atlas_coords(g_cell)
		if atlas == water_coords or atlas == deep_water_coords:
			return true

	return false

func is_walkable_at(world_pos: Vector2) -> bool:
	return not is_wall_at(world_pos)

func _falloff_at(gx: int, gy: int) -> float:
	if not island_falloff:
		return 0.0
	var nx := float(gx) / maxf(float(width) * 0.5, 1.0)
	var ny := float(gy) / maxf(float(height) * 0.5, 1.0)
	var dist := clampf(maxf(absf(nx), absf(ny)), 0.0, 1.0)
	var smooth := dist * dist * (3.0 - 2.0 * dist)
	return smooth * falloff_strength

func _apply_camera_limits() -> void:
	if Engine.is_editor_hint() or not clamp_camera:
		return
	var cam := get_viewport().get_camera_2d()
	if cam == null and get_tree() != null and get_tree().current_scene != null:
		var found := get_tree().current_scene.find_child("*Camera2D*", true, false)
		if found is Camera2D:
			cam = found
	if cam == null:
		return

	var vp_size := get_viewport_rect().size * cam.zoom
	if map_world_rect.size.x >= vp_size.x and map_world_rect.size.y >= vp_size.y:
		cam.limit_left = int(floor(map_world_rect.position.x))
		cam.limit_top = int(floor(map_world_rect.position.y))
		cam.limit_right = int(ceil(map_world_rect.end.x))
		cam.limit_bottom = int(ceil(map_world_rect.end.y))

func _place_entities_on_map() -> void:
	if Engine.is_editor_hint() or not align_colony_to_map:
		return

	var center_pos := map_world_rect.get_center()
	if is_wall_at(center_pos):
		center_pos = Vector2.ZERO

	var piles := get_tree().get_nodes_in_group("stockpile")
	for i in range(piles.size()):
		var pile := piles[i]
		if pile is Node2D and is_instance_valid(pile):
			var pos := clamp_world_pos_to_map(center_pos + Vector2(i * 48.0, 0.0), 32.0)
			if not is_wall_at(pos):
				pile.global_position = pos

	var hamsters := get_tree().get_nodes_in_group("hamsters")
	for i in range(hamsters.size()):
		var h := hamsters[i]
		if h is Node2D and is_instance_valid(h):
			if not is_world_pos_in_map(h.global_position, 24.0) or is_wall_at(h.global_position):
				var angle := TAU * float(i) / maxf(float(hamsters.size()), 1.0)
				h.global_position = clamp_world_pos_to_map(center_pos + Vector2(cos(angle), sin(angle)) * 36.0, 24.0)

	var mountain_node := get_node_or_null("Mountain")
	if mountain_node is Node2D and not (mountain_node is TileMapLayer) and is_instance_valid(mountain_node):
		if not is_world_pos_in_map(mountain_node.global_position, 16.0):
			mountain_node.global_position = clamp_world_pos_to_map(mountain_node.global_position, 24.0)

	for group_name in ["mountains", "mountain", "rocks", "rock"]:
		for node in get_tree().get_nodes_in_group(group_name):
			if node is Node2D and not (node is TileMapLayer) and is_instance_valid(node):
				if not is_world_pos_in_map(node.global_position, 16.0):
					node.global_position = clamp_world_pos_to_map(node.global_position, 24.0)

func GenerateTerrain() -> void:
	_ensure_noise()
	if randomize_seed_on_generate and not Engine.is_editor_hint():
		reroll_noise_seeds()

	if ground == null:
		ground = _find_layer_anywhere(["Ground", "ground"])
	if plants == null:
		plants = _find_layer_anywhere(["Plants", "plants"])
	if mountain_layer == null:
		mountain_layer = _find_layer_anywhere(["Mountain", "mountain", "Mountains", "mountains"])
	if ground == null or noise == null:
		return

	global_position = Vector2.ZERO
	ground.position = Vector2.ZERO
	if plants != null:
		plants.position = Vector2.ZERO
	if mountain_layer != null:
		mountain_layer.position = Vector2.ZERO

	_clear_spawned_props()
	ground.clear()
	if plants != null:
		plants.clear()
	if mountain_layer != null and mountain_layer.tile_set != null:
		mountain_layer.clear()
	_cell_noise.clear()

	map_world_rect = _compute_map_bounds()

	var rng := RandomNumberGenerator.new()
	rng.randomize()

	var half_w := int(width / 2)
	var half_h := int(height / 2)
	var start_x := -half_w
	var end_x := start_x + width
	var start_y := -half_h
	var end_y := start_y + height

	var grass_count := 0
	var food_count := 0
	var mountain_count := 0

	for gx in range(start_x, end_x):
		for gy in range(start_y, end_y):
			var cell := Vector2i(gx, gy)
			var raw_n: float = noise.get_noise_2d(float(gx), float(gy))
			var n: float = raw_n - _falloff_at(gx, gy)
			var m: float = moisture_noise.get_noise_2d(float(gx), float(gy)) if moisture_noise != null else 0.0
			var dist_from_center := Vector2(float(gx), float(gy)).length()

			if enable_rivers and river_noise != null and dist_from_center > center_clearing_radius:
				var r_val: float = absf(river_noise.get_noise_2d(float(gx), float(gy)))
				if r_val < river_width:
					var river_carve := (1.0 - (r_val / river_width)) * 0.45
					n -= river_carve

			if dist_from_center <= center_clearing_radius:
				n = clampf(maxf(n, grassThreshold + 0.05), sand_threshold + 0.05, mountain_threshold - 0.1)

			var micro_jitter := rng.randf_range(-1.0, 1.0) * (blend_jitter * (1.0 - blend_moisture_weight))
			var moisture_jitter := m * (blend_jitter * blend_moisture_weight)
			var blended_n: float = n + moisture_jitter + micro_jitter

			_cell_noise[cell] = blended_n
			var world_pos: Vector2 = ground.to_global(ground.map_to_local(cell))

			if not is_world_pos_in_map(world_pos, 0.0):
				continue

			var tile_coords: Vector2i
			var is_grass := false
			if blended_n < water_threshold - 0.1:
				tile_coords = deep_water_coords
			elif blended_n < water_threshold:
				tile_coords = water_coords
			elif blended_n < sand_threshold:
				tile_coords = sand_coords
			elif blended_n < grassThreshold:
				tile_coords = dirt_coords if m < -0.05 else light_grass_coords
				is_grass = m >= -0.05
			elif blended_n < forestThreshold:
				tile_coords = light_grass_coords if m < 0.05 else dark_grass_coords
				is_grass = true
			else:
				tile_coords = dark_grass_coords
				is_grass = true

			ground.set_cell(cell, 0, tile_coords, 0)

			var is_mountain := false
			if mountain_layer != null and mountain_layer.tile_set != null and blended_n >= mountain_threshold and dist_from_center > center_clearing_radius:
				mountain_layer.set_cell(cell, mountain_source_id, mountain_tile_coords, 0)
				is_mountain = true
				mountain_count += 1

			if is_grass and not is_mountain:
				grass_count += 1

				if grass_anim != null and rng.randi_range(0, 18) == 0:
					var grass := grass_anim.instantiate()
					grass.add_to_group("spawned_prop")
					add_child(grass)
					grass.global_position = clamp_world_pos_to_map(world_pos, 4.0)

				if custom_scene != null and rng.randi_range(0, 28) == 0:
					var instance := custom_scene.instantiate()
					instance.add_to_group("spawned_prop")
					add_child(instance)
					instance.global_position = clamp_world_pos_to_map(world_pos, 8.0)
					food_count += 1
					if not Engine.is_editor_hint():
						FoodManager.register_food(instance)
						var haul_job := Job.new("haul", 20, instance.global_position, instance)
						TaskManager.add_job(haul_job)

				if plants != null and m > 0.05 and rng.randi_range(0, 14) == 0:
					plants.set_cell(cell, 0, Vector2i(0, 0), 0)

	if not Engine.is_editor_hint():
		_place_entities_on_map()
		_apply_camera_limits()
		print("Map bounds: ", map_world_rect, " | grass: ", grass_count, " | mountains: ", mountain_count, " | food: ", food_count)

func get_speed_multiplier_at(world_pos: Vector2) -> float:
	if not is_world_pos_in_map(world_pos, 0.0):
		return 0.0

	if mountain_layer != null and mountain_layer.tile_set != null:
		var m_cell: Vector2i = mountain_layer.local_to_map(mountain_layer.to_local(world_pos))
		if mountain_layer.get_cell_source_id(m_cell) != -1:
			return mountain_speed_multiplier

	if ground == null:
		return default_ground_speed_multiplier

	var cell: Vector2i = ground.local_to_map(ground.to_local(world_pos))
	var atlas: Vector2i = ground.get_cell_atlas_coords(cell)

	if (atlas == water_coords or atlas == deep_water_coords) and water_is_wall:
		return 0.0

	var multiplier: float = default_ground_speed_multiplier
	if atlas == light_grass_coords:
		multiplier = light_grass_speed_multiplier
	elif atlas == dark_grass_coords:
		multiplier = dark_grass_speed_multiplier
	elif atlas == dirt_coords:
		multiplier = dirt_speed_multiplier
	elif atlas == sand_coords:
		multiplier = sand_speed_multiplier
	elif atlas == water_coords:
		multiplier = water_speed_multiplier
	elif atlas == deep_water_coords:
		multiplier = deep_water_speed_multiplier

	if plants != null and plants.get_cell_source_id(cell) != -1:
		multiplier *= plant_speed_multiplier

	var tile_data: TileData = ground.get_cell_tile_data(cell)
	if tile_data != null and tile_data.has_custom_data("speed_multiplier"):
		multiplier *= float(tile_data.get_custom_data("speed_multiplier"))

	return clampf(multiplier, 0.0, 2.0)
