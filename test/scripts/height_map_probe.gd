## Disposable look-dev probe for HeightMap: noise, falloff and colour-band
## debug views, judged flat before any 3D exists.
extends Node

@export var grid_size: int = 256
@export var seed_value: int = 2
@export var noise_scale: float = 90.0
@export var octaves: int = 5
@export_range(0.0, 1.0) var persistence: float = 0.5
@export var lacunarity: float = 2.0
@export var normalize_mode: HeightMap.NormalizeMode = HeightMap.NormalizeMode.LOCAL
@export var combine_mode: HeightMap.CombineMode = HeightMap.CombineMode.SUBTRACT
@export var falloff_shape: HeightMap.FalloffShape = HeightMap.FalloffShape.SQUARE
@export var falloff_noise_scale: float = 40.0
@export_range(0.0, 1.0) var falloff_noise_amount: float = 0.25

var _bands: Array[Dictionary] = HeightMapBands.bands()

var _field: HeightMap
var _texture_rect: TextureRect
var _info_label: Label
## "colour", "noise" or "falloff" — see _unhandled_input.
var _debug_mode: String = "colour"
var _current_seed: int = 0


func _ready() -> void:
	_current_seed = seed_value
	_build_view()
	_regenerate()


## 1 colour bands, 2 raw noise (pre-falloff), 3 falloff alone. R rerolls to
## a random seed, [ and ] step the seed by one, C swaps subtract/multiply —
## all three regenerate.
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed):
		return
	match event.keycode:
		KEY_1:
			_debug_mode = "colour"
			_refresh_texture()
		KEY_2:
			_debug_mode = "noise"
			_refresh_texture()
		KEY_3:
			_debug_mode = "falloff"
			_refresh_texture()
		KEY_R:
			_current_seed = randi()
			_regenerate()
		KEY_BRACKETLEFT:
			_current_seed -= 1
			_regenerate()
		KEY_BRACKETRIGHT:
			_current_seed += 1
			_regenerate()
		KEY_C:
			combine_mode = HeightMap.CombineMode.MULTIPLY if combine_mode == HeightMap.CombineMode.SUBTRACT else HeightMap.CombineMode.SUBTRACT
			_regenerate()
		KEY_V:
			falloff_shape = HeightMap.FalloffShape.RADIAL if falloff_shape == HeightMap.FalloffShape.SQUARE else HeightMap.FalloffShape.SQUARE
			_regenerate()


func _regenerate() -> void:
	_field = HeightMap.new()
	_field.generate(grid_size, grid_size, _current_seed, noise_scale, octaves, persistence, lacunarity, Vector2.ZERO, normalize_mode, combine_mode, falloff_shape, falloff_noise_scale, falloff_noise_amount)
	_refresh_texture()


func _build_view() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.name = "HeightMapDebugLayer"
	add_child(layer)

	_texture_rect = TextureRect.new()
	_texture_rect.name = "HeightMapDebugView"
	_texture_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_texture_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_texture_rect)

	_info_label = Label.new()
	_info_label.name = "HeightMapDebugInfo"
	_info_label.position = Vector2(16, 16)
	_info_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	_info_label.add_theme_constant_override("shadow_offset_x", 1)
	_info_label.add_theme_constant_override("shadow_offset_y", 1)
	layer.add_child(_info_label)


func _refresh_texture() -> void:
	var image: Image = Image.create_empty(grid_size, grid_size, false, Image.FORMAT_RGB8)
	for y in range(grid_size):
		for x in range(grid_size):
			image.set_pixel(x, y, _pixel_colour(y * grid_size + x))
	_texture_rect.texture = ImageTexture.create_from_image(image)
	var mode_name: String = "subtract" if combine_mode == HeightMap.CombineMode.SUBTRACT else "multiply"
	var shape_name: String = "square" if falloff_shape == HeightMap.FalloffShape.SQUARE else "radial"
	_info_label.text = "seed %d, %s, %s   1 colour  2 noise  3 falloff   R random seed  [ ] step seed  C swap blend  V swap falloff" % [_current_seed, mode_name, shape_name]


func _pixel_colour(index: int) -> Color:
	match _debug_mode:
		"noise":
			var v: float = _field.noise_values[index]
			return Color(v, v, v)
		"falloff":
			var v: float = _field.falloff_values[index]
			return Color(v, v, v)
		_:
			return HeightMapBands.colour_for(_field.values[index], _bands)
