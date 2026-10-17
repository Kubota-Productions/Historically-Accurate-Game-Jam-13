class_name FPSCamera
extends Node3D

@export var player: FPSPlayer
@export var camera: Camera3D

@export_group("Look")
@export var mouse_sensitivity: float = 0.1
@export var invert_y: bool = false
@export_range(10.0, 89.9) var max_pitch_deg: float = 89.0

@export_group("Eye")
@export var stand_eye_height: float = 1.55
@export var crouch_eye_height: float = 0.85
@export var crouch_glide_time: float = 0.06

@export_group("Step Smoothing")
@export var step_smooth_speed: float = 4.0
@export var step_smooth_catch_up: float = 8.0
@export var step_smooth_max_lag: float = 1.2

@export_group("View")
@export var strafe_roll_deg: float = 1.5
@export var strafe_roll_speed: float = 5.0
@export var roll_smooth_time: float = 0.1
@export var landing_dip: float = 0.12
@export var landing_dip_min_speed: float = 5.0
@export var landing_dip_full_speed: float = 14.0
@export var dip_stiffness: float = 300.0
@export var dip_damping: float = 22.0

var yaw: float = 0.0
var pitch: float = 0.0
var _roll := 0.0
var _eye := 0.0
var _dip := 0.0
var _dip_velocity := 0.0
var _lag := Vector3.ZERO
var _pending_lift := Vector3.ZERO
var _prev_pos := Vector3.ZERO
var _curr_pos := Vector3.ZERO


func _ready() -> void:
	top_level = true
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	process_physics_priority = 100
	_eye = stand_eye_height
	set_look(player.global_rotation.y, 0.0)
	snap_to_player()
	player.landed.connect(_on_landed)
	player.stepped.connect(_on_stepped)
	player.teleported.connect(snap_to_player)


func _unhandled_input(event: InputEvent) -> void:
	var motion := event as InputEventMouseMotion
	if motion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var vertical := motion.relative.y * (-1.0 if invert_y else 1.0)
		set_look(wrapf(yaw - deg_to_rad(motion.relative.x * mouse_sensitivity), -PI, PI), pitch - deg_to_rad(vertical * mouse_sensitivity))


func _physics_process(_delta: float) -> void:
	_prev_pos = _curr_pos + _pending_lift
	_curr_pos = player.global_position
	_lag = (_lag + _pending_lift).limit_length(step_smooth_max_lag)
	_pending_lift = Vector3.ZERO


func _process(delta: float) -> void:
	var feet := _prev_pos.lerp(_curr_pos, Engine.get_physics_interpolation_fraction())

	var rate := step_smooth_speed + _lag.length() * step_smooth_catch_up
	if not player.is_on_floor():
		rate += absf(player.velocity.y)
	_lag = _lag.move_toward(Vector3.ZERO, rate * delta)
	feet -= _lag

	var eye_target := crouch_eye_height if player.is_crouching else stand_eye_height
	_eye = lerpf(_eye, eye_target, 1.0 - exp(-delta / maxf(crouch_glide_time, 0.001)))

	var spring_denominator := 1.0 + dip_damping * delta + dip_stiffness * delta * delta
	_dip_velocity = (_dip_velocity - dip_stiffness * _dip * delta) / spring_denominator
	_dip += _dip_velocity * delta

	var yaw_basis := Basis(Vector3.UP, yaw)
	var side := clampf(player.velocity.dot(yaw_basis.x) / maxf(strafe_roll_speed, 0.01), -1.0, 1.0)
	var roll_goal := -side * deg_to_rad(strafe_roll_deg)
	_roll = lerpf(_roll, roll_goal, 1.0 - exp(-delta / maxf(roll_smooth_time, 0.001)))

	global_transform = Transform3D(
		yaw_basis * Basis(Vector3.RIGHT, pitch) * Basis(Vector3.BACK, _roll),
		feet + Vector3.UP * (_eye + _dip)
	)


func _on_stepped(offset: Vector3) -> void:
	_pending_lift += offset


func _on_landed(impact_speed: float) -> void:
	var span := maxf(landing_dip_full_speed - landing_dip_min_speed, 0.001)
	var strength := clampf((impact_speed - landing_dip_min_speed) / span, 0.0, 1.0)
	if strength <= 0.0:
		return
	_dip = minf(_dip, -strength * landing_dip)
	_dip_velocity = 0.0


func snap_to_player() -> void:
	_prev_pos = player.global_position
	_curr_pos = _prev_pos
	_lag = Vector3.ZERO
	_pending_lift = Vector3.ZERO


func set_look(new_yaw: float, new_pitch: float) -> void:
	yaw = new_yaw
	pitch = clampf(new_pitch, -deg_to_rad(max_pitch_deg), deg_to_rad(max_pitch_deg))
	player.look_yaw = yaw
