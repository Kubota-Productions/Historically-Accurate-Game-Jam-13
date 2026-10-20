class_name CreditsScreen
extends Control

signal finished

@export_range(1.0, 120.0) var page_seconds: float = 7.0
@export_multiline var team: String = "Fractals\nAerial\nSystem Synger\nryvle\nVi (Vladyslav)"

var page: int = 0
var elapsed: float = 0.0
var active: bool = false

@onready var heading: Label = %Heading
@onready var body: Label = %Body
@onready var menu_button: Button = %ReturnToMenu


func _ready() -> void:
	menu_button.pressed.connect(finish)
	close()


func open() -> void:
	page = 0
	elapsed = 0.0
	active = true
	_show_page()
	show()
	menu_button.grab_focus()


func close() -> void:
	active = false
	hide()


func finish() -> void:
	if not active:
		return
	close()
	finished.emit()


func _process(delta: float) -> void:
	if not active:
		return
	elapsed += delta
	if elapsed < page_seconds:
		return
	elapsed = 0.0
	page += 1
	if page >= 3:
		finish()
	else:
		_show_page()


func _show_page() -> void:
	match page:
		0:
			heading.text = tr("For Laika")
			body.text = tr("A very good dog.")
		1:
			heading.text = tr("Made by")
			body.text = team
		2:
			heading.text = tr("Thank you for playing")
			body.text = tr("Returning to the main menu…")
