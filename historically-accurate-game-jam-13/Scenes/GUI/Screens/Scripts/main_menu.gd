extends Control

signal start_requested
signal settings_requested
signal quit_requested


func _ready() -> void:
	%Start.pressed.connect(func() -> void: start_requested.emit())
	%Settings.pressed.connect(func() -> void: settings_requested.emit())
	%Quit.pressed.connect(func() -> void: quit_requested.emit())


func open() -> void:
	show()
	%Start.grab_focus()


func focus_settings() -> void:
	%Settings.grab_focus()
