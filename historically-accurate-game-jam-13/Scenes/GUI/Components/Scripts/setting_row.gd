extends HBoxContainer

signal value_changed(id: StringName, value: Variant)

var definition: SettingDefinition
var _options: Array = []
var editor: Control:
	get:
		return [%Slider, %Toggle, %Choice][definition.kind]


func _ready() -> void:
	%Title.text = tr(definition.label)
	%Slider.visible = definition.kind == SettingDefinition.Kind.SLIDER
	%Toggle.visible = definition.kind == SettingDefinition.Kind.TOGGLE
	%Choice.visible = definition.kind == SettingDefinition.Kind.CHOICE
	%Value.visible = %Slider.visible
	%Slider.min_value = definition.minimum
	%Slider.max_value = definition.maximum
	%Slider.step = definition.step
	%Slider.value_changed.connect(_slider_changed)
	%Toggle.toggled.connect(func(value: bool) -> void: value_changed.emit(definition.id, value))
	%Choice.item_selected.connect(func(index: int) -> void: value_changed.emit(definition.id, _options[index][1]))


func refresh(value: Variant, options: Array = []) -> void:
	match definition.kind:
		SettingDefinition.Kind.SLIDER:
			%Slider.set_value_no_signal(value)
			_show_value(value)
		SettingDefinition.Kind.TOGGLE:
			%Toggle.set_pressed_no_signal(value)
		SettingDefinition.Kind.CHOICE:
			_options = options.duplicate()
			if _options.is_empty():
				for index: int in definition.options.size():
					_options.append([definition.options[index], index])
			%Choice.clear()
			for option: Array in _options:
				%Choice.add_item(tr(option[0]))
				if option[1] == value:
					%Choice.select(%Choice.item_count - 1)


func _slider_changed(value: float) -> void:
	_show_value(value)
	value_changed.emit(definition.id, value)


func _show_value(value: float) -> void:
	%Value.text = "%d%%" % roundi(value * 100.0) if definition.value_format == "%" else definition.value_format % value
