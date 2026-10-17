class_name SettingsEffects
extends RefCounted


static func apply(settings: GameSettings, targets: Dictionary) -> void:
	for definition: SettingDefinition in settings.definitions.values():
		if definition.effect_target.is_empty():
			continue
		var target: Object = targets.get(definition.effect_target)
		if is_instance_valid(target):
			target.set(definition.effect_property, settings.get_value(definition.id))
