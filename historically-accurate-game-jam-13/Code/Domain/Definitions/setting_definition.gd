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


func _init(key: StringName, data: Dictionary) -> void:
	id = key
	section = data.get("section", &"display")
	label = data["label"]
	default_value = data["default"]
	kind = Kind.TOGGLE if default_value is bool else Kind.SLIDER if default_value is float else Kind.CHOICE
	minimum = data.get("minimum", 0.0)
	maximum = data.get("maximum", 1.0)
	step = data.get("step", 0.01)
	value_format = data.get("format", "%")
	options = data.get("options", [])
	audio_bus = data.get("bus", &"")
	confirmation = data.get("confirmation", false)
	var effect: Array = data.get("effect", [])
	if not effect.is_empty():
		assert(effect.size() == 2, "Setting effect needs a target and property")
		effect_target = effect[0]
		effect_property = effect[1]


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
