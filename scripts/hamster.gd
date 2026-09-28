extends CharacterBody2D

# Movement speed in pixels per second
const SPEED = 300.0

# Exported target node reference (assignable via the Godot Inspector)
@export var target: Node2D = null

# Onready reference to the child NavigationAgent2D node
@onready var navigation_agent_2d: NavigationAgent2D = $NavigationAgent2D

# Prepare need levels of hamsters
var hunger = 100
var sleep = 100
var mood = 100
var recreation = 100

# Rate at which needs decrease
var hunger_rate = 1
var sleep_rate = 1



func _ready() -> void:
	# Defer navigation setup until the physics server is fully synced
	call_deferred("hamster_setup")


func hamster_setup() -> void:
	# Wait one physics frame to ensure the navigation map is fully loaded
	await get_tree().physics_frame
	if target:
		# Set the initial destination position for navigation
		navigation_agent_2d.target_position = target.global_position


func acquire_target() -> void:
	#TODO generalise target acquisition to whatever is desired
	# Retrieve the first node assigned to the "Food" group (e.g., a food container node)
	var food_container = get_tree().get_nodes_in_group("Food")[0]
	var available_food = food_container.get_children()
	
	# Select the first available piece of food as the new target
	if !available_food.is_empty():
		var new_target = available_food[0]
		target = new_target


func _physics_process(delta: float) -> void:
	think()
	# Update target destination if a target exists, otherwise find a new target
	if target:
		navigation_agent_2d.target_position = target.global_position
	else:
		acquire_target()
	
	# Stop movement processing if the destination has been reached
	if navigation_agent_2d.is_navigation_finished():
		return
		
	# Calculate movement direction toward the next path waypoint
	var current_agent_position = global_position
	var next_path_position = navigation_agent_2d.get_next_path_position()
	var new_velocity = current_agent_position.direction_to(next_path_position) * SPEED
	
	# Move the character using the current velocity
	move_and_slide()
	
	# Handle navigation avoidance if enabled, otherwise directly apply velocity
	if navigation_agent_2d.avoidance_enabled:
		navigation_agent_2d.set_velocity(new_velocity)
	else:
		_on_navigation_agent_2d_velocity_computed(new_velocity)		


func _on_navigation_agent_2d_velocity_computed(safe_velocity: Vector2) -> void:
	# Callback to apply the safe calculated velocity (used during navigation/avoidance)
	velocity = safe_velocity


func eating_food() -> void:
	# Replenish hunger when consuming food
	print("IM EATING FOOD")
	hunger += 50


func _on_timer_timeout() -> void:
	# Periodically reduce hunger over time
	hunger -= hunger_rate

func think() -> void:
	print("I am thinking")
	print("My hunger is ", hunger)
	print("My sleepiness is ", sleep)
	print("My mood is ", mood)
