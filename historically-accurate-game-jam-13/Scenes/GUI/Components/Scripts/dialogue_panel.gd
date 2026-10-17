extends PanelContainer

signal finished(dialogue_id: StringName)
signal bark_requested
signal line_changed(bark_required: bool)

var session := DialogueSession.new()
var _entrance: Tween
var _revision: int = 0
var active: bool:
	get: return session.active
var _dialogue_id: StringName:
	get: return session.id
var _lines: Array:
	get: return session.lines
var _index: int:
	get: return session.index

@onready var speaker: Label = %Speaker
@onready var line: Label = %Line
@onready var response: Label = %Response


func _ready() -> void:
	session.line_changed.connect(_show_line)
	session.bark_requested.connect(bark_requested.emit)
	session.finished.connect(_on_finished)


func open(dialogue_id: StringName, lines: Array) -> void:
	close()
	if session.open(dialogue_id, lines):
		show()
		modulate.a = 0.0
		_animate_open.call_deferred(_revision)


func advance(bark: bool) -> void:
	session.advance(bark)


func requires_bark() -> bool:
	return session.requires_bark()


func refresh_bindings() -> void:
	if not active:
		return
	var action: StringName = &"bark" if requires_bark() else &"interact"
	response.text = "[%s]  %s" % [InputHints.key(action), tr("Bark to answer") if requires_bark() else tr("Continue dialogue")]


func show_bark_feedback() -> void:
	if active and not requires_bark():
		response.text = tr("Woof!   [%s] Continue dialogue") % InputHints.key(&"interact")


func close() -> void:
	session.close()
	_reset_visuals()


func _reset_visuals() -> void:
	_revision += 1
	if _entrance:
		_entrance.kill()
	modulate.a = 1.0
	scale = Vector2.ONE
	hide()


func _on_finished(id: StringName) -> void:
	_reset_visuals()
	finished.emit(id)


func _show_line(bark_required: bool) -> void:
	var entry := session.current()
	speaker.text = tr(str(entry.get("speaker", "SCIENTIST")))
	line.text = tr(entry.text)
	refresh_bindings()
	line_changed.emit(bark_required)


func _animate_open(revision: int) -> void:
	if not is_inside_tree() or not active or revision != _revision:
		return
	pivot_offset = Vector2(size.x * 0.5, size.y)
	scale = Vector2.ONE * 0.985
	_entrance = create_tween().set_parallel(true)
	_entrance.tween_property(self, "modulate:a", 1.0, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_entrance.tween_property(self, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
