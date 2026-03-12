extends BoardState
class_name Airborne

@onready var player: BoardController = get_parent().get_parent()


func enter_state() -> void:
	print_debug("Enter Airborne")

func exit_state() -> void:
	print_debug("Exit Airborne")

func physics_process(delta: float) -> void:
	# 1. Update State & Inputs
	player._read_input(delta)
	_update_loco_state()
	
	_update_speed(delta)
	
	_update_air_pitch(delta)
	player.move_and_slide()


# =================================================
# LOCOMOTION STATE RESOLVER
func _update_loco_state() -> void:
	if player.is_wall_running:
		loco_state_machine.change_state("Wall_Running")
	elif player.is_on_floor():
		if player.can_jump and player.inp_jump_held:
			loco_state_machine.change_state("Jump_Charging")
		elif player.drift_input and player.current_speed >= player.drift_min_speed:
			loco_state_machine.change_state("Drifting")
		else:
			loco_state_machine.change_state("Grounded")
	else:
		return


# =================================================
# SPEED
func _update_speed(delta: float) -> void:
	if !player.is_on_floor() && !player.is_wall_running:
		var dive_factor: float = sin(player.current_air_pitch)
		if dive_factor > 0:
			player.current_speed += player.dive_speed_gain * dive_factor * delta
		else:
			player.current_speed -= player.pull_up_speed_loss * abs(dive_factor) * delta
		player.current_speed = max(player.current_speed, 0.0)


# =================================================
# AIR CONTROLS (PITCH)
func _update_air_pitch(delta: float) -> void:
	var target_pitch: float = 0.0
	if !player.is_on_floor() && !player.is_wall_running:
		target_pitch = player.inp_pitch * deg_to_rad(player.air_pitch_max_angle)
	var lerp_speed: float = player.air_pitch_responsiveness if (!player.is_on_floor() && !player.is_wall_running) else player.air_pitch_return_speed
	player.current_air_pitch = lerp(player.current_air_pitch, target_pitch, lerp_speed * delta)
