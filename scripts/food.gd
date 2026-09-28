extends Area2D


# Called when the node enters the scene tree for the first time
func _ready() -> void:
	pass # Replace with function body.


# Called every frame; unused in this script
func _process(delta: float) -> void:
	pass


# Triggered when another physics body enters this Area2D collision zone
func _on_body_entered(body: CharacterBody2D) -> void:
	# Trigger the hamster's eating method to restore hunger
	body.eating_food()
	
	# Destroy this food item after it has been consumed
	queue_free()
	pass # Replace with function body.
