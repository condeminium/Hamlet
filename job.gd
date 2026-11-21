class_name Job
extends RefCounted

var type: String = ""
var priority: int = 10
var target_node: Node2D = null
var target_pos: Vector2 = Vector2.ZERO
var claimed_by: Node = null

func _init(p_type: String, p_priority: int = 10, p_pos: Vector2 = Vector2.ZERO, p_node: Node2D = null) -> void:
	type = p_type
	priority = p_priority
	target_pos = p_pos
	target_node = p_node

func is_valid_job() -> bool:
	if target_node != null:
		return is_instance_valid(target_node) and not target_node.is_queued_for_deletion()
	return true
