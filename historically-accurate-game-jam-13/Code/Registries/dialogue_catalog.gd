class_name DialogueCatalog
extends RefCounted

const CONVERSATIONS := {
	&"greeting": preload("res://GameData/Dialogue/Training/01_greeting.gd"),
	&"reminder": preload("res://GameData/Dialogue/Training/Optional/reminder.gd"),
	&"scientist": preload("res://GameData/Dialogue/Training/Optional/scientist.gd"),
	&"trained": preload("res://GameData/Dialogue/Training/02_trained.gd"),
	&"arrival": preload("res://GameData/Dialogue/Station/01_arrival.gd"),
	&"robot": preload("res://GameData/Dialogue/Station/02_robot.gd"),
}


static func lines(id: StringName) -> Array:
	if not CONVERSATIONS.has(id):
		push_error("Unknown dialogue: " + str(id))
		return []
	return CONVERSATIONS[id].LINES.duplicate(true)
