@tool
extends Node2D

@onready var custom_scene = load("res://thing.tscn")
@export var generateTerrain : bool
@export var clearTerrain : bool
@export var mapWidth : int
@export var mapHeight : int
@export var waterThreshold : float
@export var water2Threshold : float
@export var sandThreshold : float
@export var grassThreshold : float
@export var grass2Threshold : float
@export var dirtThreshold : float
@export var rockThreshold : float
@export var snowThreshold : float
@export var terrainSeed : int

@onready var ground: TileMapLayer = $Ground
@onready var mountain: TileMapLayer = $Mountain
@onready var plants: TileMapLayer = $Plants
@onready var grass_anim = load("res://grass.tscn")
@onready var rock = load("res://rock.tscn")

func _process(_delta: float) -> void:
	if generateTerrain:
		generateTerrain = false
		_clear_all()
		GenerateTerrain()

	if clearTerrain:
		clearTerrain = false
		_clear_all()

func _clear_all() -> void:
	ground.clear()
	mountain.clear()
	plants.clear()
	for child in get_children():
		if child.is_in_group("spawned_prop"):
			child.queue_free()

func GenerateTerrain() -> void:
	print("Generating Terrain....")
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_CELLULAR
	var rng := RandomNumberGenerator.new()

	if terrainSeed == 0:
		noise.seed = rng.randi()
	else:
		noise.seed = terrainSeed

	for x in range(mapWidth):
		for y in range(mapHeight):
			var n := noise.get_noise_2d(x, y)
			var cell := Vector2i(x, y)
			var world_pos: Vector2 = ground.map_to_local(cell)

			if n > waterThreshold:
				ground.set_cell(cell, 0, Vector2i(2, 1), 0)
			elif n > water2Threshold:
				ground.set_cell(cell, 0, Vector2i(1, 1), 0)
			elif n > sandThreshold:
				ground.set_cell(cell, 0, Vector2i(0, 2), 0)
			elif n > grassThreshold:
				ground.set_cell(cell, 0, Vector2i(0, 0), 0)
				if rng.randi_range(0, 20) == 0:
					var grass = grass_anim.instantiate()
					grass.add_to_group("spawned_prop")
					add_child(grass)
					grass.position = world_pos
				if rng.randi_range(0, 20) == 0:
					var instance = custom_scene.instantiate()
					instance.add_to_group("spawned_prop")
					add_child(instance)
					instance.position = world_pos
					if not Engine.is_editor_hint():
						FoodManager.register_food(instance)
				if rng.randi_range(0, 20) == 0:
					plants.set_cell(cell, 0, Vector2i(0, 0), 0)
			elif n > grass2Threshold:
				ground.set_cell(cell, 0, Vector2i(1, 0), 0)
				if rng.randi_range(0, 1) == 0:
					var grass = grass_anim.instantiate()
					grass.add_to_group("spawned_prop")
					add_child(grass)
					grass.position = world_pos
				if rng.randi_range(0, 20) == 0:
					plants.set_cell(cell, 0, Vector2i(1, 0), 0)
			elif n > dirtThreshold:
				ground.set_cell(cell, 0, Vector2i(2, 0), 0)
			elif n > rockThreshold:
				if rng.randi_range(0, 10) == 0:
					var boulder = rock.instantiate()
					boulder.add_to_group("spawned_prop")
					add_child(boulder)
					boulder.position = world_pos
				ground.set_cell(cell, 0, Vector2i(3, 0), 0)
				mountain.set_cell(cell, 0, Vector2i(3, 1), 0)
			elif n > snowThreshold:
				ground.set_cell(cell, 0, Vector2i(0, 1), 0)
			else:
				ground.set_cell(cell, 0, Vector2i(3, 3), 0)

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_clear_all()
	GenerateTerrain()
