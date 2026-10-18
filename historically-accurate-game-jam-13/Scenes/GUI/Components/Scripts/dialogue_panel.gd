class_name DialoguePanel
extends PanelContainer

@export var fade_seconds: float = 0.4
@export var grow_seconds: float = 0.45
@export var start_scale: float = 0.985

var session := DialogueSession.new()
var entrance: Tween

@onready var speaker: Label = %Speaker
@onready var line: Label = %Line
@onready var response: Label = %Response


func _ready() -> void:
	session.line_changed.connect(_show_line)
	session.finished.connect(func(_dialogue: Dialogue) -> void: _hide())
	resized.connect(func() -> void: pivot_offset = Vector2(size.x * 0.5, size.y))


func open(dialogue: Dialogue) -> bool:
	if not session.open(dialogue):
		return false
	show()
	if entrance:
		entrance.kill()
	modulate.a = 0.0
	scale = Vector2.ONE * start_scale
	entrance = create_tween().set_parallel()
	entrance.tween_property(self, "modulate:a", 1.0, fade_seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	entrance.tween_property(self, "scale", Vector2.ONE, grow_seconds).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	return true


func close() -> void:
	session.close()
	_hide()


func refresh_bindings() -> void:
	if not session.active:
		return
	if session.requires_bark():
		response.text = "[%s]  %s" % [InputHints.key(&"bark"), tr("Bark to answer")]
	else:
		response.text = "[%s]  %s" % [InputHints.key(&"interact"), tr("Continue dialogue")]


func show_bark_feedback() -> void:
	response.text = tr("Woof!   [%s] Continue dialogue") % InputHints.key(&"interact")


func _show_line() -> void:
	speaker.text = tr(session.current().speaker)
	line.text = tr(session.current().text)
	refresh_bindings()


func _hide() -> void:
	if entrance:
		entrance.kill()
	modulate.a = 1.0
	scale = Vector2.ONE
	hide()
