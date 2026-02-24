class_name PlaySoundsFX
extends Node

# =================================================
# REFERENCES
@onready var board_controller: BoardController = $".."

# =================================================
# AUDIO PLAYERS
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
var current_jump_charge: float = 0.0
var max_charge_time: float = 0.8

# =================================================
# JUMP
func _update_jump_charge(delta: float, is_charging_jump: bool, is_wall_running: bool) -> void:
	var grounded = board_controller.is_on_floor() || is_wall_running
	if is_charging_jump && grounded:
		current_jump_charge = move_toward(current_jump_charge, 1.0, delta / max_charge_time)
		_play(sfx_jump_charge_loop)
	else:
		current_jump_charge = 0.0
		_stop(sfx_jump_charge_loop)

func play_jump_launch() -> void:
	_play_once(sfx_jump_launch)

func play_land() -> void:
	_play_once(sfx_land)

# =================================================
# ENGINE
func _update_engine_audio(current_speed: float, max_speed: float) -> void:
	if !sfx_engine_loop: return
	if current_speed > 1.0:
		_play(sfx_engine_loop)
		sfx_engine_loop.pitch_scale = lerp(0.9, 1.6, current_speed / max_speed)
	else:
		_stop(sfx_engine_loop)

# =================================================
# DRIFT
func play_drift_loop() -> void:
	_play(sfx_drift_loop)

func stop_drift_loop() -> void:
	_stop(sfx_drift_loop)

func play_dash() -> void:
	_play_once(sfx_dash)

# =================================================
# BRAKING
func play_brake() -> void:
	_play(sfx_brake)

func stop_brake() -> void:
	_stop(sfx_brake)

# =================================================
# HELPERS
func _play(player: AudioStreamPlayer3D) -> void:
	if player && !player.playing:
		player.play()

func _stop(player: AudioStreamPlayer3D) -> void:
	if player && player.playing:
		player.stop()

func _play_once(player: AudioStreamPlayer3D) -> void:
	if player:
		player.play()
