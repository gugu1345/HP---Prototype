extends BoardState
class_name Airborne

@onready var player: BoardController = get_parent().get_parent()

func enter_state() -> void:
	print_debug("Enter Airborne")

func exit_state() -> void:
	print_debug("Exit Airborne")

func physics_process(_delta: float) -> void:
	player.move_and_slide()
