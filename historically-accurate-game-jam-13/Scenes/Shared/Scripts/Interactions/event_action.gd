@tool
class_name EventAction
extends InteractionAction

@export var event: StringName
@export var completed_flag: StringName
@export var completed_prompt: String


func prompt(room: LaikaRoom, target: Interactable) -> String:
	return tr(completed_prompt) if room.progress.has_flag(completed_flag) else super(room, target)


func execute(room: LaikaRoom, _target: Interactable) -> void:
	room.progress.handle_event(event)


func configuration_errors(room: LaikaRoom, target: Interactable) -> PackedStringArray:
	var errors := super(room, target)
	errors.append_array(unknown_flags(room, [completed_flag]))
	if event.is_empty() or (room and not room.progress.knows_event(event)):
		errors.append("event: choose an event from %s's progress." % (room.name if room else "the room"))
	return errors


func _validate_property(property: Dictionary) -> void:
	super(property)
	if property.name == "event":
		property.hint = PROPERTY_HINT_ENUM_SUGGESTION
		property.hint_string = ",".join(RoomProgress.declared(&"EVENTS"))
