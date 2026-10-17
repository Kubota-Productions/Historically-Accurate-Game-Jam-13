class_name TrainingProgress
extends RoomProgress

@export var socket: ItemSocket

var _dialogues: Dictionary[StringName, Callable]
var _events: Dictionary[StringName, Callable]


func setup(owner_room: LaikaRoom) -> void:
	super.setup(owner_room)
	_dialogues = {&"greeting": _start_fetch, &"trained": _ready_to_depart}
	_events = {&"test": _test_power}
	socket.installed.connect(_on_installed)


func begin() -> void:
	room.objective_changed.emit(tr("Say hello to the scientist"), tr("TRAINING  /  01"))
	room.dialogue_requested.emit(&"greeting")


func complete_dialogue(id: StringName) -> void:
	if _dialogues.has(id):
		_dialogues[id].call()


func handle_event(event: StringName, _source: LaikaInteractionPoint) -> void:
	if _events.has(event):
		_events[event].call()


func _start_fetch() -> void:
	step = Step.FETCH
	set_flag(&"fetch", true)
	room.objective_changed.emit(tr("Bring two batteries to the training stand"), tr("0 / %d BATTERIES") % socket.capacity)
	room.thought_requested.emit(tr("Two things. One mouth. I can do this."))


func _ready_to_depart() -> void:
	step = Step.CAPSULE
	set_flag(&"departure_ready", true)
	room.objective_changed.emit(tr("Get comfortable in the capsule"), tr("TRAINING COMPLETE"))
	room.thought_requested.emit(tr("My bed has buttons now."))


func _on_installed(_id: StringName, count: int) -> void:
	if socket.is_full():
		step = Step.POWER
		set_flag(&"fetch", false)
		set_flag(&"power_ready", true)
		room.objective_changed.emit(tr("Press the test button"), tr("%d / %d BATTERIES · READY") % [count, socket.capacity])
	else:
		room.objective_changed.emit(tr("Bring the second battery to the stand"), tr("%d / %d BATTERIES") % [count, socket.capacity])


func _test_power() -> void:
	if step == Step.POWER:
		room.dialogue_requested.emit(&"trained")
	elif not socket.is_full():
		room.thought_requested.emit(tr("Click. Still needs two batteries."))
	else:
		room.thought_requested.emit(tr("Test complete. Time to get into the capsule."))


func get_item_count() -> int:
	return socket.count
