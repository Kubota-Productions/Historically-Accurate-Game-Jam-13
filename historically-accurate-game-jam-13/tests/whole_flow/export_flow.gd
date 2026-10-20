extends "res://tests/support/flow_test.gd"


func run() -> void:
	var source := GAME_SCENE.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	var packed := PackedScene.new()
	check(packed.pack(source) == OK, "Game can be repacked by the exporter")
	source.free()
	var game := packed.instantiate()
	var host := game.get_node_or_null("WorldPresentation/ProjectionInput/WorldHost")
	check(host is Node3D, "Export repacking preserves WorldHost inside the projection viewport")
	check(game.get_node_or_null("%WorldHost") == host and host != null, "WorldHost keeps its unique-name binding after export repacking")
	root.add_child(game)
	await frames(2)
	check(game.room != null and game.room.configured, "Repacked game boots a configured room")
	if host:
		check(game.room.get_parent() == host, "Room is mounted in the preserved WorldHost")
		check(game.room.get_viewport() == game.projection.viewport, "Room renders through the projection SubViewport")
	game.transition.fade_out_seconds = 0.0
	game.transition.fade_in_seconds = 0.0
	game.transition.chapter_hold_seconds = 0.0
	game.transition.menu_hold_seconds = 0.0
	game.transition.intro_pause_seconds = 0.0
	await game.start_game()
	check(game.room.control_enabled and game.dialogue.session.active, "Repacked game starts training and its greeting")
	_finish_dialogue(game)
	check(game.room.progress.has_flag(&"departure_ready"), "Introduction unlocks preparation")
	await game.enter_room(load("res://GameData/Rooms/station.tres"))
	_finish_dialogue(game)
	check(game.room.progress.has_flag(&"fetch"), "Training greeting unlocks item collection")
	for path: NodePath in [^"Pickups/Battery1/Item", ^"Pickups/Battery2/Item"]:
		var item: PickupItem = game.room.get_node(path)
		game.room.carry.take(item)
		check(game.room.carry.store(game.room.progress.socket), "Training battery can be installed after export repacking")
	game.room.progress.handle_event(&"test")
	_finish_dialogue(game)
	check(game.room.progress.has_flag(&"departure_ready"), "Successful test unlocks departure")
	await game.enter_room(load("res://GameData/Rooms/rocket.tres"))
	check(game.room.progress is RocketProgress and game.room.get_parent() == host, "Rocket transition preserves WorldHost")
	game.room.progress.flight_seconds = 0.05
	check(await wait_for(func(): return game.mode == game.Mode.CREDITS and not game.transitioning), "Repacked game reaches credits")
	await game.return_to_menu()
	check(game.menu.visible and game.room.progress is OpeningProgress, "Repacked game returns to the menu and reloads training")
	game.free()


func _finish_dialogue(game: GameShell) -> void:
	for line: int in 30:
		if not game.dialogue.session.active:
			return
		game.dialogue.session.advance(game.dialogue.session.requires_bark())
