extends BoardState
class_name WallRunning

@onready var player: BoardController = get_parent().get_parent()


func enter_state() -> void:
	print_debug("Enter Wall_Running")

func exit_state() -> void:
	print_debug("Exit Wall_Running")

func physics_process(delta: float) -> void:
	# 1. Update State & Inputs
	player._read_input(delta)
	_update_loco_state()
	
	_update_speed(delta)
	
	# Wall Run Detection
	_detect_wall_running()
	
	# 5. Post-move logic
	_maintain_wall_speed()
	_apply_ramp_boost_on_leave()
	player.move_and_slide()


# =================================================
# LOCOMOTION STATE RESOLVER
func _update_loco_state() -> void:
	if player.is_wall_running:
		return
	elif player.is_on_floor():
		if player.can_jump and player.inp_jump_held:
			loco_state_machine.change_state("Jump_Charging")
		elif player.drift_input and player.current_speed >= player.drift_min_speed:
			loco_state_machine.change_state("Drifting")
		else:
			loco_state_machine.change_state("Grounded")
	else:
		loco_state_machine.change_state("Airborne")


# =================================================
# SPEED
func _update_speed(delta: float) -> void:
	pass

# =================================================
# WALL RUNNING
func _detect_wall_running() -> void:
	if player.is_on_floor():
		player.is_wall_running = false
		return
	var found_wall: bool = false
	for i in player.get_slide_collision_count():
		var n: Vector3 = player.get_slide_collision(i).get_normal()
		if abs(n.dot(Vector3.UP)) < 0.3:
			player.wall_normal = n
			found_wall = true
			if not player.was_wall_running:
				player._dbg_log("EVENT: Wall run START — speed: %.1f, normal: %s" % [player.current_speed, player.wall_normal])
			player.is_wall_running = true
			break
	if !found_wall:
		player.is_wall_running = false

func _maintain_wall_speed() -> void:
	if !player.is_wall_running: return
	player.velocity = player.velocity.slide(player.wall_normal).normalized() * player.current_speed
	player.velocity -= player.wall_normal * player.stick_force * player.get_physics_process_delta_time()

func _apply_ramp_boost_on_leave() -> void:
	if player.was_on_floor && !player.is_on_floor():
		var angle_factor: float = 1.0 - player.get_floor_normal().dot(Vector3.UP)
		if angle_factor > 0.15:
			player.velocity += player.velocity.normalized() * player.slope_launch_boost * angle_factor
			player._dbg_log("EVENT: Ramp boost — angle_factor: %.2f" % angle_factor)
