class_name ItemInspection
extends Control

signal closed

const DRAG_THRESHOLD := 5.0
const ROTATION_SPEED := 0.008

var target: Interactable
var _model: Node3D
var _previous_mouse_mode: Input.MouseMode
var _dragging: bool = false
var _drag_distance: float = 0.0
var _zoom: float = 1.0

@onready var preview: SubViewportContainer = %Preview
@onready var viewport: SubViewport = %InspectionViewport
@onready var pivot: Node3D = %Pivot
@onready var camera: Camera3D = %InspectionCamera


func _ready() -> void:
	%Close.pressed.connect(close)
	%Reset.pressed.connect(reset_view)
	preview.resized.connect(_frame_model)
	hide()


func open(source: Interactable) -> bool:
	if not is_instance_valid(source) or not source.allow_inspection or not source.is_inside_tree():
		return false
	var model: Node3D
	if source.inspection_scene:
		var instance := source.inspection_scene.instantiate()
		if not instance is Node3D:
			instance.free()
			return false
		model = Node3D.new()
		model.add_child(instance)
		_add_occluders(model)
	else:
		model = _snapshot(source)
	if model == null:
		return false
	var bounds := _bounds(model)
	if bounds.size.length_squared() < 0.000001:
		model.free()
		return false
	if visible:
		close()
	target = source
	_model = model
	pivot.add_child(model)
	var radius := bounds.size.length() * 0.5
	model.scale /= radius
	model.position -= bounds.get_center() / radius
	for part: InspectionPart in model.find_children("*", "InspectionPart", true, false):
		if target.inspected_parts.has(part.part_id):
			part.reveal(true)
	%ItemTitle.text = tr(source.inspection_title if not source.inspection_title.is_empty() else (source.item_name if source is PickupItem else source.display_name))
	%Description.text = tr(source.inspection_description)
	%PartHint.text = ""
	_previous_mouse_mode = Input.mouse_mode
	source.tree_exiting.connect(close, CONNECT_ONE_SHOT)
	show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	reset_view()
	return true


func close() -> void:
	if not visible:
		return
	hide()
	if is_instance_valid(target) and target.tree_exiting.is_connected(close):
		target.tree_exiting.disconnect(close)
	target = null
	_dragging = false
	if is_instance_valid(_model):
		pivot.remove_child(_model)
		_model.queue_free()
	_model = null
	Input.mouse_mode = _previous_mouse_mode
	closed.emit()


func reset_view() -> void:
	pivot.basis = Basis.IDENTITY
	_zoom = 1.0
	_frame_model()


func consume_input(event: InputEvent) -> bool:
	if not visible:
		return false
	if event.is_action_pressed(&"ui_cancel") or (not event is InputEventMouse and event.is_action_pressed(&"inspect")):
		close()
	elif event is InputEventMouseMotion:
		if _dragging:
			_drag_distance += event.relative.length()
			pivot.rotate_y(event.relative.x * ROTATION_SPEED)
			pivot.rotate(Vector3.RIGHT, event.relative.y * ROTATION_SPEED)
		var part := _part_at(event.position)
		%PartHint.text = tr(part.caption) if part else ""
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_dragging = preview.get_global_rect().has_point(event.position)
				_drag_distance = 0.0
			else:
				if _dragging and _drag_distance < DRAG_THRESHOLD:
					_activate_part(_part_at(event.position))
				_dragging = false
		elif event.pressed and preview.get_global_rect().has_point(event.position):
			if event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
				_zoom = clampf(_zoom * (0.9 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.1), 0.65, 2.0)
				_frame_model()
	# Let the overlay's own buttons receive GUI events; never forward to the game.
	return not (event is InputEventMouse and not _dragging and not preview.get_global_rect().has_point(event.position))


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_dragging = false


func _exit_tree() -> void:
	close()


func _frame_model() -> void:
	if not is_node_ready() or preview.size.y <= 0.0:
		return
	var aspect := preview.size.x / preview.size.y
	var half_fov := deg_to_rad(camera.fov * 0.5)
	if aspect < 1.0:
		half_fov = atan(tan(half_fov) * aspect)
	camera.position = Vector3(0.0, 0.0, 1.15 / sin(half_fov) * _zoom)


func _part_at(screen_position: Vector2) -> InspectionPart:
	if not preview.get_global_rect().has_point(screen_position):
		return null
	var point := (screen_position - preview.global_position) * Vector2(viewport.size) / preview.size
	var origin := camera.project_ray_origin(point)
	var query := PhysicsRayQueryParameters3D.create(origin, origin + camera.project_ray_normal(point) * 30.0)
	var part := camera.get_world_3d().direct_space_state.intersect_ray(query).get("collider") as InspectionPart
	return part if part and not part.activated and not part.part_id.is_empty() else null


func _activate_part(part: InspectionPart) -> void:
	if part == null or not is_instance_valid(target):
		return
	target.inspected_parts[part.part_id] = true
	part.reveal()
	%PartHint.text = ""
	target.inspection_part_activated.emit(part.part_id)


func _snapshot(source: Interactable) -> Node3D:
	var model := Node3D.new()
	for mesh: MeshInstance3D in source.find_children("*", "MeshInstance3D", true, false):
		if mesh.mesh == null or not mesh.is_visible_in_tree():
			continue
		if source is PickupItem and source.scent_marker and (mesh == source.scent_marker or source.scent_marker.is_ancestor_of(mesh)):
			continue
		var copy := MeshInstance3D.new()
		copy.mesh = mesh.mesh
		copy.material_override = mesh.material_override
		for surface: int in mesh.mesh.get_surface_count():
			copy.set_surface_override_material(surface, mesh.get_surface_override_material(surface))
		model.add_child(copy)
		copy.transform = source.global_transform.affine_inverse() * mesh.global_transform
	return model


func _add_occluders(model: Node3D) -> void:
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		if mesh.mesh and mesh.visible:
			var parent := mesh.get_parent()
			while parent != model and not parent is InspectionPart:
				parent = parent.get_parent()
			if not parent is InspectionPart:
				mesh.create_trimesh_collision()


func _bounds(model: Node3D) -> AABB:
	var result := AABB()
	var found := false
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		if mesh.mesh == null:
			continue
		var transform := mesh.transform
		var parent := mesh.get_parent()
		while parent != model:
			if parent is Node3D:
				transform = parent.transform * transform
			parent = parent.get_parent()
		var box := transform * mesh.get_aabb()
		result = result.merge(box) if found else box
		found = true
	return result
