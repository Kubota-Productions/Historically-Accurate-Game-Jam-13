extends "res://tests/support/flow_test.gd"

const ROOMS := "res://GameData/Rooms/"
const DIALOGUES := "res://GameData/Dialogue/"
const TEMPLATES := "res://Scenes/Shared/Interactables/"


func run() -> void:
	for path: String in _resources(ROOMS, ".tres"):
		await _room_is_valid(load(path))
	for path: String in _resources(DIALOGUES, ".tres"):
		_dialogue_is_valid(path)
	for path: String in _resources(TEMPLATES, ".tscn"):
		if path.ends_with("/Interactable.tscn"):
			continue
		var template: Interactable = load(path).instantiate()
		root.add_child(template)
		check(template.configuration_errors().is_empty(), "%s is ready to place: %s" % [path.get_file(), template.configuration_errors()])
		template.free()
	for action: StringName in PlayerBindings.ACTIONS:
		check(InputMap.action_get_events(action).size() == 1, "Input %s has exactly one default binding" % action)


func _room_is_valid(definition: RoomDefinition) -> void:
	check(not definition.title.is_empty() and not definition.heading.is_empty(), "%s has a title and heading" % definition.resource_path)
	var room := definition.instantiate()
	root.add_child(room)
	await process_frame
	check(room.configured, "%s is configured: %s" % [room.name, room.configuration_errors()])
	for target: Interactable in room.interactables():
		var errors := target.configuration_errors(room)
		check(errors.is_empty(), "%s/%s is valid: %s" % [room.name, room.get_path_to(target), errors])
	room.free()


func _dialogue_is_valid(path: String) -> void:
	var dialogue: Dialogue = load(path)
	check(not dialogue.lines.is_empty(), "%s has lines" % path.get_file())
	for line: DialogueLine in dialogue.lines:
		check(not line.speaker.is_empty() and not line.text.is_empty(), "%s lines have a speaker and text" % path.get_file())


func _resources(folder: String, extension: String) -> PackedStringArray:
	var paths: PackedStringArray = []
	for file: String in DirAccess.get_files_at(folder):
		if file.ends_with(extension):
			paths.append(folder + file)
	for directory: String in DirAccess.get_directories_at(folder):
		paths.append_array(_resources(folder + directory + "/", extension))
	return paths
