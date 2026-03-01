# Finite State Machine. https://www.youtube.com/watch?v=ow_Lum-Agbs
extends BoardController
class_name BoardStateMachine

@export var initial_state : BoardState

var current_state : BoardState
var states : Dictionary = {}

func _ready() -> void:
	for child in get_children():
		if child is BoardState:
			states[child.name.to_lower()] = child
			child.Transitioned.connect(transition)
	
	if initial_state:
		initial_state.enter_state()
		current_state = initial_state


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta: float) -> void:
	if current_state:
		current_state._physics_process(delta)

func transition(state, new_state_name):
	if state != current_state:
		return
	
	var new_state = states.get(new_state_name.to_lower())
	if !new_state:
		return
	
	if current_state:
		current_state.exit_state()
	
	new_state.enter_state()
	
	current_state = new_state
