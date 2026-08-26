extends GutTest

func test_clear_has_zero_intensity() -> void:
	assert_eq(WeatherVisual.intensity_for(WeatherQuery.CATEGORY_CLEAR), 0.0)


func test_overcast_rain_storm_intensity_increases_with_severity() -> void:
	var overcast := WeatherVisual.intensity_for(WeatherQuery.CATEGORY_OVERCAST)
	var rain := WeatherVisual.intensity_for(WeatherQuery.CATEGORY_RAIN)
	var storm := WeatherVisual.intensity_for(WeatherQuery.CATEGORY_STORM)
	assert_gt(overcast, 0.0)
	assert_gt(rain, overcast)
	assert_gt(storm, rain)


func test_tint_is_distinct_per_category() -> void:
	var tints := [
		WeatherVisual.tint_for(WeatherQuery.CATEGORY_CLEAR),
		WeatherVisual.tint_for(WeatherQuery.CATEGORY_OVERCAST),
		WeatherVisual.tint_for(WeatherQuery.CATEGORY_RAIN),
		WeatherVisual.tint_for(WeatherQuery.CATEGORY_STORM),
	]
	for i in tints.size():
		for j in range(i + 1, tints.size()):
			assert_ne(tints[i], tints[j], "category %d and %d should have distinct tints" % [i, j])


func test_unknown_category_falls_back_to_clear() -> void:
	assert_eq(WeatherVisual.intensity_for("not_a_real_category"), WeatherVisual.intensity_for(WeatherQuery.CATEGORY_CLEAR))
	assert_eq(WeatherVisual.tint_for("not_a_real_category"), WeatherVisual.tint_for(WeatherQuery.CATEGORY_CLEAR))
