extends "res://tests/support/flow_test.gd"

var shell: GameShell


func run() -> void:
	shell = await boot_shell()
	shell.transition.fade_out_seconds = 0.01
	shell.transition.fade_in_seconds = 0.01
	shell.transition.chapter_hold_seconds = 0.01
	shell.transition.menu_hold_seconds = 0.01
	shell.transition.intro_pause_seconds = 0.01
	check(shell.menu.visible and not shell.room.control_enabled, "Boot opens the menu with gameplay disabled")
	await shell.start_game()
	check(shell.room.progress is OpeningProgress, "New game starts in the introduction")
	check(not shell.room.has_node("Pickups") and not shell.room.has_node("Props/TrainingStand"), "The battery task has moved out of scene one")
	await _aim(Vector3(-2.5, 0, 2.0), "Props/Capsule/Entry")
	# Dialogue owns interact until the introduction has finished.
	check(not shell.room.progress.has_flag(&"departure_ready"), "Departure starts locked")
	await _finish_dialogue()
	check(shell.room.progress.has_flag(&"departure_ready"), "The introduction unlocks preparation")
	await _use("Props/Capsule/Entry", Vector3(-2.5, 0, 2.0))
	await _settle()
	check(shell.room.progress is StationProgress, "The first exit loads the second scene")
	check(not shell.room.has_node("Actors/Robot"), "The temporary robot is absent")
	await _finish_dialogue()
	check(shell.room.progress.has_flag(&"fetch"), "The preparation briefing enables pickups")
	await _use("Props/Capsule/Entry", Vector3(2.2, 0, -1.7))
	check(not shell.transitioning and shell.room.progress is StationProgress, "Boarding early keeps the player in preparation")
	await _use("Props/TestButton", Vector3(1.5, 0, 1.8))
	check(not shell.dialogue.session.active, "An early test is recoverable")
	for battery: String in ["Battery1", "Battery2"]:
		var item: Node3D = shell.room.get_node("Pickups/" + battery + "/Item")
		await _use("Pickups/" + battery + "/Item", item.global_position + Vector3(0, 0, 1.3))
		check(shell.room.carry.item != null, "The battery can be picked up through the raycast")
		await _use("Props/TrainingStand/Slots", Vector3(-0.3, 0, 1.2))
		check(shell.room.carry.item == null, "Interaction installs the held battery")
	check(shell.room.progress.socket.is_full(), "Both batteries fill the stand")
	await _use("Props/TestButton", Vector3(1.5, 0, 1.8))
	await _finish_dialogue()
	check(shell.room.progress.has_flag(&"departure_ready"), "The test unlocks the rocket")
	await _use("Props/Capsule/Entry", Vector3(2.2, 0, -1.7))
	await _settle()
	check(shell.room.progress is LiftoffProgress and shell.room.configured, "The liftoff scene is connected and configured")
	check(not shell.hud.visible and not shell.room.control_enabled, "Liftoff video hides the HUD and disables dog actions")
	var cues: Array[AudioCue] = []
	var record_cue := func(cue: AudioCue) -> void: cues.append(cue)
	shell.audio.cue_played.connect(record_cue)
	await press(&"bark")
	Input.action_press(&"sniff")
	await frames(2)
	check(cues.is_empty() and not shell.room.scent.active and not shell.hud.visible, "Dog actions are ignored while the liftoff video plays")
	Input.action_release(&"sniff")
	shell.audio.cue_played.disconnect(record_cue)
	shell.pause_game()
	shell.resume_game()
	check(not shell.hud.visible and not shell.room.control_enabled, "Resuming during liftoff video keeps HUD hidden and dog actions disabled")
	var liftoff: LiftoffProgress = shell.room.progress
	liftoff.video.finished.emit()
	await _settle()
	check(shell.room.progress is RocketProgress and shell.room.configured and shell.hud.visible, "The fourth scene is connected and configured")
	var flight: RocketProgress = shell.room.progress
	check(not shell.room.player.is_physics_processing() and shell.room.rig.is_processing_unhandled_input(), "Flight keeps Laika seated while allowing mouse look")
	check(flight.active, "Flight begins after the room transition")
	shell.pause_game()
	var elapsed := flight.elapsed
	await create_timer(0.1, true).timeout
	check(is_equal_approx(elapsed, flight.elapsed), "Pausing freezes the ending countdown")
	shell.resume_game()
	flight.flight_seconds = 0.15
	check(await wait_for(func(): return shell.mode == shell.Mode.CREDITS and not shell.transitioning), "Flight fades into credits")
	check(shell.credits.visible and not shell.hud.visible and not shell.room.control_enabled, "Credits own input and hide gameplay")
	await press(&"bark")
	check(not shell.hud.visible, "Gameplay input cannot reopen the HUD during credits")
	shell.credits.page_seconds = 0.05
	check(await wait_for(func(): return shell.menu.visible and not shell.transitioning), "Credits automatically return to the menu")
	check(shell.mode == shell.Mode.MENU and not paused and not shell.credits.active, "The menu restores a clean state")
	await shell.start_game()
	check(shell.room.progress is OpeningProgress and not shell.room.progress.has_flag(&"departure_ready"), "Replay resets progression")
	await shell.enter_room(load("res://GameData/Rooms/rocket.tres"))
	shell.room.progress.flight_seconds = 0.05
	shell.credits.page_seconds = 7.0
	await wait_for(func(): return shell.mode == shell.Mode.CREDITS and not shell.transitioning)
	await press(&"ui_cancel")
	await _settle()
	check(shell.menu.visible and not shell.credits.visible, "Escape exits credits without opening pause")
	shell.queue_free()
	await frames(2)


func _finish_dialogue() -> void:
	var limit := 20
	while shell.dialogue.session.active and limit > 0:
		await press(&"bark" if shell.dialogue.session.requires_bark() else &"interact")
		limit -= 1
	check(limit > 0, "Dialogue can be completed with the advertised actions")


func _aim(position: Vector3, path: NodePath) -> void:
	shell.room.rig.set_process_unhandled_input(false)
	shell.room.player.teleport(position)
	await create_timer(0.4).timeout
	var point: Vector3 = shell.room.get_node(path).global_position
	var direction := (point - shell.room.camera.global_position).normalized()
	shell.room.rig.set_look(atan2(-direction.x, -direction.z), asin(direction.y))
	await frames(3)


func _use(path: NodePath, position: Vector3) -> void:
	await _aim(position, path)
	check(shell.room.interactor.target == shell.room.get_node(path), "Raycast reaches %s" % path)
	await press(&"interact")


func _settle() -> void:
	check(await wait_for(func(): return not shell.transitioning), "Transition finishes")
