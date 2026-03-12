extends BoardState
class_name JumpCharging

@onready var player: BoardController = get_parent().get_parent()


func enter_state() -> void:
	print_debug("Enter Jump_Charging")

func exit_state() -> void:
	print_debug("Exit Jump_Charging")

func physics_process(delta: float) -> void:
	# 1. Update State & Inputs
	player._read_input(delta)
	_update_loco_state()
	
	_update_jump_charge(delta)
	
	_update_speed(delta)
	player.move_and_slide()


# =================================================
# LOCOMOTION STATE RESOLVER
func _update_loco_state() -> void:
	if player.is_wall_running:
		loco_state_machine.change_state("Wall_Running")
	elif player.is_on_floor():
		if player.can_jump and player.inp_jump_held:
			return
		elif player.drift_input and player.current_speed >= player.drift_min_speed:
			loco_state_machine.change_state("Drifting")
		else:
			loco_state_machine.change_state("Grounded")
	else:
		loco_state_machine.change_state("Airborne")


# =================================================
# SPEED
func _update_speed(delta: float) -> void:
	player.current_speed = lerp(player.current_speed, 0.0, player.jump_charge_drag * delta)


# JUMP STATE
func _update_jump_charge(delta: float) -> void:
	if player.can_jump and player.inp_jump_held:
		player.is_charging_jump = true
		player.current_jump_charge = move_toward(player.current_jump_charge, 1.0, delta / player.max_charge_time)
	if player.is_charging_jump and not player.inp_jump_held:
		player._dbg_log("EVENT: Jump launched — charge: %.2f" % (player.PlayerSFX.current_jump_charge if player.PlayerSFX else 1.0))
		player._execute_jump()
		player.is_charging_jump = false
		player.current_jump_charge = 0.0
