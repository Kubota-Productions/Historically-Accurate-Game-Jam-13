extends PanelContainer

@export var action: StringName = &"interact"
@export var caption: String = "Interact"

@onready var key_label: Label = %Key
@onready var caption_label: Label = %Caption


func _ready() -> void:
	refresh_bindings()


func refresh_bindings() -> void:
	key_label.text = InputHints.key(action)
	caption_label.text = tr(caption)


func set_caption(text: String) -> void:
	caption = text
	caption_label.text = tr(text)


func set_available(available: bool) -> void:
	modulate.a = 1.0 if available else 0.48
