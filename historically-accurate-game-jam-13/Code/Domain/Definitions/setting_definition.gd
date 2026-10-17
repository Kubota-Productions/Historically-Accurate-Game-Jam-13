class_name SettingDefinition
extends RefCounted

enum Kind { SLIDER, TOGGLE, CHOICE }

var id: StringName
var section: StringName
var label: String
var kind: Kind
var default_value: Variant
var minimum: float = 0.0
var maximum: float = 1.0
var step: float = 0.01
var value_format: String = "%"
var options: Array = []
var effect_target: StringName
var effect_property: StringName
var audio_bus: StringName
var confirmation: bool = false
var _errors: PackedStringArray = []


func _init(key: StringName, data: Dictionary) -> void:
	id = key
	for field: String in ["section", "label", "format", "bus"]:
		if data.has(field) and not (data[field] is String or data[field] is StringName):
			_errors.append(field + ": expected text.")
	for field: String in data:
		if not field in ["kind", "section", "label", "default", "minimum", "maximum", "step", "format", "options", "bus", "confirmation", "effect"]:
			_errors.append("unknown field: " + field)
	section = str(data.get("section", &"display"))
	label = str(data.get("label", ""))
	default_value = data.get("default")
	var configured_kind: Variant = data.get("kind")
	if configured_kind is int and configured_kind in Kind.values():
		kind = configured_kind
	else:
		_errors.append("kind: use SettingDefinition.Kind.SLIDER, TOGGLE or CHOICE.")
	for field: String in ["minimum", "maximum", "step"]:
		var value: Variant = data.get(field, get(field))
		if (value is float or value is int) and is_finite(float(value)):
			set(field, float(value))
		else:
			_errors.append(field + ": use a finite number.")
	value_format = str(data.get("format", "%"))
	if data.get("options", []) is Array:
		options = data.get("options", [])
	else:
		_errors.append("options: expected an array of labels.")
	audio_bus = str(data.get("bus", &""))
	if data.get("confirmation", false) is bool:
		confirmation = data.get("confirmation", false)
	else:
		_errors.append("confirmation: expected a boolean.")
	var effect: Variant = data.get("effect", [])
	if not effect is Array or (not effect.is_empty() and effect.size() != 2):
		_errors.append("effect: expected [target, property].")
	elif not effect.is_empty():
		effect_target = str(effect[0])
		effect_property = str(effect[1])


func configuration_errors() -> PackedStringArray:
	var errors := _errors.duplicate()
	if id.is_empty() or label.is_empty():
		errors.append("id and label: both are required.")
	if not section in [&"display", &"audio", &"input"]:
		errors.append("section: choose display, audio or input.")
	match kind:
		Kind.SLIDER:
			if value_format != "%" and not _valid_number_format(value_format):
				errors.append("format: use one numeric placeholder, such as %.2f, or % for percent.")
			if not (default_value is int or default_value is float) or not is_finite(float(default_value)):
				errors.append("default: expected a finite slider number.")
			elif minimum > maximum or step <= 0 or default_value < minimum or default_value > maximum:
				errors.append("range: default must fit minimum/maximum and step must be positive.")
		Kind.TOGGLE:
			if not default_value is bool:
				errors.append("default: expected a boolean for a toggle.")
		Kind.CHOICE:
			if default_value is Vector2i:
				if id != &"resolution" or default_value.x < 960 or default_value.y < 540:
					errors.append("default: resolution must be at least 960 by 540.")
			elif not default_value is int or default_value < 0 or default_value >= options.size():
				errors.append("options: expected choices and a valid default index.")
			for option: Variant in options:
				if not option is String:
					errors.append("options: every label must be a string.")
	if confirmation and not id in [&"window_mode", &"resolution"]:
		errors.append("confirmation: only window_mode and resolution use the display transaction.")
	if not audio_bus.is_empty() and kind != Kind.SLIDER:
		errors.append("bus: audio buses require a slider.")
	return errors


func sanitize(value: Variant) -> Variant:
	match kind:
		Kind.SLIDER:
			if (value is float or value is int) and is_finite(float(value)):
				return clampf(float(value), minimum, maximum)
		Kind.TOGGLE:
			if value is bool:
				return value
		Kind.CHOICE:
			if typeof(value) == typeof(default_value):
				if value is Vector2i:
					return value if value.x >= 960 and value.y >= 540 else default_value
				if value is int and value >= 0 and value < options.size():
					return value
	return default_value


func _valid_number_format(value: String) -> bool:
	var pattern := RegEx.create_from_string("^(?:[^%]|%%)*%[-+0 #]*[0-9]*(?:\\.[0-9]+)?[dfis](?:[^%]|%%)*$")
	return pattern.search(value) != null
