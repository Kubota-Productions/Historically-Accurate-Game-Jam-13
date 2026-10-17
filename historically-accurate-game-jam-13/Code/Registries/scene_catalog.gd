class_name SceneCatalog
extends RefCounted

const ROOMS: Dictionary[StringName, String] = {
	&"training": "res://Scenes/Levels/TrainingRoom.tscn",
	&"station": "res://Scenes/Levels/StationRoom.tscn",
}


static func create_room(id: StringName) -> LaikaRoom:
	return (load(ROOMS[id]) as PackedScene).instantiate() as LaikaRoom
