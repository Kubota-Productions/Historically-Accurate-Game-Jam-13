class_name LaikaRoom
extends Node3D

signal objective_changed(text: String, detail: String)
signal prompt_changed(text: String, action: StringName)
signal carrying_changed(text: String)
signal thought_requested(text: String)
signal dialogue_requested(id: StringName)
signal departure_requested
signal sniffing_changed(active: bool)

enum Step { GREETING, FETCH, POWER, CAPSULE, ARRIVAL, COMPLETE }

const CARRIED_MATERIAL := preload("res://Resources/Materials/carried_item.tres")

@export var station: bool = false
@export var interaction_distance: float = 3.0

var step: Step = Step.GREETING
var batteries: int = 0
var carried: LaikaInteractionPoint
var target: LaikaInteractionPoint
var control_enabled: bool = false
var _pickup_basis: Basis
var _carried_parent: Node
var _carried_mesh: MeshInstance3D
var _pickup_material: Material
var _pickup_layers: int
var _pickup_shadow: GeometryInstance3D.ShadowCastingSetting
var _sniffing: bool = false
var _last_prompt: String = ""

@onready var player: FPSPlayer = $Actors/Player
@onready var rig: FPSCamera = $Actors/Player/CameraHolder
@onready var camera: Camera3D = $Actors/Player/CameraHolder/Camera3D
@onready var carry_anchor: Marker3D = $Actors/Player/CameraHolder/Camera3D/CarryAnchor
@onready var menu_camera: Camera3D = $Cameras/MenuCamera
@onready var scent_markers: Node3D = $Hints/ScentMarkers


func _ready() -> void:
	set_control_enabled(false)
	menu_camera.make_current()
	if station:
		step = Step.ARRIVAL


func _process(_delta: float) -> void:
	if not control_enabled:
		return
	var query := PhysicsRayQueryParameters3D.create(
		camera.global_position,
		camera.global_position - camera.global_basis.z * interaction_distance,
		3,
		[player.get_rid()]
	)
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	target = hit.get("collider") as LaikaInteractionPoint
	_refresh_prompt()
	var sniffing := Input.is_action_pressed(&"sniff")
	if sniffing != _sniffing:
		_sniffing = sniffing
		scent_markers.visible = sniffing
		sniffing_changed.emit(sniffing)


func begin() -> void:
	camera.make_current()
	set_control_enabled(true)
	carrying_changed.emit("")
	if station:
		objective_changed.emit("Find the source of the voice", "STATION  /  ARRIVAL")
		dialogue_requested.emit(&"arrival")
	else:
		objective_changed.emit("Say hello to the scientist", "TRAINING  /  01")
		dialogue_requested.emit(&"greeting")


func set_control_enabled(enabled: bool) -> void:
	control_enabled = enabled
	player.set_physics_process(enabled)
	rig.set_process_unhandled_input(enabled)
	if not enabled:
		player.velocity = Vector3.ZERO
		target = null
		_last_prompt = ""
		prompt_changed.emit("", &"interact")
		_sniffing = false
		scent_markers.hide()
		sniffing_changed.emit(false)


func complete_dialogue(id: StringName) -> void:
	if id == &"greeting":
		step = Step.FETCH
		objective_changed.emit("Bring two batteries to the training stand", "0 / 2 BATTERIES")
		thought_requested.emit("Two things. One mouth. I can do this.")
	elif id == &"trained":
		step = Step.CAPSULE
		objective_changed.emit("Get comfortable in the capsule", "TRAINING COMPLETE")
		thought_requested.emit("My bed has buttons now.")
	elif id == &"arrival":
		objective_changed.emit("Talk to the service robot", "APPROACH THE ROBOT")
	elif id == &"robot":
		step = Step.COMPLETE
		objective_changed.emit("Playground complete", "Explore freely · Esc opens the menu")


func interact() -> void:
	if not control_enabled:
		return
	if not is_instance_valid(target):
		return
	var id := target.interaction_id
	if id == &"scientist":
		dialogue_requested.emit(&"reminder" if step == Step.FETCH else &"scientist")
	elif id == &"robot":
		if step == Step.COMPLETE:
			thought_requested.emit("No more tasks here. I can explore, or leave through the menu.")
		else:
			dialogue_requested.emit(&"robot")
	elif id.begins_with("battery"):
		if not carried and step == Step.FETCH:
			_take(target)
	elif id == &"stand":
		if carried:
			_insert_battery()
		elif batteries < 2:
			thought_requested.emit("Something goes in here. Probably not my nose.")
	elif id == &"button":
		if step == Step.POWER:
			dialogue_requested.emit(&"trained")
		elif batteries < 2:
			thought_requested.emit("Click. Still needs two batteries.")
		else:
			thought_requested.emit("Test complete. Time to get into the capsule.")
	elif id == &"capsule":
		if step == Step.CAPSULE:
			set_control_enabled(false)
			departure_requested.emit()
		else:
			thought_requested.emit("He hasn't said it's bedtime yet.")


func drop() -> void:
	if not carried:
		return
	var point := _find_drop_position()
	if not point.is_finite():
		thought_requested.emit("No room to put this down here.")
		return
	carried.reparent(_carried_parent)
	(_carried_parent as Node3D).global_position = point
	carried.global_transform = Transform3D(_pickup_basis, point)
	carried.collision_layer = 2
	_restore_carried_visuals()
	var marker: Node3D = get_node("Hints/ScentMarkers/Marker" + str(carried.interaction_id).trim_prefix("battery"))
	marker.global_position = point + Vector3.UP * 0.55
	marker.show()
	carried = null
	carrying_changed.emit("")


func _find_drop_position() -> Vector3:
	var forward := Basis(Vector3.UP, player.look_yaw) * Vector3.FORWARD
	var side := forward.cross(Vector3.UP)
	var offsets: Array[Vector3] = [forward * 0.85, forward * 0.55, forward * 0.3 + side * 0.65, forward * 0.3 - side * 0.65]
	var shape: CollisionShape3D = carried.get_node("CollisionShape3D")
	var space := get_world_3d().direct_space_state
	for offset: Vector3 in offsets:
		var from := player.global_position + offset + Vector3.UP * 1.3
		var ray := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 2.0, 1, [player.get_rid()])
		var hit := space.intersect_ray(ray)
		if hit.is_empty() or (hit.normal as Vector3).y < 0.7:
			continue
		var point: Vector3 = hit.position + Vector3.UP * 0.28
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = shape.shape
		query.transform = Transform3D(_pickup_basis, point)
		query.collision_mask = 3
		query.exclude = [player.get_rid(), carried.get_rid()]
		if space.intersect_shape(query, 1).is_empty():
			return point
	return Vector3.INF


func bark() -> void:
	thought_requested.emit("Woof!")


func _take(item: LaikaInteractionPoint) -> void:
	carried = item
	_pickup_basis = item.global_basis
	_carried_parent = item.get_parent()
	_carried_mesh = item.get_node("Cell")
	_pickup_material = _carried_mesh.material_override
	_pickup_layers = _carried_mesh.layers
	_pickup_shadow = _carried_mesh.cast_shadow
	_carried_mesh.material_override = CARRIED_MATERIAL
	_carried_mesh.layers = 2
	_carried_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	get_node("Hints/ScentMarkers/Marker" + str(item.interaction_id).trim_prefix("battery")).hide()
	item.collision_layer = 0
	item.reparent(carry_anchor)
	item.transform = Transform3D(Basis.from_scale(_pickup_basis.get_scale()), Vector3.ZERO)
	carrying_changed.emit("battery")


func _insert_battery() -> void:
	carried.reparent(_carried_parent)
	carried.hide()
	_restore_carried_visuals()
	carried = null
	batteries += 1
	get_node("Props/TrainingStand/Cell%d" % batteries).show()
	carrying_changed.emit("")
	if batteries == 2:
		step = Step.POWER
		objective_changed.emit("Press the test button", "2 / 2 BATTERIES · READY")
	else:
		objective_changed.emit("Bring the second battery to the stand", "1 / 2 BATTERIES")


func _restore_carried_visuals() -> void:
	_carried_mesh.material_override = _pickup_material
	_carried_mesh.layers = _pickup_layers
	_carried_mesh.cast_shadow = _pickup_shadow
	_carried_mesh = null


func _refresh_prompt() -> void:
	var text := ""
	var action: StringName = &"interact"
	if target:
		text = target.display_name
		if target.interaction_id == &"stand":
			text = "Place battery" if carried else ("Inspect battery slots" if batteries < 2 else "")
		elif target.interaction_id == &"button" and step == Step.CAPSULE:
			text = "Test complete — enter the capsule"
	if carried and target and str(target.interaction_id).begins_with("battery"):
		text = ""
	if text != _last_prompt:
		_last_prompt = text
		prompt_changed.emit(text, action)
