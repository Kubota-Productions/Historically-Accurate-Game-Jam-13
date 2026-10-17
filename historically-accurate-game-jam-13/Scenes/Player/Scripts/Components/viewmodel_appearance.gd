class_name ViewmodelAppearance
extends RefCounted

var _meshes: Array[Dictionary] = []


func apply(root: Node3D, priority: int) -> void:
	var meshes: Array[Node] = root.find_children("*", "MeshInstance3D", true, false)
	if root is MeshInstance3D:
		meshes.push_front(root)
	for mesh: MeshInstance3D in meshes:
		if mesh.mesh == null:
			continue
		var surfaces: Array[Material] = []
		for surface: int in mesh.mesh.get_surface_count():
			surfaces.append(mesh.get_surface_override_material(surface))
		_meshes.append({"mesh": mesh, "override": mesh.material_override,
			"surfaces": surfaces, "layers": mesh.layers, "shadow": mesh.cast_shadow})
		mesh.layers = 2
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if mesh.material_override:
			mesh.material_override = _material(mesh.material_override, priority)
		else:
			for surface: int in mesh.mesh.get_surface_count():
				mesh.set_surface_override_material(surface, _material(mesh.get_active_material(surface), priority))


func restore() -> void:
	for state: Dictionary in _meshes:
		var mesh: MeshInstance3D = state.mesh
		if not is_instance_valid(mesh):
			continue
		mesh.material_override = state.override
		mesh.layers = state.layers
		mesh.cast_shadow = state.shadow
		for surface: int in state.surfaces.size():
			mesh.set_surface_override_material(surface, state.surfaces[surface])
	_meshes.clear()


func _material(source: Material, priority: int) -> Material:
	if source != null and not source is BaseMaterial3D:
		return source
	var material := source.duplicate() as BaseMaterial3D if source else StandardMaterial3D.new()
	material.no_depth_test = true
	material.disable_receive_shadows = true
	material.render_priority = priority
	return material
