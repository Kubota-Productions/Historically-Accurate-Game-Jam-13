class_name DialogueSession
extends RefCounted

signal line_changed
signal finished(dialogue: Dialogue)
signal bark_requested

var dialogue: Dialogue
var index: int = 0
var active: bool:
	get: return dialogue != null


func open(next: Dialogue) -> bool:
	if active or next == null or next.lines.is_empty():
		return false
	dialogue = next
	index = 0
	line_changed.emit()
	return true


func current() -> DialogueLine:
	return dialogue.lines[index]


func requires_bark() -> bool:
	return active and current().bark


func advance(bark: bool) -> void:
	if not active or bark != requires_bark():
		return
	if bark:
		bark_requested.emit()
	index += 1
	if index < dialogue.lines.size():
		line_changed.emit()
		return
	var done := dialogue
	close()
	finished.emit(done)


func close() -> void:
	dialogue = null
	index = 0
