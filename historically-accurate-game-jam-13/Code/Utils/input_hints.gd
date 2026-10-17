class_name InputHints
extends RefCounted


static func key(action: StringName) -> String:
	var events := InputMap.action_get_events(action)
	return event_text(events[0]) if not events.is_empty() else "—"


static func event_text(event: InputEvent) -> String:
	if event is InputEventKey:
		return OS.get_keycode_string(event.physical_keycode if event.physical_keycode else event.keycode)
	if event is InputEventMouseButton:
		return {MOUSE_BUTTON_LEFT: "LMB", MOUSE_BUTTON_RIGHT: "RMB", MOUSE_BUTTON_MIDDLE: "MMB", MOUSE_BUTTON_XBUTTON1: "Mouse 4", MOUSE_BUTTON_XBUTTON2: "Mouse 5"}.get(event.button_index, "Mouse")
	return "—"
