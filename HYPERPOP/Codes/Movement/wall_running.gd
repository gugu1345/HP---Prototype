extends BoardState
class_name WallRunning

@onready var player: BoardController = get_parent().get_parent()

func enter_state() -> void:
	print_debug("Enter Wall_Running")

func exit_state() -> void:
	print_debug("Exit Wall_Running")

func physics_process(_delta: float) -> void:
	player.move_and_slide()
