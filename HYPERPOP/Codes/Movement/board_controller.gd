extends CharacterBody3D
class_name BoardController

# =================================================
# LOCOMOTION STATE ENUM
enum LocomotionState {
	GROUNDED,       # on floor, normal movement
	DRIFTING,       # on floor, drifting
	JUMP_CHARGING,  # on floor, charging a jump
	AIRBORNE,       # in the air
	WALL_RUNNING    # running along a wall
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

# =================================================
# CONFIG — JUMP & CHARGE
@export_category("Jump")
@export var min_jump_force: float = 12.0
@export var max_jump_force: float = 35.0
@export var jump_charge_drag: float = 0.3

# =================================================
# CONFIG — PHYSICS
@export_category("Physics")
@export var gravity_mul: float = 5.0
@export var stick_force: float = 100.0
@export var slope_alignment_speed: float = 22.0
@export var snap_length: float = 1.5
@export var max_velocity: float = 150.0
@export var slope_launch_boost: float = 10.0

# =================================================
# CONFIG — SLOPE PHYSICS
@export_category("Slope Physics")
@export var slope_accel_strength: float = 22.0
@export var air_alignment_speed: float = 5.0

# =================================================
# CONFIG — AIR CONTROLS
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
@export var debug_console_log: bool = false
var _debug_console_throttle: float = 0.0

# =================================================
# STATE
var current_speed: float = 0.0
var smoothed_input_x: float = 0.0
var was_on_floor: bool = true
var air_time: float = 0.0
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
		var canvas := CanvasLayer.new()
		canvas.name = "DebugCanvas"
		add_child(canvas)
		var label := RichTextLabel.new()
		label.name = "DebugLabel"
		label.bbcode_enabled = true
		label.set_anchors_preset(Control.PRESET_TOP_LEFT)
		label.position = Vector2(10, 10)
		label.size = Vector2(420, 320)
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
	_update_loco_state()

	# 2. Physics & Momentum
	_apply_slope_momentum(delta)
	_apply_surface_gravity(delta)
	_apply_rotation(delta)
	_apply_horizontal_movement()

	# Wall Run Detection
	_detect_wall_running()
	_update_loco_state()

	if was_wall_running and not is_wall_running:
		_on_wall_run_exit()
		_dbg_log("EVENT: Wall run EXIT — speed: %.1f" % current_speed)

	# 3. Per-state alignment & stick
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

	# 4. Execution
	if not is_charging_jump and not is_wall_running:
		apply_floor_snap()
	move_and_slide()

	if Cam:
		Cam._update_camera_logic(delta, loco_state == LocomotionState.DRIFTING)

	# 5. Post-move logic
	_maintain_wall_speed()
	_apply_ramp_boost_on_leave()
	_handle_landing(delta)


	if PlayerSFX:
		PlayerSFX._update_engine_audio(current_speed, max_speed)

	# Update state tracking (after move)
	was_on_floor = is_on_floor()
	was_wall_running = is_wall_running
	if is_on_floor():
		_update_board_visual(delta, get_floor_normal())
		# ADDED: only write true ground normal when actually on floor, never during wall run
		if not is_wall_running:
			_update_board_visual(delta, get_floor_normal())
		air_time = 0.0
		grounded_time += delta
		if grounded_time >= 3.5:
			last_ground_position = global_position
			grounded_time = 0.0
	else:
		grounded_time = 0.0

	if debug_enabled:
		_update_debug(delta)

# =================================================
# LOCOMOTION STATE RESOLVER
func _update_loco_state() -> void:
	if is_wall_running:
		loco_state = LocomotionState.WALL_RUNNING
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

# =================================================
# SPEED
func _update_speed(delta: float) -> void:
	if dash_timer > 0.0:
		dash_timer -= delta
		current_speed = dash_velocity
		return

	if loco_state == LocomotionState.JUMP_CHARGING:
		current_speed = lerp(current_speed, 0.0, jump_charge_drag * delta)
		return

	if loco_state == LocomotionState.DRIFTING:
		return

	if inp_throttle > 0:
		current_speed = move_toward(current_speed, max_speed, acceleration * delta)
	elif inp_brake > 0:
		current_speed = move_toward(current_speed, 0.0, braking * delta)
	else:
		var drag: float = friction if is_on_floor() else air_drag
		current_speed = move_toward(current_speed, 0.0, drag * delta)

	if !is_on_floor() && !is_wall_running:
		var dive_factor: float = sin(current_air_pitch)
		if dive_factor > 0:
			current_speed += dive_speed_gain * dive_factor * delta
		else:
			current_speed -= pull_up_speed_loss * abs(dive_factor) * delta
		current_speed = max(current_speed, 0.0)

	current_speed = clamp(current_speed, 0.0, max_velocity)

# =================================================
# PHYSICS & ROTATION
func _apply_rotation(delta: float) -> void:
	var turn_scale: float = 0.5 if loco_state == LocomotionState.JUMP_CHARGING else 1.0
	if loco_state == LocomotionState.DRIFTING:
		turn_scale *= drift_turn_multiplier
	if !is_on_floor() && !is_wall_running:
		turn_scale *= air_rotation_multiplier
	rotate_object_local(Vector3.UP, smoothed_input_x * rotation_speed * turn_scale * delta)

func _apply_horizontal_movement() -> void:
	if is_wall_running: return
	var forward: Vector3 = -transform.basis.z
	var horizontal_forward: Vector3 = Vector3(forward.x, 0.0, forward.z)
	if horizontal_forward.length_squared() > 0.01:
		horizontal_forward = horizontal_forward.normalized()
	else:
		horizontal_forward = -transform.basis.z
	velocity.x = horizontal_forward.x * current_speed
	velocity.z = horizontal_forward.z * current_speed

func _apply_slope_momentum(delta: float) -> void:
	if !is_on_floor(): return
	var normal: Vector3 = get_floor_normal()
	var slope: float = 1.0 - normal.dot(Vector3.UP)
	if slope < 0.02: return
	var downhill: Vector3 = Vector3.DOWN.slide(normal).normalized()
	var alignment: float = downhill.dot(-global_transform.basis.z)
	current_speed += alignment * slope_accel_strength * slope * delta

func _apply_surface_gravity(delta: float) -> void:
	var g: float = ProjectSettings.get_setting("physics/3d/default_gravity") * gravity_mul
	if is_on_floor() || get_slide_collision_count() > 0:
		velocity -=  get_floor_normal() * g * delta
	else:
		velocity.y -= g * delta

func _apply_floor_stick(delta: float) -> void:
	if !(is_on_floor() || is_wall_running): return
	var stick_normal: Vector3 = wall_normal if is_wall_running else  get_floor_normal()
	var stick: float = stick_force
	if !is_wall_running && velocity.normalized().dot(stick_normal) < 0.1:
		stick *= 2.0
	velocity -= stick_normal * stick * delta

# =================================================
# WALL RUNNING
func _detect_wall_running() -> void:
	if is_on_floor():
		is_wall_running = false
		return
	var found_wall: bool = false
	for i in get_slide_collision_count():
		var n: Vector3 = get_slide_collision(i).get_normal()
		if abs(n.dot(Vector3.UP)) < 0.3:
			wall_normal = n
			found_wall = true
			if not was_wall_running:
				_dbg_log("EVENT: Wall run START — speed: %.1f, normal: %s" % [current_speed, wall_normal])
			is_wall_running = true
			break
	if !found_wall:
		is_wall_running = false

func _maintain_wall_speed() -> void:
	if !is_wall_running: return
	velocity = velocity.slide(wall_normal).normalized() * current_speed
	velocity -= wall_normal * stick_force * get_physics_process_delta_time()

func _apply_ramp_boost_on_leave() -> void:
	if was_on_floor && !is_on_floor():
		var angle_factor: float = 1.0 -  get_floor_normal().dot(Vector3.UP)
		if angle_factor > 0.15:
			velocity += velocity.normalized() * slope_launch_boost * angle_factor
			_dbg_log("EVENT: Ramp boost — angle_factor: %.2f" % angle_factor)

# =================================================
# ALIGNMENTS
func _align_to_surface(delta: float, target_normal: Vector3) -> void:
	var target_basis: Basis = global_transform.basis
	target_basis.y = target_normal
	target_basis.x = -target_basis.z.cross(target_normal)
	target_basis = target_basis.orthonormalized()
	global_transform.basis = global_transform.basis.slerp(target_basis, slope_alignment_speed * delta)

func _align_to_upright(delta: float) -> void:
	var current_up: Vector3 = global_transform.basis.y
	if current_up.dot(Vector3.UP) > 0.99:
		return
	var target_basis: Basis = global_transform.basis
	target_basis.y = Vector3.UP
	target_basis.x = -target_basis.z.cross(Vector3.UP)
	target_basis = target_basis.orthonormalized()
	global_transform.basis = global_transform.basis.slerp(target_basis, air_alignment_speed * delta)

func _on_wall_run_exit() -> void:
	up_direction = Vector3.UP
	if velocity.y < 0:
		velocity.y *= 0.5

func _teleport_to_last_ground() -> void:
	global_position = last_ground_position
	velocity = Vector3.ZERO
	current_speed = 0.0
	air_time = 0.0
	current_air_pitch = 0.0

# =================================================
# VISUALS
func _update_board_visual(delta: float,Vec3:Vector3) -> void:
	if !board_mesh: return
	var lean_mult: float = drift_lean_multiplier if loco_state == LocomotionState.DRIFTING else 1.0
	var speed_percent: float = clamp(current_speed / max_speed, 0.2, 1.2)
	var target_tilt: float = -smoothed_input_x * (max_lean_angle * lean_mult) * speed_percent
	current_tilt = lerp(current_tilt, target_tilt, lean_responsiveness * delta)


	# Build forward from character facing, projected onto the ground plane
	var char_fwd: Vector3 = -global_transform.basis.z
	var fwd: Vector3 = (char_fwd - Vec3 * char_fwd.dot(Vec3)).normalized()
	if fwd.length_squared() < 0.01:
		fwd = -global_transform.basis.z  # fallback

	var right: Vector3 = fwd.cross(Vec3).normalized()
	if right.length_squared() < 0.01:
		right = global_transform.basis.x  # fallback
	
	var visual_basis: Basis = Basis(right, Vec3, -fwd)
	visual_basis = visual_basis.rotated(visual_basis.z, current_tilt)
	var total_pitch: float = (crouch_tilt_amount if loco_state == LocomotionState.JUMP_CHARGING else 0.0) + current_air_pitch
	visual_basis = visual_basis.rotated(visual_basis.x, total_pitch)
	board_mesh.global_transform.basis = board_mesh.global_transform.basis.slerp(visual_basis.orthonormalized(), 20.0 * delta)

# =================================================
# DEBUG HELPERS
func _dbg_log(msg: String) -> void:
	if debug_enabled and debug_console_log:
		print("[BoardController] ", msg)

func _update_debug(delta: float) -> void:
	_debug_console_throttle -= delta
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

		# Ground object name
		var ground_name: String = "none"
		if is_on_floor():
			for i in get_slide_collision_count():
				var col = get_slide_collision(i)
				if col.get_normal().dot(Vector3.UP) > 0.5:
					ground_name = col.get_collider().name
					break

		# Board mesh debug
		if board_mesh:
			var floor_normal: Vector3 = get_floor_normal() if is_on_floor() else Vector3.DOWN
			print("[BoardMesh] ground=%s  vec3(floor_normal)=%s  tilt=%.3f  pitch=%.3f" % [
				ground_name,
				floor_normal,
				current_tilt,
				current_air_pitch
			])
		else:
			print("[BoardMesh] WARNING: board_mesh is null!")

func _make_bar(value: float, max_val: float, width: int) -> String:
	var filled := int(clamp(value / max_val, 0.0, 1.0) * width)
	return "[" + "█".repeat(filled) + "░".repeat(width - filled) + "]"
