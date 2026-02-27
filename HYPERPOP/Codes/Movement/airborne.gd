extends BoardState
class_name Airborne

# =================================================
# STATE
var air_time: float = 0.0
var is_charging_jump: bool = false

# =================================================
# CONFIG — JUMP & CHARGE
@export_category("Jump")
@export var min_jump_force: float = 12.0
@export var max_jump_force: float = 35.0
@export var jump_charge_drag: float = 0.3

# =================================================
# MAIN LOOP
func _physics_process(delta: float) -> void:
	if PlayerSFX:
		PlayerSFX._update_jump_charge(delta, is_charging_jump, is_wall_running)
	
	_update_jump_state()

# =================================================
# JUMP STATE
func _update_jump_state() -> void:
	var can_jump = is_on_floor()

	if is_charging_jump and inp_jump_just_released:
		_dbg_log("EVENT: Jump launched — charge: %.2f" % (PlayerSFX.current_jump_charge if PlayerSFX else 1.0))
		_execute_jump()
		is_charging_jump = false
		return

	if can_jump and inp_jump_held:
		is_charging_jump = true
	elif not inp_jump_held:
		is_charging_jump = false


# =================================================
# AIR CONTROLS (PITCH)
func _update_air_pitch(delta: float) -> void:
	var target_pitch: float = 0.0
	if !is_on_floor() && !is_wall_running:
		target_pitch = inp_pitch * deg_to_rad(air_pitch_max_angle)
	var lerp_speed: float = air_pitch_responsiveness if (!is_on_floor() && !is_wall_running) else air_pitch_return_speed
	current_air_pitch = lerp(current_air_pitch, target_pitch, lerp_speed * delta)


# =================================================
# JUMP
func _execute_jump() -> void:
	var charge_val: float = PlayerSFX.current_jump_charge if PlayerSFX else 1.0
	var force: float = lerp(min_jump_force, max_jump_force, charge_val)

	if is_wall_running && wall_normal != Vector3.ZERO:
		velocity += wall_normal * force * 1.4
		velocity.y += force * 0.5
		is_wall_running = false
		_on_wall_run_exit()
		_dbg_log("EVENT: Wall jump — force: %.1f, wall_normal: %s" % [force, wall_normal])
	else:
		velocity += Vector3.UP * force
		_dbg_log("EVENT: Standard jump — force: %.1f" % force)

	if PlayerSFX:
		PlayerSFX.play_jump_launch()
		PlayerSFX.current_jump_charge = 0.0

func _handle_landing(delta: float) -> void:
	if !is_on_floor():
		air_time += delta
		if air_time >= 20.0 and last_ground_position != Vector3.ZERO:
			_teleport_to_last_ground()
			_dbg_log("EVENT: Teleported to last ground pos (air_time >= 20s)")
		return
	if !was_on_floor && air_time > 0.15:
		_dbg_log("EVENT: Landed — air_time: %.2fs, speed: %.1f" % [air_time, current_speed])
		if PlayerSFX: PlayerSFX.play_land()
