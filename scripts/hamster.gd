extends CharacterBody2D


const SPEED = 300.0
@export var target: Node2D = null
@onready var navigation_agent_2d: NavigationAgent2D = $NavigationAgent2D

func _ready() -> void:
	call_deferred("hamster_setup")

func hamster_setup():
	await get_tree().physics_frame
	if target:
		navigation_agent_2d.target_position = target.global_position
func acquire_target():
	var food_container = get_tree().get_nodes_in_group("Food")[0]
	var available_food = food_container.get_children()
	
	if !available_food.is_empty():
		var new_target = available_food[0]
		target = new_target

func _physics_process(delta: float) -> void:
	if target:
		navigation_agent_2d.target_position = target.global_position
	else:
		acquire_target()
	if navigation_agent_2d.is_navigation_finished():
		return
	var current_agent_position = global_position
	var next_path_position = navigation_agent_2d.get_next_path_position()
	velocity = current_agent_position.direction_to(next_path_position) * SPEED
	move_and_slide()

	
