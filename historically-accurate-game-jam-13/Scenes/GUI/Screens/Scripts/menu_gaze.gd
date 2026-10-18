class_name MenuGaze
extends Node

@export var button_container: Container
@export var preview: TextureRect
@export var preview_camera: Camera3D
@export var look_target: Marker3D
@export_range(0.1, 30.0, 0.1) var response_speed: float = 12.0
@export_range(0.1, 5.0, 0.1) var gaze_strength: float = 2.0

var _neutral_position: Vector3

@onready var _menu: Control = get_parent() as Control


func _ready() -> void:
	if not _menu or not button_container or not preview or not preview_camera or not look_target:
		push_error("MenuGaze: assign the menu buttons, preview, camera and look target.")
		set_process(false)
		return
	_neutral_position = look_target.position
	_menu.visibility_changed.connect(_on_visibility_changed)
	_on_visibility_changed()


func _process(delta: float) -> void:
	var goal := look_target.get_parent_node_3d().to_global(_neutral_position)
	if preview.texture != null and preview.size.x > 0.0 and preview.size.y > 0.0:
		var texture_size := preview.texture.get_size()
		if texture_size.x > 0.0 and texture_size.y > 0.0:
			var mouse_position := preview.get_global_transform_with_canvas().affine_inverse() * preview.get_global_transform_with_canvas().affine_inverse().affine_inverse() * get_viewport().get_mouse_position()
			var depth := (goal - preview_camera.global_position).dot(-preview_camera.global_basis.z)
			if depth > preview_camera.near:
				var point := preview_camera.project_position(_preview_point(mouse_position, texture_size), depth)
				var center := preview_camera.project_position(_preview_point(preview.size * 0.5, texture_size), depth)
				goal += (point - center) * gaze_strength
	look_target.global_position = look_target.global_position.lerp(goal, 1.0 - exp(-response_speed * delta))


func _preview_point(canvas_position: Vector2, texture_size: Vector2) -> Vector2:
	var local := canvas_position
	var image := _image_rect(texture_size)
	var uv := (local - image.position) / image.size
	if preview.stretch_mode == TextureRect.STRETCH_TILE:
		uv = Vector2(fposmod(uv.x, 1.0), fposmod(uv.y, 1.0))
	if preview.flip_h:
		uv.x = 1.0 - uv.x
	if preview.flip_v:
		uv.y = 1.0 - uv.y
	var viewport_size := preview_camera.get_viewport().get_visible_rect().size
	return uv * viewport_size


func _image_rect(texture_size: Vector2) -> Rect2:
	var image_size := preview.size
	var offset := Vector2.ZERO
	match preview.stretch_mode:
		TextureRect.STRETCH_TILE, TextureRect.STRETCH_KEEP:
			image_size = texture_size
		TextureRect.STRETCH_KEEP_CENTERED:
			image_size = texture_size
			offset = (preview.size - image_size) * 0.5
		TextureRect.STRETCH_KEEP_ASPECT, TextureRect.STRETCH_KEEP_ASPECT_CENTERED:
			var ratio := preview.size / texture_size
			image_size = texture_size * minf(ratio.x, ratio.y)
			if preview.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_CENTERED:
				offset = (preview.size - image_size) * 0.5
		TextureRect.STRETCH_KEEP_ASPECT_COVERED:
			var ratio := preview.size / texture_size
			image_size = texture_size * maxf(ratio.x, ratio.y)
			offset = (preview.size - image_size) * 0.5
	return Rect2(offset, image_size)


func _on_visibility_changed() -> void:
	look_target.position = _neutral_position
	set_process(_menu.is_visible_in_tree())
