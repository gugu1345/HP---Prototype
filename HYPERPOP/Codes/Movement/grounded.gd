extends BoardState
class_name Grounded

@onready var player: BoardController = get_parent().get_parent()

func enter_state() -> void:
	pass

func exit_state() -> void:
	pass

func physics_process(_delta: float) -> void:
	pass
