# https://www.youtube.com/watch?v=K9JizfQ-oFU
extends RefCounted

class_name BoardInterface

# Virtual methods for states to override

func enter(prev_state: String = "") -> void:
	pass

func exit() -> void:
	pass

func physics_update(delta: float) -> void:
	pass

func handle_input(event: InputEvent) -> void:
	pass
