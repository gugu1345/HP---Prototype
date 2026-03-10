extends Node3D

@export var player: CharacterBody3D

func _ready() -> void:
	if player == null:
		push_warning("player is null, add player to game manager")

func _process(delta: float) -> void:
	reset_level(player)

func reset_level(player: CharacterBody3D) -> void:
	var out_of_bound_floor = -500
	if player.global_position.y < out_of_bound_floor: get_tree().reload_current_scene()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("reset_level"): get_tree().reload_current_scene()
