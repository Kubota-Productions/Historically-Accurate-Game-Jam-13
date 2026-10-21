@tool
class_name GameAudioProfile
extends Resource

@export_group("Interface")
@export var ui_confirm: AudioCue
@export_group("Items")
@export var pickup: AudioCue
@export var drop: AudioCue
@export var install: AudioCue
@export_group("Player")
@export var bark: AudioCue
@export var footstep: AudioCue
@export var sniff: AudioCue
@export var jump: AudioCue
@export_group("Mix")
@export var sound_vca_path: String = "vca:/SFX & UI"
@export var music_vca_path: String = "vca:/Music & Ambience"


func configuration_errors() -> PackedStringArray:
	var errors: PackedStringArray = []
	for property: Dictionary in get_property_list():
		var cue: Variant = get(property.name)
		if cue is AudioCue:
			for error: String in cue.configuration_errors():
				errors.append("%s/%s" % [property.name, error])
	for path: String in [sound_vca_path, music_vca_path]:
		if not path.is_empty() and not FmodServer.check_vca_path(path):
			errors.append("mix: unknown FMOD VCA '%s'." % path)
	return errors


func _validate_property(property: Dictionary) -> void:
	if not property.name.ends_with("_vca_path") or not Engine.is_editor_hint():
		return
	var server := Engine.get_singleton("FmodServer")
	if not server or not server.has_method("get_all_vca"):
		return
	var paths: PackedStringArray = []
	for vca: FmodVCA in server.get_all_vca():
		paths.append(vca.get_path())
	paths.sort()
	property.hint = PROPERTY_HINT_ENUM_SUGGESTION
	property.hint_string = ",".join(paths)
