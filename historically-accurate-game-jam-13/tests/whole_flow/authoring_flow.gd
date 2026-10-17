extends SceneTree

class ChainProgress extends RoomProgress:
	func complete_dialogue(_id: StringName) -> void:
		room.dialogue_requested.emit(&"reminder")

class RejectSocket extends ItemSocket:
	func install(_id: StringName) -> bool:
		return false

var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var shell = load("res://Scenes/Game/Game.tscn").instantiate()
	root.add_child(shell)
	await process_frame
	await shell.start_game()
	shell.dialogue.advance(true)
	shell.dialogue.advance(false)
	var room: LaikaRoom = shell.room
	var original_count := room.get_interactions().size()
	room.player.teleport(Vector3(0, 0, 2.4))
	await physics_frame
	await physics_frame

	var shelf := Node3D.new()
	room.add_child(shelf)
	shelf.position = Vector3(3, 0, 2)
	var sibling := Node3D.new()
	shelf.add_child(sibling)
	sibling.position = Vector3(1, 0, 0)
	var shelf_before := shelf.global_transform
	var sibling_before := sibling.global_transform
	var item: LaikaInteractionPoint = load("res://Scenes/Shared/Interactables/Pickup.tscn").instantiate()
	shelf.add_child(item)
	_check(room.get_interactions().size() == original_count + 1, "Runtime items register automatically")
	_check(item.configuration_errors(room).is_empty(), "Pickup template is ready without extra internal wiring")
	var first: MeshInstance3D = item.visual_root.get_node("Mesh")
	var texture := ImageTexture.create_from_image(Image.create(2, 2, false, Image.FORMAT_RGBA8))
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.2, 0.4, 0.8)
	material.albedo_texture = texture
	first.material_override = material
	var second := MeshInstance3D.new()
	second.mesh = BoxMesh.new()
	second.mesh.surface_set_material(0, material)
	item.visual_root.add_child(second)
	item.item_shape.position = Vector3(0.05, 0.15, 0)
	item.rotation.z = 0.3
	item.scale = Vector3(1.2, 0.8, 1.1)
	var world_scale := item.global_basis.get_scale()
	_check(room.carry.take(item), "A multi-mesh item can be picked up")
	_check(item.global_basis.get_scale().is_equal_approx(world_scale), "Carry preserves the authored world scale")
	_check(first.layers == 2 and second.layers == 2, "All meshes use the viewmodel render layer")
	var held := first.material_override as StandardMaterial3D
	_check(held != material and held.albedo_texture == texture and held.albedo_color == material.albedo_color, "Viewmodel materials preserve textures and color without mutating the asset")
	_check(second.get_surface_override_material(0) != null and not material.no_depth_test, "Per-surface materials are handled without changing shared resources")
	_check(room.get_interactions().size() == original_count + 1, "Reparenting does not duplicate the interaction registration")
	room.carry.drop()
	_check(room.carry.item == null, "An offset rotated collider finds a valid drop position")
	_check(shelf.global_transform.is_equal_approx(shelf_before) and sibling.global_transform.is_equal_approx(sibling_before), "Dropping does not move the container or siblings")
	_check(first.material_override == material and second.get_surface_override_material(0) == null, "Drop restores both material override kinds")
	_check(first.layers == 1 and second.layers == 1 and item.collision_layer == 2, "Drop restores rendering and collision layers")
	var bounds: AABB = item.item_shape.global_transform * item.item_shape.shape.get_debug_mesh().get_aabb()
	_check(absf(bounds.position.y - 0.03) < 0.03, "The transformed collider rests above the floor")

	room.carry.take(item)
	var rejected := RejectSocket.new()
	room.add_child(rejected)
	_check(not room.carry.store(rejected) and room.carry.item == item and item.visible, "Failed installation leaves the carried item intact")
	var socket := ItemSocket.new()
	room.add_child(socket)
	socket.accepted_item = &"other"
	_check(not room.carry.store(socket), "A mismatched socket does not consume an item")
	socket.accepted_item = item.item_id
	_check(room.carry.store(socket) and socket.count == 1 and not item.visible, "Successful installation consumes exactly one item")

	var fresh: LaikaInteractionPoint = load("res://Scenes/Shared/Interactables/Pickup.tscn").instantiate()
	room.add_child(fresh)
	_check(fresh.action != item.action and fresh.item_shape.shape != item.item_shape.shape, "Template instances have independent action and collider configuration")
	room.scent._update(true)
	_check(fresh.scent_marker.visible, "New sources participate in scent automatically")
	room.scent.enabled = false
	_check(not fresh.scent_marker.visible, "Disabling scent hides markers immediately")
	var count_before := room.get_interactions().size()
	fresh.queue_free()
	await process_frame
	room.scent._update(true)
	_check(room.get_interactions().size() == count_before - 1, "Deleted sources unregister without stale references")
	room.scent._update(false)

	var original: RoomProgress = room.progress
	var chain := ChainProgress.new()
	room.add_child(chain)
	chain.setup(room)
	room.progress = chain
	shell._open_dialogue(&"scientist")
	shell.dialogue.advance(true)
	_check(shell.dialogue.active and shell.dialogue.session.id == &"reminder", "A completion handler can immediately start another conversation")
	_check(not room.interactor.enabled and shell.hud._dialogue_active and room.control_enabled, "Chained dialogue preserves context locking, HUD and movement")
	shell.pause_game()
	_check(not room.scent.enabled, "Pause disables contextual effects")
	shell.resume_game()
	_check(not room.interactor.enabled and shell.dialogue.active, "Resume preserves the active dialogue's interaction lock")
	shell.dialogue.close()
	room.progress = original
	shell._sync_context()
	_check(room.interactor.enabled, "Closing the conversation restores world interactions")
	var opened: bool = shell.dialogue.open(&"invalid_test", [{"text": 123}])
	shell._sync_context()
	_check(not opened and not shell.dialogue.active and room.interactor.enabled and not shell.hud._dialogue_active, "A refused conversation does not lock interactions or HUD")
	_check(not DialogueSession.content_errors([{"text": 123}]).is_empty(), "Invalid dialogue data is rejected before presentation")
	_check(not DialogueSession.content_errors([]).is_empty(), "Empty conversations fail validation")
	var session := DialogueSession.new()
	session.open(&"greeting", DialogueCatalog.lines(&"greeting"))
	session.lines[0].text = "Modified session"
	_check(DialogueCatalog.lines(&"greeting")[0].text != "Modified session", "Only the session copies content and the catalog remains unchanged")

	var slider := SettingDefinition.new(&"test_volume", {"kind": SettingDefinition.Kind.SLIDER, "label": "Volume", "default": 1, "section": &"audio"})
	_check(slider.kind == SettingDefinition.Kind.SLIDER and slider.configuration_errors().is_empty() and is_equal_approx(slider.sanitize(0.5), 0.5), "An integer default remains an explicitly defined slider")
	var malformed := SettingDefinition.new(&"bad", {"kind": SettingDefinition.Kind.SLIDER, "label": "Bad", "default": 2, "minimum": 3, "maximum": 1})
	_check(not malformed.configuration_errors().is_empty(), "Invalid ranges produce configuration errors")
	var missing_kind := SettingDefinition.new(&"bad", {"label": "Bad", "default": true})
	_check(not missing_kind.configuration_errors().is_empty(), "A missing kind cannot silently infer a different control")
	var invalid_point := LaikaInteractionPoint.new()
	invalid_point.action = SocketAction.new()
	_check("socket" in ";".join(invalid_point.configuration_errors()), "Missing Inspector wiring identifies the required field")
	invalid_point.free()
	var bad_event := EventAction.new()
	bad_event.event_id = &"unknown_event"
	_check(not bad_event.configuration_errors(item, room).is_empty(), "Unknown level events are detected")
	var missing_flag := PickupAction.new()
	missing_flag.required_flag = &"misspelled_flag"
	var previous_action: InteractionAction = item.action
	item.action = missing_flag
	_check(not item.configuration_errors(room).is_empty(), "Unknown flag names are caught before gameplay")
	item.action = previous_action
	var preferences := GameSettings.new()
	preferences.register(SettingDefinition.new(&"bad_target", {"kind": SettingDefinition.Kind.TOGGLE, "label": "Test", "default": false, "effect": [&"player", &"missing_property"]}))
	var effect_errors := SettingsEffects.configuration_errors(preferences, {&"player": room.rig, &"projection": shell.projection, &"dog_vision": shell.dog_vision})
	_check("missing_property" in ";".join(effect_errors), "Invalid effect property names identify the missing property")
	_check(DialogueCatalog.configuration_errors().is_empty(), "All shipped conversations pass schema validation")

	shell.queue_free()
	await process_frame
	await process_frame
	print("AUTHORING_FLOW: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)
