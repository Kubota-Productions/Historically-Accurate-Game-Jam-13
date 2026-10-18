class_name FPSPlayer
extends CharacterBody3D

signal landed(impact_speed: float)
signal stepped(offset: Vector3)
signal teleported

const MOVE_FORWARD := &"forward"
const MOVE_BACK := &"backwards"
const MOVE_LEFT := &"left"
const MOVE_RIGHT := &"right"
const JUMP := &"jump"
const PROBE_INSET := 0.03
const HULL_FLOOR_CLEARANCE := 0.4
const FLOOR_NORMAL_TOLERANCE := 0.01
const MIN_STEP_HEIGHT := 0.02
const STEP_DROP_PADDING := 0.05
const RISER_PROBE_INSET := 0.02
const RISER_LEAN_TOLERANCE := 0.08
const RISER_LEAN_MIN_LIFT := 0.05
const TREAD_PROBE_LIFT := 0.05
const TREAD_LEVEL_TOLERANCE := 0.05
const STEP_DOWN_MIN_DROP := 0.03
const FLAT_FLOOR_NORMAL := 0.99
const AUTO_CROUCH_SPEED_REACH := 0.1

@export_group("Ground Movement")
@export var walk_speed: float = 4.0
@export var crouch_speed_scale: float = 0.4
@export var crouch_slowdown: float = 0.1
@export var ground_accel: float = 10.0
@export var friction: float = 4.0
@export var stop_speed: float = 2.5

@export_group("Air Movement")
@export var air_acceleration: float = 10.0
@export var air_speed_cap: float = 0.76
@export var gravity: float = 20.3
@export var max_fall_speed: float = 40.0

@export_group("Jumping")
@export var jump_height: float = 1.2
@export var auto_bhop: bool = true
@export var jump_buffer_time: float = 0.1

@export_group("Body")
@export var collision_shape: CollisionShape3D
@export var body_radius: float = 0.5
@export var stand_height: float = 2.0
@export var crouch_height: float = 1.0

@export_group("Steps")
@export var max_step_height: float = 1.1
@export var max_drop_height: float = 0.6
@export var step_reach: float = 0.15
@export var step_advance: float = 0.5
@export var min_tread_depth: float = 2.0
@export var max_slope_degrees: float = 45.0

@export_group("Auto Crouch")
@export var auto_crouch: bool = true
@export var auto_crouch_reach: float = 0.6

var look_yaw: float = 0.0
var is_crouching: bool = false

var _standing_hull: CapsuleShape3D
var _crouching_hull: CapsuleShape3D
var _standing_probe: CapsuleShape3D
var _crouching_probe: CapsuleShape3D
var _probe_bottom: float = 0.0
var _floor_normal_min: float = 0.0
var _jump_buffer: float = 0.0
var _wish_dir := Vector3.ZERO
var _peak_fall: float = 0.0
var _riser := KinematicCollision3D.new()
var _ceiling := KinematicCollision3D.new()
var _landing := KinematicCollision3D.new()
var _ahead := KinematicCollision3D.new()
var _settled := KinematicCollision3D.new()
var _probe_query := PhysicsShapeQueryParameters3D.new()


func _ready() -> void:
	_standing_hull = _capsule(body_radius, stand_height)
	_crouching_hull = _capsule(body_radius, crouch_height)
	_probe_bottom = maxf(minf(HULL_FLOOR_CLEARANCE, crouch_height - body_radius * 2.0 + PROBE_INSET), 0.0)
	_standing_probe = _capsule(body_radius - PROBE_INSET, stand_height - PROBE_INSET - _probe_bottom)
	_crouching_probe = _capsule(body_radius - PROBE_INSET, crouch_height - PROBE_INSET - _probe_bottom)
	_probe_query.collision_mask = collision_mask
	_probe_query.exclude = [get_rid()]
	_apply_hull(false)
	motion_mode = CharacterBody3D.MOTION_MODE_GROUNDED
	floor_max_angle = deg_to_rad(max_slope_degrees)
	floor_snap_length = max_drop_height
	floor_stop_on_slope = true
	floor_constant_speed = true
	_floor_normal_min = cos(floor_max_angle) - FLOOR_NORMAL_TOLERANCE


func _physics_process(delta: float) -> void:
	_update_crouch()

	_jump_buffer = maxf(_jump_buffer - delta, 0.0)
	if Input.is_action_just_pressed(JUMP):
		_jump_buffer = jump_buffer_time

	var input := Input.get_vector(MOVE_LEFT, MOVE_RIGHT, MOVE_FORWARD, MOVE_BACK)
	_wish_dir = Basis(Vector3.UP, look_yaw) * Vector3(input.x, 0.0, input.y)
	if _wish_dir.length_squared() > 0.0001:
		_wish_dir = _wish_dir.normalized()

	var wish_speed := minf(input.length(), 1.0) * walk_speed * (crouch_speed_scale if is_crouching else 1.0)
	var was_on_floor := is_on_floor()
	var grounded := was_on_floor

	if grounded and (_jump_buffer > 0.0 or (auto_bhop and Input.is_action_pressed(JUMP))):
		velocity.y = sqrt(2.0 * gravity * jump_height)
		_jump_buffer = 0.0
		grounded = false

	if grounded:
		_apply_friction(delta)
		_accelerate(_wish_dir, wish_speed, ground_accel, delta)
		if is_crouching:
			_limit_crouch_speed(delta)
		velocity.y = 0.0
	else:
		_air_accelerate(_wish_dir, wish_speed, delta)
		velocity.y = maxf(velocity.y - gravity * delta, -max_fall_speed)
		_peak_fall = maxf(_peak_fall, -velocity.y)

	if grounded and _try_step_up():
		return

	var height_before := global_position.y
	move_and_slide()

	var on_floor := is_on_floor()
	if on_floor and not was_on_floor:
		landed.emit(_peak_fall)
		_peak_fall = 0.0
	elif on_floor and was_on_floor:
		var drop := height_before - global_position.y
		if drop > STEP_DOWN_MIN_DROP and get_floor_normal().y > FLAT_FLOOR_NORMAL:
			stepped.emit(Vector3.DOWN * drop)


func _try_step_up() -> bool:
	var dir := _move_direction()
	if dir == Vector3.ZERO:
		return false

	var start := global_transform

	if not test_move(start, dir * step_reach, _riser):
		return false
	if _riser.get_normal().y >= _floor_normal_min:
		return false

	var height := max_step_height
	if test_move(start, Vector3.UP * max_step_height, _ceiling):
		height = _ceiling.get_travel().y
	if height < MIN_STEP_HEIGHT:
		return false

	var advance := dir * step_advance
	var raised := start.translated(Vector3.UP * height)
	if test_move(raised, advance):
		return false

	var over := raised.translated(advance)
	if not test_move(over, Vector3.DOWN * (height + STEP_DROP_PADDING), _landing):
		return false

	var landed_at := over.origin + _landing.get_travel()
	if landed_at.y - start.origin.y < MIN_STEP_HEIGHT:
		return false

	var tread := _landing.get_position()
	if not _riser_is_vertical(start, dir, _riser.get_travel().length(), tread.y - start.origin.y):
		return false
	if not _tread_holds(landed_at, tread, dir):
		return false

	global_position = landed_at
	stepped.emit(landed_at - start.origin)
	return true


func _riser_is_vertical(start: Transform3D, dir: Vector3, contact_distance: float, step_height: float) -> bool:
	var probe_lift := step_height - body_radius + RISER_PROBE_INSET
	if probe_lift <= RISER_LEAN_MIN_LIFT:
		return true
	var raised := start.translated(Vector3.UP * probe_lift)
	return test_move(raised, dir * (contact_distance + RISER_LEAN_TOLERANCE))


func _tread_holds(landing_point: Vector3, tread: Vector3, dir: Vector3) -> bool:
	var edge_gap := maxf((tread - landing_point).dot(dir), 0.0)
	var run := dir * (edge_gap + min_tread_depth)
	var hover_height := maxf(landing_point.y, tread.y) + TREAD_PROBE_LIFT
	var hover := Transform3D(global_transform.basis, Vector3(landing_point.x, hover_height, landing_point.z))

	var travel := run
	var walled := false
	if test_move(hover, run, _ahead):
		if _ahead.get_normal().y >= _floor_normal_min:
			return false
		travel = _ahead.get_travel()
		walled = true

	if walled and travel.length() < edge_gap:
		return true

	var drop := Vector3.DOWN * (TREAD_PROBE_LIFT + TREAD_LEVEL_TOLERANCE)
	if not test_move(hover.translated(travel), drop, _settled):
		return false
	return _settled.get_normal().y >= _floor_normal_min


func _limit_crouch_speed(delta: float) -> void:
	var limit := walk_speed * crouch_speed_scale
	var flat := Vector2(velocity.x, velocity.z)
	var speed := flat.length()
	if speed <= limit:
		return

	var new_speed := limit
	if crouch_slowdown > 0.0:
		new_speed = maxf(speed - crouch_slowdown * delta, limit)
	flat *= new_speed / speed
	velocity.x = flat.x
	velocity.z = flat.y


func _apply_friction(delta: float) -> void:
	var speed := Vector2(velocity.x, velocity.z).length()
	if speed < 0.001:
		velocity.x = 0.0
		velocity.z = 0.0
		return

	var control := maxf(speed, stop_speed)
	var new_speed := maxf(speed - control * friction * delta, 0.0)
	var factor := new_speed / speed
	velocity.x *= factor
	velocity.z *= factor


func _accelerate(wish_dir: Vector3, wish_speed: float, accel: float, delta: float) -> void:
	var add_speed := wish_speed - velocity.dot(wish_dir)
	if add_speed <= 0.0:
		return
	var accel_speed := minf(accel * delta * wish_speed, add_speed)
	velocity += wish_dir * accel_speed


func _air_accelerate(wish_dir: Vector3, wish_speed: float, delta: float) -> void:
	var capped := minf(wish_speed, air_speed_cap)
	var add_speed := capped - velocity.dot(wish_dir)
	if add_speed <= 0.0:
		return
	var accel_speed := minf(air_acceleration * delta * wish_speed, add_speed)
	velocity += wish_dir * accel_speed


func _update_crouch() -> void:
	var low_ceiling := auto_crouch and _low_ceiling_ahead()
	if low_ceiling and is_on_floor():
		_set_crouch(true)
	elif is_crouching and not low_ceiling and not _hull_blocked(false, global_position, Vector3.ZERO):
		_set_crouch(false)


func _set_crouch(on: bool) -> void:
	is_crouching = on
	_apply_hull(on)


func _capsule(radius: float, height: float) -> CapsuleShape3D:
	var shape := CapsuleShape3D.new()
	shape.radius = radius
	shape.height = maxf(height, radius * 2.0)
	return shape


func _apply_hull(short: bool) -> void:
	var hull := _crouching_hull if short else _standing_hull
	collision_shape.shape = hull
	collision_shape.position = Vector3(0.0, hull.height * 0.5, 0.0)


func _hull_blocked(crouched: bool, feet: Vector3, motion: Vector3) -> bool:
	var probe := _crouching_probe if crouched else _standing_probe
	_probe_query.shape = probe
	_probe_query.transform = Transform3D(Basis(), feet + Vector3.UP * (_probe_bottom + probe.height * 0.5))
	_probe_query.motion = Vector3.ZERO
	var space := get_world_3d().direct_space_state
	if not space.intersect_shape(_probe_query, 1).is_empty():
		return true
	if motion == Vector3.ZERO:
		return false
	_probe_query.motion = motion
	var fractions := space.cast_motion(_probe_query)
	return fractions.size() >= 2 and fractions[1] < 1.0


func _move_direction() -> Vector3:
	var flat := Vector3(velocity.x, 0.0, velocity.z)
	if flat.length_squared() > 0.25:
		return flat.normalized()
	return _wish_dir


func _low_ceiling_ahead() -> bool:
	var dir := _move_direction()
	var motion := Vector3.ZERO
	if dir != Vector3.ZERO:
		motion = dir * (auto_crouch_reach + Vector2(velocity.x, velocity.z).length() * AUTO_CROUCH_SPEED_REACH)

	var feet := global_position
	if _hull_blocked(true, feet, motion):
		return false
	return _hull_blocked(false, feet, motion)


func teleport(to: Vector3) -> void:
	global_position = to
	velocity = Vector3.ZERO
	_peak_fall = 0.0
	teleported.emit()
