class_name ScentTrail
extends Node3D

@export_range(1.0, 5.0) var length: float = 3.0
@export_range(0.3, 3.0) var lifetime: float = 1.2

var crumbs: Array[MeshInstance3D] = []
var age: float = 0.0
var _pulse: int = 0


func _ready() -> void:
	var mesh := QuadMesh.new()
	mesh.size = Vector2(0.07, 0.07)
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	var haze := GradientTexture2D.new()
	haze.gradient = gradient
	haze.width = 32
	haze.height = 32
	haze.fill = GradientTexture2D.FILL_RADIAL
	haze.fill_from = Vector2(0.5, 0.5)
	haze.fill_to = Vector2(0.5, 1.0)
	for index: int in 5:
		var crumb := MeshInstance3D.new()
		crumb.mesh = mesh
		crumb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		material.albedo_texture = haze
		material.albedo_color = Color(0.8, 0.85, 0.72, 0.0)
		crumb.material_override = material
		add_child(crumb)
		crumb.hide()
		crumbs.append(crumb)


func clear() -> void:
	for crumb: MeshInstance3D in crumbs:
		crumb.hide()


func emit_hint(origin: Vector3, destination: Vector3, excluded: Array[RID]) -> void:
	clear()
	age = 0.0
	_pulse += 1
	var offset := destination - origin
	offset.y = 0.0
	if offset.length() < 1.0:
		return
	var forward := offset.normalized()
	var side := forward.cross(Vector3.UP)
	var reach := minf(length, offset.length() * 0.6)
	var space := get_world_3d().direct_space_state
	var previous := origin + Vector3.UP * 0.25
	for index: int in crumbs.size():
		var step := 0.5 + (reach - 0.5) * float(index + 1) / float(crumbs.size())
		var point := origin + forward * step + side * sin(float(index) * 1.8 + float(_pulse)) * 0.2
		var floor_query := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 1.25, point + Vector3.DOWN * 2.0, Layers.WORLD, excluded)
		var floor_hit := space.intersect_ray(floor_query)
		if floor_hit.is_empty() or floor_hit.normal.y < 0.65:
			break
		point = floor_hit.position + Vector3.UP * 0.12
		var wall_query := PhysicsRayQueryParameters3D.create(previous, point + Vector3.UP * 0.12, Layers.WORLD, excluded)
		if not space.intersect_ray(wall_query).is_empty():
			break
		crumbs[index].global_position = point
		crumbs[index].show()
		previous = point + Vector3.UP * 0.12


func _process(delta: float) -> void:
	age += delta
	if age >= lifetime:
		clear()
		return
	for index: int in crumbs.size():
		var crumb := crumbs[index]
		if not crumb.visible:
			continue
		crumb.position.y += delta * 0.06
		var material := crumb.material_override as StandardMaterial3D
		var opacity := sin(PI * clampf(age / lifetime, 0.0, 1.0)) * 0.16
		material.albedo_color.a = opacity
