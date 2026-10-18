class_name GameHud
extends Control

@export var thought_seconds: float = 4.0
@export var bark_seconds: float = 1.2

var _prompt_text: String = ""
var _dialogue_active: bool = false
var _bark_required: bool = false

@onready var objective: Label = %Objective
@onready var progress: Label = %Progress
@onready var chapter: Label = %Chapter
@onready var prompt: Label = %Prompt
@onready var carrying: Label = %Carrying
@onready var thought_panel: PanelContainer = %ThoughtPanel
@onready var thought: Label = %Thought
@onready var thought_timer: Timer = %ThoughtTimer
@onready var scent: Label = %Scent
@onready var interact_hint: ActionHint = %Interact
@onready var bark_hint: ActionHint = %Bark
@onready var sniff_hint: ActionHint = %Sniff
@onready var action_hints: Array[ActionHint] = [%Interact, %Jump, %Bark, %Sniff]


func _ready() -> void:
	thought_timer.timeout.connect(thought_panel.hide)
	refresh_bindings()


func refresh_bindings() -> void:
	%DropHint.text = tr("[%s]  Put down") % InputHints.key(&"drop")
	%PauseHint.text = tr("%s  ·  pause") % InputHints.key(&"ui_cancel")
	for hint: ActionHint in action_hints:
		hint.refresh()
	set_prompt(_prompt_text)


func set_objective(text: String, detail: String, values: Array = []) -> void:
	objective.text = tr(text)
	progress.text = tr(detail) % values if not values.is_empty() else tr(detail)


func set_chapter(text: String) -> void:
	chapter.text = tr(text)


func set_prompt(text: String) -> void:
	_prompt_text = text
	prompt.text = "[%s]  %s" % [InputHints.key(&"interact"), text] if not text.is_empty() else ""
	_refresh_interact()


func set_carrying(item_name: String) -> void:
	carrying.text = tr("In your teeth: %s") % tr(item_name) if not item_name.is_empty() else ""
	%DropHint.visible = not item_name.is_empty()


func show_thought(text: String, seconds: float = thought_seconds) -> void:
	thought.text = tr(text)
	thought_panel.show()
	thought_timer.start(seconds)


func show_bark() -> void:
	show_thought("Woof!", bark_seconds)


func set_sniffing(active: bool) -> void:
	scent.visible = active


func set_dialogue_active(active: bool, bark_required: bool) -> void:
	_dialogue_active = active
	_bark_required = active and bark_required
	interact_hint.caption = "Continue" if active else "Interact"
	bark_hint.caption = "Woof!" if _bark_required else "Bark"
	sniff_hint.available = not active
	_refresh_interact()


func reset() -> void:
	thought_timer.stop()
	thought_panel.hide()
	set_dialogue_active(false, false)
	set_carrying("")
	set_prompt("")
	set_sniffing(false)


func _refresh_interact() -> void:
	interact_hint.available = not _bark_required and (_dialogue_active or not _prompt_text.is_empty())
