extends GutTest
## Tests for scripts/dialogue_box.gd (issue #12). Only checks that
## show_dialogue()'s content is set/observable — no rendering/animation
## assertions, mirroring test_villager_nameplate.gd/test_presence_light.gd's
## thin-presentation-seam test shape (issue #12's Testing Decisions).


func test_show_dialogue_sets_speaker_name_and_lines() -> void:
	var box: DialogueBox = autofree(DialogueBox.new())

	box.show_dialogue("Corwen", ["Watches over the harvest with quiet pride."])

	assert_eq(box.speaker_name, "Corwen")
	assert_eq(box.lines, ["Watches over the harvest with quiet pride."])


func test_show_dialogue_accepts_a_god_or_a_folk_member_the_same_way() -> void:
	# User Story 3: no assumption baked in about whether the speaker is a
	# God or a Folk member — same shape either way.
	var box: DialogueBox = autofree(DialogueBox.new())

	box.show_dialogue("A Renowned Villager", ["The bread smells almost ready."])

	assert_eq(box.speaker_name, "A Renowned Villager")
	assert_eq(box.lines, ["The bread smells almost ready."])


func test_close_clears_speaker_name_and_lines() -> void:
	# User Story 12: closing leaves no lingering state.
	var box: DialogueBox = autofree(DialogueBox.new())
	box.show_dialogue("Corwen", ["A line of dialogue."])

	box.close()

	assert_eq(box.speaker_name, "")
	assert_eq(box.lines, ([] as Array[String]))


func test_show_thinking_sets_speaker_and_awaiting_flag() -> void:
	var box: DialogueBox = autofree(DialogueBox.new())

	box.show_thinking("A Renowned Villager")

	assert_eq(box.speaker_name, "A Renowned Villager")
	assert_true(box.is_awaiting_response)
	assert_false(box.is_pending_approval)


func test_show_dialogue_clears_awaiting_and_pending_approval() -> void:
	var box: DialogueBox = autofree(DialogueBox.new())
	box.show_thinking("A Renowned Villager")

	box.show_dialogue("A Renowned Villager", ["The bread smells almost ready."])

	assert_false(box.is_awaiting_response)
	assert_false(box.is_pending_approval)


func test_show_pending_approval_sets_lines_and_pending_flag() -> void:
	var box: DialogueBox = autofree(DialogueBox.new())

	box.show_pending_approval("A Renowned Villager", ["A fresh reaction.", "A fresh wish."])

	assert_eq(box.lines, ["A fresh reaction.", "A fresh wish."])
	assert_true(box.is_pending_approval)
	assert_false(box.is_awaiting_response)


func test_close_clears_awaiting_and_pending_approval_too() -> void:
	var box: DialogueBox = autofree(DialogueBox.new())
	box.show_pending_approval("A Renowned Villager", ["A fresh reaction."])

	box.close()

	assert_false(box.is_pending_approval)
	assert_false(box.is_awaiting_response)
