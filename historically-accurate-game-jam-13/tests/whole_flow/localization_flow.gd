extends "res://tests/support/flow_test.gd"


func run() -> void:
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
	var shell := await boot_shell()
	shell.open_settings()
	check(shell.settings.window_mode.get_item_text(0) == "У вікні", "Display choices translate")
	var binding: Control = shell.settings.get_node("%Bindings").get_child(0)
	check(binding.get_node("%ActionName").text == "Рух уперед", "Binding labels translate")
	var forward_key: InputEvent = InputMap.action_get_events(&"forward")[0]
	check(shell.preferences.bindings.problem(&"interact", forward_key) == "Уже призначено: Рух уперед.", "Binding errors translate the template and inserted action")
	shell.close_settings()
	await shell.start_game()
	check(shell.dialogue.speaker.text == "ВЧЕНИЙ", "Dialogue speakers translate")
	check(shell.dialogue.line.text == "Доброго ранку. Готова до гри?", "Dialogue text translates from constant content")
	shell.dialogue.session.advance(true)
	shell.dialogue.session.advance(false)
	check(shell.hud.progress.text == "БАТАРЕЇ: 0 / 2", "Progress translates before inserting numbers")
	shell.room.interactor.target = shell.room.get_node("Pickups/Battery1/Item")
	shell.room.interact()
	check(shell.hud.carrying.text == "У зубах: батарея", "Carrying hints translate the whole sentence and item")
	var socket: ItemSocket = shell.room.get_node("Props/TrainingStand/Slots")
	check(socket.get_prompt(shell.room) == "Покласти батарея", "Interaction prompts translate before formatting")

	shell.queue_free()
	await frames(2)
	TranslationServer.set_locale("en")
	TranslationServer.remove_translation(translation)
