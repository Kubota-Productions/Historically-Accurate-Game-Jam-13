extends SceneTree

const PALETTE: Array[Color] = [Color.RED, Color.GREEN, Color.BLUE, Color.YELLOW, Color.CYAN, Color.MAGENTA, Color(0.4, 0.4, 0.4), Color.WHITE]

var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Dog vision rendering requires a display and GPU renderer.")
		quit(1)
		return
	root.size = Vector2i(960, 540)
	root.position = Vector2i.ZERO
	var world := Node3D.new()
	root.add_child(world)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 4.5
	camera.position.z = 10.0
	world.add_child(camera)
	for index: int in PALETTE.size():
		var tile := MeshInstance3D.new()
		tile.mesh = QuadMesh.new()
		tile.mesh.size = Vector2(1.8, 1.8)
		tile.position = Vector3(-3.0 + (index % 4) * 2.0, 1.0 if index < 4 else -1.0, 0.0)
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = PALETTE[index]
		tile.material_override = material
		world.add_child(tile)
	var filter: CanvasLayer = load("res://Scenes/GUI/Components/DogVisionFilter.tscn").instantiate()
	root.add_child(filter)
	var interface := CanvasLayer.new()
	interface.layer = 10
	root.add_child(interface)
	var ui_marker := ColorRect.new()
	ui_marker.color = Color.RED
	ui_marker.size = Vector2(960, 48)
	interface.add_child(ui_marker)
	await _settle()
	var before := root.get_texture().get_image()
	before.save_png("/tmp/laika-dog-vision-off.png")
	filter.show()
	await _settle()
	var after := root.get_texture().get_image()
	after.save_png("/tmp/laika-dog-vision-on.png")
	for index: int in PALETTE.size():
		var sample := Vector2i(120 + (index % 4) * 240, 150 if index < 4 else 390)
		var original := before.get_pixelv(sample)
		var filtered := after.get_pixelv(sample)
		_check(absf(filtered.r - filtered.g) < 0.015, "Swatch %d has no red/green opponent difference" % index)
		_check(absf(original.b - filtered.b) < 0.015, "Swatch %d preserves its blue channel" % index)
		if index >= 6:
			_check(_distance(original, filtered) < 0.015, "Neutral swatch %d stays neutral at the same brightness" % index)
	_check(after.get_pixel(600, 150).b > after.get_pixel(600, 150).r + 0.5, "Blue stays distinct")
	_check(after.get_pixel(840, 150).r > after.get_pixel(840, 150).b + 0.5, "Yellow stays distinct")
	_check(_distance(before.get_pixel(100, 24), after.get_pixel(100, 24)) < 0.005, "GUI above the filter keeps its original color")
	filter.hide()
	await _settle()
	var restored := root.get_texture().get_image()
	_check(_distance(before.get_pixel(120, 150), restored.get_pixel(120, 150)) < 0.005, "Disabling restores the original world color")
	print("DOG_VISION_RENDER: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


func _settle() -> void:
	for frame: int in 4:
		await process_frame
		await RenderingServer.frame_post_draw


func _distance(a: Color, b: Color) -> float:
	return maxf(absf(a.r - b.r), maxf(absf(a.g - b.g), absf(a.b - b.b)))


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)
