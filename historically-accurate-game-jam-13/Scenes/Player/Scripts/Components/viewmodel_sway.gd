extends Node

@export var visual: Node3D
@export var camera: Camera3D
@export_range(0.0, 5.0, 0.1) var max_angle: float = 0.8
@export_range(0.0, 1.0, 0.01) var amount: float = 0.35
@export_range(1.0, 30.0, 0.5) var response: float = 12.0
@export var render_as_viewmodel: bool = true

var _rest: Transform3D
var _previous: Quaternion
var _offset := Vector3.ZERO
var _appearance := ViewmodelAppearance.new()


func _ready() -> void:
	_rest = visual.transform
	_previous = camera.global_basis.get_rotation_quaternion()
	if render_as_viewmodel:
		_appearance.apply(visual, 126)


func _process(delta: float) -> void:
	var current := camera.global_basis.get_rotation_quaternion()
	var difference := _previous.inverse() * current
	if difference.w < 0.0:
		difference = -difference
	_previous = current
	if difference.get_angle() > 0.7 or delta > 0.25:
		_offset = Vector3.ZERO
	else:
		var angles := difference.get_euler()
		var limit := deg_to_rad(max_angle)
		var rate := maxf(response, 0.001)
		var lag := amount / (rate * maxf(delta, 0.001))
		var goal := Vector3(
			clampf(-angles.x * lag, -limit, limit),
			clampf(-angles.y * lag, -limit, limit),
			0.0
		)
		_offset = _offset.lerp(goal, 1.0 - exp(-rate * delta))
	visual.transform = Transform3D(_rest.basis * Basis.from_euler(_offset), _rest.origin)
