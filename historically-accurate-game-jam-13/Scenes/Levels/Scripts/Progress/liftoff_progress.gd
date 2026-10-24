class_name LiftoffProgress
extends RoomProgress

@export var video: VideoStreamPlayer
@export var destination: RoomDefinition


func _ready() -> void:
	super()
	if video:
		video.finished.connect(_on_video_finished)


func begin() -> void:
	if video and not video.is_playing():
		video.play()


func configuration_errors() -> PackedStringArray:
	var errors: PackedStringArray = []
	if video == null:
		errors.append("video: assign the VideoStreamPlayer.")
	if destination == null:
		errors.append("destination: choose a room.")
	return errors


func _on_video_finished() -> void:
	if destination:
		room.departure_requested.emit(destination)
