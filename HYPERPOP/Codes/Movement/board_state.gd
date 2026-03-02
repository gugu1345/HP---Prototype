extends Node
class_name BoardState

# =================================================
# LOCOMOTION STATE
	#GROUNDED,       # on floor, normal movement
	#DRIFTING,       # on floor, drifting
	#JUMP_CHARGING,  # on floor, charging a jump
	#AIRBORNE,       # in the air
	#WALL_RUNNING    # running along a wall
@export var loco_state_machine: BoardStateMachine

func enter_state() -> void:
	pass

func exit_state() -> void:
	pass

# Not needed as BoardController is not using func _process
# If BoardController has func _process, use with BoardStateMachine func update
func update(_delta: float) -> void:
	pass

func physics_process(_delta: float) -> void:
	pass
