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


func is_menu_hit(position: Vector2) -> bool:
	return %MainMenu.get_global_rect().has_point(position)


func _on_timeout() -> void:
	close()
	expired.emit()
