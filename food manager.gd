extends Node

var available_food: Array[Node2D] = []

func register_food(food: Node2D) -> void:
	if is_instance_valid(food) and not available_food.has(food):
		available_food.append(food)

func unregister_food(food: Node2D) -> void:
	available_food.erase(food)

func find_and_claim_nearest(searcher: Node, searcher_pos: Vector2) -> Node2D:
	var nearest: Node2D = null
	var min_dist_sq: float = INF

	for i in range(available_food.size() - 1, -1, -1):
		var food := available_food[i]
		if not is_instance_valid(food) or food.is_queued_for_deletion():
			available_food.remove_at(i)
			continue

		var claimed_by = food.get("claimed_by")
		if claimed_by != null and claimed_by != searcher and is_instance_valid(claimed_by):
			continue

		var dist_sq := searcher_pos.distance_squared_to(food.global_position)
		if dist_sq < min_dist_sq:
			min_dist_sq = dist_sq
			nearest = food

	if nearest != null:
		nearest.set("claimed_by", searcher)

	return nearest

func release_claim(food: Node2D, searcher: Node) -> void:
	if is_instance_valid(food) and food.get("claimed_by") == searcher:
		food.set("claimed_by", null)
