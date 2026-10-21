class_name GameAudio
extends Node

signal cue_played(cue: AudioCue)

const CUSTOM_UI_GROUP := &"custom_ui_audio"

@export var ui_root: Control
@export var profile: GameAudioProfile
@export var menu_music: FmodEventEmitter2D
@export_range(0.1, 5.0, 0.05) var footstep_distance: float = 0.8

var _sound_vca: FmodVCA
var _music_vca: FmodVCA
var _listener: FmodListener3D
var _menu_active: bool = false


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
	var footsteps := FootstepTracker.new()
	footsteps.name = "Footsteps"
	footsteps.player = room.player
	footsteps.step_distance = footstep_distance
	footsteps.step_requested.connect(play.bind(profile.footstep, room.player))
	room.player.add_child(footsteps)


func set_menu_active(enabled: bool) -> void:
	if enabled == _menu_active:
		return
	_menu_active = enabled
	if menu_music == null:
		return
	if not enabled:
		menu_music.stop()
		return
	var errors := menu_music_configuration_errors()
	if not errors.is_empty():
		push_warning("GameAudio: " + "; ".join(errors))
		return
	menu_music.play()


func menu_music_configuration_errors() -> PackedStringArray:
	if menu_music == null or menu_music.event_name.is_empty():
		return ["MenuMusic: assign a background music event."]
	if not FmodServer.check_event_path(menu_music.event_name):
		return ["MenuMusic: event is missing from the loaded FMOD banks."]
	if FmodServer.get_event(menu_music.event_name).is_3d():
		return ["MenuMusic: export this event as 2D in FMOD and rebuild the banks; spatial music is not started."]
	return []


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
