extends CharacterBody3D
class_name BoardController

# =================================================
# CONFIG — MOTION
@export_category("Motion")
@export var max_speed: float = 90.0
@export var acceleration: float = 20.0
@export var braking: float = 50.0
@export var friction: float = 15.0
@export var air_drag: float = 5.0
@export var rotation_speed: float = 1.5

# =================================================
# CONFIG — JUMP & CHARGE
@export_category("Jump")
@export var min_jump_force: float = 12.0
@export var max_jump_force: float = 35.0
@export var max_charge_time: float = 0.8
@export var jump_charge_drag: float = 0.3 # <--- Ajustado para funcionar com Lerp (Progressivo)

# =================================================
# CONFIG — PHYSICS
@export_category("Physics")
@export var gravity_mul: float = 3.0
@export var stick_force: float = 120.0 # Increased to stick better to slopes
@export var slope_alignment_speed: float = 22.0
@export var snap_length: float = 0.8 # Snap distance to keep grounded on slopes

# =================================================
# CONFIG — SLOPE MOMENTUM
@export_category("Slope Momentum")
@export var slope_accel_strength: float = 22.0

# =================================================
# CONFIG — VISUALS & LEAN
@export_category("Visuals")
@export var board_mesh: Node3D
@export var board_target: Node3D
@export var visual_spring_strength: float = 350.0
@export var visual_spring_damping: float = 30.0

@export_group("Lean Settings")
@export var max_lean_angle: float = 0.6
@export var drift_lean_multiplier: float = 1.5
@export var lean_responsiveness: float = 8.0
@export var crouch_tilt_amount: float = -0.12

# =================================================
# CONFIG — CAMERA (SONIC RIDERS STYLE)
@export_category("Camera System")
@export var camera_node: Camera3D
@export var cam_target_height: float = 1.8 
@export var cam_base_offset: Vector3 = Vector3(0, 1.2, 0)
@export var cam_base_dist: float = 8.5
@export var cam_speed_dist_add: float = 0.9
@export var cam_fov_base: float = 70.0
@export var cam_fov_max: float = 90.0
@export var cam_follow_speed: float = 10.0
@export var cam_rotation_smoothness: float = 12.0

@export_group("Camera Jump Effects")
@export var cam_jump_zoom_fov: float = -15.0 
@export var cam_jump_zoom_dist: float = -2.0 
@export var cam_jump_lerp_speed: float = 0.8 # <--- Reduzido para ser bem lento e dramático

@export_group("Camera Controls")
@export var cam_mouse_sens: float = 0.002
@export var cam_joy_sens: float = 3.0
@export var cam_auto_reset_speed: float = 3.5

# =================================================
# CONFIG — DRIFT
@export_category("Drift")
@export var drift_min_speed: float = 10.0
@export var drift_turn_multiplier: float = 3.0
@export var drift_max_charge_time: float = 1.2
@export var drift_dash_force: float = 50.0
@export var drift_dash_duration: float = 0.2
@export var drift_deceleration_rate: float = 8.0

# =================================================
# CONFIG — AUDIO
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
var previous_speed: float = 0.0
var input_dir: Vector2 = Vector2.ZERO
var was_on_floor: bool = true

# Jump
var current_jump_charge: float = 0.0
var is_charging_jump: bool = false

# Visual/Drift
var board_y_velocity: float = 0.0
var current_tilt: float = 0.0
var is_drifting: bool = false
var drift_charge: float = 0.0
var dash_timer: float = 0.0
var dash_velocity: float = 0.0

# Camera State
var _cam_yaw: float = 0.0
var _cam_pitch: float = -0.15 
var _cam_manual_timer: float = 0.0
var _cam_jump_effect_ratio: float = 0.0 

# =================================================
# MAIN LOOP
func _ready() -> void:
	if camera_node:
		camera_node.top_level = true 
		_cam_yaw = global_rotation.y
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and camera_node:
		_cam_yaw -= event.relative.x * cam_mouse_sens
		_cam_pitch -= event.relative.y * cam_mouse_sens
		_cam_manual_timer = 1.2

func _physics_process(delta: float) -> void:
	set_floor_max_angle(deg_to_rad(170))
	set_floor_snap_length(snap_length) # Enable floor snapping
	previous_speed = current_speed

	_read_input()
	_update_jump_charge(delta)
	_update_drift(delta)
	_update_speed(delta)
	_apply_slope_momentum(delta)
	_apply_surface_gravity(delta)
	_apply_rotation(delta)
	_apply_horizontal_movement()
	_apply_floor_stick(delta)
	_align_to_surface(delta)

	move_and_slide()

	_handle_landing()
	_update_board_visual(delta)
	_update_camera_riders(delta)
	_update_engine_audio()
	
	was_on_floor = is_on_floor()

# =================================================
# INPUT & SPEED
func _read_input() -> void:
	input_dir.x = Input.get_axis("right", "left")


	is_charging_jump = Input.is_action_pressed("Jump") and is_on_floor()

	if Input.is_action_just_released("Jump") and is_on_floor():
		_execute_jump()

func _update_speed(delta: float) -> void:
	if dash_timer > 0.0:
		dash_timer -= delta
		current_speed = dash_velocity
		return

	# --- ATUALIZADO: Freio Progressivo (Lerp) ---
	if is_charging_jump:
		# Lerp cria uma curva suave: freia mais no começo e suaviza no final
		current_speed = lerp(current_speed, 0.0, jump_charge_drag * delta)
		return 

	var throttle: float = Input.get_action_strength("throttle") if InputMap.has_action("throttle") else Input.get_action_strength("ui_up")
	var brake: float = Input.get_action_strength("brake") if InputMap.has_action("brake") else Input.get_action_strength("ui_down")

	if throttle > 0.0:
		current_speed = move_toward(current_speed, max_speed, acceleration * delta)
	elif brake > 0.0:
		current_speed = move_toward(current_speed, 0.0, braking * delta)
		if sfx_brake and not sfx_brake.playing: sfx_brake.play()
	else:
		var drag: float = friction if is_on_floor() else air_drag
		current_speed = move_toward(current_speed, 0.0, drag * delta)

# =================================================
# JUMP
func _update_jump_charge(delta: float) -> void:
	if is_charging_jump:
		# Também suavizei levemente o carregamento da barra de força
		current_jump_charge = move_toward(current_jump_charge, 1.0, (delta / max_charge_time) * 0.9)
		if sfx_jump_charge_loop and not sfx_jump_charge_loop.playing: sfx_jump_charge_loop.play()
		if sfx_jump_charge_loop:
			sfx_jump_charge_loop.pitch_scale = 1.0 + current_jump_charge * 0.8
	else:
		if sfx_jump_charge_loop and sfx_jump_charge_loop.playing: sfx_jump_charge_loop.stop()

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
	if not is_on_floor(): return
	var normal: Vector3 = get_floor_normal()
	var slope: float = 1.0 - normal.dot(Vector3.UP)
	if slope < 0.02: return
	var downhill: Vector3 = Vector3.DOWN.slide(normal).normalized()
	var alignment: float = downhill.dot(-transform.basis.z)
	current_speed += alignment * slope_accel_strength * slope * delta
	current_speed = clamp(current_speed, 0.0, max_speed * 2.0)

func _apply_surface_gravity(delta: float) -> void:
	var g: float = ProjectSettings.get_setting("physics/3d/default_gravity") * gravity_mul
	if is_on_floor(): velocity += -get_floor_normal() * g * delta
	else: velocity.y -= g * delta

func _apply_rotation(delta: float) -> void:
	var turn_scale: float = 0.5 if is_charging_jump else 1.0
	if is_drifting: turn_scale *= drift_turn_multiplier * clamp(current_speed / max_speed, 0.5, 1.0)
	if abs(current_speed) > 1.0 or is_drifting:
		rotate_object_local(Vector3.UP, input_dir.x * rotation_speed * turn_scale * delta)

func _apply_horizontal_movement() -> void:
	var forward: Vector3 = -transform.basis.z
	velocity.x = forward.x * current_speed
	velocity.z = forward.z * current_speed

func _apply_floor_stick(delta: float) -> void:
	if not is_on_floor(): return
	
	# Scale stick force based on speed (more speed = more stick needed)
	var stick: float = stick_force * clamp(current_speed / max_speed, 0.6, 2.5)
	
	# Apply stronger stick force when going down slopes
	var floor_normal = get_floor_normal()
	var slope_factor = 1.0 - floor_normal.dot(Vector3.UP)
	if slope_factor > 0.1:
		stick *= 1.0 + (slope_factor * 1.5) # Increase stick on slopes
	
	velocity -= floor_normal * stick * delta
	
	# Dampen any upward velocity component when on ground
	var upward_velocity = velocity.dot(floor_normal)
	if upward_velocity > 0:
		velocity -= floor_normal * upward_velocity * 0.5

func _align_to_surface(delta: float) -> void:
	var target_up: Vector3 = get_floor_normal() if is_on_floor() else Vector3.UP
	var target: Transform3D = global_transform
	target.basis.y = target_up
	target.basis.x = -target.basis.z.cross(target_up)
	target.basis = target.basis.orthonormalized()
	global_transform = global_transform.interpolate_with(target, slope_alignment_speed * delta)

# =================================================
# VISUALS
func _update_board_visual(delta: float) -> void:
	if not board_mesh or not board_target: return
	
	var displacement: float = board_target.global_position.y - board_mesh.global_position.y
	board_y_velocity += (displacement * visual_spring_strength - board_y_velocity * visual_spring_damping) * delta
	board_mesh.global_position.y += board_y_velocity * delta
	board_mesh.global_position.x = board_target.global_position.x
	board_mesh.global_position.z = board_target.global_position.z

	var lean_mult: float = drift_lean_multiplier if is_drifting else 1.0
	var target_tilt: float = -input_dir.x * (max_lean_angle * lean_mult) * clamp(current_speed / max_speed, 0.2, 1.2)
	current_tilt = lerp(current_tilt, target_tilt, lean_responsiveness * delta)

	var visual_basis: Basis = global_transform.basis
	visual_basis = visual_basis.rotated(global_transform.basis.z, current_tilt)
	visual_basis = visual_basis.rotated(global_transform.basis.x, crouch_tilt_amount if is_charging_jump else 0.0)
	board_mesh.global_transform.basis = board_mesh.global_transform.basis.slerp(visual_basis.orthonormalized(), 20.0 * delta)

# =================================================
# CAMERA LOGIC (UPDATED PROGRESSIVE)
func _update_camera_riders(delta: float) -> void:
	if not camera_node: return

	var joy_axis = Input.get_vector("camera_left", "camera_right", "camera_up", "camera_down")
	if joy_axis.length() > 0.1:
		_cam_yaw -= joy_axis.x * cam_joy_sens * delta
		_cam_pitch -= joy_axis.y * cam_joy_sens * delta
		_cam_manual_timer = 1.2
	
	_cam_pitch = clamp(_cam_pitch, -0.9, 0.5)

	if current_speed > 1.0:
		_cam_manual_timer -= delta
		if _cam_manual_timer <= 0:
			var target_yaw = global_rotation.y
			_cam_yaw = lerp_angle(_cam_yaw, target_yaw, cam_auto_reset_speed * delta)
			_cam_pitch = lerp(_cam_pitch, -0.15, cam_auto_reset_speed * delta)

	# --- ATUALIZADO: Zoom mais lento e progressivo ---
	var target_effect = 1.0 if is_charging_jump else 0.0
	_cam_jump_effect_ratio = lerp(_cam_jump_effect_ratio, target_effect, cam_jump_lerp_speed * delta)

	var speed_ratio = clamp(current_speed / max_speed, 0.0, 1.0)
	var fov_target = cam_fov_base + (speed_ratio * (cam_fov_max - cam_fov_base))
	
	fov_target += (_cam_jump_effect_ratio * cam_jump_zoom_fov)
	camera_node.fov = lerp(camera_node.fov, fov_target, delta * 4.0)

	var dist_final = cam_base_dist + (speed_ratio * cam_speed_dist_add)
	dist_final += (_cam_jump_effect_ratio * cam_jump_zoom_dist)

	var cam_basis = Basis().rotated(Vector3.UP, _cam_yaw).rotated(Vector3.RIGHT, _cam_pitch)
	camera_node.global_transform.basis = camera_node.global_transform.basis.slerp(cam_basis, cam_rotation_smoothness * delta)

	var direction = -camera_node.global_transform.basis.z
	var target_pos = global_position 
	target_pos += Vector3.UP * (cam_target_height + cam_base_offset.y) 
	target_pos -= direction * dist_final
	
	camera_node.global_position = camera_node.global_position.lerp(target_pos, cam_follow_speed * delta)
	
	var focus_point = global_position + Vector3.UP * cam_target_height
	focus_point += direction * (speed_ratio * 3.0) 
	
	var look_transform = camera_node.global_transform.looking_at(focus_point)
	camera_node.global_transform.basis = camera_node.global_transform.basis.slerp(look_transform.basis, 5.0 * delta)

# =================================================
# AUDIO ENGINE
func _update_engine_audio() -> void:
	if not sfx_engine_loop: return
	if current_speed > 1.0:
		if not sfx_engine_loop.playing: sfx_engine_loop.play()
		sfx_engine_loop.pitch_scale = lerp(0.9, 1.6, current_speed / max_speed)
	else:
		if sfx_engine_loop.playing: sfx_engine_loop.stop()
