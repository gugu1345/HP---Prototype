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

# =================================================
# STATE
var yaw : float = 0.0
var pitch : float = -0.15 # Começa levemente inclinada para baixo (Riders style)
var manual_control_timer : float = 0.0

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
	var target_fov = fov_base + (speed_ratio * (fov_max - fov_base))
	self.fov = lerp(self.fov, target_fov, fov_lerp_speed * delta)

	# 3. ROTAÇÃO (Slerp para feeling flutuante/smooth)
	var target_basis = Basis().rotated(Vector3.UP, yaw).rotated(Vector3.RIGHT, pitch)
	global_transform.basis = global_transform.basis.slerp(target_basis, rotation_smoothness * delta)

	# 4. POSIÇÃO FINAL
	# No Riders, a câmera se afasta mais conforme a velocidade aumenta
	var dynamic_dist = base_distance + (speed_ratio * speed_distance_mult)
	
	var back_direction = global_transform.basis.z
	
	# Posição ideal = Posição do Player + Offset de Altura + (Direção Traseira * Distancia)
	# O camera_offset.y aqui permite subir a câmera sem mudar o ângulo do "LookAt"
	var target_pos = player.global_position + (Vector3.UP * (target_height_offset + camera_offset.y)) 
	target_pos += back_direction * dynamic_dist
	target_pos += global_transform.basis.x * camera_offset.x # Offset lateral (se quiser estilo ombro)

	# Suavização da posição
	global_position = global_position.lerp(target_pos, follow_lerp_speed * delta)

	# 5. OLHAR PARA O PLAYER (Com offset levemente acima)
	# O "look_ahead" dá a sensação de que a câmera antecipa a curva
	var look_target = player.global_position + (Vector3.UP * target_height_offset)
	look_at(look_target)
