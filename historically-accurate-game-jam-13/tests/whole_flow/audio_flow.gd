extends "res://tests/support/flow_test.gd"


class SignalSource extends Node3D:
	signal fired(number: int, body: Node3D)


class RecordingCue extends AudioCue:
	var calls: int = 0
	var last_source: Node3D

	func play(source: Node3D = null) -> bool:
		calls += 1
		last_source = source
		return true


func run() -> void:
	var shell := await boot_shell()
	shell._replace_room(load("res://GameData/Rooms/station.tres"))
	var profile := shell.audio.profile
	check(profile.configuration_errors().is_empty(), "Audio profile matches the loaded FMOD banks")
	check(FmodServer.check_event_path(profile.ui_confirm.event_name), "Aerial's confirmation event is loaded")
	check(FmodServer.get_all_banks().size() >= root.get_node("FmodBankLoaderGlobal").bank_paths.size(), "The configured FMOD banks are loaded")
	check(profile.pickup != profile.drop and profile.drop != profile.install, "Item cues can be edited independently")
	var sound := FmodServer.get_vca(profile.sound_vca_path)
	var music := FmodServer.get_vca(profile.music_vca_path)
	shell.preferences.set_value(&"sound_volume", 0.23)
	shell.preferences.set_value(&"music_volume", 0.61)
	check(is_equal_approx(sound.get_volume(), 0.23), "Sound volume controls the SFX and UI VCA")
	check(is_equal_approx(music.get_volume(), 0.61), "Music volume independently controls the music and ambience VCA")
	shell.preferences.set_value(&"sound_volume", 0.0)
	check(is_zero_approx(sound.get_volume()) and is_equal_approx(music.get_volume(), 0.61), "Muting sound keeps music independent")
	shell.preferences.set_value(&"sound_volume", 0.7)
	var played: Array[AudioCue] = []
	shell.audio.cue_played.connect(func(cue: AudioCue) -> void: played.append(cue))
	shell.menu.get_node("%Settings").pressed.emit()
	check(shell.settings.visible and played == [profile.ui_confirm], "Settings opens immediately and plays its assigned cue once")
	var extra := Button.new()
	shell.settings.add_child(extra)
	extra.pressed.emit()
	check(played.size() == 2 and played.back() == profile.ui_confirm, "Dynamically added buttons receive audio automatically")
	extra.add_to_group(GameAudio.CUSTOM_UI_GROUP)
	extra.pressed.emit()
	check(played.size() == 2, "A button can opt out of the default UI sound")
	extra.free()
	shell.settings.hide()
	var item: PickupItem = shell.room.get_node("Pickups/Battery1/Item")
	shell.room.carry.take(item)
	check(played.back() == profile.pickup and played.size() == 3, "Picking up an item uses the pickup cue")
	var wrong_socket := ItemSocket.new()
	wrong_socket.accepted_item = &"other_item"
	check(not shell.room.carry.store(wrong_socket) and played.size() == 3, "Rejected installation produces no success cue")
	wrong_socket.free()
	check(shell.room.carry.store(shell.room.progress.socket), "The audio hook does not prevent installing an item")
	check(played.back() == profile.install and played.size() == 4, "Installation uses a separate install cue exactly once")
	var second_item: PickupItem = shell.room.get_node("Pickups/Battery2/Item")
	shell.room.player.teleport(Vector3(0, 0, 2.4))
	await physics_frame
	await physics_frame
	shell.room.carry.take(second_item)
	shell.room.carry.drop()
	check(shell.room.carry.item == null and played.back() == profile.drop and played.size() == 6, "A successful drop plays its own cue once")
	shell.room.carry.changed.emit("")
	check(played.size() == 6, "Refreshing carry UI state does not produce an item sound")
	check(not shell.audio.play(null), "Unassigned optional cues are silent")
	var missing := AudioCue.new()
	missing.event_name = "event:/missing_test_event"
	check(not missing.configuration_errors().is_empty() and not missing.play(), "Missing events are rejected before creating an FMOD instance")
	var malformed := profile.ui_confirm.duplicate(true) as AudioCue
	malformed.parameters[&"character"] = Vector3.ONE
	check(not malformed.configuration_errors().is_empty(), "Unsupported parameter types are reported")
	malformed.parameters[&"character"] = NAN
	check(not malformed.configuration_errors().is_empty(), "Non-finite parameter values are reported")
	malformed.parameters[&"character"] = "unknown_label"
	check(not malformed.configuration_errors().is_empty() and not malformed.play(), "Unknown FMOD labels are rejected before playback")
	malformed.parameters = {&"unknown_parameter": 1.0}
	check(not malformed.configuration_errors().is_empty(), "Unknown FMOD parameter names are reported")
	var spatial := profile.bark.duplicate(true) as AudioCue
	check(not spatial.play(), "A spatial cue requires a valid source")
	check(spatial.play(shell.room.player), "Spatial cues can attach to a world source")
	check(shell.room.camera.find_children("*", "FmodListener3D", false, false).size() == 1, "The active room has an FMOD listener on its player camera")
	var bark := profile.ui_confirm.duplicate(true) as AudioCue
	var previous_bark := profile.bark
	profile.bark = bark
	await shell.start_game()
	check(shell.room.camera.find_children("*", "FmodListener3D", false, false).size() == 1, "Replacing a room installs its own player listener")
	await frames(2)
	check(FmodServer.get_object_attached_to_listener(0) == shell.room.camera.find_children("*", "FmodListener3D", false, false)[0], "FMOD follows the new player listener after the old room is freed")
	await press(&"bark")
	check(played.back() == bark, "Dialogue bark responses use the assigned bark cue")
	profile.bark = previous_bark
	shell.free()
	await _signal_component()


func _signal_component() -> void:
	var first := SignalSource.new()
	var second := SignalSource.new()
	root.add_child(first)
	root.add_child(second)
	var cue := RecordingCue.new()
	cue.event_name = "event:/UI/ui_confirm"
	var component: AudioSignal = load("res://Scenes/Shared/Audio/AudioSignal.tscn").instantiate()
	component.signal_name = &"fired"
	component.cue = cue
	first.add_child(component)
	await frames(2)
	check(component.configuration_errors().is_empty(), "A signal component can use its parent without explicit wiring")
	first.fired.emit(1, first)
	check(cue.calls == 1 and cue.last_source == first, "Signal arguments are ignored and the parent supplies the spatial source")
	component.reparent(second)
	await frames(2)
	first.fired.emit(2, first)
	check(cue.calls == 1, "Reparenting disconnects the old signal")
	second.fired.emit(3, second)
	check(cue.calls == 2 and cue.last_source == second, "Reparenting reconnects the new source once")
	component.free()
	second.fired.emit(4, second)
	check(cue.calls == 2, "Removing the audio component disconnects playback")
	var explicit := AudioSignal.new()
	explicit.source = first
	explicit.signal_name = &"fired"
	explicit.cue = cue
	explicit.spatial_source = second
	second.add_child(explicit)
	await frames(2)
	first.fired.emit(5, first)
	check(cue.calls == 3 and cue.last_source == second, "Signal source and sound origin can be assigned separately")
	explicit.free()
	first.free()
	second.free()
	var on_ready := SignalSource.new()
	var ready_audio := AudioSignal.new()
	ready_audio.signal_name = &"ready"
	ready_audio.cue = cue
	on_ready.add_child(ready_audio)
	root.add_child(on_ready)
	check(cue.calls == 4, "A parent's ready signal can trigger audio without being missed")
	on_ready.free()
