extends PanelContainer

signal finished(dialogue_id: StringName)
signal bark_requested
signal line_changed(bark_required: bool)

var active: bool = false
var _dialogue_id: StringName
var _lines: Array = []
var _index: int = 0
var _entrance: Tween
var _revision: int = 0

@onready var speaker: Label = %Speaker
@onready var line: Label = %Line
@onready var response: Label = %Response


func open(dialogue_id: StringName, lines: Array) -> void:
	close()
	_dialogue_id = dialogue_id
	_lines = lines
	_index = 0
	active = not _lines.is_empty()
	visible = active
	if active:
		_show_line()
		modulate.a = 0.0
		_animate_open.call_deferred(_revision)


func advance(bark: bool) -> void:
	if not active or bark != requires_bark():
		return
	if bark:
		bark_requested.emit()
	_index += 1
	if _index >= _lines.size():
		close()
		finished.emit(_dialogue_id)
	else:
		_show_line()


func requires_bark() -> bool:
	return active and bool(_lines[_index].get("bark", false))


func refresh_bindings() -> void:
	if not active:
		return
	var action: StringName = &"bark" if requires_bark() else &"interact"
	response.text = "[%s]  %s" % [InputHints.key(action), "Bark to answer" if requires_bark() else "Continue dialogue"]


func show_bark_feedback() -> void:
	if active and not requires_bark():
		response.text = "Woof!   [%s] Continue dialogue" % InputHints.key(&"interact")


func close() -> void:
	_revision += 1
	if _entrance:
		_entrance.kill()
	active = false
	_lines.clear()
	modulate.a = 1.0
	scale = Vector2.ONE
	hide()


func _show_line() -> void:
	var entry: Dictionary = _lines[_index]
	speaker.text = str(entry.get("speaker", "SCIENTIST"))
	line.text = str(entry.text)
	refresh_bindings()
	line_changed.emit(requires_bark())


func _animate_open(revision: int) -> void:
	if not is_inside_tree() or not active or revision != _revision:
		return
	pivot_offset = Vector2(size.x * 0.5, size.y)
	scale = Vector2.ONE * 0.985
	_entrance = create_tween().set_parallel(true)
	_entrance.tween_property(self, "modulate:a", 1.0, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_entrance.tween_property(self, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
