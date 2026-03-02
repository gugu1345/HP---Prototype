extends BoardState
class_name Grounded

@onready var player: BoardController = get_parent().get_parent()

func enter_state() -> void:
	print_debug("Enter Grounded")

func exit_state() -> void:
	print_debug("Exit Grounded")

func physics_process(_delta: float) -> void:
	player.move_and_slide()
