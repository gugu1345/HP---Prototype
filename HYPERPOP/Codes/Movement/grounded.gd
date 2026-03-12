## Grounded State
extends BoardState
class_name Grounded

@onready var player: BoardController = get_parent().get_parent()


func enter_state() -> void:
	print_debug("Enter Grounded")

func exit_state() -> void:
	print_debug("Exit Grounded")

func physics_process(delta: float) -> void:
	# 1. Update State & Inputs
	player._read_input(delta)
	_update_loco_state()
	
	_update_speed(delta)
	
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
			return
	else:
		loco_state_machine.change_state("Airborne")


# =================================================
# SPEED
func _update_speed(delta: float) -> void:
	if player.inp_throttle > 0:
		player.current_speed = move_toward(player.current_speed, player.max_speed, player.acceleration * delta)
	elif player.inp_brake > 0:
		player.current_speed = move_toward(player.current_speed, 0.0, player.braking * delta)
	else:
		var drag: float = player.friction if player.is_on_floor() else player.air_drag
		player.current_speed = move_toward(player.current_speed, 0.0, drag * delta)
