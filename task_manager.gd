extends Node

var jobs: Array[Job] = []

func add_job(job: Job) -> void:
	if job != null and not jobs.has(job):
		jobs.append(job)

func has_job_for_node(node: Node2D) -> bool:
	if node == null or not is_instance_valid(node):
		return false
	for job in jobs:
		if is_instance_valid(job.target_node) and job.target_node == node:
			return true
	return false

func remove_jobs_for_node(node: Node2D, releaser: Node = null) -> void:
	for i in range(jobs.size() - 1, -1, -1):
		var job := jobs[i]
		if job.target_node == node:
			if releaser != null and job.claimed_by == releaser and node != null:
				FoodManager.release_claim(node, releaser)
			jobs.remove_at(i)

func request_job(worker: Node, worker_pos: Vector2, min_priority_allowed: int = 999) -> Job:
	var best_job: Job = null
	var best_score: float = INF

	for i in range(jobs.size() - 1, -1, -1):
		var job := jobs[i]
		if not job.is_valid_job():
			jobs.remove_at(i)
			continue

		if job.claimed_by != null and job.claimed_by != worker and is_instance_valid(job.claimed_by):
			continue

		if job.priority > min_priority_allowed:
			continue

		var pos := job.target_node.global_position if is_instance_valid(job.target_node) else job.target_pos
		var dist_sq := worker_pos.distance_squared_to(pos)
		var score := float(job.priority) * 1000000.0 + dist_sq

		if score < best_score:
			best_score = score
			best_job = job

	if best_job != null:
		best_job.claimed_by = worker
		if best_job.type == "forage" and is_instance_valid(best_job.target_node):
			best_job.target_node.set("claimed_by", worker)

	return best_job

func release_job(job: Job, worker: Node) -> void:
	if job == null:
		return
	if job.claimed_by == worker:
		job.claimed_by = null
		if job.type == "forage" and is_instance_valid(job.target_node):
			FoodManager.release_claim(job.target_node, worker)

func complete_job(job: Job, worker: Node) -> void:
	if job == null:
		return
	if job.claimed_by == worker:
		job.claimed_by = null
		if job.type == "forage" and is_instance_valid(job.target_node):
			FoodManager.release_claim(job.target_node, worker)
	jobs.erase(job)
