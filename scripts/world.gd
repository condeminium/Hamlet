extends Node2D

# Preloaded scene resources for spawning Food and Hamster entities
const FOOD = preload("res://food.tscn")
const HAM = preload("res://hamster.tscn")


# Called when the node enters the scene tree for the first time
func _ready() -> void:
	pass # Replace with function body.


# Called every frame to handle user input for spawning entities and quitting
func _process(delta: float) -> void:
	var clicker = get_local_mouse_position()
	
	# Quit the game when the "exit" action is triggered
	if Input.is_action_just_pressed("exit"):
		get_tree().quit()
		
	# Spawn a food item at mouse position on left-click and add it to the Food group container
	if Input.is_action_just_pressed("click"):
		var instance = FOOD.instantiate()
		instance.global_position = clicker
		var foodCollection = get_tree().get_nodes_in_group("Food")[0]
		foodCollection.add_child(instance)
		
	# Spawn a hamster entity at mouse position on right-click and add it to the parent node
	if Input.is_action_just_pressed("right_click"):
		var instance = HAM.instantiate()
		instance.global_position = clicker
		get_parent().add_child(instance)
