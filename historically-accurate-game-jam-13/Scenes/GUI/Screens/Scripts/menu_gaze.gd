class_name MenuGaze
extends Node

@export var button_container: Container
@export var preview: TextureRect
@export var preview_camera: Camera3D
@export var look_target: Marker3D
@export_range(0.1, 30.0, 0.1) var response_speed: float = 12.0
@export_range(0.1, 5.0, 0.1) var gaze_strength: float = 2.0

var _buttons: Array[BaseButton] = []
var _hovered: BaseButton
var _neutral_position: Vector3

@onready var _menu: Control = get_parent() as Control


func _ready() -> void:
	if not _menu or not button_container or not preview or not preview_camera or not look_target:
		push_error("MenuGaze: assign the menu buttons, preview, camera and look target.")
		set_process(false)
		return
	_neutral_position = look_target.position
	for child: Node in button_container.get_children():
		if child is BaseButton:
			_buttons.append(child)
			child.mouse_entered.connect(_on_mouse_entered.bind(child))
			child.mouse_exited.connect(_on_mouse_exited.bind(child))
	_menu.visibility_changed.connect(_on_visibility_changed)
	_on_visibility_changed()


func _process(delta: float) -> void:
	var button := _hovered
	if not _can_follow(button):
		button = button_container.get_viewport().gui_get_focus_owner() as BaseButton
	var goal := look_target.get_parent_node_3d().to_global(_neutral_position)
	if _can_follow(button) and button in _buttons:
		goal = _button_target(button, goal)
	look_target.global_position = look_target.global_position.lerp(goal, 1.0 - exp(-response_speed * delta))


func _button_target(button: BaseButton, neutral: Vector3) -> Vector3:
	if preview.texture == null or preview.size.x <= 0.0 or preview.size.y <= 0.0:
		return neutral
	var texture_size := preview.texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return neutral
	var center := button.get_global_transform_with_canvas() * (button.size * 0.5)
	var reference := button_container.get_global_transform_with_canvas() * (button_container.size * 0.5)
	var depth := (neutral - preview_camera.global_position).dot(-preview_camera.global_basis.z)
	if depth <= preview_camera.near:
		return neutral
	var point := preview_camera.project_position(_preview_point(center, texture_size), depth)
	var reference_point := preview_camera.project_position(_preview_point(reference, texture_size), depth)
	return neutral + (point - reference_point) * gaze_strength


func _preview_point(canvas_position: Vector2, texture_size: Vector2) -> Vector2:
	var local := preview.get_global_transform_with_canvas().affine_inverse() * canvas_position
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


func _can_follow(button: BaseButton) -> bool:
	return is_instance_valid(button) and button.is_visible_in_tree() and not button.disabled


func _on_mouse_entered(button: BaseButton) -> void:
	_hovered = button


func _on_mouse_exited(button: BaseButton) -> void:
	if _hovered == button:
		_hovered = null


func _on_visibility_changed() -> void:
	_hovered = null
	look_target.position = _neutral_position
	set_process(_menu.is_visible_in_tree())
	if _menu.is_visible_in_tree():
		for button: BaseButton in _buttons:
			if _can_follow(button) and Rect2(Vector2.ZERO, button.size).has_point(button.get_local_mouse_position()):
				_hovered = button
				break
