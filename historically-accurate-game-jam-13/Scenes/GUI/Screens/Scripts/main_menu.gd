class_name MainMenu
extends Control

signal start_requested
signal settings_requested
signal quit_requested


func _ready() -> void:
	%Start.pressed.connect(start_requested.emit)
	%Settings.pressed.connect(settings_requested.emit)
	%Quit.pressed.connect(quit_requested.emit)


func open() -> void:
	show()
	%Start.grab_focus()


func focus_settings() -> void:
	%Settings.grab_focus()
