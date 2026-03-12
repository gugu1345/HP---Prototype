extends CharacterBody3D
class_name BoardController


# =================================================
# LOCOMOTION STATE
	#GROUNDED,       # on floor, normal movement
	#DRIFTING,       # on floor, drifting
	#JUMP_CHARGING,  # on floor, charging a jump
	#AIRBORNE,       # in the air
	#WALL_RUNNING    # running along a wall
@export var loco_state_machine: BoardStateMachine

# CONFIG — MOTION
@export_category("Motion")
@export var max_speed: float = 150.0
@export var acceleration: float = 5.0
@export var braking: float = 50.0
@export var friction: float = 15.0
@export var air_drag: float = 35.0
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
@export var gravity_mul: float = 5.0
@export var stick_force: float = 120.0
@export var slope_alignment_speed: float = 15.0 
@export var snap_length: float = 0.8
@export var slope_launch_boost: float = 10.0
@export_flags_3d_physics var ignore_align_mask: int = 0 ## Layers that won't trigger rotation or stick

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
@export var debug_console_log: bool = false
var _debug_console_throttle: float = 0.0

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
var smoothed_normal: Vector3 = Vector3.UP 
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
var current_jump_charge: float = 0.0
var base_fov: float = 75.0
var drift_input: bool = false
var can_jump: bool = false

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
	if loco_state_machine == null: 
		push_error("Loco State Machine is null, add BoardStateMachine to this player")
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
# MAIN LOOP
func _physics_process(delta: float) -> void:
	# 1. Update State & Inputs
	#_read_input(delta)
	if PlayerSFX:
		PlayerSFX._update_jump_charge(delta, is_charging_jump, is_wall_running)
		
	_read_input(delta)
	_update_air_pitch(delta)
	#_update_jump_charge(delta)
	_update_speed(delta)
	
	# Drifting
	if is_on_floor():
		drift_input = inp_drift and abs(inp_steer) > 0.1
	
	# Jumping
	can_jump = is_on_floor() or is_wall_running
	
	# 2. Physics & Momentum
	_apply_slope_momentum(delta)
	_apply_surface_gravity(delta)
	_apply_rotation(delta)
	_apply_horizontal_movement(delta)
	
	# Wall Run Detection
	_detect_wall_running()
	
	if was_wall_running and not is_wall_running:
		_on_wall_run_exit()
	
	# 3. Per-state alignment & stick
	if is_wall_running:
		smoothed_normal = smoothed_normal.lerp(wall_normal, 20.0 * delta)
		up_direction = wall_normal
		_apply_floor_stick(delta)
	elif is_on_floor():
		var raw_normal = get_floor_normal()
		smoothed_normal = smoothed_normal.lerp(raw_normal, slope_alignment_speed * delta)
		last_surface_normal = raw_normal
		air_time = 0.0
		grounded_time += delta
		up_direction = raw_normal
		_apply_floor_stick(delta)
	else:
		smoothed_normal = smoothed_normal.lerp(Vector3.UP, air_alignment_speed * delta)
		up_direction = Vector3.UP
		grounded_time = 0.0
		air_time += delta
		if air_time >= 20.0 and last_ground_position != Vector3.ZERO:
			_teleport_to_last_ground()

# 4. Execution
	if not is_charging_jump:
		if is_on_floor() or is_wall_running:
			apply_floor_snap()
		move_and_slide()


	_maintain_wall_speed()
	_apply_ramp_boost_on_leave()
	
	# 5. Post-move logic
	#_maintain_wall_speed()
	#_apply_ramp_boost_on_leave()
	_handle_landing(delta)
	_update_board_visual(delta)
	
	if PlayerSFX and PlayerSFX.has_method("_update_engine_audio"):
		PlayerSFX._update_engine_audio(current_speed, max_speed)

	if velocity.length() > max_speed:
		velocity = velocity.normalized() * max_speed
	
	
# =================================================
# SURFACE IGNORE CHECK
# Returns true if every active contact is on a layer in ignore_align_mask.
# When true, alignment and stick force are skipped for that surface.
func _surface_is_ignored() -> bool:
	if ignore_align_mask == 0: return false
	var count := get_slide_collision_count()
	if count == 0: return false
	for i in count:
		var col := get_slide_collision(i)
		var collider := col.get_collider()
		if collider == null: continue
		# If this collider's layer has ANY bits outside the ignore mask, don't ignore
		if collider.collision_layer & ~ignore_align_mask:
			return false
	return true


# =================================================
# INPUT — single source of truth, pure reads only
func _read_input(delta: float) -> void:
	inp_throttle           = Input.get_action_strength("throttle")
	inp_brake              = Input.get_action_strength("brake")
	inp_steer              = Input.get_action_strength("left") - Input.get_action_strength("right")
	inp_drift              = Input.is_action_pressed("drift")
	inp_jump_held          = Input.is_action_pressed("Jump")
	inp_pitch              = inp_throttle - inp_brake
	smoothed_input_x = lerp(smoothed_input_x, inp_steer, rotation_smoothing * delta)
	inp_pitch = inp_throttle - inp_brake
	input_dir.x = inp_steer


# =================================================
# JUMP
func _execute_jump() -> void:
	var charge_val: float = PlayerSFX.current_jump_charge if PlayerSFX else 1.0
	var force = lerp(min_jump_force, max_jump_force, current_jump_charge)
	floor_snap_length = 0.0
	
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

# W SPEED
func _update_speed(delta: float) -> void:
	if dash_timer > 0.0:
		dash_timer -= delta
		current_speed = dash_velocity
	elif is_charging_jump:
		current_speed = lerp(current_speed, 0.0, jump_charge_drag * delta)
	else:
		if is_on_floor():
			if inp_throttle > 0: current_speed = move_toward(current_speed, max_speed, acceleration * delta)
			elif inp_brake > 0: current_speed = move_toward(current_speed, 0.0, braking * delta)
			else: current_speed = move_toward(current_speed, 0.0, friction * delta)
		else:
			current_speed = move_toward(current_speed, 0.0, air_drag * delta)
		
		var dive = sin(current_air_pitch)
		current_speed += (dive_speed_gain if dive > 0 else pull_up_speed_loss) * dive * delta
	current_speed = clamp(current_speed, 0.0, max_speed)


# =================================================
# PHYSICS & ROTATION
func _apply_rotation(delta: float) -> void:
	var turn_scale = 1.0
	if is_charging_jump: turn_scale = 0.5
	elif is_drifting: turn_scale *= drift_turn_multiplier
	elif !is_on_floor(): turn_scale = air_rotation_multiplier
	rotate_object_local(Vector3.UP, smoothed_input_x * rotation_speed * turn_scale * delta)

func _apply_horizontal_movement(delta: float) -> void:
	if is_wall_running: return
	var fwd = -global_transform.basis.z
	var rgt = global_transform.basis.x
	if is_on_floor():
		velocity.x = (fwd * current_speed).x
		velocity.z = (fwd * current_speed).z
	else:
		var target_vel = (fwd * current_speed) + (rgt * smoothed_input_x * air_lateral_force)
		velocity.x = move_toward(velocity.x, target_vel.x, 30.0 * delta)
		velocity.z = move_toward(velocity.z, target_vel.z, 30.0 * delta)

func _apply_slope_momentum(delta: float) -> void:
	if !is_on_floor(): return
	var n = get_floor_normal()
	var slope = 1.0 - n.dot(Vector3.UP)
	if slope < 0.02: return
	current_speed += Vector3.DOWN.slide(n).normalized().dot(-global_transform.basis.z) * slope_accel_strength * slope * delta

func _apply_surface_gravity(delta: float) -> void:
	var g = ProjectSettings.get_setting("physics/3d/default_gravity") * gravity_mul
	if is_wall_running: g *= wall_gravity_mul
	var sn = wall_normal if is_wall_running else (last_surface_normal if is_on_floor() else Vector3.UP)
	velocity += -sn * g * delta

func _apply_floor_stick(delta: float) -> void:
	var sn = wall_normal if is_wall_running else last_surface_normal
	velocity += -sn * (wall_stick_force if is_wall_running else stick_force) * delta

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

func _detect_wall_running() -> void:
	if !enable_wall_running || is_on_floor() || current_speed < wall_run_min_speed:
		is_wall_running = false
		return
	for i in get_slide_collision_count():
		var n = get_slide_collision(i).get_normal()
		if abs(n.dot(Vector3.UP)) < 0.3:
			wall_normal = n
			is_wall_running = true
			return
	is_wall_running = false

func _maintain_wall_speed() -> void:
	if is_wall_running: velocity = velocity.slide(wall_normal).normalized() * current_speed

# =================================================
# VISUALS
func _update_board_visual(delta: float) -> void:
	if !board_target: return
	var target_tilt = -smoothed_input_x * (max_lean_angle * (drift_lean_multiplier if is_drifting else 1.0))
	current_tilt = lerp(current_tilt, target_tilt, lean_responsiveness * delta)
	var vb = Basis.IDENTITY.rotated(Vector3.FORWARD, current_tilt).rotated(Vector3.RIGHT, (crouch_tilt_amount if is_charging_jump else 0.0) + current_air_pitch)
	board_target.transform.basis = board_target.transform.basis.slerp(vb, 15.0 * delta)


func _update_air_pitch(delta: float) -> void:
	var target = inp_pitch * deg_to_rad(air_pitch_max_angle) if !is_on_floor() else 0.0
	current_air_pitch = lerp(current_air_pitch, target, (air_pitch_responsiveness if !is_on_floor() else air_pitch_return_speed) * delta)

func _on_wall_run_exit() -> void:
	last_surface_normal = Vector3.UP; up_direction = Vector3.UP

func _teleport_to_last_ground() -> void:
	global_position = last_ground_position; velocity = Vector3.ZERO; current_speed = 0.0

func _apply_ramp_boost_on_leave() -> void:
	if was_on_floor && !is_on_floor():
		var af = 1.0 - last_surface_normal.dot(Vector3.UP)
		if af > 0.15: velocity += velocity.normalized() * slope_launch_boost * af

func ChangeVelocity(vec: Vector3, force: float) -> void:
	velocity += vec * force

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
			#LocomotionState.keys()[loco_state],
			loco_state_machine.get_current_state(),
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
		if board_target:
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
