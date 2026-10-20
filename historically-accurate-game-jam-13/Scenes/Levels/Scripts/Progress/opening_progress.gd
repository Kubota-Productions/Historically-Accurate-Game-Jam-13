class_name OpeningProgress
extends RoomProgress

const FLAGS: Array[StringName] = [&"departure_ready"]
const GREETING: Dialogue = preload("res://GameData/Dialogue/Opening/greeting.tres")


func begin() -> void:
	room.objective_changed.emit("Listen to the scientist", "EARTH / INTRODUCTION", [])
	room.dialogue_requested.emit(GREETING)


func dialogue_finished(dialogue: Dialogue) -> void:
	if dialogue == GREETING:
		set_flag(&"departure_ready")
		room.objective_changed.emit("Continue to the preparation room", "READY FOR TRAINING", [])
