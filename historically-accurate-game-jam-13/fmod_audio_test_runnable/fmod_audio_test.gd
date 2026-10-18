extends Node3D

# Audio Test: Run Curren Scene and press up to play the sound, right to change it
# to a squeaky one and left to change it back to a button one.

@onready var emitter: FmodEventEmitter3D = $FmodEventEmitter3D


func _process(delta: float) -> void:
	# Example of an emitter being called to play an event.
	if Input.is_action_just_pressed("forward"):
		emitter.play()

	# Example of an emitter being called to change a parameter of its event
	if Input.is_action_just_pressed("right"):
		emitter.set_parameter("character", "dog")

	if Input.is_action_just_pressed("left"):
		emitter.set_parameter("character", "human")
