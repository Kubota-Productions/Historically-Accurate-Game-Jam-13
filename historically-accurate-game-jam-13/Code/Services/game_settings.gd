class_name GameSettings
extends RefCounted

signal changed
signal display_changed

enum WindowMode { WINDOWED, BORDERLESS, FULLSCREEN }

const PATH := "user://settings.cfg"
const DISPLAY_CONFIRM_SECONDS := 15

var sound_volume: float = 0.7
var music_volume: float = 0.7
var sensitivity: float = 0.1
var dog_vision: bool = false
var window_mode: WindowMode = WindowMode.WINDOWED
var resolution := Vector2i(1280, 720)
var bindings := PlayerBindings.new()
var display_pending: bool = false
var display_deadline: int = 0
var _previous_display: Dictionary = {}
var _window: Window


func initialize(window: Window) -> void:
	_window = window
	resolution = _window.size
	var config := ConfigFile.new()
	if config.load(PATH) == OK:
		sound_volume = clampf(float(config.get_value("audio", "sound_volume", config.get_value("audio", "volume", 0.7))), 0.0, 1.0)
		music_volume = clampf(float(config.get_value("audio", "music_volume", 0.7)), 0.0, 1.0)
		sensitivity = clampf(float(config.get_value("input", "sensitivity", 0.1)), 0.03, 0.3)
		dog_vision = bool(config.get_value("display", "dog_vision", false))
		window_mode = clampi(int(config.get_value("display", "window_mode", 0)), 0, 2) as WindowMode
		var saved_size: Variant = config.get_value("display", "resolution", resolution)
		if saved_size is Vector2i and saved_size.x >= 960 and saved_size.y >= 540:
			resolution = saved_size
		bindings.load_saved(config)
		_apply_display()
	_apply_audio()


func set_audio(sound: float, music: float) -> void:
	sound_volume = clampf(sound, 0.0, 1.0)
	music_volume = clampf(music, 0.0, 1.0)
	_apply_audio()
	changed.emit()


func set_sensitivity(value: float) -> void:
	sensitivity = clampf(value, 0.03, 0.3)
	changed.emit()


func set_dog_vision(enabled: bool) -> void:
	dog_vision = enabled
	changed.emit()


func resolutions() -> Array[Vector2i]:
	var limit := Vector2i(3840, 2160)
	if DisplayServer.get_name() != "headless":
		limit = DisplayServer.screen_get_usable_rect(_window.current_screen).size
	var result: Array[Vector2i] = []
	for size: Vector2i in [Vector2i(960, 540), Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080), Vector2i(2560, 1440), Vector2i(3840, 2160)]:
		if size.x <= limit.x and size.y <= limit.y:
			result.append(size)
	if not result.has(resolution):
		result.append(resolution)
	return result


func refresh_window_size() -> void:
	if not display_pending and DisplayServer.get_name() != "headless" and window_mode == WindowMode.WINDOWED:
		resolution = _window.size


func preview_display(mode: int, size: Vector2i) -> void:
	if display_pending or mode < 0 or mode > 2 or not resolutions().has(size):
		return
	_previous_display = {"mode": window_mode, "resolution": resolution, "position": _window.position}
	window_mode = mode as WindowMode
	resolution = size
	display_pending = true
	display_deadline = Time.get_ticks_msec() + DISPLAY_CONFIRM_SECONDS * 1000
	_apply_display()
	display_changed.emit()


func confirm_display() -> void:
	display_pending = false
	_previous_display.clear()
	save()
	display_changed.emit()


func revert_display() -> void:
	if not display_pending:
		return
	window_mode = _previous_display.mode
	resolution = _previous_display.resolution
	display_pending = false
	_apply_display()
	if DisplayServer.get_name() != "headless" and window_mode == WindowMode.WINDOWED:
		_window.position = _previous_display.position
	_previous_display.clear()
	display_changed.emit()


func tick_display() -> void:
	if display_pending and Time.get_ticks_msec() >= display_deadline:
		revert_display()


func save() -> Error:
	var config := ConfigFile.new()
	config.set_value("audio", "sound_volume", sound_volume)
	config.set_value("audio", "music_volume", music_volume)
	config.set_value("input", "sensitivity", sensitivity)
	config.set_value("display", "dog_vision", dog_vision)
	var display: Dictionary = _previous_display if display_pending else {"mode": window_mode, "resolution": resolution}
	config.set_value("display", "window_mode", display.mode)
	config.set_value("display", "resolution", display.resolution)
	bindings.save(config)
	var result := config.save(PATH)
	if result != OK:
		push_warning("Could not save settings: %s" % error_string(result))
	return result


func _apply_audio() -> void:
	for bus: String in ["Sound", "Music"]:
		var index := AudioServer.get_bus_index(bus)
		var volume := sound_volume if bus == "Sound" else music_volume
		AudioServer.set_bus_volume_linear(index, volume)
		AudioServer.set_bus_mute(index, is_zero_approx(volume))


func _apply_display() -> void:
	if DisplayServer.get_name() == "headless":
		return
	_window.mode = Window.MODE_WINDOWED
	_window.borderless = false
	var screen := DisplayServer.screen_get_usable_rect(_window.current_screen)
	resolution = Vector2i(clampi(resolution.x, 960, maxi(960, screen.size.x)), clampi(resolution.y, 540, maxi(540, screen.size.y)))
	if window_mode == WindowMode.WINDOWED:
		_window.size = resolution
		_window.position = screen.position + (screen.size - resolution) / 2
	elif window_mode == WindowMode.BORDERLESS:
		_window.borderless = true
		_window.size = DisplayServer.screen_get_size(_window.current_screen)
		_window.position = DisplayServer.screen_get_position(_window.current_screen)
	else:
		_window.mode = Window.MODE_EXCLUSIVE_FULLSCREEN
