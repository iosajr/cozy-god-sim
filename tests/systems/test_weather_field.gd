extends GutTest

func test_baked_image_has_the_requested_resolution() -> void:
	var img := WeatherField.bake_image(8, 200.0, 0.0)
	assert_eq(img.get_width(), 8)
	assert_eq(img.get_height(), 8)


func test_a_cell_matches_weather_query_at_that_worlds_position() -> void:
	var resolution := 8
	var world_size := 200.0
	var absolute_time := 5.0
	var img := WeatherField.bake_image(resolution, world_size, absolute_time)

	# Reproduce cell 0,0's world position the same way bake_image does.
	var world_pos := WeatherField.cell_to_world_position(0, 0, resolution, world_size)
	var expected_category := WeatherQuery.category_at(world_pos, absolute_time)

	# FORMAT_RGBA8 quantizes to 8-bit channels (~1/255 step), so compare
	# with a tolerance comfortably above that quantization error, not
	# exact float equality.
	var pixel := img.get_pixel(0, 0)
	assert_almost_eq(pixel.r, WeatherVisual.tint_for(expected_category).r, 0.01)
	assert_almost_eq(pixel.g, WeatherVisual.tint_for(expected_category).g, 0.01)
	assert_almost_eq(pixel.b, WeatherVisual.tint_for(expected_category).b, 0.01)
	assert_almost_eq(pixel.a, WeatherVisual.intensity_for(expected_category), 0.01)


func test_same_inputs_always_bake_the_same_image() -> void:
	var img1 := WeatherField.bake_image(6, 200.0, 42.0)
	var img2 := WeatherField.bake_image(6, 200.0, 42.0)
	assert_eq(img1.get_data(), img2.get_data())


func test_cell_to_world_position_covers_the_full_world_extent() -> void:
	var resolution := 4
	var world_size := 200.0
	var top_left := WeatherField.cell_to_world_position(0, 0, resolution, world_size)
	var bottom_right := WeatherField.cell_to_world_position(resolution - 1, resolution - 1, resolution, world_size)
	assert_almost_eq(top_left.x, -world_size / 2.0, world_size / resolution)
	assert_almost_eq(bottom_right.x, world_size / 2.0, world_size / resolution)
