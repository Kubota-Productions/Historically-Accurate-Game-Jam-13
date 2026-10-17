class_name SettingsCatalog
extends RefCounted

const DEFINITIONS := {
	&"window_mode": {
		"kind": SettingDefinition.Kind.CHOICE,
		"section": &"display",
		"label": "Window mode",
		"default": 0,
		"options": ["Windowed", "Borderless fullscreen", "Fullscreen"],
		"confirmation": true,
	},
	&"resolution": {
		"kind": SettingDefinition.Kind.CHOICE,
		"section": &"display",
		"label": "Resolution",
		"default": Vector2i(1280, 720),
		"confirmation": true,
	},
	&"dog_vision": {
		"kind": SettingDefinition.Kind.TOGGLE,
		"section": &"display",
		"label": "Dog vision",
		"default": true,
		"effect": [&"dog_vision", &"visible"],
	},
	&"panini_projection": {
		"kind": SettingDefinition.Kind.TOGGLE,
		"section": &"display",
		"label": "Panini projection",
		"default": true,
		"effect": [&"projection", &"enabled"],
	},
	&"sound_volume": {
		"kind": SettingDefinition.Kind.SLIDER,
		"section": &"audio",
		"label": "Sound volume",
		"default": 0.7,
		"bus": &"Sound",
	},
	&"music_volume": {
		"kind": SettingDefinition.Kind.SLIDER,
		"section": &"audio",
		"label": "Music volume",
		"default": 0.7,
		"bus": &"Music",
	},
	&"sensitivity": {
		"kind": SettingDefinition.Kind.SLIDER,
		"section": &"input",
		"label": "Mouse sensitivity",
		"default": 0.1,
		"minimum": 0.03,
		"maximum": 0.3,
		"step": 0.01,
		"format": "%.2f",
		"effect": [&"player", &"mouse_sensitivity"],
	},
}


static func definitions() -> Array[SettingDefinition]:
	var result: Array[SettingDefinition] = []
	for id: StringName in DEFINITIONS:
		result.append(SettingDefinition.new(id, DEFINITIONS[id]))
	return result
