class_name RocketProgress
extends RoomProgress

signal flight_started
signal flight_finished

@export_range(1.0, 180.0) var flight_seconds: float = 25.0

var elapsed: float = 0.0
var active: bool = false


func begin() -> void:
	elapsed = 0.0
	active = true
	room.objective_changed.emit("Look out into space", "LAIKA", [])
	flight_started.emit()


func _process(delta: float) -> void:
	if not active:
		return
	elapsed += delta
	if elapsed >= flight_seconds:
		active = false
		flight_finished.emit()
		room.completed.emit()
