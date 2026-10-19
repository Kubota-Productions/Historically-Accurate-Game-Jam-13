extends "res://tests/support/flow_test.gd"

var steps: int = 0


func run() -> void:
	await _footsteps()
	await _menu_music()


func _footsteps() -> void:
	var floor_body := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(50, 1, 50)
	collision.shape = shape
	floor_body.add_child(collision)
	root.add_child(floor_body)
	floor_body.position.y = -0.5
	var player: FPSPlayer = load("res://Scenes/Player/FPSPlayer.tscn").instantiate()
	player.position.y = 1.1
	root.add_child(player)
	var tracker := FootstepTracker.new()
	tracker.player = player
	tracker.step_requested.connect(func() -> void: steps += 1)
	player.add_child(tracker)
	await _physics_frames(30)
	check(player.is_on_floor() and steps == 0, "Standing on the floor is silent")
	Input.action_press(&"forward")
	await _physics_frames(45)
	Input.action_release(&"forward")
	check(steps >= 2, "Walking emits footsteps based on actual distance")
	await _physics_frames(30)
	var previous := steps
	await _physics_frames(20)
	check(steps == previous, "Stopping does not keep emitting footsteps")
	player.teleport(Vector3(12, 1.0, 0))
	await _physics_frames(3)
	check(steps == previous, "Teleporting does not produce a footstep burst")
	Input.action_press(&"jump")
	await _physics_frames(2)
	Input.action_release(&"jump")
	previous = steps
	var stayed_silent := true
	for frame: int in 240:
		if player.is_on_floor():
			break
		await physics_frame
		stayed_silent = stayed_silent and steps == previous
	check(stayed_silent and player.is_on_floor(), "Jumping and falling do not produce walking sounds")
	player.set_physics_process(false)
	player.position.x += 1.0
	await _physics_frames(3)
	check(steps == previous, "Disabled player controls are silent")
	player.set_physics_process(true)
	Input.action_press(&"forward")
	paused = true
	await frames(10)
	paused = false
	Input.action_release(&"forward")
	check(steps == previous, "Paused gameplay does not emit footsteps")
	player.free()
	floor_body.free()
	await frames(2)


func _menu_music() -> void:
	var shell: GameShell = GAME_SCENE.instantiate()
	var audio: GameAudio = shell.get_node("Audio")
	var emitter: FmodEventEmitter2D = shell.get_node("Audio/MenuMusic")
	var current_music := emitter.event_name
	var spatial_music := FmodServer.get_event(current_music).is_3d()
	check(audio.menu_music_configuration_errors().is_empty() != spatial_music, "Menu music validation follows the FMOD event spatial settings")
	emitter.event_name = "event:/UI/ui_confirm"
	emitter.allow_fadeout = false
	root.add_child(shell)
	check(audio.menu_music_configuration_errors().is_empty(), "A 2D event can use the menu music lifecycle")
	var event := FmodServer.get_event(emitter.event_name)
	check(await wait_for(func() -> bool: return _playing_count(event) == 1), "Menu starts one native FMOD event")
	var initial_count := event.get_instance_count()
	shell.open_settings()
	check(_playing_count(event) == 1, "Menu settings keep the existing music playing")
	shell.close_settings()
	check(event.get_instance_count() == initial_count, "Returning from settings does not create another music instance")
	audio.set_menu_active(true)
	check(event.get_instance_count() == 1, "Repeated menu activation does not create duplicate music")
	await shell.start_game()
	check(await wait_for(func() -> bool: return _playing_count(event) == 0), "Starting gameplay stops menu music")
	check(shell.room.player.get_node("Footsteps") is FootstepTracker, "New rooms receive the reusable footstep component")
	var played: Array[AudioCue] = []
	audio.cue_played.connect(func(cue: AudioCue) -> void: played.append(cue))
	shell.room.player.get_node("Footsteps").step_requested.emit()
	check(played == [audio.profile.footstep], "A player step triggers the assigned FMOD cue once")
	check(audio.profile.footstep.parameters[&"character"] == "dog", "Laika uses the dog footstep variant")
	shell.pause_game()
	shell.open_settings()
	check(_playing_count(event) == 0, "Pause settings do not start menu music")
	shell.close_settings()
	shell.resume_game()
	shell.return_to_menu()
	check(await wait_for(func() -> bool: return _playing_count(event) == 1), "Returning to the menu restarts music")
	await wait_for(func() -> bool: return not shell.transitioning)
	audio.set_menu_active(false)
	check(await wait_for(func() -> bool: return _playing_count(event) == 0), "Leaving the menu explicitly stops playback")
	emitter.event_name = current_music
	shell.free()
	await frames(2)


func _playing_count(event: FmodEventDescription) -> int:
	var count := 0
	if event.get_instance_count() == 0:
		return count
	for instance: FmodEvent in event.get_instance_list():
		if instance.is_valid() and instance.get_playback_state() != FmodEvent.FMOD_STUDIO_PLAYBACK_STOPPED:
			count += 1
	return count


func _physics_frames(count: int) -> void:
	for frame: int in count:
		await physics_frame
