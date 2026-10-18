@tool
class_name DisplaySettings
extends RefCounted

signal changed

enum WindowMode { WINDOWED, BORDERLESS, FULLSCREEN }

const MODE_LABELS: Dictionary[WindowMode, String] = {
	WindowMode.WINDOWED: "Windowed",
	WindowMode.BORDERLESS: "Borderless fullscreen",
	WindowMode.FULLSCREEN: "Fullscreen",
}
const MIN_SIZE := Vector2i(960, 540)
const SIZES: Array[Vector2i] = [Vector2i(960, 540), Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080), Vector2i(2560, 1440), Vector2i(3840, 2160)]

var mode := WindowMode.WINDOWED
var size := Vector2i(1280, 720)
var pending: bool = false
var _window: Window
var _saved_mode: WindowMode
var _saved_size: Vector2i
var _saved_position: Vector2i


func restore(config: ConfigFile, window: Window) -> void:
	_window = window
	var saved_mode: Variant = config.get_value("display", "window_mode", WindowMode.WINDOWED)
	mode = saved_mode if saved_mode in WindowMode.values() else WindowMode.WINDOWED
	var saved_size: Variant = config.get_value("display", "resolution", window.size)
	size = saved_size if saved_size is Vector2i and saved_size.x >= MIN_SIZE.x and saved_size.y >= MIN_SIZE.y else window.size
	_apply()


func save(config: ConfigFile) -> void:
	config.set_value("display", "window_mode", _saved_mode if pending else mode)
	config.set_value("display", "resolution", _saved_size if pending else size)


func sizes() -> Array[Vector2i]:
	var limit: Vector2i = _screen().size if _has_window() else SIZES.back()
	var result: Array[Vector2i] = SIZES.filter(func(option: Vector2i) -> bool: return option.x <= limit.x and option.y <= limit.y)
	if not size in result:
		result.append(size)
	return result


func refresh_from_window() -> void:
	if _has_window() and not pending and mode == WindowMode.WINDOWED:
		size = _window.size


func preview(new_mode: WindowMode, new_size: Vector2i) -> void:
	if pending:
		return
	_saved_mode = mode
	_saved_size = size
	_saved_position = _window.position
	mode = new_mode
	size = new_size
	pending = true
	_apply()
	changed.emit()


func confirm() -> void:
	pending = false
	changed.emit()


func revert() -> void:
	if not pending:
		return
	mode = _saved_mode
	size = _saved_size
	pending = false
	_apply()
	if _has_window() and mode == WindowMode.WINDOWED:
		_window.position = _saved_position
	changed.emit()


func _apply() -> void:
	if not _has_window():
		return
	var screen := _screen()
	size = size.clamp(MIN_SIZE, MIN_SIZE.max(screen.size))
	_window.mode = Window.MODE_WINDOWED
	_window.borderless = false
	match mode:
		WindowMode.WINDOWED:
			_window.size = size
			_window.position = screen.position + Vector2i(Vector2(screen.size - size) / 2.0)
		WindowMode.BORDERLESS:
			_window.borderless = true
			_window.size = DisplayServer.screen_get_size(_window.current_screen)
			_window.position = DisplayServer.screen_get_position(_window.current_screen)
		WindowMode.FULLSCREEN:
			_window.mode = Window.MODE_EXCLUSIVE_FULLSCREEN


func _screen() -> Rect2i:
	return DisplayServer.screen_get_usable_rect(_window.current_screen)


func _has_window() -> bool:
	return _window != null and DisplayServer.get_name() != "headless"
