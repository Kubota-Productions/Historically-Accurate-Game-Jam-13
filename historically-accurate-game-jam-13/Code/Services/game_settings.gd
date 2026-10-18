class_name GameSettings
extends RefCounted

signal changed(id: StringName)

const PATH := "user://settings.cfg"
const CATALOG: SettingsCatalog = preload("res://GameData/Settings/settings.tres")

var definitions: Dictionary[StringName, SettingDefinition] = {}
var display := DisplaySettings.new()
var bindings := PlayerBindings.new()
var _values: Dictionary[StringName, Variant] = {}


func _init(catalog: SettingsCatalog = CATALOG) -> void:
	for definition: SettingDefinition in catalog.settings:
		add(definition)


func add(definition: SettingDefinition) -> void:
	definitions[definition.id] = definition
	_values[definition.id] = definition.get_default()


func get_value(id: StringName) -> Variant:
	return _values[id]


func set_value(id: StringName, value: Variant) -> void:
	var clean: Variant = definitions[id].sanitize(value)
	if _values[id] == clean:
		return
	_values[id] = clean
	definitions[id].apply(clean)
	changed.emit(id)


func restore(window: Window) -> void:
	var config := ConfigFile.new()
	config.load(PATH)
	for definition: SettingDefinition in definitions.values():
		_values[definition.id] = definition.sanitize(config.get_value("settings", definition.id, definition.get_default()))
		definition.apply(_values[definition.id])
	bindings.restore(config)
	display.restore(config, window)


func save() -> Error:
	var config := ConfigFile.new()
	for id: StringName in _values:
		config.set_value("settings", id, _values[id])
	bindings.save(config)
	display.save(config)
	var result := config.save(PATH)
	if result != OK:
		push_warning("Could not save settings: %s" % error_string(result))
	return result
