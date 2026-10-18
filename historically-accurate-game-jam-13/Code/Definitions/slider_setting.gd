@tool
class_name SliderSetting
extends SettingDefinition

@export var default_value: float = 0.5
@export var minimum: float = 0.0
@export var maximum: float = 1.0
@export var step: float = 0.01
@export var percent: bool = true
@export var audio_bus: StringName


func get_default() -> Variant:
	return default_value


func sanitize(value: Variant) -> Variant:
	if (value is float or value is int) and is_finite(value):
		return clampf(value, minimum, maximum)
	return default_value


func apply(value: Variant) -> void:
	var bus := AudioServer.get_bus_index(audio_bus)
	if bus < 0:
		return
	AudioServer.set_bus_volume_linear(bus, value)
	AudioServer.set_bus_mute(bus, is_zero_approx(value))


func format(value: float) -> String:
	return "%d%%" % roundi(value * 100.0) if percent else "%.2f" % value
