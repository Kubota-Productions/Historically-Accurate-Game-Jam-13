class_name GameSettings
extends RefCounted

signal changed
signal display_changed

enum WindowMode { WINDOWED, BORDERLESS, FULLSCREEN }

const PATH := "user://settings.cfg"
const DISPLAY_CONFIRM_SECONDS := 15

signal value_changed(id: StringName, value: Variant)

var definitions: Dictionary[StringName, SettingDefinition] = {}
var _values: Dictionary[StringName, Variant] = {}

var window_mode: WindowMode:
	get: return get_value(&"window_mode")
	set(value): _values[&"window_mode"] = value

var resolution: Vector2i:
	get: return get_value(&"resolution")
	set(value): _values[&"resolution"] = value

var bindings := PlayerBindings.new()
var display_pending: bool = false
var display_deadline: int = 0
var _previous_display: Dictionary = {}
var _window: Window


func _init() -> void:
	for definition: SettingDefinition in SettingsCatalog.definitions():
		register(definition)


func register(definition: SettingDefinition) -> void:
	assert(not definitions.has(definition.id), "Duplicate setting: " + str(definition.id))
	definitions[definition.id] = definition
	_values[definition.id] = definition.default_value


func get_value(id: StringName) -> Variant:
	return _values[id]


func set_value(id: StringName, value: Variant) -> void:
	if not definitions.has(id) or definitions[id].confirmation:
		return
	var clean: Variant = definitions[id].sanitize(value)
	if _values[id] == clean:
		return
	_values[id] = clean
	_apply_audio()
	value_changed.emit(id, clean)
	changed.emit()


func initialize(window: Window) -> void:
	_window = window
	resolution = _window.size
	var config := ConfigFile.new()
	if config.load(PATH) == OK:
		for definition: SettingDefinition in definitions.values():
			var fallback: Variant = resolution if definition.id == &"resolution" else definition.default_value
			if definition.id == &"sound_volume":
				fallback = config.get_value("audio", "volume", fallback)
			_values[definition.id] = definition.sanitize(config.get_value(definition.section, definition.id, fallback))
		bindings.load_saved(config)
		_apply_display()
	_apply_audio()


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
	for definition: SettingDefinition in definitions.values():
		var value: Variant = _values[definition.id]
		if display_pending and definition.confirmation:
			value = _previous_display["mode" if definition.id == &"window_mode" else "resolution"]
		config.set_value(definition.section, definition.id, value)
	bindings.save(config)
	var result := config.save(PATH)
	if result != OK:
		push_warning("Could not save settings: %s" % error_string(result))
	return result


func _apply_audio() -> void:
	for definition: SettingDefinition in definitions.values():
		if definition.audio_bus.is_empty():
			continue
		var index := AudioServer.get_bus_index(definition.audio_bus)
		if index < 0:
			continue
		var volume: float = get_value(definition.id)
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
