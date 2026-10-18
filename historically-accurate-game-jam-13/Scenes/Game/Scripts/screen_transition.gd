class_name ScreenTransition
extends Node

@export var fade: ColorRect
@export var title: Label
@export var fade_out_seconds: float = 0.25
@export var fade_in_seconds: float = 0.45
@export var chapter_hold_seconds: float = 0.9
@export var menu_hold_seconds: float = 0.15
@export var intro_pause_seconds: float = 0.2

var _tween: Tween
var _hold_seconds: float


func cover(text: String) -> void:
	title.text = tr(text)
	_hold_seconds = menu_hold_seconds if text.is_empty() else chapter_hold_seconds
	fade.modulate.a = 0.0
	fade.show()
	await _fade_to(1.0, fade_out_seconds, 0.0)


func reveal() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await _fade_to(0.0, fade_in_seconds, _hold_seconds)
	fade.hide()


func clear() -> void:
	if _tween:
		_tween.kill()
	fade.hide()


func _fade_to(alpha: float, seconds: float, delay: float) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_tween.tween_property(fade, "modulate:a", alpha, seconds).set_trans(Tween.TRANS_SINE).set_delay(delay)
	await _tween.finished
