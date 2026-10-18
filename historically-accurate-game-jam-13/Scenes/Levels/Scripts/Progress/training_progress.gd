class_name TrainingProgress
extends RoomProgress

const FLAGS: Array[StringName] = [&"fetch", &"departure_ready"]
const EVENTS: Array[StringName] = [&"test"]
const GREETING: Dialogue = preload("res://GameData/Dialogue/Training/greeting.tres")
const TRAINED: Dialogue = preload("res://GameData/Dialogue/Training/trained.tres")

@export var socket: ItemSocket


func _ready() -> void:
	super()
	if socket:
		socket.installed.connect(_on_installed)


func begin() -> void:
	room.objective_changed.emit("Say hello to the scientist", "TRAINING  /  01", [])
	room.dialogue_requested.emit(GREETING)


func dialogue_finished(dialogue: Dialogue) -> void:
	if dialogue == GREETING:
		set_flag(&"fetch")
		room.objective_changed.emit("Bring two batteries to the training stand", "0 / %d BATTERIES", [socket.capacity])
		room.thought_requested.emit("Two things. One mouth. I can do this.")
	elif dialogue == TRAINED:
		set_flag(&"departure_ready")
		room.objective_changed.emit("Get comfortable in the capsule", "TRAINING COMPLETE", [])
		room.thought_requested.emit("My bed has buttons now.")


func handle_event(event: StringName) -> void:
	if event != &"test":
		return
	if has_flag(&"departure_ready"):
		room.thought_requested.emit("Test complete. Time to get into the capsule.")
	elif socket.is_full():
		room.dialogue_requested.emit(TRAINED)
	else:
		room.thought_requested.emit("Click. Still needs two batteries.")


func configuration_errors() -> PackedStringArray:
	return [] if socket else ["socket: choose the training stand's ItemSocket."]


func _on_installed(count: int) -> void:
	if socket.is_full():
		set_flag(&"fetch", false)
		room.objective_changed.emit("Press the test button", "%d / %d BATTERIES · READY", [count, socket.capacity])
	else:
		room.objective_changed.emit("Bring the second battery to the stand", "%d / %d BATTERIES", [count, socket.capacity])
