class_name PlayerBindings
extends RefCounted

signal changed

const ACTIONS: Dictionary[StringName, String] = {
	&"forward": "Move forward",
	&"backwards": "Move backward",
	&"left": "Move left",
	&"right": "Move right",
	&"Jump": "Jump",
	&"interact": "Interact",
	&"drop": "Put down item",
	&"bark": "Bark",
	&"sniff": "Sniff (hold)",
}

var _defaults: Dictionary = {}


func _init() -> void:
	for action: StringName in ACTIONS:
		var definition: Dictionary = ProjectSettings.get_setting("input/" + str(action), {})
		_defaults[action] = definition.get("events", []).slice(0, 1).duplicate(true)


func assign(action: StringName, event: InputEvent) -> String:
	if not ACTIONS.has(action):
		return "Unknown control."
	if event == null:
		return "Each action needs one binding. Choose a replacement."
	if not event is InputEventKey and not event is InputEventMouseButton:
		return "Use a keyboard key or a mouse button."
	if event is InputEventKey:
		if event.physical_keycode == KEY_ESCAPE:
			return "Escape is reserved for going back. Choose another key."
		if event.physical_keycode in [KEY_SHIFT, KEY_CTRL, KEY_ALT, KEY_META]:
			return "Choose a key other than a modifier."
	for other: StringName in ACTIONS:
		if other == action:
			continue
		for binding: InputEvent in InputMap.action_get_events(other):
			if binding.is_match(event):
				return "Already assigned to %s." % ACTIONS[other]
	InputMap.action_erase_events(action)
	InputMap.action_add_event(action, event.duplicate())
	changed.emit()
	return ""


func reset() -> void:
	for action: StringName in ACTIONS:
		InputMap.action_erase_events(action)
		for event: InputEvent in _defaults[action]:
			InputMap.action_add_event(action, event.duplicate())
	changed.emit()


func save(config: ConfigFile) -> void:
	for action: StringName in ACTIONS:
		var event: InputEvent = InputMap.action_get_events(action)[0]
		var value: Dictionary = {}
		if event is InputEventKey:
			value = {"key": event.physical_keycode}
		elif event is InputEventMouseButton:
			value = {"mouse": event.button_index}
		config.set_value("bindings", action, value)


func load_saved(config: ConfigFile) -> void:
	var used: Array[InputEvent] = []
	var resolved: Dictionary = {}
	for action: StringName in ACTIONS:
		var saved: Variant = config.get_value("bindings", action, [])
		var values: Variant = [saved] if saved is Dictionary else saved
		var events: Array[InputEvent] = []
		if values is Array:
			for value: Variant in values:
				if events.size() == 1:
					break
				if not value is Dictionary:
					continue
				var event: InputEvent
				if value.has("key") and int(value.key) > 0 and int(value.key) != KEY_ESCAPE:
					event = InputEventKey.new()
					event.physical_keycode = int(value.key)
				elif value.has("mouse") and int(value.mouse) in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_XBUTTON1, MOUSE_BUTTON_XBUTTON2]:
					event = InputEventMouseButton.new()
					event.button_index = int(value.mouse)
				if event != null and not _contains(used, event):
					events.append(event)
					used.append(event)
		resolved[action] = events
	for action: StringName in ACTIONS:
		if resolved[action].is_empty():
			for event: InputEvent in _defaults[action]:
				if not _contains(used, event):
					resolved[action].append(event)
					used.append(event)
					break
		if resolved[action].is_empty():
			reset()
			return
	for action: StringName in ACTIONS:
		InputMap.action_erase_events(action)
		for event: InputEvent in resolved[action]:
			InputMap.action_add_event(action, event)
	changed.emit()


func _contains(events: Array[InputEvent], candidate: InputEvent) -> bool:
	for event: InputEvent in events:
		if event.is_match(candidate):
			return true
	return false
