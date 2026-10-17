extends PanelContainer

signal menu_requested
signal expired

const DISPLAY_SECONDS: float = 5.0


func _ready() -> void:
	%MainMenu.pressed.connect(func() -> void: menu_requested.emit())
	%Lifetime.timeout.connect(_on_timeout)


func open() -> void:
	show()
	%Lifetime.start(DISPLAY_SECONDS)


func close() -> void:
	%Lifetime.stop()
	hide()


func _on_timeout() -> void:
	close()
	expired.emit()
