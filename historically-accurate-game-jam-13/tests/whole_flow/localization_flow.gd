extends SceneTree

var failures: int = 0
var checks: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var translation := Translation.new()
	translation.locale = "uk"
	var messages := {
		"Window mode": "Режим вікна",
		"Windowed": "У вікні",
		"Move forward": "Рух уперед",
		"SCIENTIST": "ВЧЕНИЙ",
		"Good morning, little cosmonaut. Ready for our game?": "Доброго ранку. Готова до гри?",
		"0 / %d BATTERIES": "БАТАРЕЇ: 0 / %d",
		"battery": "батарея",
		"In your teeth: %s": "У зубах: %s",
		"Place %s": "Покласти %s",
		"Already assigned to %s.": "Уже призначено: %s.",
	}
	for source: String in messages:
		translation.add_message(source, messages[source])
	TranslationServer.add_translation(translation)
	TranslationServer.set_locale("uk")
	var shell = load("res://Scenes/Game/Game.tscn").instantiate()
	root.add_child(shell)
	await process_frame
	shell.open_settings()
	var row: Control = shell.settings.row(&"window_mode")
	_check(row.get_node("%Title").text == "Режим вікна", "Catalog labels translate when presented")
	_check(row.editor.get_item_text(0) == "У вікні", "Catalog choice labels translate")
	var binding: Control = shell.settings.binding_rows.get_child(0)
	_check(binding.get_node("%ActionName").text == "Рух уперед", "Binding labels translate")
	var key: InputEvent = InputMap.action_get_events(&"forward")[0]
	_check(shell.preferences.bindings.assign(&"interact", key) == "Уже призначено: Рух уперед.", "Binding errors translate the template and inserted action")
	shell.close_settings()
	await shell.start_game()
	_check(shell.dialogue.speaker.text == "ВЧЕНИЙ", "Dialogue speakers translate")
	_check(shell.dialogue.line.text == "Доброго ранку. Готова до гри?", "Dialogue text translates from constant content")
	var isolated := DialogueSession.new()
	isolated.open(&"greeting", DialogueCatalog.lines(&"greeting"))
	isolated.lines[0].text = "Changed copy"
	_check(DialogueCatalog.lines(&"greeting")[0].text != "Changed copy", "Dialogue sessions cannot mutate catalog content")
	shell.dialogue.advance(true)
	shell.dialogue.advance(false)
	_check(shell.hud.progress.text == "БАТАРЕЇ: 0 / 2", "Progress translates before inserting numbers")
	shell.room.interactor.target = shell.room.get_node("Pickups/Battery1/Item")
	shell.room.interact()
	_check(shell.hud.carrying.text == "У зубах: батарея", "Carrying hints translate the whole sentence and item")
	var socket: LaikaInteractionPoint = shell.room.get_node("Props/TrainingStand/Slots")
	_check(socket.get_prompt(shell.room) == "Покласти батарея", "Interaction prompts translate before formatting")

	shell.queue_free()
	await process_frame
	await process_frame
	TranslationServer.set_locale("en")
	TranslationServer.remove_translation(translation)
	print("LOCALIZATION_FLOW: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)
