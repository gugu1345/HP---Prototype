extends BoardState
class_name Drifting

@onready var player: BoardController = get_parent().get_parent()

# =================================================
# STATE VIRTUALS
func enter_state() -> void:
	print_debug("Enter Drifting")
	player.is_drifting = true
	if player.PlayerSFX: 
		player.PlayerSFX.play_drift_loop()

func exit_state() -> void:
	print_debug("Exit Drifting")
	player.is_drifting = false
	player.drift_charge = 0.0
	if player.PlayerSFX:
		player.PlayerSFX.stop_drift_loop()

func physics_process(delta: float) -> void:
	# 1. Update State & Inputs
	player._read_input(delta)
	
	_update_loco_state()
	
	# 2. Drift Logic & Dash Execution
	_update_drift(delta)
	
	# 3. Final Movement
	_update_speed(delta)
	player.move_and_slide()


# =================================================
# LOCOMOTION STATE RESOLVER
func _update_loco_state() -> void:
	if !player.is_on_floor():
		loco_state_machine.change_state("Airborne")
		return
		
	if player.current_speed < player.drift_min_speed:
		loco_state_machine.change_state("Grounded")
		return

	if not player.drift_input:
		_handle_drift_dash()
		loco_state_machine.change_state("Grounded")

# =================================================
# SPEED
func _update_speed(delta: float) -> void:
	pass


# =================================================
# DRIFT & DASH
func _update_drift(delta: float) -> void:
	player.current_speed = move_toward(player.current_speed, 0.0, player.drift_deceleration_rate * delta)
	player.drift_charge = move_toward(player.drift_charge, 1.0, delta / player.drift_max_charge_time)


func _handle_drift_dash() -> void:
	if player.drift_charge >= 1.0:
		player.dash_velocity = player.current_speed + player.drift_dash_force
		player.dash_timer = player.drift_dash_duration
		
		player._dbg_log("EVENT: Drift DASH released — dash_velocity: %.1f" % player.dash_velocity)
		
		if player.PlayerSFX: 
			player.PlayerSFX.play_dash()
