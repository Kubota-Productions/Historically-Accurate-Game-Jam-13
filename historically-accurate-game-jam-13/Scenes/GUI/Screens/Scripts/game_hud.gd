extends Control

var _thought_time: float = 0.0
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
@onready var scent: Label = %Scent


func _ready() -> void:
	refresh_bindings()


func _process(delta: float) -> void:
	if _thought_time > 0.0:
		_thought_time -= delta
		thought_panel.visible = _thought_time > 0.0


func refresh_bindings() -> void:
	%DropHint.text = tr("[%s]  Put down") % InputHints.key(&"drop")
	%PauseHint.text = tr("%s  ·  pause") % InputHints.key(&"ui_cancel")
	for card: Node in [%Interact, %Jump, %Bark, %Sniff]:
		card.refresh_bindings()
	set_prompt(_prompt_text)


func set_objective(text: String, detail: String, values: Array = []) -> void:
	objective.text = tr(text)
	progress.text = tr(detail) % values if not values.is_empty() else tr(detail)


func set_chapter(text: String) -> void:
	chapter.text = tr(text)


func set_prompt(text: String, _action: StringName = &"interact") -> void:
	_prompt_text = text
	prompt.text = "[%s]  %s" % [InputHints.key(&"interact"), text] if not text.is_empty() else ""
	%Interact.set_available(not _bark_required and (_dialogue_active or not text.is_empty()))


func set_carrying(text: String) -> void:
	carrying.text = tr("In your teeth: %s") % tr(text) if not text.is_empty() else ""
	%DropHint.visible = not text.is_empty()


func show_thought(text: String, duration: float = 4.0) -> void:
	thought.text = tr(text)
	_thought_time = duration
	thought_panel.show()


func set_sniffing(active: bool) -> void:
	scent.visible = active


func set_dialogue_active(active: bool, bark_required: bool = false) -> void:
	_dialogue_active = active
	_bark_required = active and bark_required
	%Interact.set_caption(tr("Continue") if active else tr("Interact"))
	%Interact.set_available(not _bark_required and (active or not _prompt_text.is_empty()))
	%Bark.set_caption(tr("Woof!") if _bark_required else tr("Bark"))
	%Sniff.set_available(not active)
	%Jump.set_available(true)


func reset() -> void:
	_thought_time = 0.0
	thought_panel.hide()
	set_dialogue_active(false)
	set_carrying("")
	set_prompt("")
	set_sniffing(false)
