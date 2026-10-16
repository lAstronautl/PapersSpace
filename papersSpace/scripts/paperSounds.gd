extends RefCounted

# PaperComponent.Sound: the "PaperScribbles" collection (variation 0.1), played
# when text is saved on a paper and when a pen signs it.
const scribbles = [
	preload("res://sfx/paper_scribble1.ogg"), preload("res://sfx/paper_scribble2.ogg"),
	preload("res://sfx/paper_scribble3.ogg"), preload("res://sfx/paper_scribble4.ogg"),
	preload("res://sfx/paper_scribble5.ogg"),
]
const pitchVariation = 0.1

static func pick() -> AudioStream:
	return scribbles.pick_random()

# Plays a random scribble through a one-shot player under `parent`.
static func play(parent: Node, positional_at = null) -> void:
	var player
	if positional_at == null:
		player = AudioStreamPlayer.new()
	else:
		player = AudioStreamPlayer2D.new()
		player.global_position = positional_at
	player.stream = pick()
	player.pitch_scale = 1.0 + randf_range(-pitchVariation, pitchVariation)
	parent.add_child(player)
	player.play()
	player.finished.connect(player.queue_free)
