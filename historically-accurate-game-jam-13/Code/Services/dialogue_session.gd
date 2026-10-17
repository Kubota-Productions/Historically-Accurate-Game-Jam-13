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
	var errors := content_errors(content)
	if not errors.is_empty():
		push_warning("Dialogue %s: %s" % [dialogue_id, "; ".join(errors)])
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


static func content_errors(content: Array) -> PackedStringArray:
	var errors: PackedStringArray = []
	if content.is_empty():
		errors.append("lines: add at least one line.")
	for line: int in content.size():
		var entry: Variant = content[line]
		if not entry is Dictionary or not entry.get("text") is String or entry.get("text", "").is_empty():
			errors.append("line %d: text must be a nonempty string." % (line + 1))
		elif not entry.get("speaker", "") is String or not entry.get("bark", false) is bool:
			errors.append("line %d: speaker must be text and bark must be boolean." % (line + 1))
	return errors
