class_name PlayerBindings
extends RefCounted

signal changed

const ACTIONS: Dictionary[StringName, String] = {
	&"forward": "Move forward",
	&"backwards": "Move backward",
	&"left": "Move left",
	&"right": "Move right",
	&"jump": "Jump",
	&"interact": "Interact",
	&"drop": "Put down item",
	&"bark": "Bark",
	&"sniff": "Sniff (hold)",
}
const MOUSE_BUTTONS: Array[MouseButton] = [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_XBUTTON1, MOUSE_BUTTON_XBUTTON2]
const MODIFIERS: Array[Key] = [KEY_SHIFT, KEY_CTRL, KEY_ALT, KEY_META]

var _defaults: Dictionary[StringName, InputEvent] = {}


func _init() -> void:
	for action: StringName in ACTIONS:
		_defaults[action] = ProjectSettings.get_setting("input/" + action).events[0]


static func normalized(event: InputEvent) -> InputEvent:
	if event is InputEventKey:
		var key := InputEventKey.new()
		key.physical_keycode = event.physical_keycode if event.physical_keycode else event.keycode
		return key
	if event is InputEventMouseButton:
		var mouse := InputEventMouseButton.new()
		mouse.button_index = event.button_index
		return mouse
	return null


func problem(action: StringName, event: InputEvent) -> String:
	var unusable := _unusable(event)
	if not unusable.is_empty():
		return unusable
	for other: StringName in ACTIONS:
		if other != action and event_for(other).is_match(event):
			return tr("Already assigned to %s.") % tr(ACTIONS[other])
	return ""


func assign(action: StringName, event: InputEvent) -> void:
	InputMap.action_erase_events(action)
	InputMap.action_add_event(action, event)
	changed.emit()


func event_for(action: StringName) -> InputEvent:
	return InputMap.action_get_events(action)[0]


func reset() -> void:
	for action: StringName in ACTIONS:
		InputMap.action_erase_events(action)
		InputMap.action_add_event(action, _defaults[action])
	changed.emit()


func save(config: ConfigFile) -> void:
	for action: StringName in ACTIONS:
		var event := event_for(action)
		if event is InputEventKey:
			config.set_value("bindings", action, {"key": event.physical_keycode})
		else:
			config.set_value("bindings", action, {"mouse": event.button_index})


func restore(config: ConfigFile) -> void:
	var loaded: Dictionary[StringName, InputEvent] = {}
	for action: StringName in ACTIONS:
		var event := _decode(config.get_value("bindings", action, {}))
		loaded[action] = event if event and _unusable(event).is_empty() else _defaults[action]
	for action: StringName in ACTIONS:
		if loaded.values().filter(loaded[action].is_match).size() > 1:
			reset()
			return
	for action: StringName in loaded:
		InputMap.action_erase_events(action)
		InputMap.action_add_event(action, loaded[action])
	changed.emit()


func _unusable(event: InputEvent) -> String:
	if event is InputEventKey and event.physical_keycode == KEY_ESCAPE:
		return tr("Escape is reserved for going back. Choose another key.")
	if event is InputEventKey and event.physical_keycode in MODIFIERS:
		return tr("Choose a key other than a modifier.")
	if not event is InputEventKey and not (event is InputEventMouseButton and event.button_index in MOUSE_BUTTONS):
		return tr("Use a keyboard key or a mouse button.")
	return ""


func _decode(value: Variant) -> InputEvent:
	if value is Dictionary and value.get("key") is int:
		var key := InputEventKey.new()
		key.physical_keycode = value.key
		return key
	if value is Dictionary and value.get("mouse") is int:
		var mouse := InputEventMouseButton.new()
		mouse.button_index = value.mouse
		return mouse
	return null
