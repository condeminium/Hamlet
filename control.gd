extends Control
@onready var hamster: CharacterBody2D = $"../Hamster"
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	var value = str(hamster.hunger)
	$Label.text = "Hunger Level : " + value
	pass
