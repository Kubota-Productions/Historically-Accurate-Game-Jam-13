class_name CompletionNotice
extends PanelContainer

signal menu_requested

@onready var lifetime: Timer = %Lifetime


func _ready() -> void:
	%MainMenu.pressed.connect(menu_requested.emit)
	lifetime.timeout.connect(close)


func open() -> void:
	show()
	lifetime.start()


func close() -> void:
	lifetime.stop()
	hide()
