extends BoardState
class_name Drifting

@onready var player: BoardController = get_parent().get_parent()

func enter_state() -> void:
	print_debug("Enter Drifting")

func exit_state() -> void:
	print_debug("Exit Drifting")

func physics_process(_delta: float) -> void:
	player.move_and_slide()
