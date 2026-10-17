extends SceneTree

var shell: Node
var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var legacy := ConfigFile.new()
	legacy.set_value("audio", "volume", 0.4)
	legacy.set_value("input", "sensitivity", 0.12)
	legacy.set_value("bindings", "interact", [{"mouse": MOUSE_BUTTON_LEFT}, {"key": KEY_E}])
	legacy.set_value("bindings", "drop", [{"mouse": MOUSE_BUTTON_RIGHT}, {"key": KEY_R}])
	legacy.save(GameSettings.PATH)
	shell = load("res://Scenes/Game/Game.tscn").instantiate()
	root.add_child(shell)
	await process_frame
	var preferences: GameSettings = shell.preferences
	_check(is_equal_approx(preferences.get_value(&"sound_volume"), 0.4), "Legacy sound volume migrates")
	_check(is_equal_approx(preferences.get_value(&"music_volume"), 0.7), "Music has an independent default")
	_check(preferences.get_value(&"dog_vision") and shell.dog_vision.visible, "Dog vision defaults on when no preference is saved")
	_check(preferences.get_value(&"panini_projection") and shell.projection.enabled, "Panini defaults on when no preference is saved")
	_check(_single_bindings(), "Legacy bindings migrate to exactly one input per action")
	_check(InputHints.key(&"interact") == "LMB" and InputHints.key(&"drop") == "RMB", "Legacy default alternatives are removed")
	shell.open_settings()
	var panel: Control = shell.settings
	panel.tabs.current_tab = 0
	panel.row(&"dog_vision").editor.button_pressed = true
	_check(preferences.get_value(&"dog_vision") and shell.dog_vision.visible, "Dog vision toggle enables the filter immediately")
	panel.row(&"dog_vision").editor.button_pressed = false
	_check(not preferences.get_value(&"dog_vision") and not shell.dog_vision.visible, "Dog vision toggle disables the filter immediately")
	panel.row(&"dog_vision").editor.button_pressed = true
	var sound_bus := AudioServer.get_bus_index("Sound")
	panel.tabs.current_tab = 1
	var music_bus := AudioServer.get_bus_index("Music")
	_check(sound_bus > 0 and music_bus > 0 and sound_bus != music_bus, "Sound and Music have separate audio buses")
	panel.row(&"sound_volume").editor.value = 0.25
	_check(is_equal_approx(AudioServer.get_bus_volume_linear(sound_bus), 0.25), "Sound slider changes Sound bus")
	_check(is_equal_approx(AudioServer.get_bus_volume_linear(music_bus), 0.7), "Sound slider leaves music alone")
	panel.row(&"music_volume").editor.value = 0.85
	_check(is_equal_approx(AudioServer.get_bus_volume_linear(music_bus), 0.85), "Music slider changes Music bus")
	_check(is_equal_approx(AudioServer.get_bus_volume_linear(sound_bus), 0.25), "Music slider leaves sound alone")
	panel.row(&"sound_volume").editor.value = 0.0
	_check(AudioServer.is_bus_mute(sound_bus) and not AudioServer.is_bus_mute(music_bus), "Zero sound volume only mutes Sound")
	panel.row(&"sound_volume").editor.value = 0.25
	_check(not AudioServer.is_bus_mute(sound_bus), "Raising Sound volume unmutes it")
	panel.tabs.current_tab = 2
	panel.row(&"sensitivity").editor.value = 0.19
	_check(is_equal_approx(shell.room.rig.mouse_sensitivity, 0.19), "Sensitivity applies immediately")
	panel.begin_capture(&"interact")
	await _key(KEY_K)
	_check(InputHints.key(&"interact") == "K", "Interaction can be rebound")
	_check("K" == shell.hud.get_node("%Interact").get_node("%Key").text, "HUD shows only the new binding")
	_check(InputMap.action_get_events(&"interact").size() == 1, "Rebinding replaces the previous input")
	panel.begin_capture(&"bark")
	await _key(KEY_W)
	_check(InputHints.key(&"bark") == "F" and panel._capture_action == &"bark", "Conflicting keys are rejected")
	_check("Move forward" in panel.get_node("%BindingStatus").text, "The conflict names its existing action")
	await _key(KEY_ESCAPE)
	_check(panel.visible and panel._capture_action.is_empty(), "Escape cancels capture without closing Settings")
	panel.begin_capture(&"interact")
	await _mouse(MOUSE_BUTTON_MIDDLE)
	_check(InputHints.key(&"interact") == "MMB" and InputMap.action_get_events(&"interact").size() == 1, "A mouse binding replaces the keyboard binding")
	_check(not preferences.bindings.assign(&"sniff", null).is_empty() and InputHints.key(&"sniff") == "Q", "An action cannot lose its only binding")

	shell.close_settings()
	var saved := ConfigFile.new()
	saved.load(GameSettings.PATH)
	_check(is_equal_approx(float(saved.get_value("audio", "sound_volume")), 0.25), "Sound volume is saved")
	_check(is_equal_approx(float(saved.get_value("audio", "music_volume")), 0.85), "Music volume is saved")
	_check(not saved.has_section_key("display", "reduced_motion"), "Shorter transitions are absent from saved settings")
	_check(saved.has_section_key("bindings", "interact"), "Bindings are saved")
	_check(saved.get_value("display", "dog_vision", false), "Dog vision preference is saved")
	var reload := GameSettings.new()
	reload.initialize(root)
	_check(reload.get_value(&"dog_vision"), "Dog vision preference survives loading")
	_check(InputHints.key(&"interact") == "MMB" and _single_bindings(), "Single bindings survive loading")
	await shell.start_game()
	_check(shell.dog_vision.visible, "Dog vision remains enabled after entering training")
	await _mouse(MOUSE_BUTTON_LEFT)
	_check(shell.dialogue.session.index == 0, "The old mouse binding cannot advance dialogue")
	await _mouse(MOUSE_BUTTON_MIDDLE)
	_check(shell.dialogue.session.index == 0 and shell.dialogue.response.text == "[F]  Bark to answer", "A bark response only accepts the Bark action")
	await _key(KEY_F)
	_check(shell.dialogue.session.index == 1, "The Bark binding answers a bark request")
	await _key(KEY_K)
	await _key(KEY_E)
	_check(shell.dialogue.session.index == 1, "Replaced and former alternative keys no longer interact")
	await _key(KEY_F)
	_check(shell.dialogue.session.index == 1, "Barking does not advance an ordinary text line")
	_check("Woof!" in shell.dialogue.response.text and "[MMB] Continue dialogue" in shell.dialogue.response.text, "Barking gives visible feedback with the rebound continue button")
	await _mouse(MOUSE_BUTTON_MIDDLE)
	_check(not shell.dialogue.active and shell.room.control_enabled, "The single rebound context action continues ordinary dialogue")
	await _key(KEY_ESCAPE)
	await shell.return_to_menu()
	preferences.bindings.reset()
	_check(InputHints.key(&"interact") == "LMB" and InputHints.key(&"drop") == "RMB" and _single_bindings(), "Reset restores one authored binding per action")
	shell.open_settings()
	panel.tabs.current_tab = 0
	_check(panel.row(&"dog_vision").editor.button_pressed, "The toggle reflects the stored preference when reopened")
	var original_mode := preferences.window_mode
	var original_size := preferences.resolution
	preferences.preview_display(GameSettings.WindowMode.WINDOWED, Vector2i(960, 540))
	await _settle()
	_check(preferences.display_pending and panel.get_node("%DisplayConfirmation").visible, "A display preview requires confirmation")
	if DisplayServer.get_name() != "headless":
		_check(root.size == Vector2i(960, 540), "Windowed resolution changes the native window")
	preferences.save()
	saved.load(GameSettings.PATH)
	_check(saved.get_value("display", "resolution") == original_size, "An unconfirmed resolution is not persisted")
	preferences.display_deadline = Time.get_ticks_msec() - 1
	preferences.tick_display()
	await _settle()
	_check(not preferences.display_pending and preferences.resolution == original_size, "Expired display previews restore the previous resolution")
	_check(preferences.window_mode == original_mode, "Expired display previews restore the previous mode")
	_check(preferences.get_value(&"dog_vision") and shell.dog_vision.visible and panel.row(&"dog_vision").editor.button_pressed, "Display rollback preserves the independent dog vision preference")
	preferences.preview_display(GameSettings.WindowMode.WINDOWED, Vector2i(960, 540))
	preferences.confirm_display()
	saved.load(GameSettings.PATH)
	_check(saved.get_value("display", "resolution") == Vector2i(960, 540), "Confirmed display settings are saved")
	for mode: int in [GameSettings.WindowMode.BORDERLESS, GameSettings.WindowMode.FULLSCREEN]:
		preferences.preview_display(mode, preferences.resolution)
		await _settle()
		_check(preferences.window_mode == mode and preferences.display_pending, "Fullscreen mode can be previewed")
		if DisplayServer.get_name() != "headless":
			_check(root.borderless if mode == GameSettings.WindowMode.BORDERLESS else root.mode == Window.MODE_EXCLUSIVE_FULLSCREEN, "The native window uses the selected fullscreen mode")
		preferences.revert_display()
		await _settle()
		_check(preferences.window_mode == GameSettings.WindowMode.WINDOWED, "Revert restores windowed mode")
	preferences.preview_display(GameSettings.WindowMode.BORDERLESS, preferences.resolution)
	shell.close_settings()
	_check(not preferences.display_pending and preferences.window_mode == GameSettings.WindowMode.WINDOWED, "Closing settings reverts pending video changes")
	shell.queue_free()
	await process_frame
	await process_frame
	var restarted: Node = load("res://Scenes/Game/Game.tscn").instantiate()
	root.add_child(restarted)
	await process_frame
	_check(restarted.preferences.get_value(&"dog_vision") and restarted.dog_vision.visible, "A fresh game shell applies saved dog vision at startup")
	restarted.queue_free()
	await process_frame
	print("SETTINGS_FLOW: %d checks, %d failures (%s)" % [checks, failures, DisplayServer.get_name()])
	quit(0 if failures == 0 else 1)


func _key(code: Key) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.physical_keycode = code
		event.keycode = code
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame


func _mouse(button: MouseButton) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = button
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame


func _settle() -> void:
	for frame in range(6):
		await process_frame


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)


func _single_bindings() -> bool:
	for action: StringName in PlayerBindings.ACTIONS:
		if InputMap.action_get_events(action).size() != 1:
			return false
	return true
