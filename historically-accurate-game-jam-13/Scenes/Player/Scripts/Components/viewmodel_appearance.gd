class_name ViewmodelAppearance
extends RefCounted

class SavedMesh:
	var mesh: MeshInstance3D
	var override: Material
	var surfaces: Array[Material] = []
	var layers: int
	var shadow: GeometryInstance3D.ShadowCastingSetting

var _saved: Array[SavedMesh] = []


func apply(root: Node3D, priority: int) -> void:
	var meshes: Array[Node] = root.find_children("*", "MeshInstance3D", true, false)
	if root is MeshInstance3D:
		meshes.push_front(root)
	for mesh: MeshInstance3D in meshes:
		if mesh.mesh == null:
			continue
		var saved := SavedMesh.new()
		saved.mesh = mesh
		saved.override = mesh.material_override
		saved.layers = mesh.layers
		saved.shadow = mesh.cast_shadow
		for surface: int in mesh.mesh.get_surface_count():
			saved.surfaces.append(mesh.get_surface_override_material(surface))
		_saved.append(saved)
		mesh.layers = Layers.VIEWMODEL
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if mesh.material_override:
			mesh.material_override = _on_top(mesh.material_override, priority)
		else:
			for surface: int in mesh.mesh.get_surface_count():
				mesh.set_surface_override_material(surface, _on_top(mesh.get_active_material(surface), priority))


func restore() -> void:
	for saved: SavedMesh in _saved:
		if not is_instance_valid(saved.mesh):
			continue
		saved.mesh.material_override = saved.override
		saved.mesh.layers = saved.layers
		saved.mesh.cast_shadow = saved.shadow
		for surface: int in saved.surfaces.size():
			saved.mesh.set_surface_override_material(surface, saved.surfaces[surface])
	_saved.clear()


func _on_top(source: Material, priority: int) -> Material:
	if source != null and not source is BaseMaterial3D:
		return source
	var material := source.duplicate() as BaseMaterial3D if source else StandardMaterial3D.new()
	material.no_depth_test = true
	material.disable_receive_shadows = true
	material.render_priority = priority
	return material
