class_name StationProgress
extends RoomProgress

enum Step { ARRIVAL, COMPLETE }

var step: Step = Step.ARRIVAL


func setup(owner_room: LaikaRoom) -> void:
	super.setup(owner_room)
	_flags = {&"complete": false}
	_dialogues = {&"arrival": _arrived, &"robot": _complete}


func begin() -> void:
	room.objective_changed.emit("Find the source of the voice", "STATION  /  ARRIVAL", [])
	room.dialogue_requested.emit(&"arrival")


func _arrived() -> void:
	room.objective_changed.emit("Talk to the service robot", "APPROACH THE ROBOT", [])


func _complete() -> void:
	step = Step.COMPLETE
	set_flag(&"complete", true)
	room.objective_changed.emit("Playground complete", "Explore freely · Esc opens the menu", [])
	room.completed.emit()
