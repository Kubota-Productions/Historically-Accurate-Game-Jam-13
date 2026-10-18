@tool
class_name RoomDefinition
extends Resource

@export_file("*.tscn") var scene_path: String
@export var title: String
@export var heading: String


func instantiate() -> LaikaRoom:
	return load(scene_path).instantiate()
