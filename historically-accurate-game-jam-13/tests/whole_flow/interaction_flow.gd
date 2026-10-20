extends "res://tests/support/flow_test.gd"

const PICKUP := preload("res://Scenes/Shared/Interactables/Pickup.tscn")
const SCIENTIST: Dialogue = preload("res://GameData/Dialogue/Training/scientist.tres")
const REMINDER: Dialogue = preload("res://GameData/Dialogue/Training/reminder.tres")

@warning_ignore("missing_tool")
class CounterAction extends InteractionAction:
	var count: int = 0

	func execute(_room: LaikaRoom, _target: Interactable) -> void:
		count += 1

class ChainProgress extends RoomProgress:
	func dialogue_finished(_dialogue: Dialogue) -> void:
		room.dialogue_requested.emit(REMINDER)

@warning_ignore("missing_tool")
class RejectSocket extends ItemSocket:
	func install(_item: PickupItem) -> bool:
		return false

var shell: GameShell
var room: LaikaRoom


func run() -> void:
	shell = await boot_shell()
	await shell.enter_room(load("res://GameData/Rooms/station.tres"))
	room = shell.room
	await _dialogue_keeps_movement()
	_custom_actions_need_no_room_code()
	_any_item_can_be_carried()
	await _carrying_preserves_the_asset()
	_sockets_take_matching_items()
	await _scent_follows_pickups()
	_dialogues_can_chain()
	_mistakes_are_reported()
	shell.queue_free()


func _dialogue_keeps_movement() -> void:
	check(room.control_enabled and not room.interactor.enabled, "Dialogue keeps movement but blocks world interactions")
	var start := room.player.global_position
	Input.action_press(&"forward")
	for frame: int in 10:
		await physics_frame
	Input.action_release(&"forward")
	check(room.player.global_position.distance_to(start) > 0.01 and shell.dialogue.session.active, "The player walks while a conversation stays open")
	shell.dialogue.session.advance(true)
	shell.dialogue.session.advance(false)
	check(room.interactor.enabled, "World interactions resume when dialogue finishes")
	room.player.teleport(Vector3(0, 0, 2.4))
	await physics_frame
	await physics_frame


func _custom_actions_need_no_room_code() -> void:
	var target := Interactable.new()
	var action := CounterAction.new()
	target.action = action
	room.add_child(target)
	room.interactor.target = target
	room.interact()
	check(action.count == 1, "A new action works without changing the room")
	action.required_flag = &"departure_ready"
	room.interact()
	check(action.count == 1, "An unmet flag blocks the action")
	room.progress.set_flag(&"departure_ready")
	room.interact()
	check(action.count == 2, "Meeting the flag enables the action")
	room.progress.set_flag(&"departure_ready", false)
	target.hide()
	action.required_flag = &""
	room.interact()
	check(action.count == 2, "Hidden objects cannot be used")
	target.free()


func _any_item_can_be_carried() -> void:
	var group := Node3D.new()
	group.scale = Vector3.ONE * 1.5
	room.add_child(group)
	var item := PickupItem.new()
	item.action = PickupAction.new()
	item.item_id = &"wrench"
	item.item_name = "wrench"
	item.visual_root = MeshInstance3D.new()
	item.visual_root.mesh = BoxMesh.new()
	item.shape = CollisionShape3D.new()
	item.shape.shape = BoxShape3D.new()
	item.add_child(item.visual_root)
	item.add_child(item.shape)
	group.add_child(item)
	check(item.configuration_errors(room).is_empty(), "A pickup built in code is valid")
	var scale_before := item.global_basis.get_scale()
	room.interactor.target = item
	room.interact()
	check(room.carry.item == item and item.global_basis.get_scale().is_equal_approx(scale_before), "Any item can be carried without changing its size")
	var socket := ItemSocket.new()
	socket.capacity = 1
	room.add_child(socket)
	check(not room.carry.store(socket) and room.carry.item == item, "A socket rejects the wrong item without dropping it")
	socket.accepted_item = &"wrench"
	check(room.carry.store(socket) and socket.count == 1 and room.carry.item == null and not item.visible, "A socket accepts its item")
	check(socket.is_full() and not socket.accepts(item), "A full socket takes nothing more")
	socket.free()
	group.free()


func _carrying_preserves_the_asset() -> void:
	var shelf := Node3D.new()
	room.add_child(shelf)
	shelf.position = Vector3(3, 0, 2)
	var sibling := Node3D.new()
	shelf.add_child(sibling)
	var shelf_before := shelf.global_transform
	var count_before := room.interactables().size()
	var item: PickupItem = PICKUP.instantiate()
	shelf.add_child(item)
	check(room.interactables().size() == count_before + 1, "Placed items register automatically")
	check(item.configuration_errors(room).is_empty(), "The pickup template needs no extra wiring")
	var first: MeshInstance3D = item.visual_root.find_children("*", "MeshInstance3D", true, false)[0]
	var material := StandardMaterial3D.new()
	material.albedo_texture = ImageTexture.create_from_image(Image.create(2, 2, false, Image.FORMAT_RGBA8))
	first.material_override = material
	var second := MeshInstance3D.new()
	second.mesh = BoxMesh.new()
	second.mesh.surface_set_material(0, material)
	item.visual_root.add_child(second)
	item.shape.position = Vector3(0.05, 0.15, 0)
	item.rotation.z = 0.3
	item.scale = Vector3(1.2, 0.8, 1.1)
	var world_scale := item.global_basis.get_scale()
	room.carry.take(item)
	check(item.global_basis.get_scale().is_equal_approx(world_scale), "Carrying keeps the world scale")
	check(room.camera.get_node("Snout").is_ancestor_of(item), "A held item follows the snout sway")
	check(first.layers == Layers.VIEWMODEL and second.layers == Layers.VIEWMODEL, "Every mesh renders on the viewmodel layer")
	var held := first.material_override as StandardMaterial3D
	check(held != material and held.albedo_texture == material.albedo_texture, "Held materials keep textures without changing the asset")
	check(second.get_surface_override_material(0) != null and not material.no_depth_test, "Surface materials are handled without changing shared resources")
	check(room.interactables().size() == count_before + 1, "Reparenting does not register twice")
	room.carry.drop()
	check(room.carry.item == null, "An offset rotated collider finds a drop position")
	check(shelf.global_transform.is_equal_approx(shelf_before) and sibling.get_parent() == shelf, "Dropping leaves the container alone")
	check(first.material_override == material and second.get_surface_override_material(0) == null, "Dropping restores both material kinds")
	check(first.layers == 1 and item.collision_layer == Layers.INTERACTABLES, "Dropping restores rendering and collision")
	var bounds: AABB = item.shape.global_transform * item.shape.shape.get_debug_mesh().get_aabb()
	var bottom := Vector3(bounds.get_center().x, bounds.position.y, bounds.get_center().z)
	var floor_hit := room.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(bottom, bottom + Vector3.DOWN * 0.2, Layers.WORLD))
	check(not floor_hit.is_empty() and floor_hit.normal.y >= CarryController.FLOOR_MIN_NORMAL_Y, "The dropped collider rests just above walkable terrain")
	var placement := PhysicsShapeQueryParameters3D.new()
	placement.shape = item.shape.shape
	placement.transform = item.shape.global_transform
	placement.collision_mask = Layers.WORLD
	check(room.get_world_3d().direct_space_state.intersect_shape(placement, 1).is_empty(), "The dropped collider does not penetrate the terrain")
	room.carry.take(item)
	var rejecting := RejectSocket.new()
	room.add_child(rejecting)
	check(not room.carry.store(rejecting) and room.carry.item == item and item.visible, "A failed install keeps the item in the mouth")
	room.carry.drop()
	rejecting.free()
	item.queue_free()
	await process_frame
	check(room.interactables().size() == count_before, "Deleted items unregister")
	shelf.free()


func _sockets_take_matching_items() -> void:
	var stand: ItemSocket = room.get_node("Props/TrainingStand/Slots")
	var action: SocketAction = stand.action
	check(stand.get_prompt(room) == "Inspect battery slots", "An empty mouth inspects the socket")
	var thoughts: Array[String] = []
	var record := func(text: String) -> void: thoughts.append(text)
	room.thought_requested.connect(record)
	stand.interact(room)
	room.thought_requested.disconnect(record)
	check(thoughts == [action.empty_message], "Using a socket with an empty mouth explains it")


func _scent_follows_pickups() -> void:
	var fresh: PickupItem = PICKUP.instantiate()
	room.add_child(fresh)
	Input.action_press(&"sniff")
	await frames(3)
	check(room.scent.active and fresh.scent_marker.visible, "New pickups take part in scent")
	room.carry.take(fresh)
	check(not fresh.scent_marker.visible, "A carried item has no scent marker")
	room.carry.drop()
	room.scent.enabled = false
	check(not room.scent.active and not fresh.scent_marker.visible, "Disabling scent hides markers")
	Input.action_release(&"sniff")
	room.scent.enabled = true
	fresh.free()


func _dialogues_can_chain() -> void:
	var original := room.progress
	var chain := ChainProgress.new()
	room.add_child(chain)
	chain.room = room
	room.progress = chain
	room.dialogue_requested.emit(SCIENTIST)
	shell.dialogue.session.advance(true)
	check(shell.dialogue.session.dialogue == REMINDER, "Finishing a conversation can start another")
	check(not room.interactor.enabled and room.control_enabled and shell.hud.interact_hint.caption == "Continue", "A chained conversation keeps the dialogue context")
	shell.pause_game()
	check(not room.scent.enabled, "Pause disables scent")
	shell.resume_game()
	check(not room.interactor.enabled and shell.dialogue.session.active, "Resume keeps the conversation")
	room.progress = original
	shell.dialogue.session.advance(false)
	check(room.interactor.enabled, "Ending the conversation restores interactions")
	room.dialogue_requested.emit(Dialogue.new())
	check(not shell.dialogue.session.active and room.interactor.enabled, "An empty conversation is refused without locking anything")
	chain.free()


func _mistakes_are_reported() -> void:
	var point := Interactable.new()
	check("action" in "".join(point.configuration_errors()), "A missing action is reported")
	point.action = SocketAction.new()
	check("ItemSocket" in "".join(point.configuration_errors()), "An action on the wrong node type is reported")
	point.action = PickupAction.new()
	point.action.required_flag = &"misspelled"
	check("misspelled" in "".join(point.configuration_errors(room)), "Unknown flags are reported")
	var event := EventAction.new()
	event.event = &"unknown"
	point.action = event
	check("event" in "".join(point.configuration_errors(room)), "Unknown events are reported")
	check(&"fetch" in RoomProgress.declared(&"FLAGS") and &"test" in RoomProgress.declared(&"EVENTS"), "The Inspector offers the flags and events levels declare")
	point.free()
