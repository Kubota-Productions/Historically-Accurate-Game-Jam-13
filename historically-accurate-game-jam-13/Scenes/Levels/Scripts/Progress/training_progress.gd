class_name TrainingProgress
extends RoomProgress

enum Step { GREETING, FETCH, POWER, CAPSULE }

@export var socket: ItemSocket

var step: Step = Step.GREETING

func setup(owner_room: LaikaRoom) -> void:
	super.setup(owner_room)
	_flags = {&"fetch": false, &"power_ready": false, &"departure_ready": false}
	_dialogues = {&"greeting": _start_fetch, &"trained": _ready_to_depart}
	_events = {&"test": _test_power}
	if socket:
		socket.installed.connect(_on_installed)


func begin() -> void:
	room.objective_changed.emit("Say hello to the scientist", "TRAINING  /  01", [])
	room.dialogue_requested.emit(&"greeting")


func configuration_errors() -> PackedStringArray:
	return [] if socket else ["socket: assign the training stand's ItemSocket."]


func _start_fetch() -> void:
	step = Step.FETCH
	set_flag(&"fetch", true)
	room.objective_changed.emit("Bring two batteries to the training stand", "0 / %d BATTERIES", [socket.capacity])
	room.thought_requested.emit("Two things. One mouth. I can do this.")


func _ready_to_depart() -> void:
	step = Step.CAPSULE
	set_flag(&"departure_ready", true)
	room.objective_changed.emit("Get comfortable in the capsule", "TRAINING COMPLETE", [])
	room.thought_requested.emit("My bed has buttons now.")


func _on_installed(_id: StringName, count: int) -> void:
	if socket.is_full():
		step = Step.POWER
		set_flag(&"fetch", false)
		set_flag(&"power_ready", true)
		room.objective_changed.emit("Press the test button", "%d / %d BATTERIES · READY", [count, socket.capacity])
	else:
		room.objective_changed.emit("Bring the second battery to the stand", "%d / %d BATTERIES", [count, socket.capacity])


func _test_power(_source: LaikaInteractionPoint) -> void:
	if step == Step.POWER:
		room.dialogue_requested.emit(&"trained")
	elif not socket.is_full():
		room.thought_requested.emit("Click. Still needs two batteries.")
	else:
		room.thought_requested.emit("Test complete. Time to get into the capsule.")
