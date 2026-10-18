extends "res://tests/support/flow_test.gd"


func run() -> void:
	_catalog_is_valid()
	_values_are_sanitized()
	_settings_survive_restart()
	_volume_drives_its_bus()
	_bindings_reject_conflicts()
	_bindings_survive_restart()
	_display_preview_needs_confirmation()


func _catalog_is_valid() -> void:
	var ids: Array[StringName] = []
	for definition: SettingDefinition in GameSettings.CATALOG.settings:
		check(not definition.id.is_empty() and not definition.label.is_empty(), "%s has an id and a label" % definition.resource_name)
		check(not definition.id in ids, "%s has a unique id" % definition.id)
		ids.append(definition.id)
		check(definition.sanitize(definition.get_default()) == definition.get_default(), "%s default is valid" % definition.id)
		if definition is SliderSetting:
			check(definition.minimum < definition.maximum and definition.step > 0.0, "%s has a usable range" % definition.id)
			check(definition.audio_bus.is_empty() or AudioServer.get_bus_index(definition.audio_bus) >= 0, "%s audio bus exists" % definition.id)
		if definition is ChoiceSetting:
			check(not definition.options.is_empty(), "%s has options" % definition.id)
	for id: StringName in [&"dog_vision", &"panini_projection", &"sensitivity", &"sound_volume", &"music_volume"]:
		check(id in ids, "The game uses the catalog setting %s" % id)


func _values_are_sanitized() -> void:
	var settings := GameSettings.new(_catalog())
	settings.set_value(&"speed", NAN)
	check(is_equal_approx(settings.get_value(&"speed"), 0.1), "A malformed number falls back to the default")
	settings.set_value(&"speed", 10.0)
	check(is_equal_approx(settings.get_value(&"speed"), 0.3), "Sliders clamp to their range")
	settings.set_value(&"invert", "yes")
	check(settings.get_value(&"invert") == false, "Toggles accept only booleans")
	settings.set_value(&"quality", 7)
	check(settings.get_value(&"quality") == 0, "Choices accept only existing options")
	var changes: Array[StringName] = []
	settings.changed.connect(changes.append)
	settings.set_value(&"quality", 1)
	settings.set_value(&"quality", 1)
	check(changes == [&"quality"], "Changing a value notifies once")
	var slider: SliderSetting = settings.definitions[&"speed"]
	check(slider.format(0.25) == "0.25", "Sliders can format as decimals")
	slider.percent = true
	check(slider.format(0.25) == "25%", "Sliders can format as percent")


func _settings_survive_restart() -> void:
	DirAccess.remove_absolute(GameSettings.PATH)
	var settings := GameSettings.new(_catalog())
	settings.restore(root)
	check(settings.get_value(&"invert") == false, "Missing save files use defaults")
	settings.set_value(&"invert", true)
	settings.set_value(&"quality", 1)
	check(settings.save() == OK, "Settings save")
	var reloaded := GameSettings.new(_catalog())
	reloaded.restore(root)
	check(reloaded.get_value(&"invert") and reloaded.get_value(&"quality") == 1, "Saved values load after a restart")
	var corrupted := ConfigFile.new()
	corrupted.set_value("settings", "speed", "fast")
	corrupted.save(GameSettings.PATH)
	reloaded.restore(root)
	check(is_equal_approx(reloaded.get_value(&"speed"), 0.1), "Corrupted values load as defaults")
	DirAccess.remove_absolute(GameSettings.PATH)


func _volume_drives_its_bus() -> void:
	var bus := AudioServer.get_bus_index(&"Sound")
	var volume := SliderSetting.new()
	volume.id = &"volume"
	volume.audio_bus = &"Sound"
	var catalog := SettingsCatalog.new()
	catalog.settings.append(volume)
	var settings := GameSettings.new(catalog)
	settings.set_value(&"volume", 0.25)
	check(is_equal_approx(AudioServer.get_bus_volume_linear(bus), 0.25) and not AudioServer.is_bus_mute(bus), "Volume changes its audio bus")
	settings.set_value(&"volume", 0.0)
	check(AudioServer.is_bus_mute(bus), "Zero volume mutes its bus")
	settings.set_value(&"volume", 0.7)


func _bindings_reject_conflicts() -> void:
	var bindings := PlayerBindings.new()
	bindings.reset()
	check(not bindings.problem(&"interact", _key(KEY_W)).is_empty(), "A key used by another action is rejected")
	check("Move forward" in bindings.problem(&"interact", _key(KEY_W)), "A conflict names the other action")
	check(not bindings.problem(&"interact", _key(KEY_ESCAPE)).is_empty(), "Escape stays reserved")
	check(not bindings.problem(&"interact", _key(KEY_SHIFT)).is_empty(), "Modifiers cannot be bound alone")
	check(not bindings.problem(&"interact", _mouse(MOUSE_BUTTON_WHEEL_UP)).is_empty(), "The wheel cannot be bound")
	check(bindings.problem(&"interact", _key(KEY_K)).is_empty(), "A free key is accepted")
	bindings.assign(&"interact", _key(KEY_K))
	check(InputHints.key(&"interact") == "K" and InputMap.action_get_events(&"interact").size() == 1, "Assigning replaces the previous binding")
	bindings.reset()
	check(InputHints.key(&"interact") == "LMB", "Reset restores the project bindings")
	check(PlayerBindings.normalized(_key(KEY_E)).physical_keycode == KEY_E, "Captured keys use physical key codes")


func _bindings_survive_restart() -> void:
	var bindings := PlayerBindings.new()
	bindings.assign(&"interact", _mouse(MOUSE_BUTTON_MIDDLE))
	var config := ConfigFile.new()
	bindings.save(config)
	bindings.reset()
	bindings.restore(config)
	check(InputHints.key(&"interact") == "MMB", "Saved bindings load")
	config.set_value("bindings", "drop", {"key": KEY_W})
	bindings.reset()
	bindings.restore(config)
	check(InputHints.key(&"interact") == "LMB" and InputHints.key(&"drop") == "RMB", "Conflicting saves keep the defaults")
	bindings.restore(ConfigFile.new())
	check(InputHints.key(&"interact") == "LMB", "Missing saves keep the defaults")
	bindings.assign(&"forward", _key(KEY_I))
	bindings.assign(&"backwards", _key(KEY_W))
	bindings.save(config)
	bindings.reset()
	bindings.restore(config)
	check(InputHints.key(&"forward") == "I" and InputHints.key(&"backwards") == "W", "Swapped keys survive a restart")
	config.erase_section_key("bindings", "jump")
	bindings.restore(config)
	check(InputHints.key(&"forward") == "I" and InputHints.key(&"jump") == "Space", "A missing action falls back to its default alone")
	bindings.reset()


func _display_preview_needs_confirmation() -> void:
	var display := DisplaySettings.new()
	display.restore(ConfigFile.new(), root)
	var original := display.size
	display.preview(DisplaySettings.WindowMode.BORDERLESS, original)
	check(display.pending and display.mode == DisplaySettings.WindowMode.BORDERLESS, "A display preview is pending")
	var config := ConfigFile.new()
	display.save(config)
	check(config.get_value("display", "window_mode") == DisplaySettings.WindowMode.WINDOWED, "Pending display changes are not saved")
	display.revert()
	check(not display.pending and display.mode == DisplaySettings.WindowMode.WINDOWED, "Revert restores the previous mode")
	display.preview(DisplaySettings.WindowMode.FULLSCREEN, original)
	display.confirm()
	display.save(config)
	check(config.get_value("display", "window_mode") == DisplaySettings.WindowMode.FULLSCREEN, "Confirmed display changes are saved")
	config.set_value("display", "resolution", Vector2i(10, 10))
	config.set_value("display", "window_mode", 9)
	display.restore(config, root)
	check(display.mode == DisplaySettings.WindowMode.WINDOWED and display.size == root.size, "Invalid saved display values are ignored")
	check(display.sizes().has(display.size), "The current size is always offered")


func _catalog() -> SettingsCatalog:
	var speed := SliderSetting.new()
	speed.id = &"speed"
	speed.default_value = 0.1
	speed.minimum = 0.03
	speed.maximum = 0.3
	speed.percent = false
	var invert := ToggleSetting.new()
	invert.id = &"invert"
	var quality := ChoiceSetting.new()
	quality.id = &"quality"
	quality.options = ["Low", "High"]
	var catalog := SettingsCatalog.new()
	catalog.settings.assign([speed, invert, quality])
	return catalog


func _key(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code
	return event


func _mouse(button: MouseButton) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = button
	return event
