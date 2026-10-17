extends HBoxContainer

signal binding_requested(action: StringName)

@export var action: StringName = &"interact"


func _ready() -> void:
	%Binding.pressed.connect(func() -> void: binding_requested.emit(action))
	refresh()


func refresh() -> void:
	%ActionName.text = PlayerBindings.ACTIONS[action]
	%Binding.text = InputHints.key(action)


func show_capture() -> void:
	%Binding.text = "Press a key…"


func focus_binding() -> void:
	%Binding.grab_focus()
