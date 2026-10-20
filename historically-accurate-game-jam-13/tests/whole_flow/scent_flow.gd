extends "res://tests/support/flow_test.gd"


func run() -> void:
	var shell := await boot_shell()
	shell.transition.fade_out_seconds = 0.01
	shell.transition.fade_in_seconds = 0.01
	shell.transition.chapter_hold_seconds = 0.01
	shell.transition.intro_pause_seconds = 0.01
	await shell.enter_room(load("res://GameData/Rooms/station.tres"))
	while shell.dialogue.session.active:
		shell.dialogue.session.advance(shell.dialogue.session.requires_bark())
	shell.room.player.teleport(Vector3(0, 0, 3))
	shell.room.player.set_physics_process(false)
	var first: PickupItem = shell.room.get_node("Pickups/Battery1/Item")
	var second: PickupItem = shell.room.get_node("Pickups/Battery2/Item")
	first.global_position = Vector3(-4, 0, 3)
	second.global_position = Vector3(6, 0, 3)
	var scent := shell.room.scent
	check(scent.nearest_item() == null and _visible_crumbs(scent.trail).is_empty(), "Scent clues are hidden until sniffing")
	Input.action_press(&"sniff")
	await frames(4)
	check(scent.nearest_item() == first, "The nearest loose item attracts the scent")
	var crumbs := _visible_crumbs(scent.trail)
	check(not crumbs.is_empty(), "Sniffing reveals a short local trail")
	check(not first.scent_marker.visible and not second.scent_marker.visible, "The items themselves are not highlighted")
	var local_only := true
	var stops_short := true
	for crumb: MeshInstance3D in crumbs:
		local_only = local_only and crumb.global_position.distance_to(shell.room.player.global_position) <= scent.trail.length + 0.3
		stops_short = stops_short and crumb.global_position.distance_to(first.global_position) > 1.0
	check(local_only and stops_short, "The trail gives nearby breadcrumbs without marking the destination")
	scent.trail._process(scent.trail.lifetime)
	check(_visible_crumbs(scent.trail).is_empty(), "Scent puffs fade instead of leaving a permanent path")
	var wall := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.2, 2.0, 2.0)
	shape.shape = box
	wall.add_child(shape)
	shell.room.add_child(wall)
	wall.global_position = Vector3(-1.2, 0.5, 3)
	await physics_frame
	await physics_frame
	scent.trail.emit_hint(shell.room.player.global_position, first.global_position, [shell.room.player.get_rid()])
	var through_wall := false
	for crumb: MeshInstance3D in _visible_crumbs(scent.trail):
		through_wall = through_wall or crumb.global_position.x < -1.1
	check(not through_wall, "The trail does not reveal breadcrumbs through solid walls")
	wall.queue_free()
	shell.room.carry.take(first)
	await frames(3)
	check(scent.nearest_item() == second, "A held battery no longer attracts the scent")
	second.hide()
	scent.refresh()
	await frames(3)
	check(_visible_crumbs(scent.trail).is_empty(), "Installed or hidden items cannot leave a scent trail")
	Input.action_release(&"sniff")
	await frames(3)
	check(not scent.active and _visible_crumbs(scent.trail).is_empty(), "Releasing sniff clears the trail")
	shell.queue_free()
	await frames(2)


func _visible_crumbs(trail: ScentTrail) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	for crumb: MeshInstance3D in trail.crumbs:
		if crumb.visible:
			result.append(crumb)
	return result
