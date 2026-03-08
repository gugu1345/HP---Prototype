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
	
	_update_speed(delta)
	player.move_and_slide()


# =================================================
# LOCOMOTION STATE RESOLVER
func _update_loco_state() -> void:
	if player.is_wall_running:
		loco_state_machine.change_state("Wall_Running")
	elif player.is_on_floor():
		if player.is_charging_jump:
			return
		elif player.is_drifting:
			loco_state_machine.change_state("Drifting")
		else:
			loco_state_machine.change_state("Grounded")
	else:
		loco_state_machine.change_state("Airborne")


# =================================================
# SPEED
func _update_speed(delta: float) -> void:
	player.current_speed = lerp(player.current_speed, 0.0, player.jump_charge_drag * delta)
