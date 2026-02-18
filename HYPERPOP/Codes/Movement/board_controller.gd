extends CharacterBody3D
class_name BoardController

# =================================================
# LOCOMOTION STATE ENUM
enum LocomotionState {
	GROUNDED,       # on floor, normal movement
	DRIFTING,       # on floor, drifting
	JUMP_CHARGING,  # on floor, charging a jump
	AIRBORNE,       # in the air
	WALL_RUNNING,   # running along a wall
	WALL_ATTACHED   # too slow to wall-run; sliding down
}
var loco_state: LocomotionState = LocomotionState.GROUNDED

# =================================================
# CONFIG — MOTION
@export_category("Motion")
@export var max_speed: float = 105.0
@export var acceleration: float = 15.0
@export var braking: float = 50.0
@export var friction: float = 15.0
@export var air_drag: float = 35
@export var rotation_speed: float = 1.5
@export var rotation_smoothing: float = 12.0
@export var max_velocity: float = 150.0

# =================================================
# CONFIG — JUMP & CHARGE
@export_category("Jump")
@export var min_jump_force: float = 12.0
@export var max_jump_force: float = 35.0
@export var jump_charge_drag: float = 0.3

# =================================================
# CONFIG — PHYSICS
@export_category("Physics")
@export var gravity_mul: float = 5
@export var stick_force: float = 120.0
@export var slope_alignment_speed: float = 22.0
@export var snap_length: float = 0.8

# =================================================
# CONFIG — SLOPE PHYSICS
@export_category("Slope Physics")
@export var slope_accel_strength: float = 22.0
@export var air_alignment_speed: float = 5.0

# =================================================
# CONFIG — WALL RUNNING
@export_category("Wall Running")
@export var wall_run_min_speed: float = 25.0
@export var wall_stick_force: float = 180.0
@export var wall_gravity_mul: float = 0.35
var is_wall_attached: bool = false
@export var wall_attach_slide_speed: float = 8.0
@export var wall_attach_gravity_mul: float = 0.15

# =================================================
# CONFIG — AIR CONTROLS
@export_category("Air Controls")
@export var air_rotation_multiplier: float = 2.5
@export var air_rotation_delay: float = 0.15
@export var air_pitch_max_angle: float = 50.0
@export var air_pitch_responsiveness: float = 10.0
@export var air_pitch_return_speed: float = 4.0
@export var dive_speed_gain: float = 55.0
@export var pull_up_speed_loss: float = 30.0
@export var air_lateral_force: float = 18.0
@export var air_stability_leveling: float = 3.5

# =================================================
# CONFIG — VISUALS & LEAN
@export_category("Visuals")
@export var board_mesh: Node3D
@export var board_target: Node3D
@export var Rider_Model: Node3D
@export var visual_spring_strength: float = 350.0
@export var visual_spring_damping: float = 30.0
@export_group("Lean Settings")
@export var max_lean_angle: float = 0.6
@export var drift_lean_multiplier: float = 1.5
@export var lean_responsiveness: float = 8.0
@export_group("Animation")
@export var crouch_tilt_amount: float = -0.12

# =================================================
# CONFIG — DRIFT
@export_category("Drift")
@export var drift_min_speed: float = 10.0
@export var drift_turn_multiplier: float = 2.0
@export var drift_max_charge_time: float = 1.2
@export var drift_dash_force: float = 50.0
@export var drift_dash_duration: float = 0.2
@export var drift_deceleration_rate: float = 8.0

# =================================================
# SYSTEMS
@export_category("Systems")
@export var Cam: CameraController
@export var PlayerSFX: PlaySoundsFX

# =================================================
# DEBUG
@export_category("Debug")
@export var debug_enabled: bool = true
@export var debug_console_log: bool = false          # prints key events to Output
var _debug_console_throttle: float = 0.0             # limits console spam to once per second

# =================================================
# STATE
var current_speed: float = 0.0
var smoothed_input_x: float = 0.0
var was_on_floor: bool = true
var last_surface_normal: Vector3 = Vector3.UP
var air_time: float = 0.0
var air_spin_timer: float = 0.0
var is_charging_jump: bool = false
var current_tilt: float = 0.0
var is_drifting: bool = false
var drift_charge: float = 0.0
var dash_timer: float = 0.0
var dash_velocity: float = 0.0
var is_wall_running: bool = false
var was_wall_running: bool = false
var wall_normal: Vector3 = Vector3.ZERO
var current_air_pitch: float = 0.0
var last_ground_position: Vector3 = Vector3.ZERO
var grounded_time: float = 0.0
var moveDir: Vector3

# =================================================
# CENTRALISED INPUT STATE — populated once per frame in _read_input()
var inp_throttle: float = 0.0
var inp_brake: float = 0.0
var inp_steer: float = 0.0
var inp_drift: bool = false
var inp_jump_held: bool = false
var inp_jump_just_released: bool = false
var inp_pitch: float = 0.0

# =================================================
# READY
func _ready() -> void:
	floor_max_angle = deg_to_rad(130)
	floor_snap_length = snap_length
	floor_stop_on_slope = false
	floor_block_on_wall = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	if debug_enabled:
		# Auto-create a label if none was assigned in the Inspector
		var canvas := CanvasLayer.new()
		canvas.name = "DebugCanvas"
		add_child(canvas)
		var label := RichTextLabel.new()
		label.name = "DebugLabel"
		label.bbcode_enabled = true
		label.set_anchors_preset(Control.PRESET_TOP_LEFT)
		label.position = Vector2(10, 10)
		label.size = Vector2(420, 320)
		# Semi-transparent background via modulate — style as needed
		label.add_theme_color_override("default_color", Color(0.9, 1.0, 0.9))
		label.add_theme_font_size_override("normal_font_size", 14)
		_dbg_log("DEBUG: auto-created on-screen label")

# =================================================
# MAIN LOOP
func _physics_process(delta: float) -> void:
	# 1. Update State & Inputs
	_read_input(delta)
	if PlayerSFX:
		PlayerSFX._update_jump_charge(delta, is_charging_jump, is_wall_running)

	_update_drift(delta)
	_update_speed(delta)
	_update_jump_state()
	_update_air_pitch(delta)

	# Resolve locomotion state before physics branching
	_update_loco_state()

	# 2. Physics & Momentum
	_apply_slope_momentum(delta)
	_apply_surface_gravity(delta)
	_apply_rotation(delta)
	moveDir *= current_speed
	_apply_horizontal_movement(delta)

	_detect_wall_running()
	_update_loco_state()  # re-resolve after wall detection

	if was_wall_running and not is_wall_running and not is_wall_attached:
		_on_wall_run_exit()
		_dbg_log("EVENT: Wall run EXIT — speed: %.1f" % current_speed)

	# 3. Per-state surface handling
	match loco_state:
		LocomotionState.WALL_RUNNING:
			_align_Board(delta, wall_normal, true)
			_apply_floor_stick(delta)

		LocomotionState.WALL_ATTACHED:
			_align_Board(delta)
			velocity.x = move_toward(velocity.x, 0.0, 20.0 * delta)
			velocity.z = move_toward(velocity.z, 0.0, 20.0 * delta)
			velocity.y = move_toward(velocity.y, -wall_attach_slide_speed, 10.0 * delta)
			ChangeVelocity(-wall_normal, wall_stick_force * delta)

		LocomotionState.GROUNDED, LocomotionState.DRIFTING, LocomotionState.JUMP_CHARGING:
			_align_Board(delta,Vector3.UP, true)
			last_surface_normal = Vector3.UP
			air_time = 0.0
			if grounded_time >= 3.5:
				last_ground_position = global_position
				grounded_time = 0.0
			else:
				grounded_time += delta
			_apply_floor_stick(delta)

		LocomotionState.AIRBORNE:
			_align_Board(delta)
			grounded_time = 0.0
			air_time += delta
			if air_time >= 20.0 and last_ground_position != Vector3.ZERO:
				_teleport_to_last_ground()
				_dbg_log("EVENT: Teleported to last ground pos (air_time >= 20s)")


	apply_floor_snap()
	move_and_slide()

	if Cam:
		Cam._update_camera_logic(delta, loco_state == LocomotionState.DRIFTING)

	# 5. Post-move logic
	_maintain_wall_speed()
	_apply_ramp_boost_on_leave()
	_handle_landing(delta)
	_update_board_visual(delta)

	if PlayerSFX:
		PlayerSFX._update_engine_audio(current_speed, max_speed)

	was_on_floor = is_on_floor()
	was_wall_running = is_wall_running

	# Update debug display every frame (label) and throttled console
	if debug_enabled:
		_update_debug(delta)

# =================================================
# LOCOMOTION STATE RESOLVER
func _update_loco_state() -> void:
	if is_wall_running:
		loco_state = LocomotionState.WALL_RUNNING
	elif is_wall_attached:
		loco_state = LocomotionState.WALL_ATTACHED
	elif is_on_floor():
		if is_charging_jump:
			loco_state = LocomotionState.JUMP_CHARGING
		elif is_drifting:
			loco_state = LocomotionState.DRIFTING
		else:
			loco_state = LocomotionState.GROUNDED
	else:
		loco_state = LocomotionState.AIRBORNE

# =================================================
# INPUT — single source of truth, pure reads only
func _read_input(delta: float) -> void:
	inp_throttle           = Input.get_action_strength("throttle")
	inp_brake              = Input.get_action_strength("brake")
	inp_steer              = Input.get_action_strength("left") - Input.get_action_strength("right")
	inp_drift              = Input.is_action_pressed("drift")
	inp_jump_held          = Input.is_action_pressed("Jump")
	inp_jump_just_released = Input.is_action_just_released("Jump")
	inp_pitch              = inp_throttle - inp_brake

	smoothed_input_x = lerp(smoothed_input_x, inp_steer, rotation_smoothing * delta)
	moveDir = -global_transform.basis.z

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
# AIR CONTROLS
func _update_air_pitch(delta: float) -> void:
	if !is_on_floor() && !is_on_wall():
		var target_pitch: float = inp_pitch * deg_to_rad(air_pitch_max_angle)
		current_air_pitch = lerp(current_air_pitch, target_pitch, air_pitch_responsiveness * delta)
	else:
		current_air_pitch = lerp(current_air_pitch, 0.0, air_pitch_return_speed * delta)

# =================================================
# JUMP
func _execute_jump() -> void:
	var charge_val: float = PlayerSFX.current_jump_charge if PlayerSFX else 1.0
	var force: float = lerp(min_jump_force, max_jump_force, charge_val)

	floor_snap_length = 0.0
	air_spin_timer = 0.0

	if is_wall_running && wall_normal != Vector3.ZERO:
		ChangeVelocity(wall_normal, force * 1.4)
		ChangeVelocity(Vector3.UP, force * 0.5)
		is_wall_running = false
		_on_wall_run_exit()
		_dbg_log("EVENT: Wall jump — force: %.1f, wall_normal: %s" % [force, wall_normal])
	else:
		ChangeVelocity(global_transform.basis.y, force)
		_dbg_log("EVENT: Standard jump — force: %.1f" % force)

	if PlayerSFX:
		PlayerSFX.play_jump_launch()
		PlayerSFX.current_jump_charge = 0.0

func _handle_landing(delta: float) -> void:
	if !is_on_floor(): return
	if !was_on_floor && air_time > 0.15:
		_dbg_log("EVENT: Landed — air_time: %.2fs, speed: %.1f" % [air_time, current_speed])
		if PlayerSFX: PlayerSFX.play_land()

# =================================================
# DRIFT & DASH
func _update_drift(delta: float) -> void:
	if !is_on_floor() || current_speed < drift_min_speed:
		is_drifting = false
		drift_charge = 0.0
		if PlayerSFX: PlayerSFX.stop_drift_loop()
		return

	var drift_input = inp_drift and abs(inp_steer) > 0.1

	if is_drifting and not drift_input:
		if drift_charge >= 1.0:
			dash_velocity = current_speed + drift_dash_force
			dash_timer = drift_dash_duration
			_dbg_log("EVENT: Drift DASH released — dash_velocity: %.1f" % dash_velocity)
			if PlayerSFX: PlayerSFX.play_dash()
		drift_charge = 0.0
		if PlayerSFX: PlayerSFX.stop_drift_loop()

	is_drifting = drift_input

	if is_drifting:
		current_speed = move_toward(current_speed, 0.0, drift_deceleration_rate * delta)
		drift_charge = move_toward(drift_charge, 1.0, delta / drift_max_charge_time)
		if PlayerSFX: PlayerSFX.play_drift_loop()

# =================================================
# SPEED & SPEED CAP
func _update_speed(delta: float) -> void:
	if dash_timer > 0.0:
		dash_timer -= delta
		current_speed = dash_velocity
		return

	match loco_state:
		LocomotionState.JUMP_CHARGING:
			current_speed = lerp(current_speed, 0.0, jump_charge_drag * delta)

		LocomotionState.GROUNDED:
			if inp_throttle > 0:
				current_speed = move_toward(current_speed, max_speed, acceleration * delta)
			elif inp_brake > 0:
				current_speed = move_toward(current_speed, 0.0, braking * delta)
			else:
				current_speed = move_toward(current_speed, 0.0, friction * delta)

		LocomotionState.DRIFTING:
			pass  # deceleration handled inside _update_drift

		LocomotionState.AIRBORNE, LocomotionState.WALL_RUNNING, LocomotionState.WALL_ATTACHED:
			current_speed = move_toward(current_speed, 0.0, air_drag * delta)
			var dive_factor: float = sin(current_air_pitch)
			if dive_factor > 0:
				current_speed += dive_speed_gain * dive_factor * delta
			else:
				current_speed -= pull_up_speed_loss * abs(dive_factor) * delta

	current_speed = clamp(current_speed, 0.0, max_velocity)

# =================================================
# PHYSICS & ROTATION
func _apply_rotation(delta: float) -> void:
	var turn_scale: float = 1.0

	match loco_state:
		LocomotionState.JUMP_CHARGING:
			turn_scale = 0.5
		LocomotionState.DRIFTING:
			turn_scale = drift_turn_multiplier
		LocomotionState.AIRBORNE:
			turn_scale = 0.1 if air_spin_timer < air_rotation_delay else air_rotation_multiplier
		_:
			turn_scale = 1.0

	rotate_object_local(Vector3.UP, smoothed_input_x * rotation_speed * turn_scale * delta)

func _apply_horizontal_movement(delta: float) -> void:
	if loco_state == LocomotionState.WALL_RUNNING: return
	velocity.x = move_toward(velocity.x, moveDir.x, 30.0 * delta)
	velocity.z = move_toward(velocity.z, moveDir.z, 30.0 * delta)

func _apply_slope_momentum(delta: float) -> void:
	if !is_on_floor(): return
	var normal: Vector3 = get_floor_normal()
	var slope: float = 1.0 - normal.dot(Vector3.UP)
	if slope < 0.02: return
	var downhill: Vector3 = Vector3.DOWN.slide(normal).normalized()
	var alignment: float = downhill.dot(-board_mesh.global_transform.basis.z)
	current_speed += alignment * slope_accel_strength * slope * delta
	current_speed = clamp(current_speed, 0.0, max_velocity)

func _apply_surface_gravity(delta: float) -> void:
	var g: float = ProjectSettings.get_setting("physics/3d/default_gravity") * gravity_mul
	if loco_state == LocomotionState.WALL_RUNNING: g *= wall_gravity_mul
	if is_on_floor() || get_slide_collision_count() > 0:
		ChangeVelocity(-last_surface_normal, g * delta)
	else:
		ChangeVelocity(-Vector3.UP, g * delta)

func _apply_floor_stick(delta: float) -> void:
	if !(is_on_floor()): return
	var stick_normal: Vector3 = wall_normal if loco_state == LocomotionState.WALL_RUNNING else last_surface_normal
	var stick: float = wall_stick_force if loco_state == LocomotionState.WALL_RUNNING else stick_force
	ChangeVelocity(-stick_normal, stick * delta)

func ChangeVelocity(vet3: Vector3, force: float) -> void:
	velocity += vet3 * force

# =================================================
# WALL RUNNING & RAMP BOOST
func _detect_wall_running() -> void:
	is_wall_running = false
	is_wall_attached = false
	if is_on_floor():
		return

	for i in get_slide_collision_count():
		var n = get_slide_collision(i).get_normal()
		if abs(n.dot(Vector3.UP)) < 0.3:
			wall_normal = n
			if current_speed >= wall_run_min_speed:
				if not was_wall_running:
					_dbg_log("EVENT: Wall run START — speed: %.1f, normal: %s" % [current_speed, wall_normal])
				is_wall_running = true
			else:
				if not is_wall_attached:
					_dbg_log("EVENT: Wall ATTACH (too slow) — speed: %.1f" % current_speed)
				is_wall_attached = true
			break

func _maintain_wall_speed() -> void:
	if loco_state != LocomotionState.WALL_RUNNING: return
	velocity = velocity.slide(wall_normal).normalized() * current_speed
	ChangeVelocity(-wall_normal, wall_stick_force * get_physics_process_delta_time())

func _apply_ramp_boost_on_leave() -> void:
	if was_on_floor && !is_on_floor():
		var angle_factor = 1.0 - last_surface_normal.dot(Vector3.UP)
		if angle_factor > 0.15:
			ChangeVelocity(velocity.normalized(), slope_alignment_speed * angle_factor * get_physics_process_delta_time())
			_dbg_log("EVENT: Ramp boost — angle_factor: %.2f, speed: %.1f" % [angle_factor, current_speed])

# =================================================
# VISUALS
func _update_board_visual(delta: float) -> void:
	if !board_mesh: return
	var lean_mult: float = drift_lean_multiplier if loco_state == LocomotionState.DRIFTING else 1.0
	var speed_percent: float = clamp(current_speed / max_speed, 0.2, 1.2)
	var target_tilt: float = -smoothed_input_x * (max_lean_angle * lean_mult) * speed_percent
	current_tilt = lerp(current_tilt, target_tilt, lean_responsiveness * delta)
	var visual_basis = global_transform.basis
	visual_basis = visual_basis.rotated(visual_basis.z, current_tilt)
	var total_pitch: float = (crouch_tilt_amount if loco_state == LocomotionState.JUMP_CHARGING else 0.0) + current_air_pitch
	visual_basis = visual_basis.rotated(visual_basis.x, total_pitch)
	board_mesh.global_transform.basis = board_mesh.global_transform.basis.slerp(visual_basis.orthonormalized(), 20.0 * delta)

# =================================================
# ALIGNMENTS
func _align_Board(delta: float, target_normal: Vector3 = Vector3.ZERO, use_target: bool = false) -> void:
	var curr_fwd: Vector3 = -global_transform.basis.z
	if use_target:
		global_transform.basis.y = target_normal
		global_transform.basis.x = curr_fwd.cross(target_normal).normalized()
		global_transform.basis.z = global_transform.basis.x.cross(target_normal).normalized()
	else:
		var current_up: Vector3 = global_transform.basis.y
		if current_up.dot(Vector3.UP) < 0.99:
			var next_up = current_up.lerp(Vector3.UP, air_stability_leveling * delta).normalized()
			global_transform.basis.y = next_up
			global_transform.basis.x = curr_fwd.cross(next_up).normalized()
			global_transform.basis.z = global_transform.basis.x.cross(next_up).normalized()
	global_transform.basis = global_transform.basis.orthonormalized()

func _teleport_to_last_ground() -> void:
	global_position = last_ground_position
	velocity = Vector3.ZERO
	current_speed = 0.0
	air_time = 0.0
	current_air_pitch = 0.0
	floor_snap_length = snap_length

func _on_wall_run_exit() -> void:
	last_surface_normal = Vector3.UP
	if velocity.y < 0: velocity.y *= 0.5

# =================================================
# DEBUG HELPERS
func _dbg_log(msg: String) -> void:
	if debug_enabled and debug_console_log:
		print("[BoardController] ", msg)

func _update_debug(delta: float) -> void:
	_debug_console_throttle -= delta
	# --- Throttled console output (once per second) ---
	if debug_console_log and _debug_console_throttle <= 0.0:
		_debug_console_throttle = 1.0
		print("[Board] state=%-14s speed=%5.1f air=%.2fs wall_run=%s drift=%s drift_charge=%.0f%%" % [
			LocomotionState.keys()[loco_state],
			current_speed,
			air_time,
			"Y" if is_wall_running else "N",
			"Y" if is_drifting else "N",
			drift_charge * 100.0
		])

# Builds a simple ASCII progress bar like: [████░░░░░░]
func _make_bar(value: float, max_val: float, width: int) -> String:
	var filled := int(clamp(value / max_val, 0.0, 1.0) * width)
	return "[" + "█".repeat(filled) + "░".repeat(width - filled) + "]"
