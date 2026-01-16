extends CharacterBody3D

@export var SPEED: float = 25.0

#move the boi based on his rotation
func _physics_process(_delta: float) -> void:
	#Get the vars
	var sprint = Input.get_action_strength("forward")
	var brake = Input.get_action_strength("brake")
	#The movement
	if sprint > 0:
		velocity = -(SPEED * transform.basis.z) # Moved backwards for some reason, so I reversed it
	if brake > 0: # TODO: FIX THE BRAKE TO SLOW DOWN INSTEAD OF HARD STOP
		velocity = Vector3.ZERO
	move_and_slide()

#Rotate the boi
func _process(delta: float) -> void:
	var input = Input.get_axis("left", "right")
	transform.basis = transform.basis.rotated(Vector3(0, 1, 0), input * PI * delta)
	transform = transform.orthonormalized()
