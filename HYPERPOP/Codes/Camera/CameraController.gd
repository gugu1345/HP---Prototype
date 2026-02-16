extends Camera3D
class_name CameraController

# =================================================
# TARGET
@export_category("Target")
@export var player : CharacterBody3D
@export var target_height_offset : float = 1.8 # Altura do foco (cabeça do player)

# =================================================
# POSITIONING (Ajuste aqui para o feeling 1:1)
@export_category("Positioning")
@export var camera_offset : Vector3 = Vector3(0, 1.2, 0) # X: Lado, Y: Altura extra, Z: Frente/Trás
@export var base_distance : float = 5.5 
@export var speed_distance_mult : float = 2.0 # O quanto ela se afasta no boost
@export var follow_lerp_speed : float = 10.0 # Quão rápido ela segue a posição

# =================================================
# FOV (Sonic Riders Style)
@export_category("Field of View")
@export var fov_base : float = 80.0
@export var fov_max : float = 115.0
@export var fov_lerp_speed : float = 3.0

# =================================================
# ROTATION & RESET
@export_category("Rotation")
@export var mouse_sensitivity : float = 0.002
@export var joy_sensitivity : float = 3.0
@export var reset_speed : float = 3.5 
@export var rotation_smoothness : float = 12.0 # Suavização da rotação (Slerp)

@export_group("Jump Effects")
@export var cam_jump_zoom_fov : float = -15.0
@export var cam_jump_zoom_dist : float = -2.0
@export var cam_jump_lerp_speed : float = 0.8

# =================================================
# STATE
var yaw : float = 0.0
var pitch : float = -0.15 # Começa levemente inclinada para baixo (Riders style)
var manual_control_timer : float = 0.0
var _cam_jump_effect_ratio : float = 0.0

# =================================================
func _ready() -> void:
	top_level = true 
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	if player:
		yaw = player.global_rotation.y

# =================================================
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		yaw -= event.relative.x * mouse_sensitivity
		pitch -= event.relative.y * mouse_sensitivity
		_reset_manual_timer()

# =================================================
func _physics_process(delta: float) -> void:
	if not player: return

	_handle_joy_input(delta)
	_update_auto_reset(delta)
	_apply_camera_logic(delta)

# =================================================
func _handle_joy_input(delta: float) -> void:
	var joy_axis = Input.get_vector("camera_left", "camera_right", "camera_up", "camera_down")
	if joy_axis.length() > 0.1:
		yaw -= joy_axis.x * joy_sensitivity * delta
		pitch -= joy_axis.y * joy_sensitivity * delta
		_reset_manual_timer()

func _reset_manual_timer():
	manual_control_timer = 1.2 # Segundos até a câmera voltar a seguir o player

# =================================================
func _update_auto_reset(delta: float) -> void:
	pitch = clamp(pitch, -0.9, 0.4) # Limita para não girar demais verticalmente
	
	var player_speed = player.velocity.length()
	
	# Reset automático se o player estiver se movendo e não houver input manual
	if player_speed > 0.5:
		manual_control_timer -= delta
		if manual_control_timer <= 0:
			var target_yaw = player.global_rotation.y
			yaw = lerp_angle(yaw, target_yaw, reset_speed * delta)
			pitch = lerp(pitch, -0.2, reset_speed * delta) 

# =================================================
func _apply_camera_logic(delta: float) -> void:
	# 1. CÁLCULO DE VELOCIDADE (Proporção 0.0 a 1.0)
	var speed_ratio = 0.0
	if "current_speed" in player and "max_speed" in player:
		speed_ratio = clamp(player.current_speed / player.max_speed, 0.0, 1.0)
	else:
		# Fallback caso as variáveis não existam no player
		speed_ratio = clamp(player.velocity.length() / 20.0, 0.0, 1.0)

	# 2. FOV DINÂMICO
	# Jump/charge effect (if the player exposes `is_charging_jump`)
	var target_effect: float = 0.0
	if "is_charging_jump" in player and player.is_charging_jump:
		target_effect = 1.0
	_cam_jump_effect_ratio = lerp(_cam_jump_effect_ratio, target_effect, cam_jump_lerp_speed * delta)

	var target_fov = fov_base + (speed_ratio * (fov_max - fov_base))
	target_fov += (_cam_jump_effect_ratio * cam_jump_zoom_fov)
	self.fov = lerp(self.fov, target_fov, fov_lerp_speed * delta)

	# 3. ROTAÇÃO (Slerp para feeling flutuante/smooth)
	var target_basis = Basis().rotated(Vector3.UP, yaw).rotated(Vector3.RIGHT, pitch)
	global_transform.basis = global_transform.basis.slerp(target_basis, rotation_smoothness * delta)

	# 4. POSIÇÃO FINAL (com jump zoom/dist effect)
	var dynamic_dist = base_distance + (speed_ratio * speed_distance_mult)
	var dist_final = dynamic_dist + (_cam_jump_effect_ratio * cam_jump_zoom_dist)

	var direction = -global_transform.basis.z
	var target_pos = player.global_position + (Vector3.UP * (target_height_offset + camera_offset.y))
	target_pos -= direction * dist_final
	target_pos += global_transform.basis.x * camera_offset.x

	global_position = global_position.lerp(target_pos, follow_lerp_speed * delta)

	# 5. OLHAR PARA O PLAYER (com suavização do look-at)
	var focus_point = player.global_position + (Vector3.UP * target_height_offset)
	focus_point += direction * (speed_ratio * 3.0)

	var look_transform = global_transform.looking_at(focus_point)
	global_transform.basis = global_transform.basis.slerp(look_transform.basis, 5.0 * delta)
