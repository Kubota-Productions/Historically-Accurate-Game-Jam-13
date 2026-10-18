extends "res://tests/support/flow_test.gd"

const GREETING: Dialogue = preload("res://GameData/Dialogue/Training/greeting.tres")


func run() -> void:
	var session := DialogueSession.new()
	var finished: Array[Dialogue] = []
	session.finished.connect(finished.append)
	var barks: Array[bool] = []
	session.bark_requested.connect(func() -> void: barks.append(true))
	check(not session.open(null) and not session.open(Dialogue.new()) and not session.active, "Empty conversations are refused")
	check(session.open(GREETING) and session.active and session.current() == GREETING.lines[0], "A conversation starts at its first line")
	check(not session.open(GREETING), "A second conversation cannot interrupt the first")
	session.advance(false)
	check(session.index == 0, "Continue cannot answer a bark line")
	session.advance(true)
	check(session.index == 1 and barks.size() == 1 and not session.requires_bark(), "Barking answers a bark line")
	session.advance(true)
	check(session.index == 1, "Barking cannot skip a normal line")
	session.advance(false)
	check(not session.active and finished == [GREETING], "Finishing reports the finished conversation")
	check(GREETING.lines.size() == 2, "Sessions never modify dialogue resources")
	session.open(GREETING)
	session.close()
	check(not session.active and session.index == 0 and finished.size() == 1, "Closing does not count as finishing")
