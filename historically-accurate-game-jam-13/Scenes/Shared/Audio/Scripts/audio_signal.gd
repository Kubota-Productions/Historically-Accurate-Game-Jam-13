@tool
class_name AudioSignal
extends Node

@export var source: Node:
	set(value):
		source = value
		notify_property_list_changed()
		_refresh_warnings()
@export var signal_name: StringName:
	set(value):
		signal_name = value
		_refresh_warnings()
@export var cue: AudioCue:
	set(value):
		if cue and cue.changed.is_connected(_refresh_warnings):
			cue.changed.disconnect(_refresh_warnings)
		cue = value
		if cue:
			cue.changed.connect(_refresh_warnings)
		_refresh_warnings()
@export var spatial_source: Node3D:
	set(value):
		spatial_source = value
		_refresh_warnings()

var _signal: Signal
var _callback: Callable


func _enter_tree() -> void:
	if not Engine.is_editor_hint():
		_connect_signal()


func _exit_tree() -> void:
	if not _signal.is_null() and is_instance_valid(_signal.get_object()) and _signal.is_connected(_callback):
		_signal.disconnect(_callback)


func configuration_errors() -> PackedStringArray:
	var errors: PackedStringArray = []
	var target := source if source else get_parent()
	if not target or not target.has_signal(signal_name):
		errors.append("signal_name: choose a signal from Source (or the parent when Source is empty).")
	if cue == null:
		errors.append("cue: assign an AudioCue resource.")
	else:
		errors.append_array(cue.configuration_errors())
		if cue.is_spatial() and not is_instance_valid(_origin()):
			errors.append("spatial_source: assign a Node3D or place this component under one.")
	return errors


func _connect_signal() -> void:
	if not is_inside_tree():
		return
	var errors := configuration_errors()
	if not errors.is_empty():
		push_warning("%s: %s" % [get_path(), "; ".join(errors)])
		return
	var target := source if source else get_parent()
	for entry: Dictionary in target.get_signal_list():
		if entry.name == signal_name:
			_signal = Signal(target, signal_name)
			_callback = _play.unbind(entry.args.size()) if not entry.args.is_empty() else _play
			if not _signal.is_connected(_callback):
				_signal.connect(_callback)
			return


func _play() -> void:
	cue.play(_origin())


func _origin() -> Node3D:
	return spatial_source if is_instance_valid(spatial_source) else get_parent() as Node3D


func _get_configuration_warnings() -> PackedStringArray:
	return configuration_errors()


func _refresh_warnings() -> void:
	if is_inside_tree() and Engine.is_editor_hint():
		update_configuration_warnings()


func _validate_property(property: Dictionary) -> void:
	if property.name != "signal_name":
		return
	var target := source if source else get_parent()
	if not target:
		return
	var names: PackedStringArray = []
	for entry: Dictionary in target.get_signal_list():
		names.append(entry.name)
	names.sort()
	property.hint = PROPERTY_HINT_ENUM_SUGGESTION
	property.hint_string = ",".join(names)
