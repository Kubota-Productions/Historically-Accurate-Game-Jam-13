class_name GameAudio
extends Node

signal cue_played(cue: AudioCue)

const CUSTOM_UI_GROUP := &"custom_ui_audio"

@export var ui_root: Control
@export var profile: GameAudioProfile

var _sound_vca: FmodVCA
var _music_vca: FmodVCA
var _listener: FmodListener3D


func _ready() -> void:
	if profile == null:
		push_warning("GameAudio: assign a GameAudioProfile resource.")
		return
	for error: String in profile.configuration_errors():
		push_warning("GameAudio: " + error)
	if not profile.sound_vca_path.is_empty() and FmodServer.check_vca_path(profile.sound_vca_path):
		_sound_vca = FmodServer.get_vca(profile.sound_vca_path)
	if not profile.music_vca_path.is_empty() and FmodServer.check_vca_path(profile.music_vca_path):
		_music_vca = FmodServer.get_vca(profile.music_vca_path)
	if ui_root:
		for button: Node in ui_root.find_children("*", "BaseButton", true, false):
			_connect_button(button)
		get_tree().node_added.connect(_connect_button)


func apply_settings(preferences: GameSettings) -> void:
	if _sound_vca:
		_sound_vca.set_volume(preferences.get_value(&"sound_volume"))
	if _music_vca:
		_music_vca.set_volume(preferences.get_value(&"music_volume"))


func bind_room(room: LaikaRoom) -> void:
	if profile == null:
		return
	room.carry.picked_up.connect(play.bind(profile.pickup, room.player).unbind(1))
	room.carry.dropped.connect(play.bind(profile.drop, room.player).unbind(1))
	room.carry.stored.connect(play.bind(profile.install, room.player).unbind(1))
	_listener = FmodListener3D.new()
	room.camera.add_child(_listener)


func play(cue: AudioCue, source: Node3D = null) -> bool:
	if cue == null or not cue.play(source if is_instance_valid(source) else _listener):
		return false
	cue_played.emit(cue)
	return true


func _on_ui_pressed(button: BaseButton) -> void:
	if not button.is_in_group(CUSTOM_UI_GROUP):
		play(profile.ui_confirm)


func _connect_button(node: Node) -> void:
	if node is BaseButton and ui_root.is_ancestor_of(node):
		var callback := _on_ui_pressed.bind(node)
		if not node.pressed.is_connected(callback):
			node.pressed.connect(callback)
