class_name PauseMenu
extends Control

signal resume_requested
signal settings_requested
signal menu_requested


func _ready() -> void:
	%Resume.pressed.connect(resume_requested.emit)
	%Settings.pressed.connect(settings_requested.emit)
	%MainMenu.pressed.connect(menu_requested.emit)


func open() -> void:
	show()
	%Resume.grab_focus()


func focus_settings() -> void:
	%Settings.grab_focus()
