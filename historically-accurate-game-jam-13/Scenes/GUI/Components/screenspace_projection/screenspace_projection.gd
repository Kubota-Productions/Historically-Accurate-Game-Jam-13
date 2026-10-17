class_name ScreenspaceProjection
extends Camera3D

const MIN_VIEWPORT_SIZE := 64.0

@export var enabled: bool = true:
	set(value):
		enabled = value
		if is_node_ready():
			_resize()
@export_range(1.0, 10.0) var upscale: float = 2.0
@export_range(0.0, 1.0) var supersample_upscale_amount: float = 0.5

@onready var viewport: SubViewport = $ProjectionInput
@onready var output: MeshInstance3D = $ProjectionOutput
@onready var material: ShaderMaterial = output.material_override


func _ready() -> void:
	material.set_shader_parameter(&"screen_tex", viewport.get_texture())
	output.show()
	get_window().size_changed.connect(_resize)
	_resize()


func _unhandled_input(event: InputEvent) -> void:
	viewport.push_input(event)


func _process(_delta: float) -> void:
	var camera := viewport.get_camera_3d()
	if camera:
		material.set_shader_parameter(&"fov_deg", camera.fov)
		material.set_shader_parameter(&"fov_is_vertical", camera.keep_aspect == Camera3D.KEEP_HEIGHT)


func _resize() -> void:
	var scale := upscale if enabled else 1.0
	var size := Vector2(get_window().size) * scale
	if minf(size.x, size.y) < MIN_VIEWPORT_SIZE:
		size = Vector2.ONE * MIN_VIEWPORT_SIZE
		scale = 1.0
	viewport.size = Vector2i(size)
	if viewport.scaling_3d_mode == Viewport.SCALING_3D_MODE_BILINEAR:
		viewport.scaling_3d_scale = 1.0
	else:
		viewport.scaling_3d_scale = minf(1.0 / lerpf(scale, 1.0, sqrt(supersample_upscale_amount)), 1.0)
	material.set_shader_parameter(&"enabled", enabled)
