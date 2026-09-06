extends Node2D

@export var sfxPath: String

var minHitSpeed = 64

func _ready():
	get_parent().body_entered.connect(_on_body_entered)

func _on_body_entered(_body: Node2D):
	if get_parent().linear_velocity.length() > minHitSpeed:
		play_sound()

func play_sound():
	var audio_player = AudioStreamPlayer.new()
	add_child(audio_player)
	audio_player.stream = load(sfxPath)
	audio_player.play()
	audio_player.finished.connect(audio_player.queue_free)
