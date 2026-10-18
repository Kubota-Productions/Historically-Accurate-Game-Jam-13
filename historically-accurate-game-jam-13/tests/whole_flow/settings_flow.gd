extends "res://tests/support/flow_test.gd"

var shell: GameShell
var panel: SettingsPanel


func run() -> void:
	DirAccess.remove_absolute(GameSettings.PATH)
	shell = await boot_shell()
	panel = shell.settings
	var preferences := shell.preferences
	check(shell.dog_vision.visible and shell.projection.enabled, "Display effects default on")
	shell.open_settings()
	check(panel.visible and not shell.menu.visible, "Settings replace the menu")
	panel.row(&"dog_vision").editor.button_pressed = false
	check(not preferences.get_value(&"dog_vision") and not shell.dog_vision.visible, "Dog vision toggles the filter immediately")
	panel.row(&"dog_vision").editor.button_pressed = true
	panel.row(&"panini_projection").editor.button_pressed = false
	check(not shell.projection.enabled, "Panini toggles the projection immediately")
	panel.row(&"panini_projection").editor.button_pressed = true
	panel.row(&"sound_volume").editor.value = 0.25
	panel.row(&"music_volume").editor.value = 0.85
	check(is_equal_approx(AudioServer.get_bus_volume_linear(AudioServer.get_bus_index(&"Sound")), 0.25), "The sound slider drives the Sound bus")
	check(is_equal_approx(AudioServer.get_bus_volume_linear(AudioServer.get_bus_index(&"Music")), 0.85), "The music slider drives the Music bus")
	check(panel.row(&"sound_volume").get_node("%Value").text == "25%", "Volume shows a percentage")
	panel.row(&"sensitivity").editor.value = 0.19
	check(is_equal_approx(shell.room.rig.mouse_sensitivity, 0.19), "Sensitivity applies to the camera")
	await _rebinding()
	_display_confirmation()
	await press(&"ui_cancel")
	check(shell.menu.visible and not panel.visible, "Escape returns from settings")
	check(root.gui_get_focus_owner() == shell.menu.get_node("%Settings"), "Settings focus is restored")
	var saved := ConfigFile.new()
	saved.load(GameSettings.PATH)
	check(is_equal_approx(saved.get_value("settings", "sound_volume"), 0.25), "Closing settings saves values")
	check(saved.get_value("bindings", "interact") == {"mouse": MOUSE_BUTTON_MIDDLE}, "Closing settings saves bindings")
	await shell.start_game()
	await click(MOUSE_BUTTON_LEFT)
	check(shell.dialogue.session.index == 0, "The replaced mouse binding no longer advances dialogue")
	await click(MOUSE_BUTTON_MIDDLE)
	check(shell.dialogue.session.index == 0 and shell.dialogue.response.text == "[F]  Bark to answer", "A bark line only accepts Bark")
	await key(KEY_F)
	await key(KEY_F)
	check("Woof!" in shell.dialogue.response.text and "[MMB] Continue dialogue" in shell.dialogue.response.text, "Bark feedback shows the rebound continue key")
	await click(MOUSE_BUTTON_MIDDLE)
	check(not shell.dialogue.session.active, "The rebound key continues dialogue")
	shell.preferences.bindings.reset()
	shell.queue_free()
	await frames(2)
	var restarted := await boot_shell()
	check(is_equal_approx(restarted.preferences.get_value(&"sound_volume"), 0.25), "A restarted game loads saved settings")
	check(InputHints.key(&"interact") == "MMB", "A restarted game loads saved bindings")
	restarted.preferences.bindings.reset()
	restarted.queue_free()
	DirAccess.remove_absolute(GameSettings.PATH)


func _rebinding() -> void:
	panel.tabs.current_tab = 2
	panel.begin_capture(&"interact")
	await key(KEY_K)
	check(InputHints.key(&"interact") == "K" and not panel.is_capturing(), "Interaction can be rebound")
	check(shell.hud.get_node("%Interact/%Key").text == "K", "The HUD shows the new binding")
	panel.begin_capture(&"bark")
	await key(KEY_W)
	check(InputHints.key(&"bark") == "F" and panel.is_capturing(), "A conflicting key is rejected")
	check("Move forward" in panel.binding_status.text, "The conflict names the other action")
	await key(KEY_ESCAPE)
	check(panel.visible and not panel.is_capturing(), "Escape cancels capture without closing settings")
	panel.begin_capture(&"interact")
	await click(MOUSE_BUTTON_MIDDLE)
	check(InputHints.key(&"interact") == "MMB", "A mouse button can replace a key")


func _display_confirmation() -> void:
	var display := shell.preferences.display
	panel.tabs.current_tab = 0
	panel.window_mode.item_selected.emit(DisplaySettings.WindowMode.BORDERLESS)
	check(not panel.get_node("%ApplyDisplay").disabled and panel.resolution.disabled, "Choosing a fullscreen mode enables Apply")
	panel.get_node("%ApplyDisplay").pressed.emit()
	check(display.pending and panel.get_node("%DisplayConfirmation").visible and not panel.revert_timer.is_stopped(), "Applying asks for confirmation")
	panel.revert_timer.timeout.emit()
	check(not display.pending and display.mode == DisplaySettings.WindowMode.WINDOWED, "An unconfirmed preview reverts")
	check(panel.revert_timer.is_stopped() and not panel.get_node("%DisplayConfirmation").visible, "Reverting hides the confirmation")
	panel.window_mode.item_selected.emit(DisplaySettings.WindowMode.FULLSCREEN)
	panel.get_node("%ApplyDisplay").pressed.emit()
	panel.handle_cancel()
	check(panel.visible and not display.pending, "Escape first reverts a pending preview")
	panel.window_mode.item_selected.emit(DisplaySettings.WindowMode.BORDERLESS)
	panel.get_node("%ApplyDisplay").pressed.emit()
	panel.get_node("%KeepDisplay").pressed.emit()
	var saved := ConfigFile.new()
	saved.load(GameSettings.PATH)
	check(saved.get_value("display", "window_mode") == DisplaySettings.WindowMode.BORDERLESS, "Keeping a preview saves it")
	display.preview(DisplaySettings.WindowMode.WINDOWED, display.size)
	display.confirm()
	panel.window_mode.item_selected.emit(DisplaySettings.WindowMode.FULLSCREEN)
	panel.get_node("%ApplyDisplay").pressed.emit()
	shell.close_settings()
	check(not display.pending and display.mode == DisplaySettings.WindowMode.WINDOWED, "Closing settings reverts a pending preview")
	shell.open_settings()
