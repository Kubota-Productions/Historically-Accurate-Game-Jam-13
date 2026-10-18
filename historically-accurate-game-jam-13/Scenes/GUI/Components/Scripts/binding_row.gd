@tool
class_name BindingRow
extends HBoxContainer

signal binding_requested(action: StringName)

@export var action: StringName = &"interact"

@onready var button: Button = %Binding


func _ready() -> void:
	%ActionName.text = tr(PlayerBindings.ACTIONS[action])
	button.pressed.connect(binding_requested.emit.bind(action))
	refresh()


func refresh() -> void:
	button.text = InputHints.key(action)


func show_capture() -> void:
	button.text = tr("Press a key…")
