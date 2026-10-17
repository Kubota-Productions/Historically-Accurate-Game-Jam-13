class_name DialogueSession
extends RefCounted

signal line_changed(bark_required: bool)
signal finished(id: StringName)
signal bark_requested

var id: StringName
var lines: Array = []
var index: int = 0
var active: bool = false


func open(dialogue_id: StringName, content: Array) -> bool:
	for entry: Variant in content:
		if not entry is Dictionary or not entry.get("text") is String:
			push_error("Invalid line in dialogue: " + str(dialogue_id))
			return false
	close()
	id = dialogue_id
	lines = content.duplicate(true)
	active = not lines.is_empty()
	if active:
		line_changed.emit(requires_bark())
	return active


func current() -> Dictionary:
	return lines[index] if active else {}


func requires_bark() -> bool:
	return active and bool(current().get("bark", false))


func advance(bark: bool) -> void:
	if not active or bark != requires_bark():
		return
	if bark:
		bark_requested.emit()
	index += 1
	if index == lines.size():
		close()
		finished.emit(id)
	else:
		line_changed.emit(requires_bark())


func close() -> void:
	active = false
	index = 0
	lines = []
