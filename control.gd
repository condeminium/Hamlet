extends Control

# Onready reference to the Hamster node located in the parent node's hierarchy
@onready var hamster: CharacterBody2D = $"../Hamster"


# Called when the node enters the scene tree for the first time
func _ready() -> void:
	pass # Replace with function body.


# Called every frame; updates the HUD label with the hamster's current hunger level
func _process(delta: float) -> void:
	var value = str(hamster.hunger)
	$Label.text = "Hunger Level : " + value
	pass
