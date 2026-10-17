class_name SettingsEffects
extends RefCounted


static func apply(settings: GameSettings, targets: Dictionary) -> void:
	for definition: SettingDefinition in settings.definitions.values():
		if definition.effect_target.is_empty():
			continue
		var target: Object = targets.get(definition.effect_target)
		if is_instance_valid(target):
			target.set(definition.effect_property, settings.get_value(definition.id))


static func configuration_errors(settings: GameSettings, targets: Dictionary) -> PackedStringArray:
	var errors: PackedStringArray = []
	for definition: SettingDefinition in settings.definitions.values():
		if not definition.audio_bus.is_empty() and AudioServer.get_bus_index(definition.audio_bus) < 0:
			errors.append("Setting %s: unknown audio bus '%s'." % [definition.id, definition.audio_bus])
		if definition.effect_target.is_empty():
			continue
		var target: Object = targets.get(definition.effect_target)
		if not is_instance_valid(target):
			errors.append("Setting %s: unknown effect target '%s'." % [definition.id, definition.effect_target])
			continue
		var found := false
		for property: Dictionary in target.get_property_list():
			if property.name == definition.effect_property:
				found = true
				var allowed: Array = [typeof(definition.default_value), TYPE_NIL]
				if definition.kind == SettingDefinition.Kind.SLIDER:
					allowed = [TYPE_INT, TYPE_FLOAT, TYPE_NIL]
				if not property.type in allowed:
					errors.append("Setting %s: incompatible property type for '%s'." % [definition.id, definition.effect_property])
				break
		if not found:
			errors.append("Setting %s: unknown property '%s'." % [definition.id, definition.effect_property])
	return errors
