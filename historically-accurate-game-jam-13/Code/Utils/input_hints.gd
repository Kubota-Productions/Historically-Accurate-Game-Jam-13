@tool
class_name InputHints
extends RefCounted

const MOUSE_NAMES: Dictionary[MouseButton, String] = {
	MOUSE_BUTTON_LEFT: "LMB",
	MOUSE_BUTTON_RIGHT: "RMB",
	MOUSE_BUTTON_MIDDLE: "MMB",
	MOUSE_BUTTON_XBUTTON1: "Mouse 4",
	MOUSE_BUTTON_XBUTTON2: "Mouse 5",
}


static func key(action: StringName) -> String:
	var events: Array = InputMap.action_get_events(action) if InputMap.has_action(action) else ProjectSettings.get_setting("input/" + action, {}).get("events", [])
	var event: InputEvent = events[0] if not events.is_empty() else null
	if event is InputEventKey:
		return OS.get_keycode_string(event.physical_keycode if event.physical_keycode else event.keycode)
	if event is InputEventMouseButton:
		return TranslationServer.translate(MOUSE_NAMES.get(event.button_index, "—"))
	return "—"
