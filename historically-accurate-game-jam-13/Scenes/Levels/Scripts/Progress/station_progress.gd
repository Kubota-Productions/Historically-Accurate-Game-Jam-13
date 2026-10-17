class_name StationProgress
extends RoomProgress


func _ready() -> void:
	step = Step.ARRIVAL


func begin() -> void:
	room.objective_changed.emit(tr("Find the source of the voice"), tr("STATION  /  ARRIVAL"))
	room.dialogue_requested.emit(&"arrival")


func complete_dialogue(id: StringName) -> void:
	match id:
		&"arrival":
			room.objective_changed.emit(tr("Talk to the service robot"), tr("APPROACH THE ROBOT"))
		&"robot":
			step = Step.COMPLETE
			set_flag(&"complete", true)
			room.objective_changed.emit(tr("Playground complete"), tr("Explore freely · Esc opens the menu"))
			room.completed.emit()
