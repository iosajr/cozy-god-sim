extends GutTest
## Tests for scripts/presence_light.gd (issue #5). Only checks that the
## light's position matches what move_to() was called with — no
## rendering/visual assertions, mirroring test_villager_nameplate.gd's
## thin-presentation-seam test shape.


func test_move_to_sets_the_light_position() -> void:
	var light: OmniLight3D = autofree(PresenceLight.new())

	light.move_to(Vector3(3, 0, -2))

	assert_eq(light.position, Vector3(3, 0, -2))
