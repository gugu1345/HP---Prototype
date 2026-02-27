extends Node3D
class_name Drifting



# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


# =================================================
# DRIFT & DASH
func _update_drift(delta: float) -> void:
	if !is_on_floor() || current_speed < drift_min_speed:
		is_drifting = false
		drift_charge = 0.0
		if PlayerSFX: PlayerSFX.stop_drift_loop()
		return

	is_drifting = inp_drift and abs(inp_steer) > 0.1
	if is_drifting:
		current_speed = move_toward(current_speed, 0.0, drift_deceleration_rate * delta)
		drift_charge = move_toward(drift_charge, 1.0, delta / drift_max_charge_time)
		if PlayerSFX: PlayerSFX.play_drift_loop()
	else:
		if PlayerSFX: PlayerSFX.stop_drift_loop()
		if drift_charge >= 1.0:
			dash_velocity = current_speed + drift_dash_force
			dash_timer = drift_dash_duration
			_dbg_log("EVENT: Drift DASH released — dash_velocity: %.1f" % dash_velocity)
			if PlayerSFX: PlayerSFX.play_dash()
			drift_charge = 0.0
