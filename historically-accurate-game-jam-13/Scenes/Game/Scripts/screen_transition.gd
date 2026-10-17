extends Node

@export var fade: ColorRect
@export var title: Label
@export var fade_out_seconds: float = 0.25
@export var fade_in_seconds: float = 0.45
@export var chapter_hold_seconds: float = 0.9
@export var menu_hold_seconds: float = 0.15
@export var intro_pause_seconds: float = 0.2

var _tween: Tween


func cover(text: String) -> void:
	title.text = tr(text)
	fade.modulate.a = 0.0
	fade.show()
	if _tween:
		_tween.kill()
	_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_tween.tween_property(fade, "modulate:a", 1.0, fade_out_seconds).set_trans(Tween.TRANS_SINE)
	await _tween.finished


func reveal() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_tween.tween_interval(chapter_hold_seconds if not title.text.is_empty() else menu_hold_seconds)
	_tween.tween_property(fade, "modulate:a", 0.0, fade_in_seconds).set_trans(Tween.TRANS_SINE)
	await _tween.finished
	if is_instance_valid(fade):
		fade.hide()
