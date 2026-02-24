extends Camera3D
class_name CameraController

# =================================================
# TARGET
@export var player : CharacterBody3D
@export var target_height : float = 4

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
# DISTANCE SETTINGS
@export_category("Distance")
@export var idle_distance : float = 14
@export var normal_distance : float = 8
@export var max_distance : float = 2
@export var ramp_distance_boost : float = 0.6
@export var distance_smooth : float = 4.0

# =================================================
# HEIGHT & RAMP RESPONSE
@export_category("Height")
@export var base_height : float = 4
@export var ramp_height_adjust : float = 1.1
@export var height_smooth : float = 6.0

# =================================================
# FOV 
@export_category("FOV")
@export var fov_idle : float = 72.0
@export var fov_speed : float = 96.0
@export var fov_boost : float = 104.0
@export var fov_speed_lerp : float = 10.0

# =================================================
# LOOK & ROTATION
@export_category("Rotation")
@export var mouse_sensitivity := 0.002
@export var stick_sensitivity := 3.0
@export var auto_align_speed := 6.0
@export var rotation_smooth := 10.0

@export_group("Jump Effects")
@export var cam_jump_zoom_fov : float = -15.0
@export var cam_jump_zoom_dist : float = -2.0
@export var cam_jump_lerp_speed : float = 0.8

# =================================================
# CINEMATIC FX
@export_category("Cinematic")
@export var look_ahead_strength : float = 3.0
@export var turn_roll_strength : float = 0.35
@export var drift_roll_multiplier : float = 1.8
@export var inertia_strength : float = 6.0

# =================================================
# INTERNAL STATE
var yaw := 0.0
var pitch := -0.18
var roll := 0.0

var current_distance := 4.5
var current_height := 1.5
var velocity_offset := Vector3.ZERO
var base_fov: float = 75.0
# =================================================
func _ready():
	if camera_node:
		base_fov = camera_node.fov
	top_level = true
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	if player:
		yaw = player.global_rotation.y + PI

# =================================================
func _unhandled_input(event):
	if event is InputEventMouseMotion:
		yaw -= event.relative.x * mouse_sensitivity
		pitch -= event.relative.y * mouse_sensitivity

# =================================================
func _physics_process(delta):
	if not player:
		return

	_handle_stick_input(delta)
	_auto_align(delta)
	_update_camera(delta)

# =================================================
func _handle_stick_input(delta):
	var axis = Input.get_vector("camera_left","camera_right","camera_up","camera_down")
	if axis.length() > 0.1:
		yaw -= axis.x * stick_sensitivity * delta
		pitch -= axis.y * stick_sensitivity * delta

# =================================================
func _auto_align(delta):
	var speed = player.velocity.length()

	if speed > 1.0:
		var target_yaw = player.global_rotation.y + PI
		yaw = lerp_angle(yaw, target_yaw, auto_align_speed * delta)

		var speed_ratio = clamp(speed / 40.0, 0, 1)
		var target_pitch = -0.22 + speed_ratio * 0.12
		pitch = lerp(pitch, target_pitch, auto_align_speed * delta)

	pitch = clamp(pitch, -0.9, 0.45)

# =================================================
func _update_camera(delta):

	var speed = player.velocity.length()
	var speed_ratio = clamp(speed / 40.0, 0.0, 1.0)

	# =========================================
	# DYNAMIC DISTANCE
	var target_dist = normal_distance

	if speed < 1.0:
		target_dist = idle_distance
	else:
		target_dist = lerp(normal_distance, max_distance, speed_ratio)

	# RAMP DETECTION
	var up_dot = player.global_transform.basis.y.dot(Vector3.UP)
	var ramp_factor = clamp(1.0 - up_dot, 0.0, 1.0)

	target_dist += ramp_factor * ramp_distance_boost

	current_distance = lerp(current_distance, target_dist, distance_smooth * delta)

	# =========================================
	# DYNAMIC HEIGHT
	var target_height_pos = base_height + ramp_factor * ramp_height_adjust
	current_height = lerp(current_height, target_height_pos, height_smooth * delta)

	# =========================================
	# DYNAMIC FOV
	var target_fov = lerp(fov_idle, fov_speed, speed_ratio)
	if "dash_timer" in player and player.dash_timer > 0:
		target_fov = fov_boost

	fov = lerp(fov, target_fov, fov_speed_lerp * delta)

	# =========================================
	# CAMERA DIRECTION
	var dir = Vector3(
		sin(yaw) * cos(pitch),
		sin(pitch),
		cos(yaw) * cos(pitch)
	).normalized()

	# BASE POSITION
	var target_pos = player.global_position + Vector3.UP * current_height
	target_pos -= dir * current_distance

	# =========================================
	# INERTIA
	var desired_offset = -player.velocity * 0.015
	velocity_offset = velocity_offset.lerp(desired_offset, inertia_strength * delta)
	target_pos += velocity_offset

	global_position = global_position.lerp(target_pos, 8.0 * delta)

	# =========================================
	# LOOK AHEAD 
	var look_target = player.global_position + Vector3.UP * target_height

	if speed > 1:
		look_target += player.velocity.normalized() * look_ahead_strength * speed_ratio

	look_at(look_target)

	# =========================================
	# ROLL 
	var turn_amount = wrapf((player.global_rotation.y + PI) - yaw, -PI, PI)
	var drift_mult = drift_roll_multiplier if ("is_drifting" in player and player.is_drifting) else 1.0

	var target_roll = -turn_amount * turn_roll_strength * drift_mult
	roll = lerp(roll, target_roll, 6.0 * delta)
	roll = clamp(roll, -0.5, 0.5)

	var view_dir = (look_target - global_position).normalized()
	global_transform.basis = global_transform.basis.rotated(view_dir, roll)

	# =========================================
	# ALIGN WITH SLOPES
	var target_up = player.global_transform.basis.y
	var aligned_basis = global_transform.basis
	aligned_basis.y = aligned_basis.y.slerp(target_up, 10.0 * delta)
	aligned_basis = aligned_basis.orthonormalized()

	global_transform.basis = global_transform.basis.slerp(aligned_basis, rotation_smooth * delta)
# =================================================
func _update_camera_logic(delta: float,is_drifting:bool) -> void:
	if !camera_node: return
	camera_node.fov = lerp(camera_node.fov, drift_fov_target if is_drifting else base_fov, fov_lerp_speed * delta)
	var target_quat = global_transform.basis.get_rotation_quaternion()
	var current_quat = camera_node.global_transform.basis.get_rotation_quaternion()
	camera_node.global_transform.basis = Basis(current_quat.slerp(target_quat, rotation_lerp_speed * delta))
	var back_dir = camera_node.global_transform.basis.z
	var target_cam_pos = global_position + (back_dir * 5.0)
	camera_node.global_position = camera_node.global_position.lerp(target_cam_pos, move_lerp_speed * delta)
