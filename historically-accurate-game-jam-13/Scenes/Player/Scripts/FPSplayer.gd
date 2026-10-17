class_name FPSPlayer
extends CharacterBody3D

signal jumped
signal landed(impact_speed: float)
signal crouch_changed(crouching: bool)
signal stepped(offset: Vector3)
signal teleported

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

var action_forward: StringName = &"forward"
var action_back: StringName = &"backwards"
var action_left: StringName = &"left"
var action_right: StringName = &"right"
var action_jump: StringName = &"Jump"
var action_crouch: StringName = &"Crouch"
var action_walk: StringName = &"Walk"
var action_run: StringName = &"Run"

@export_group("Ground Movement")
@export var crouch_speed_scale: float = 0.4
@export var crouch_slowdown: float = 0.1
@export var ground_accel: float = 10.0
## ground friction.
@export var friction: float = 4.0
@export var stop_speed: float = 2.5

@export_group("Movement Speed")
@export var run_speed: float = 8
@export var walk_speed: float = 4.0

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
@export var crouch_is_toggle: bool = false

@export_group("Steps")
@export var max_step_height: float = 1.1
@export var max_drop_height: float = 0.6
@export var step_reach: float = 0.15
@export var step_advance: float = 0.5
@export var min_tread_depth: float = 2.0
var max_slope_degrees: float = 45

@export_group("Auto Crouch")
@export var auto_crouch: bool = true
@export var auto_crouch_reach: float = 0.6

var look_yaw: float = 0.0
var is_crouching := false

var _standing_hull: CapsuleShape3D
var _crouching_hull: CapsuleShape3D
var _standing_probe: CapsuleShape3D
var _crouching_probe: CapsuleShape3D
var _probe_bottom := 0.0
var _floor_normal_min := 0.0
var _crouch_wanted := false
var _jump_buffer := 0.0

## Lookyaw * input = worldspace vector describing movement intent
var _wish_dir := Vector3.ZERO

var _peak_fall := 0.0

func _ready() -> void:
	if not collision_shape:
		collision_shape = get_node_or_null("CollisionShape3D") as CollisionShape3D
	if not collision_shape:
		collision_shape = CollisionShape3D.new()
		collision_shape.name = "Hull"
		add_child(collision_shape)

	_standing_hull = _generate_hull(stand_height, 0.0)
	_crouching_hull = _generate_hull(crouch_height, 0.0)
	_probe_bottom = maxf(minf(HULL_FLOOR_CLEARANCE, crouch_height - body_radius * 2.0 + PROBE_INSET), 0.0)
	_standing_probe = _generate_probe(stand_height)
	_crouching_probe = _generate_probe(crouch_height)
	_apply_hull(false)

	motion_mode = CharacterBody3D.MOTION_MODE_GROUNDED
	floor_max_angle = deg_to_rad(max_slope_degrees)
	floor_snap_length = max_drop_height
	floor_stop_on_slope = true
	floor_constant_speed = true
	_floor_normal_min = cos(floor_max_angle) - FLOOR_NORMAL_TOLERANCE


func _physics_process(delta: float) -> void:
	if delta <= 0.0:
		return

	_update_crouch()

	_jump_buffer = maxf(_jump_buffer - delta, 0.0)
	if Input.is_action_just_pressed(action_jump):
		_jump_buffer = jump_buffer_time

	var input := Input.get_vector(action_left, action_right, action_forward, action_back)
	_wish_dir = Basis(Vector3.UP, look_yaw) * Vector3(input.x, 0.0, input.y)
	if _wish_dir.length_squared() > 0.0001:
		_wish_dir = _wish_dir.normalized()

	var wish_speed := minf(input.length(), 1.0) * _target_speed()
	var was_on_floor := is_on_floor()
	var grounded := was_on_floor

	if grounded and (_jump_buffer > 0.0 or (auto_bhop and Input.is_action_pressed(action_jump))):
		velocity.y = sqrt(2.0 * gravity * jump_height)
		_jump_buffer = 0.0
		grounded = false
		jumped.emit()

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

	var riser := KinematicCollision3D.new()
	if not test_move(start, dir * step_reach, riser):
		return false
	if riser.get_normal().y >= _floor_normal_min:
		return false

	var height := max_step_height
	var ceiling := KinematicCollision3D.new()
	if test_move(start, Vector3.UP * max_step_height, ceiling):
		height = ceiling.get_travel().y
	if height < MIN_STEP_HEIGHT:
		return false

	var advance := dir * step_advance
	var raised := start.translated(Vector3.UP * height)
	if test_move(raised, advance):
		return false

	var over := raised.translated(advance)
	var landing := KinematicCollision3D.new()
	if not test_move(over, Vector3.DOWN * (height + STEP_DROP_PADDING), landing):
		return false

	var landed_at := over.origin + landing.get_travel()
	if landed_at.y - start.origin.y < MIN_STEP_HEIGHT:
		return false

	var tread := landing.get_position()
	if not _riser_is_vertical(start, dir, riser.get_travel().length(), tread.y - start.origin.y):
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

func _tread_holds(landed: Vector3, tread: Vector3, dir: Vector3) -> bool:
	var edge_gap := maxf((tread - landed).dot(dir), 0.0)
	var run := dir * (edge_gap + min_tread_depth)
	var hover_height := maxf(landed.y, tread.y) + TREAD_PROBE_LIFT
	var hover := Transform3D(global_transform.basis, Vector3(landed.x, hover_height, landed.z))

	var travel := run
	var walled := false
	var ahead := KinematicCollision3D.new()
	if test_move(hover, run, ahead):
		if ahead.get_normal().y >= _floor_normal_min:
			return false
		travel = ahead.get_travel()
		walled = true

	if walled and travel.length() < edge_gap:
		return true

	var settled := KinematicCollision3D.new()
	var drop := Vector3.DOWN * (TREAD_PROBE_LIFT + TREAD_LEVEL_TOLERANCE)
	if not test_move(hover.translated(travel), drop, settled):
		return false
	return settled.get_normal().y >= _floor_normal_min

func _target_speed() -> float:
	if is_crouching:
		return walk_speed * crouch_speed_scale
	if _action_held(action_walk):
		return walk_speed
	if _action_held(action_run):
		return run_speed
	return walk_speed

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

func _action_held(action: StringName) -> bool:
	return InputMap.has_action(action) and Input.is_action_pressed(action)

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
	if InputMap.has_action(action_crouch):
		if crouch_is_toggle:
			if Input.is_action_just_pressed(action_crouch):
				_crouch_wanted = not _crouch_wanted
		else:
			_crouch_wanted = Input.is_action_pressed(action_crouch)

	var low_ceiling := auto_crouch and _low_ceiling_ahead()
	var want := _crouch_wanted or (low_ceiling and is_on_floor())

	if want and not is_crouching:
		_set_crouch(true)
	elif not want and is_crouching and not low_ceiling and not _hull_blocked(false, global_position, Vector3.ZERO):
		_set_crouch(false)

func _set_crouch(on: bool) -> void:
	if is_crouching == on:
		return
	is_crouching = on
	_apply_hull(on)
	crouch_changed.emit(on)

func _generate_hull(height: float, inset: float) -> CapsuleShape3D:
	var shape := CapsuleShape3D.new()
	shape.radius = body_radius - inset
	shape.height = maxf(height - inset * 2.0, shape.radius * 2.0)
	return shape

func _apply_hull(short: bool) -> void:
	var hull := _crouching_hull if short else _standing_hull
	collision_shape.shape = hull
	collision_shape.position = Vector3(0.0, hull.height * 0.5, 0.0)

func _generate_probe(top: float) -> CapsuleShape3D:
	var shape := CapsuleShape3D.new()
	shape.radius = body_radius - PROBE_INSET
	shape.height = maxf(top - PROBE_INSET - _probe_bottom, shape.radius * 2.0)
	return shape

func _hull_blocked(crouched: bool, feet: Vector3, motion: Vector3) -> bool:
	var probe := _crouching_probe if crouched else _standing_probe
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = probe
	query.collision_mask = collision_mask
	query.exclude = [get_rid()]
	query.transform = Transform3D(Basis(), feet + Vector3.UP * (_probe_bottom + probe.height * 0.5))

	var space := get_world_3d().direct_space_state
	if not space.intersect_shape(query, 1).is_empty():
		return true
	if motion == Vector3.ZERO:
		return false

	query.motion = motion
	var fractions := space.cast_motion(query)
	return fractions.size() >= 2 and fractions[1] < 1.0

## Returns movement direction along the ground plane. Height is zero'd.
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

func is_grounded() -> bool:
	return is_on_floor()
func is_auto_crouching() -> bool:
	return is_crouching and not _crouch_wanted
func get_horizontal_speed() -> float:
	return Vector2(velocity.x, velocity.z).length()
func get_wish_direction() -> Vector3:
	return _wish_dir

func teleport(to: Vector3) -> void:
	global_position = to
	velocity = Vector3.ZERO
	_peak_fall = 0.0
	teleported.emit()
