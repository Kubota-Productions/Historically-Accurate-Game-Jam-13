class_name StationProgress
extends RoomProgress

const FLAGS: Array[StringName] = [&"complete"]
const ARRIVAL: Dialogue = preload("res://GameData/Dialogue/Station/arrival.tres")
const ROBOT: Dialogue = preload("res://GameData/Dialogue/Station/robot.tres")


func begin() -> void:
	room.objective_changed.emit("Find the source of the voice", "STATION  /  ARRIVAL", [])
	room.dialogue_requested.emit(ARRIVAL)


func dialogue_finished(dialogue: Dialogue) -> void:
	if dialogue == ARRIVAL:
		room.objective_changed.emit("Talk to the service robot", "APPROACH THE ROBOT", [])
	elif dialogue == ROBOT:
		set_flag(&"complete")
		room.objective_changed.emit("Playground complete", "Explore freely · Esc opens the menu", [])
		room.completed.emit()
