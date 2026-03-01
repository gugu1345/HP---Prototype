extends Node
class_name BoardState

# Connect to child of BoardStateMachine
signal Transitioned


func enter_state() -> void:
	pass

func exit_state() -> void:
	pass

func physics_process(delta: float) -> void:
	pass
