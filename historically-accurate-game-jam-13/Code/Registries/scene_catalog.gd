class_name SceneCatalog
extends RefCounted

const ROOMS := {
	&"training": {
		"scene": preload("res://Scenes/Levels/TrainingRoom.tscn"),
		"title": "01  /  A VERY GOOD EMPLOYEE",
		"heading": "01  /  EARTH · TRAINING ROOM",
	},
	&"station": {
		"scene": preload("res://Scenes/Levels/StationRoom.tscn"),
		"title": "02  /  SOMEONE ATE THE INSTRUCTIONS",
		"heading": "02  /  ORBIT · STATION",
	},
}


static func create_room(id: StringName) -> LaikaRoom:
	if not ROOMS.has(id):
		push_error("Unknown room: " + str(id))
		return null
	return ROOMS[id].scene.instantiate() as LaikaRoom
