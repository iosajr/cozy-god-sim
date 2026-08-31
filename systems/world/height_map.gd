class_name HeightMap
extends RefCounted
## A multi-octave noise field with an edge falloff, producing one landmass
## per bake. Headless, no scene coupling.

enum NormalizeMode { LOCAL, GLOBAL }
## How noise_values and falloff_values combine into values. SUBTRACT is
## Lague's formula (a hard-edged coast); MULTIPLY tapers noise toward the
## edge instead of clamping it, for a softer coast.
enum CombineMode { SUBTRACT, MULTIPLY }
## SQUARE is Lague's formula (Chebyshev distance — square iso-lines, land
## reaches farther along the diagonals toward the corners). RADIAL is true
## distance from centre — round, no corner reach.
enum FalloffShape { SQUARE, RADIAL }

## Falloff curve shape: an S-curve from 0 at the centre to 1 at the edge.
const FALLOFF_A: float = 3.0
const FALLOFF_B: float = 2.2

var width: int = 0
var height: int = 0

## Raw multi-octave noise, normalized to [0, 1], before falloff.
var noise_values: PackedFloat32Array = PackedFloat32Array()
## The edge falloff alone, [0, 1], 0 at the centre rising to 1 at the edge.
var falloff_values: PackedFloat32Array = PackedFloat32Array()
## noise_values minus falloff_values, clamped to [0, 1] — the final field.
var values: PackedFloat32Array = PackedFloat32Array()


func generate(
	p_width: int,
	p_height: int,
	p_seed: int,
	p_scale: float,
	p_octaves: int,
	p_persistence: float,
	p_lacunarity: float,
	p_offset: Vector2 = Vector2.ZERO,
	p_normalize_mode: NormalizeMode = NormalizeMode.LOCAL,
	p_combine_mode: CombineMode = CombineMode.SUBTRACT,
	p_falloff_shape: FalloffShape = FalloffShape.SQUARE,
) -> void:
	width = p_width
	height = p_height
	noise_values = _build_noise(p_seed, p_scale, p_octaves, p_persistence, p_lacunarity, p_offset, p_normalize_mode)
	falloff_values = _build_falloff(p_falloff_shape)
	values = PackedFloat32Array()
	values.resize(noise_values.size())
	for i in range(values.size()):
		if p_combine_mode == CombineMode.MULTIPLY:
			values[i] = clampf(noise_values[i] * (1.0 - falloff_values[i]), 0.0, 1.0)
		else:
			values[i] = clampf(noise_values[i] - falloff_values[i], 0.0, 1.0)


func value_at(x: int, y: int) -> float:
	return values[y * width + x]


## Sums octaves of Perlin noise, each with its own seeded offset so peaks
## and valleys don't line up between octaves. `persistence` shrinks each
## octave's amplitude, `lacunarity` grows its frequency.
func _build_noise(
	p_seed: int,
	p_scale: float,
	p_octaves: int,
	p_persistence: float,
	p_lacunarity: float,
	p_offset: Vector2,
	p_normalize_mode: NormalizeMode,
) -> PackedFloat32Array:
	var scale: float = p_scale if p_scale > 0.0 else 0.0001

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = p_seed
	var octave_offsets: Array[Vector2] = []
	var max_possible_height: float = 0.0
	var amplitude: float = 1.0
	for i in range(p_octaves):
		var offset_x: float = rng.randi_range(-100000, 100000) + p_offset.x
		var offset_y: float = rng.randi_range(-100000, 100000) - p_offset.y
		octave_offsets.append(Vector2(offset_x, offset_y))
		max_possible_height += amplitude
		amplitude *= p_persistence

	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.frequency = 1.0

	var result: PackedFloat32Array = PackedFloat32Array()
	result.resize(width * height)
	var half_width: float = width / 2.0
	var half_height: float = height / 2.0
	var min_height: float = INF
	var max_height: float = -INF

	for y in range(height):
		for x in range(width):
			amplitude = 1.0
			var frequency: float = 1.0
			var noise_height: float = 0.0
			for i in range(p_octaves):
				var sample_x: float = (x - half_width + octave_offsets[i].x) / scale * frequency
				var sample_y: float = (y - half_height + octave_offsets[i].y) / scale * frequency
				noise_height += noise.get_noise_2d(sample_x, sample_y) * amplitude
				amplitude *= p_persistence
				frequency *= p_lacunarity
			var idx: int = y * width + x
			result[idx] = noise_height
			min_height = minf(min_height, noise_height)
			max_height = maxf(max_height, noise_height)

	for i in range(result.size()):
		if p_normalize_mode == NormalizeMode.LOCAL:
			result[i] = inverse_lerp(min_height, max_height, result[i])
		else:
			result[i] = clampf((result[i] + 1.0) / (max_possible_height / 0.9), 0.0, 1.0)
	return result


func _build_falloff(shape: FalloffShape) -> PackedFloat32Array:
	var result: PackedFloat32Array = PackedFloat32Array()
	result.resize(width * height)
	for y in range(height):
		for x in range(width):
			var nx: float = float(x) / width * 2.0 - 1.0
			var ny: float = float(y) / height * 2.0 - 1.0
			var value: float
			if shape == FalloffShape.RADIAL:
				value = minf(sqrt(nx * nx + ny * ny), 1.0)
			else:
				value = maxf(absf(nx), absf(ny))
			result[y * width + x] = _evaluate_falloff(value)
	return result


static func _evaluate_falloff(value: float) -> float:
	var a: float = pow(value, FALLOFF_A)
	var b: float = pow(FALLOFF_B - FALLOFF_B * value, FALLOFF_A)
	return a / (a + b)
