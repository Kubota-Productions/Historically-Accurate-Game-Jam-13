extends Node


func _ready() -> void:
	var state := "menu"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--review-state="):
			state = argument.trim_prefix("--review-state=")
	var shell: Node = $GameShell
	if state == "menu_gaze_neutral":
		var gaze: MenuGaze = shell.menu.get_node("MenuGaze")
		gaze.set_process(false)
		gaze.look_target.position = gaze._neutral_position
	elif state.begins_with("menu_gaze_"):
		var button_name := {"menu_gaze_start": "Start", "menu_gaze_settings": "Settings", "menu_gaze_exit": "Quit"}
		shell.menu.get_node("%" + button_name[state]).grab_focus()
	elif state.begins_with("settings"):
		shell.open_settings()
		if state.begins_with("settings_video"):
			shell.settings.tabs.current_tab = 0
			if state == "settings_video_dog":
				shell.settings.row(&"dog_vision").editor.button_pressed = true
			elif state == "settings_video_preview":
				await RenderingServer.frame_post_draw
				shell.preferences.preview_display(GameSettings.WindowMode.WINDOWED, Vector2i(960, 540))
		elif state == "settings_controls":
			shell.settings.tabs.current_tab = 2
		elif state == "settings_controls_capture":
			shell.settings.tabs.current_tab = 2
			shell.settings.begin_capture(&"interact")
			await get_tree().process_frame
			await get_tree().process_frame
			for row: Control in shell.settings.binding_rows.get_children():
				if row.action == &"interact":
					shell.settings.binding_rows.get_parent().ensure_control_visible(row)
					row.focus_binding()
		elif state == "settings_audio":
			shell.settings.tabs.current_tab = 1
	elif state != "menu":
		await shell.start_game()
		if state != "dialogue":
			shell.dialogue.advance(true)
			shell.dialogue.advance(false)
			shell.room.player.teleport(Vector3(0, 0, 2.4))
			if state == "near_wall":
				shell.room.player.teleport(Vector3(0, 0, -4.5))
			elif state.begins_with("carrying"):
				if state == "carrying_panini":
					shell.preferences.set_value(&"panini_projection", true)
				shell.room.interactor.target = shell.room.get_node("Pickups/Battery1/Item")
				shell.room.interact()
			elif state == "dialogue_long":
				shell._open_dialogue(&"robot")
				shell.dialogue.advance(true)
			elif state == "training_complete":
				for index: int in [1, 2]:
					shell.room.interactor.target = shell.room.get_node("Pickups/Battery%d/Item" % index)
					shell.room.interact()
					shell.room.interactor.target = shell.room.get_node("Props/TrainingStand/Slots")
					shell.room.interact()
				shell.room.interactor.target = shell.room.get_node("Props/TrainingStand/TestButton")
				shell.room.interact()
				shell.dialogue.advance(true)
				shell.dialogue.advance(false)
			elif state == "pause":
				shell.pause_game()
			elif state == "scientist_blockout":
				shell.room.player.teleport(Vector3(-2.2, 0, 1.0))
				shell.room.rig.set_look(0.0, 0.08)
			elif state.begins_with("station"):
				await shell._depart()
				if state != "station":
					shell.dialogue.advance(true)
					shell.dialogue.advance(false)
					shell.room.player.teleport(Vector3(0, 0, 2.0))
					shell.room.rig.set_look(0.0, 0.12)
					if state in ["station_complete", "station_bark_feedback"]:
						shell._open_dialogue(&"robot")
						shell.dialogue.advance(true)
						if state == "station_complete":
							shell.dialogue.advance(false)
						else:
							shell._play_bark()
							shell.dialogue.show_bark_feedback()
