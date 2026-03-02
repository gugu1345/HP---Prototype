extends BoardState
class_name JumpCharging

@onready var player: BoardController = get_parent().get_parent()

func enter_state() -> void:
	print_debug("Enter Jump_Charging")

func exit_state() -> void:
	print_debug("Exit Jump_Charging")

func physics_process(_delta: float) -> void:
	player.move_and_slide()
