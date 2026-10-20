@tool
class_name AudioCue
extends Resource

@export var event_name: String:
	set(value):
		event_name = value
		emit_changed()
@export var parameters: Dictionary[StringName, Variant] = {}:
	set(value):
		parameters = value
		emit_changed()


func play(source: Node3D = null) -> bool:
	if not configuration_errors().is_empty() or (is_spatial() and not is_instance_valid(source)):
		return false
	if is_spatial():
		FmodServer.play_one_shot_attached_with_params(event_name, source, parameters)
	else:
		FmodServer.play_one_shot_with_params(event_name, parameters)
	return true


func is_spatial() -> bool:
	return not event_name.is_empty() and FmodServer.check_event_path(event_name) and FmodServer.get_event(event_name).is_3d()


func configuration_errors() -> PackedStringArray:
	var errors: PackedStringArray = []
	if event_name.is_empty() or not FmodServer.check_event_path(event_name):
		return ["event_name: choose an event from the loaded FMOD banks."]
	var event := FmodServer.get_event(event_name)
	if not event.is_one_shot():
		errors.append("event_name: use a one-shot event; loops belong on an FMOD emitter.")
	var descriptions: Dictionary[StringName, FmodParameterDescription] = {}
	for description: FmodParameterDescription in event.get_parameters():
		descriptions[StringName(description.get_name())] = description
	for parameter: StringName in parameters:
		if not descriptions.has(parameter):
			errors.append("parameters/%s: this event has no such parameter." % parameter)
			continue
		var description: FmodParameterDescription = descriptions[parameter]
		var value: Variant = parameters[parameter]
		if description.is_read_only() or description.is_automatic() or description.is_global():
			errors.append("parameters/%s: choose a writable local event parameter." % parameter)
		elif value is String:
			if not description.is_labeled() or not value in event.get_parameter_labels_by_name(parameter):
				errors.append("parameters/%s: choose one of the event's FMOD labels." % parameter)
		elif value is int or value is float:
			if not is_finite(float(value)) or value < description.get_minimum() or value > description.get_maximum():
				errors.append("parameters/%s: use a finite number inside the FMOD range." % parameter)
			elif description.is_discrete() and value != round(value):
				errors.append("parameters/%s: use a whole number for a discrete parameter." % parameter)
		else:
			errors.append("parameters/%s: use a number or an FMOD label." % parameter)
	return errors


func _validate_property(property: Dictionary) -> void:
	if property.name != "event_name" or not Engine.is_editor_hint():
		return
	var server := Engine.get_singleton("FmodServer")
	if not server or not server.has_method("get_all_event_descriptions"):
		return
	var paths: PackedStringArray = []
	for event: FmodEventDescription in server.get_all_event_descriptions():
		paths.append(event.get_path())
	paths.sort()
	property.hint = PROPERTY_HINT_ENUM_SUGGESTION
	property.hint_string = ",".join(paths)
