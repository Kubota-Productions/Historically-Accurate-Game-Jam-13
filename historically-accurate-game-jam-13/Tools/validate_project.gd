extends SceneTree

var errors: PackedStringArray = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	errors.append_array(DialogueCatalog.configuration_errors())
	for definition: SettingDefinition in SettingsCatalog.definitions():
		for error: String in definition.configuration_errors():
			errors.append("Setting %s: %s" % [definition.id, error])
	var shell = load("res://Scenes/Game/Game.tscn").instantiate()
	root.add_child(shell)
	await process_frame
	errors.append_array(SettingsEffects.configuration_errors(shell.preferences,
		{&"player": shell.room.rig, &"dog_vision": shell.dog_vision, &"projection": shell.projection}))
	for action: StringName in PlayerBindings.ACTIONS:
		if InputMap.action_get_events(action).size() != 1:
			errors.append("Input %s: expected exactly one binding." % action)
	for id: StringName in SceneCatalog.ROOMS:
		var room := SceneCatalog.create_room(id)
		if room == null:
			errors.append("Room %s: cannot load scene." % id)
			continue
		shell.world_host.add_child(room)
		for error: String in room.configuration_errors():
			errors.append("Room %s: %s" % [id, error])
		var ids: Dictionary = {}
		for point: LaikaInteractionPoint in room.get_interactions():
			for error: String in point.configuration_errors(room):
				errors.append("%s: %s" % [point.get_path(), error])
			if not point.interaction_id.is_empty():
				if ids.has(point.interaction_id):
					errors.append("%s: duplicate interaction_id '%s'." % [point.get_path(), point.interaction_id])
				ids[point.interaction_id] = true
		room.queue_free()
	for name: String in ["Pickup", "Socket", "Talk", "Event", "Exit"]:
		var point = load("res://Scenes/Shared/Interactables/%s.tscn" % name).instantiate()
		root.add_child(point)
		for error: String in point.configuration_errors():
			errors.append("Template %s: %s" % [name, error])
		point.queue_free()
	shell.queue_free()
	await process_frame
	for error: String in errors:
		printerr(error)
	print("PROJECT_VALIDATION: %d errors" % errors.size())
	quit(0 if errors.is_empty() else 1)
