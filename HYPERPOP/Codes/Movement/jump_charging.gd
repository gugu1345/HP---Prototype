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
	_update_jump_state()
	player.move_and_slide()


# =================================================
# LOCOMOTION STATE RESOLVER
func _update_loco_state() -> void:
	if player.is_wall_running:
		loco_state_machine.change_state("Wall_Running")
	elif player.is_on_floor():
		if player.is_charging_jump:
			loco_state_machine.change_state("Jump_Charging")
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

# =================================================
# JUMP STATE
func _update_jump_state() -> void:
	var can_jump = player.is_on_floor()

	if player.is_charging_jump and player.inp_jump_just_released:
		player._dbg_log("EVENT: Jump launched — charge: %.2f" % (player.PlayerSFX.current_jump_charge if player.PlayerSFX else 1.0))
		_execute_jump()
		player.is_charging_jump = false
		return

	if player.can_jump and player.inp_jump_held:
		player.is_charging_jump = true
	elif not player.inp_jump_held:
		player.is_charging_jump = false

# =================================================
# JUMP
func _execute_jump() -> void:
	var charge_val: float = player.PlayerSFX.current_jump_charge if player.PlayerSFX else 1.0
	var force: float = lerp(player.min_jump_force, player.max_jump_force, charge_val)

	if player.is_wall_running && player.wall_normal != Vector3.ZERO:
		player.velocity += player.wall_normal * force * 1.4
		player.velocity.y += force * 0.5
		player.is_wall_running = false
		player._on_wall_run_exit()
		player._dbg_log("EVENT: Wall jump — force: %.1f, wall_normal: %s" % [force, player.wall_normal])
	else:
		player.velocity += player.Vector3.UP * force
		player._dbg_log("EVENT: Standard jump — force: %.1f" % force)

	if player.PlayerSFX:
		player.PlayerSFX.play_jump_launch()
		player.PlayerSFX.current_jump_charge = 0.0
