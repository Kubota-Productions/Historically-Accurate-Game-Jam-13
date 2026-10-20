@tool
class_name InspectionPart
extends StaticBody3D

@export var part_id: StringName
@export var caption: String = "Open"
@export var animation_player: AnimationPlayer
@export var animation: StringName

var activated: bool = false


func reveal(instant: bool = false) -> void:
	activated = true
	if animation_player and animation_player.has_animation(animation):
		animation_player.play(animation)
		if instant:
			animation_player.seek(animation_player.get_animation(animation).length, true)


func _get_configuration_warnings() -> PackedStringArray:
	var errors: PackedStringArray = []
	if part_id.is_empty():
		errors.append("part_id: give this part a unique ID inside the inspection scene.")
	if not animation.is_empty() and (animation_player == null or not animation_player.has_animation(animation)):
		errors.append("animation: choose an animation from Animation Player.")
	return errors
