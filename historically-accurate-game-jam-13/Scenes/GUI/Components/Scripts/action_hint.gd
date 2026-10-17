@tool
class_name ActionHint
extends PanelContainer

const UNAVAILABLE_ALPHA := 0.48

@export var action: StringName = &"interact"
@export var caption: String = "Interact":
	set(value):
		caption = value
		if is_node_ready():
			refresh()
@export var available: bool = true:
	set(value):
		available = value
		modulate.a = 1.0 if available else UNAVAILABLE_ALPHA


func _ready() -> void:
	refresh()


func refresh() -> void:
	%Key.text = InputHints.key(action)
	%Caption.text = tr(caption)
