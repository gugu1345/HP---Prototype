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

# =================================================
# CONFIG — JUMP & CHARGE
@export_category("Jump")
@export var min_jump_force: float = 12.0
@export var max_jump_force: float = 35.0
@export var max_charge_time: float = 0.8
@export var jump_charge_drag: float = 0.3

# =================================================
# CONFIG — PHYSICS
@export_category("Physics")
@export var gravity_mul: float = 3.0
@export var stick_force: float = 120.0 # Increased to stick better to slopes
@export var slope_alignment_speed: float = 22.0
@export var snap_length: float = 0.8 # Snap distance to keep grounded on slopes
@export var max_velocity: float = 150.0 # NEW: Maximum velocity cap for ChangeVelocity

# =================================================
# CONFIG — SLOPE PHYSICS
@export_category("Slope Physics")
@export var slope_accel_strength: float = 22.0
@export var slope_alignment_speed: float = 22.0
@export var air_alignment_speed: float = 5.0

# =================================================
# CONFIG — WALL RUNNING
@export_category("Wall Running")
@export var enable_wall_running: bool = true
@export var wall_run_min_speed: float = 25.0
@export var wall_stick_force: float = 180.0
@export var wall_gravity_mul: float = 0.35

# =================================================
# CONFIG — AIR CONTROLS (NEW)
@export_category("Air Controls")
@export var air_rotation_multiplier: float = 2.0
@export var air_pitch_max_angle: float = 50.0
@export var air_pitch_responsiveness: float = 8.0
@export var air_pitch_return_speed: float = 6.0
@export var dive_speed_gain: float = 45.0
@export var pull_up_speed_loss: float = 25.0

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
# CONFIG — CAMERA
@export_category("Camera Logic")
@export var camera_node : Camera3D
@export_group("Drift FX Settings")
@export var drift_fov_target : float = 48.0
@export_group("General Camera Responsiveness")
@export var move_lerp_speed : float = 1.0
@export var rotation_lerp_speed : float = 6.0
@export var fov_lerp_speed : float = 3.5

# =================================================
# AUDIO
@export_category("Audio")
@export var sfx_jump_launch: AudioStreamPlayer3D
@export var sfx_jump_charge_loop: AudioStreamPlayer3D
@export var sfx_land: AudioStreamPlayer3D
@export var sfx_drift_loop: AudioStreamPlayer3D
@export var sfx_dash: AudioStreamPlayer3D
@export var sfx_engine_loop: AudioStreamPlayer3D
@export var sfx_brake: AudioStreamPlayer3D

# =================================================
# STATE
var current_speed: float = 0.0
var input_dir: Vector2 = Vector2.ZERO
var smoothed_input_x: float = 0.0
var was_on_floor: bool = true
var last_surface_normal: Vector3 = Vector3.UP
var air_time: float = 0.0

# Jump
var current_jump_charge: float = 0.0
var is_charging_jump: bool = false

# Visual/Drift
var current_tilt: float = 0.0
var is_drifting: bool = false
var drift_charge: float = 0.0
var dash_timer: float = 0.0
var dash_velocity: float = 0.0

# Wall Running & State Management
var is_wall_running: bool = false
var was_wall_running: bool = false
var wall_normal: Vector3 = Vector3.ZERO

# Air pitch 
var current_air_pitch: float = 0.0

var base_fov: float = 75.0

# =================================================
# READY
func _ready() -> void:
	floor_max_angle = deg_to_rad(130)
	floor_snap_length = snap_length
	floor_stop_on_slope = false
	floor_block_on_wall = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	if camera_node:
		base_fov = camera_node.fov

# =================================================
# MAIN LOOP
func _physics_process(delta: float) -> void:
	# 1. Update State & Inputs
	_read_input(delta)
	_update_air_pitch(delta)          # NOVO
	_update_jump_charge(delta)
	_update_drift(delta)
	_update_speed(delta)
	
	# 2. Physics & Momentum
	_apply_slope_momentum(delta)
	_apply_surface_gravity(delta)
	_apply_rotation(delta)
	_apply_horizontal_movement()      # Modificado para projeção horizontal
	
	# WallRun Logic and Alignment
	_detect_wall_running()
	if was_wall_running and not is_wall_running:
		_on_wall_run_exit()
	
	# Aligment
	if is_wall_running:
		_align_to_surface(delta, wall_normal)
		up_direction = wall_normal
		_apply_floor_stick(delta)
	elif is_on_floor():
		_align_to_surface(delta, get_floor_normal())
		up_direction = get_floor_normal()
		_apply_floor_stick(delta)
	else:
		_align_to_upright(delta)
		up_direction = Vector3.UP
	
	# 3. Execution
	if not is_charging_jump and not is_wall_running:
		apply_floor_snap()
	move_and_slide()
	
	# 4. Post-Move Logic
	_maintain_wall_speed()
	_apply_ramp_boost_on_leave()
	_handle_landing(delta)
	_update_board_visual(delta)
	_update_engine_audio()
	
	# Atualiza estados passados
	was_on_floor = is_on_floor()
	was_wall_running = is_wall_running
	if is_on_floor():
		last_surface_normal = get_floor_normal()
		air_time = 0.0

# =================================================
# AIR CONTROLS (PITCH)
func _update_air_pitch(delta: float) -> void:
	var throttle: float = 0.0
	if InputMap.has_action("throttle"):
		throttle = Input.get_action_strength("throttle")
	else:
		throttle = Input.get_action_strength("ui_up")
	if Input.is_key_pressed(KEY_W):
		throttle = 1.0
	
	var brake: float = 0.0
	if InputMap.has_action("brake"):
		brake = Input.get_action_strength("brake")
	else:
		brake = Input.get_action_strength("ui_down")
	if Input.is_key_pressed(KEY_S):
		brake = 1.0
	
	var pitch_input: float = throttle - brake
	
	var target_pitch: float = 0.0
	if !is_on_floor() && !is_wall_running:
		target_pitch = pitch_input * deg_to_rad(air_pitch_max_angle)
	
	var lerp_speed: float = air_pitch_responsiveness if !is_on_floor() && !is_wall_running else air_pitch_return_speed
	current_air_pitch = lerp(current_air_pitch, target_pitch, lerp_speed * delta)

# =================================================
# INPUT
func _read_input(delta: float) -> void:
	input_dir.x = 0.0
	if Input.is_key_pressed(KEY_A): input_dir.x += 1.0
	if Input.is_key_pressed(KEY_D): input_dir.x -= 1.0
	if input_dir.x == 0.0:
		input_dir.x = Input.get_axis("turn_right", "turn_left")
	if input_dir.x == 0.0:
		input_dir.x = Input.get_axis("ui_right", "ui_left")
	
	smoothed_input_x = lerp(smoothed_input_x, input_dir.x, rotation_smoothing * delta)
	
	var jump_pressed = Input.is_action_pressed("Jump") && (is_on_floor() || is_wall_running)
	if is_charging_jump && !jump_pressed:
		_execute_jump()
	is_charging_jump = jump_pressed

# =================================================
# JUMP
func _update_jump_charge(delta: float) -> void:
	if is_charging_jump && (is_on_floor() || is_wall_running):
		current_jump_charge = move_toward(current_jump_charge, 1.0, delta / max_charge_time)
		if sfx_jump_charge_loop && !sfx_jump_charge_loop.playing:
			sfx_jump_charge_loop.play()
	else:
		current_jump_charge = 0.0
		if sfx_jump_charge_loop && sfx_jump_charge_loop.playing:
			sfx_jump_charge_loop.stop()

func _execute_jump() -> void:
	var force = lerp(min_jump_force, max_jump_force, current_jump_charge)
	floor_snap_length = 0.0
	if is_wall_running && wall_normal != Vector3.ZERO:
		velocity += wall_normal * force * 1.4
		velocity.y += force * 0.5
		is_wall_running = false
		_on_wall_run_exit()
	else:
		velocity += last_surface_normal * force
	if sfx_jump_launch: sfx_jump_launch.play()
	current_jump_charge = 0.0

func _handle_landing(delta: float) -> void:
	if !is_on_floor():
		air_time += delta
		return
	if !was_on_floor && air_time > 0.15:
		if sfx_land: sfx_land.play()
		_reset_ik_positions()

# =================================================
# DRIFT
func _update_drift(delta: float) -> void:
	if !is_on_floor() || current_speed < drift_min_speed:
		is_drifting = false
		drift_charge = 0.0
		if sfx_drift_loop && sfx_drift_loop.playing: sfx_drift_loop.stop()
		return
	
	is_drifting = Input.is_action_pressed("drift") && abs(input_dir.x) > 0.1
	if is_drifting:
		current_speed = move_toward(current_speed, 0.0, drift_deceleration_rate * delta)
		drift_charge = move_toward(drift_charge, 1.0, delta / drift_max_charge_time)
		if sfx_drift_loop && !sfx_drift_loop.playing:
			sfx_drift_loop.play()
	else:
		if sfx_drift_loop && sfx_drift_loop.playing:
			sfx_drift_loop.stop()
		if drift_charge >= 1.0:
			dash_velocity = current_speed + drift_dash_force
			dash_timer = drift_dash_duration
			if sfx_dash: sfx_dash.play()
			drift_charge = 0.0

# =================================================
# SPEED (agora com ganho/perda por pitch aéreo)
func _update_speed(delta: float) -> void:
	if dash_timer > 0.0:
		dash_timer -= delta
		current_speed = dash_velocity
		return
	
	if is_charging_jump:
		current_speed = lerp(current_speed, 0.0, jump_charge_drag * delta)
		return
	
	var throttle = Input.get_action_strength("throttle") if InputMap.has_action("throttle") else Input.get_action_strength("ui_up")
	if Input.is_key_pressed(KEY_W): throttle = 1.0
	var brake = Input.get_action_strength("brake") if InputMap.has_action("brake") else Input.get_action_strength("ui_down")
	if Input.is_key_pressed(KEY_S): brake = 1.0
	
	if brake > 0.0 && current_speed > 1.0:
		if sfx_brake && !sfx_brake.playing: sfx_brake.play()
	else:
		if sfx_brake && sfx_brake.playing: sfx_brake.stop()
	
	if throttle > 0:
		current_speed = move_toward(current_speed, max_speed, acceleration * delta)
	elif brake > 0:
		current_speed = move_toward(current_speed, 0.0, braking * delta)
	else:
		var drag: float = friction if is_on_floor() else air_drag
		current_speed = move_toward(current_speed, 0.0, drag * delta)
	
	# Ganho/perda de velocidade no ar baseado no pitch do board (SSX-style)
	if !is_on_floor() && !is_wall_running:
		var dive_factor = sin(current_air_pitch)  # positivo = nose down
		if dive_factor > 0:
			current_speed += dive_speed_gain * dive_factor * delta
		else:
			current_speed -= pull_up_speed_loss * abs(dive_factor) * delta
		current_speed = max(current_speed, 0.0)

	

func _execute_jump() -> void:
	var force: float = lerp(min_jump_force, max_jump_force, current_jump_charge)
	current_jump_charge = 0.0
	velocity += get_floor_normal() * force
	set_floor_snap_length(0.0) # Disable snap during jump
	if sfx_jump_launch: sfx_jump_launch.play()

func _handle_landing() -> void:
	if is_on_floor() and not was_on_floor and sfx_land: sfx_land.play()

# =================================================
# DRIFT + DASH
func _update_drift(delta: float) -> void:
	if not is_on_floor() or current_speed < drift_min_speed:
		is_drifting = false
		drift_charge = 0.0
		if sfx_drift_loop and sfx_drift_loop.playing: sfx_drift_loop.stop()
		return

	is_drifting = Input.is_action_pressed("drift") and abs(input_dir.x) > 0.1

	if is_drifting:
		current_speed = move_toward(current_speed, 0.0, drift_deceleration_rate * delta)
		drift_charge = move_toward(drift_charge, 1.0, delta / drift_max_charge_time)
		if sfx_drift_loop and not sfx_drift_loop.playing: sfx_drift_loop.play()
	else:
		if sfx_drift_loop and sfx_drift_loop.playing: sfx_drift_loop.stop()

		if drift_charge >= 1.0:
			dash_velocity = current_speed + drift_dash_force
			dash_timer = drift_dash_duration
			if sfx_dash: sfx_dash.play()
		drift_charge = 0.0

# =================================================
# PHYSICS
func _apply_slope_momentum(delta: float) -> void:
	if !is_on_floor(): return
	var normal: Vector3 = get_floor_normal()
	var slope: float = 1.0 - normal.dot(Vector3.UP)
	if slope < 0.02: return
	var downhill: Vector3 = Vector3.DOWN.slide(normal).normalized()
	var alignment: float = downhill.dot( -board_mesh.global_transform.basis.z)
	current_speed += alignment * slope_accel_strength * slope * delta

func _apply_surface_gravity(delta: float) -> void:
	var g = ProjectSettings.get_setting("physics/3d/default_gravity") * gravity_mul
	if is_wall_running: g *= wall_gravity_mul
	if is_on_floor() || get_slide_collision_count() > 0:
		velocity -= last_surface_normal * g * delta
	else:
		velocity.y -= g * delta

func _apply_rotation(delta: float) -> void:
	var turn_scale: float = 0.5 if is_charging_jump else 1.0
	if is_drifting: turn_scale *= drift_turn_multiplier
	if !is_on_floor() && !is_wall_running:
		turn_scale *= air_rotation_multiplier   # Mais responsivo no ar
	rotate_object_local(Vector3.UP, smoothed_input_x * rotation_speed * turn_scale * delta)

func _apply_horizontal_movement() -> void:
	if is_wall_running: return
	var forward = -transform.basis.z
	var horizontal_forward = Vector3(forward.x, 0.0, forward.z)
	if horizontal_forward.length_squared() > 0.01:
		horizontal_forward = horizontal_forward.normalized()
	else:
		horizontal_forward = -transform.basis.z  # fallback
	velocity.x = horizontal_forward.x * current_speed
	velocity.z = horizontal_forward.z * current_speed

func _apply_floor_stick(delta: float) -> void:
	if !(is_on_floor() || is_wall_running): return
	var stick_normal = wall_normal if is_wall_running else last_surface_normal
	var stick: float = wall_stick_force if is_wall_running else stick_force
	if !is_wall_running && velocity.normalized().dot(stick_normal) < 0.1:
		stick *= 2.0
	velocity -= stick_normal * stick * delta

# =================================================
# WALL RUN & BOOST
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
	if !found_wall:
		is_wall_running = false

func _maintain_wall_speed() -> void:
	if !is_wall_running: return
	velocity = velocity.slide(wall_normal).normalized() * current_speed
	velocity -= wall_normal * wall_stick_force * get_physics_process_delta_time()

func _apply_ramp_boost_on_leave() -> void:
	if was_on_floor && !is_on_floor():
		var angle_factor = 1.0 - last_surface_normal.dot(Vector3.UP)
		if angle_factor > 0.15:
			velocity += velocity.normalized() * slope_launch_boost * angle_factor

# =================================================
# CAMERA
func _update_camera_logic(delta: float) -> void:
	if !camera_node: return
	camera_node.fov = lerp(camera_node.fov, drift_fov_target if is_drifting else base_fov, fov_lerp_speed * delta)
	var target_quat = global_transform.basis.get_rotation_quaternion()
	var current_quat = camera_node.global_transform.basis.get_rotation_quaternion()
	camera_node.global_transform.basis = Basis(current_quat.slerp(target_quat, rotation_lerp_speed * delta))
	var back_dir = camera_node.global_transform.basis.z
	var target_cam_pos = global_position + (back_dir * 5.0)
	camera_node.global_position = camera_node.global_position.lerp(target_cam_pos, move_lerp_speed * delta)

# =================================================
# VISUALS & AUDIO
func _update_board_visual(delta: float) -> void:
	if !board_mesh: return
	var lean_mult = drift_lean_multiplier if is_drifting else 1.0
	var target_tilt = -smoothed_input_x * (max_lean_angle * lean_mult) * clamp(current_speed / max_speed, 0.2, 1.2)
	current_tilt = lerp(current_tilt, target_tilt, lean_responsiveness * delta)
	
	var visual_basis = global_transform.basis
	
	# Lean (roll)
	visual_basis = visual_basis.rotated(visual_basis.z, current_tilt)
	
	# Pitch + crouch
	var crouch_tilt = crouch_tilt_amount if is_charging_jump else 0.0
	var total_pitch = crouch_tilt + current_air_pitch
	visual_basis = visual_basis.rotated(visual_basis.x, total_pitch)
	
	board_mesh.global_transform.basis = board_mesh.global_transform.basis.slerp(visual_basis.orthonormalized(), 20.0 * delta)

func _update_engine_audio() -> void:
	if !sfx_engine_loop: return
	if current_speed > 1:
		if !sfx_engine_loop.playing: sfx_engine_loop.play()
		sfx_engine_loop.pitch_scale = lerp(0.9, 1.6, current_speed / max_speed)
	else:
		if sfx_engine_loop.playing: sfx_engine_loop.stop()

# =================================================
# WALLRUN IK
func _on_wall_run_exit() -> void:
	last_surface_normal = Vector3.UP
	up_direction = Vector3.UP
	if velocity.y < 0:
		velocity.y *= 0.5
	_reset_ik_positions()

func _reset_ik_positions() -> void:
	pass

# =================================================
# ALIGNMENTS
func _align_to_surface(delta: float, target_normal: Vector3) -> void:
	var target_basis = global_transform.basis
	target_basis.y = target_normal
	target_basis.x = -target_basis.z.cross(target_normal)
	target_basis = target_basis.orthonormalized()
	var align_speed = slope_alignment_speed
	global_transform.basis = global_transform.basis.slerp(target_basis, align_speed * delta)

func _align_to_upright(delta: float) -> void:
	var current_up = global_transform.basis.y
	var target_up = Vector3.UP
	if current_up.dot(target_up) > 0.99:
		return
	var target_basis = global_transform.basis
	target_basis.y = target_up
	target_basis.x = -target_basis.z.cross(target_up)
	target_basis = target_basis.orthonormalized()
	global_transform.basis = global_transform.basis.slerp(target_basis, air_alignment_speed * delta)
