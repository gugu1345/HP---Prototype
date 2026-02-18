extends CharacterBody3D
class_name BoardController

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
@export var enable_wall_running: bool = true
@export var wall_run_min_speed: float = 25.0
@export var wall_stick_force: float = 180.0
@export var wall_gravity_mul: float = 0.35

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

#==================================================
# SYSTEMS
@export_category("Systems")
@export var Cam: CameraController
@export var PlayerSFX: PlaySoundsFX

# =================================================
# STATE
var current_speed: float = 0.0
var input_dir: Vector2 = Vector2.ZERO
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
# =================================================
# CENTRALISED INPUT STATE — populated once per frame in _read_input()
var inp_throttle: float = 0.0
var inp_brake: float = 0.0
var inp_steer: float = 0.0        # left(+) / right(-)
var inp_drift: bool = false
var inp_jump_held: bool = false
var inp_pitch: float = 0.0        # throttle - brake  (for air pitch)

# =================================================
# READY
func _ready() -> void:
	floor_max_angle = deg_to_rad(130)
	floor_snap_length = snap_length
	floor_stop_on_slope = false
	floor_block_on_wall = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

# =================================================
# MAIN LOOP
func _physics_process(delta: float) -> void:
	# 1. Update State & Inputs
	_read_input(delta)
	_update_air_pitch(delta)
	
	if PlayerSFX:
		PlayerSFX._update_jump_charge(delta, is_charging_jump, is_wall_running)
	
	_update_drift(delta)
	_update_speed(delta)

	# 2. Physics & Momentum
	_apply_slope_momentum(delta)
	_apply_surface_gravity(delta)
	_apply_rotation(delta)
	_apply_horizontal_movement(delta)

	_detect_wall_running()
	
	if was_wall_running and not is_wall_running:
		_on_wall_run_exit()

	# Alignment Logic
	if is_wall_running:
		_align_Board(delta, wall_normal, true)
		up_direction = wall_normal
		_apply_floor_stick(delta)
	elif is_on_floor():
		_align_Board(delta, get_floor_normal(), true)
		last_surface_normal = get_floor_normal()
		
		air_time = 0.0
		if grounded_time >= 3.5:
			last_ground_position = global_position
			grounded_time =0.0
		else:
			grounded_time += delta
		up_direction = get_floor_normal()
		_apply_floor_stick(delta)
	else:
		_align_Board(delta)
		up_direction = Vector3.UP
		grounded_time = 0.0
		air_time += delta
		if air_time >= 20.0 and last_ground_position != Vector3.ZERO:
			_teleport_to_last_ground()

	# 3. Execution
	if not is_charging_jump and not is_wall_running:
		apply_floor_snap()
		move_and_slide()
	elif is_charging_jump:
		move_and_slide()
		
	if Cam:
		Cam._update_camera_logic(delta, is_drifting)

	# 4. Post-Move Logic
	_maintain_wall_speed()
	_apply_ramp_boost_on_leave()
	_handle_landing(delta)
	_update_board_visual(delta)
	
	if PlayerSFX:
		PlayerSFX._update_engine_audio(current_speed, max_speed)

	was_on_floor = is_on_floor()
	was_wall_running = is_wall_running
	if is_on_floor():
		last_surface_normal = get_floor_normal()
		air_time = 0.0
	else:
		air_time += delta

# =================================================
# INPUT — single source of truth
func _read_input(delta: float) -> void:
	# Raw axes
	inp_throttle = Input.get_action_strength("throttle")
	inp_brake    = Input.get_action_strength("brake")
	inp_steer    = Input.get_action_strength("left") - Input.get_action_strength("right")
	inp_drift    = Input.is_action_pressed("drift")
	inp_jump_held = Input.is_action_pressed("Jump")
	inp_pitch    = inp_throttle - inp_brake

	# Keyboard fallbacks
	inp_pitch = inp_throttle - inp_brake

	# Steer smoothing
	input_dir.x = inp_steer
	smoothed_input_x = lerp(smoothed_input_x, input_dir.x, rotation_smoothing * delta)

	# Jump charge / execute logic
	var can_jump = is_on_floor() or is_wall_running

	if is_charging_jump and not inp_jump_held:
		_execute_jump()
		is_charging_jump = false

	if can_jump and inp_jump_held:
		is_charging_jump = true
	elif not inp_jump_held:
		is_charging_jump = false

# =================================================
# AIR CONTROLS
func _update_air_pitch(delta: float) -> void:
	if !is_on_floor() && !is_wall_running:
		var target_pitch = inp_pitch * deg_to_rad(air_pitch_max_angle)
		current_air_pitch = lerp(current_air_pitch, target_pitch, air_pitch_responsiveness * delta)
	else:
		current_air_pitch = lerp(current_air_pitch, 0.0, air_pitch_return_speed * delta)

# =================================================
# JUMP
func _execute_jump() -> void:
	var charge_val = PlayerSFX.current_jump_charge if PlayerSFX else 1.0
	var force = lerp(min_jump_force, max_jump_force, charge_val)
	
	floor_snap_length = 0.0
	air_spin_timer = 0.0
	
	if is_wall_running && wall_normal != Vector3.ZERO:
		ChangeVelocity(wall_normal, force * 1.4)
		ChangeVelocity(Vector3.UP, force * 0.5)
		is_wall_running = false
		_on_wall_run_exit()
	else:
		ChangeVelocity(global_transform.basis.y, force)
		
	if PlayerSFX:
		PlayerSFX.play_jump_launch()
		PlayerSFX.current_jump_charge = 0.0

func _handle_landing(delta: float) -> void:
	if !is_on_floor(): return
	if !was_on_floor && air_time > 0.15:
		if PlayerSFX: PlayerSFX.play_land()
		_reset_ik_positions()

# =================================================
# DRIFT & DASH
func _update_drift(delta: float) -> void:
	if !is_on_floor() || current_speed < drift_min_speed:
		is_drifting = false
		drift_charge = 0.0
		if PlayerSFX: PlayerSFX.stop_drift_loop()
		return
		
	var drift_input = inp_drift and abs(input_dir.x) > 0.1
	
	if is_drifting and not drift_input:
		if drift_charge >= 1.0:
			dash_velocity = current_speed + drift_dash_force
			dash_timer = drift_dash_duration
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
	elif is_charging_jump:
		current_speed = lerp(current_speed, 0.0, jump_charge_drag * delta)
	else:
		if is_on_floor():
			if inp_throttle > 0:
				current_speed = move_toward(current_speed, max_speed, acceleration * delta)
			elif inp_brake > 0:
				current_speed = move_toward(current_speed, 0.0, braking * delta)
			else:
				current_speed = move_toward(current_speed, 0.0, friction * delta)
		else:
			current_speed = move_toward(current_speed, 0.0, air_drag * delta)
			var dive_factor = sin(current_air_pitch)
			if dive_factor > 0:
				current_speed += dive_speed_gain * dive_factor * delta
			else:
				current_speed -= pull_up_speed_loss * abs(dive_factor) * delta

	current_speed = clamp(current_speed, 0.0, max_velocity)

# =================================================
# PHYSICS & ROTATION
func _apply_rotation(delta: float) -> void:
	var turn_scale = 1.0
	
	if is_charging_jump:
		turn_scale = 0.5
	elif is_drifting:
		turn_scale *= drift_turn_multiplier
	elif !is_on_floor() && !is_wall_running:
		turn_scale = 0.1 if air_spin_timer < air_rotation_delay else air_rotation_multiplier
		
	rotate_object_local(Vector3.UP, smoothed_input_x * rotation_speed * turn_scale * delta)

func _apply_horizontal_movement(delta: float) -> void:
	if is_wall_running: return
	var forward = -transform.basis.z
	var right = transform.basis.x
	
	if is_on_floor():
		var horizontal_fwd = Vector3(forward.x, 0.0, forward.z).normalized() if Vector3(forward.x, 0.0, forward.z).length() > 0.01 else forward
		velocity.x = horizontal_fwd.x * current_speed
		velocity.z = horizontal_fwd.z * current_speed
	else:
		var lateral_move = -smoothed_input_x * air_lateral_force
		var target_vel = (forward * current_speed) + (right * lateral_move)
		velocity.x = move_toward(velocity.x, target_vel.x, 30.0 * delta)
		velocity.z = move_toward(velocity.z, target_vel.z, 30.0 * delta)

func _apply_slope_momentum(delta: float) -> void:
	if !is_on_floor(): return
	var normal = get_floor_normal()
	var slope = 1.0 - normal.dot(Vector3.UP)
	if slope < 0.02: return
	var downhill = Vector3.DOWN.slide(normal).normalized()
	var alignment = downhill.dot(-board_mesh.global_transform.basis.z)
	current_speed += alignment * slope_accel_strength * slope * delta
	current_speed = clamp(current_speed, 0.0, max_velocity)

func _apply_surface_gravity(delta: float) -> void:
	var g = ProjectSettings.get_setting("physics/3d/default_gravity") * gravity_mul
	if is_wall_running: g *= wall_gravity_mul
	if is_on_floor() || get_slide_collision_count() > 0:
		ChangeVelocity(-last_surface_normal , g * delta)
	else:
		ChangeVelocity(-Vector3.UP,  g * delta)

func _apply_floor_stick(delta: float) -> void:
	if !(is_on_floor() || is_wall_running): return
	var stick_normal = wall_normal if is_wall_running else last_surface_normal
	var stick = wall_stick_force if is_wall_running else stick_force
	ChangeVelocity(-stick_normal, stick * delta)
func  ChangeVelocity(vet3:Vector3,force:float) -> void:
	velocity += vet3 * force
# =================================================
# WALL RUNNING & RAMP BOOST
func _detect_wall_running() -> void:
	if !enable_wall_running || is_on_floor() || current_speed < wall_run_min_speed:
		is_wall_running = false
		return
	var found_wall = false
	for i in get_slide_collision_count():
		var n = get_slide_collision(i).get_normal()
		if abs(n.dot(Vector3.UP)) < 0.3:
			wall_normal = n
			found_wall = true
			is_wall_running = true
			break
	if !found_wall: is_wall_running = false

func _maintain_wall_speed() -> void:
	if !is_wall_running: return
	velocity = velocity.slide(wall_normal).normalized() * current_speed
	ChangeVelocity(-wall_normal, wall_stick_force * get_physics_process_delta_time())

func _apply_ramp_boost_on_leave() -> void:
	if was_on_floor && !is_on_floor():
		var angle_factor = 1.0 - last_surface_normal.dot(Vector3.UP)
		if angle_factor > 0.15:
			ChangeVelocity(velocity.normalized() , slope_alignment_speed * angle_factor * get_physics_process_delta_time())

# =================================================
# VISUALS
func _update_board_visual(delta: float) -> void:
	if !board_mesh: return
	var lean_mult = drift_lean_multiplier if is_drifting else 1.0
	var speed_percent = clamp(current_speed / max_speed, 0.2, 1.2)
	var target_tilt = -smoothed_input_x * (max_lean_angle * lean_mult) * speed_percent
	current_tilt = lerp(current_tilt, target_tilt, lean_responsiveness * delta)
	var visual_basis = global_transform.basis
	visual_basis = visual_basis.rotated(visual_basis.z, current_tilt)
	var crouch_tilt = crouch_tilt_amount if is_charging_jump else 0.0
	var total_pitch = crouch_tilt + current_air_pitch
	visual_basis = visual_basis.rotated(visual_basis.x, total_pitch)
	board_mesh.global_transform.basis = board_mesh.global_transform.basis.slerp(visual_basis.orthonormalized(), 20.0 * delta)

# =================================================
# ALIGNMENTS
func _align_Board(delta: float, target_normal: Vector3=Vector3.ZERO, use_target: bool=false) -> void:
	var curr_fwd = -global_transform.basis.z
	if use_target:
		global_transform.basis.y = target_normal
		global_transform.basis.x = curr_fwd.cross(target_normal).normalized()
		global_transform.basis.z = global_transform.basis.x.cross(target_normal).normalized()
	else:
		var current_up = global_transform.basis.y
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
	up_direction = Vector3.UP
	if velocity.y < 0: velocity.y *= 0.5

func _reset_ik_positions() -> void:
	pass
