extends Node3D
class_name WallRunning


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


# =================================================
# WALL RUNNING
func _detect_wall_running() -> void:
	if is_on_floor():
		is_wall_running = false
		return
	var found_wall: bool = false
	for i in get_slide_collision_count():
		var n: Vector3 = get_slide_collision(i).get_normal()
		if abs(n.dot(Vector3.UP)) < 0.3:
			wall_normal = n
			found_wall = true
			if not was_wall_running:
				_dbg_log("EVENT: Wall run START — speed: %.1f, normal: %s" % [current_speed, wall_normal])
			is_wall_running = true
			break
	if !found_wall:
		is_wall_running = false

func _maintain_wall_speed() -> void:
	if !is_wall_running: return
	velocity = velocity.slide(wall_normal).normalized() * current_speed
	velocity -= wall_normal * stick_force * get_physics_process_delta_time()

func _apply_ramp_boost_on_leave() -> void:
	if was_on_floor && !is_on_floor():
		var angle_factor: float = 1.0 - get_floor_normal().dot(Vector3.UP)
		if angle_factor > 0.15:
			velocity += velocity.normalized() * slope_launch_boost * angle_factor
			_dbg_log("EVENT: Ramp boost — angle_factor: %.2f" % angle_factor)
