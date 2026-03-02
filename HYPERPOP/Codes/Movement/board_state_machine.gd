# Finite State Machine. https://www.youtube.com/watch?v=ow_Lum-Agbs
# https://www.youtube.com/watch?v=2Gh5WxuAMkw
extends Node
class_name BoardStateMachine

@export var initial_state : BoardState

var current_state : BoardState
var states : Dictionary[String, BoardState] = {}

func _ready() -> void:
	for child in get_children():
		if child is BoardState:
			child.loco_state_machine = self
			states[child.name.to_lower()] = child
	
	if initial_state:
		initial_state.enter_state()
		current_state = initial_state

# Not needed as BoardController is not using func _process
# If BoardController has func _process, use with BoardState func update
func _process(delta: float) -> void:
	if current_state:
		current_state.update(delta)


func _physics_process(delta: float) -> void:
	if current_state:
		current_state.physics_process(delta)

func change_state(new_state_name: String):
	var new_state: BoardState = states.get(new_state_name.to_lower())
	
	assert(new_state, "State not found: " + new_state_name)
	
	if current_state:
		current_state.exit_state()
	
	new_state.enter_state()
	current_state = new_state

func get_current_state() -> BoardState:
	return current_state
