extends Node2D

# EmitSoundOnLand: the sound plays when a thrown item has finished its flight and
# come to rest, not on every knock along the way.
@export var sfxPath: String

const flightSpeed = 40.0
const restSpeed = 4.0

var _flying = false

func _physics_process(_delta: float) -> void :
	var speed = get_parent().linear_velocity.length()
	if speed > flightSpeed:
		_flying = true
	elif _flying and speed < restSpeed:
		_flying = false
		var audioPlayer = AudioStreamPlayer.new()
		add_child(audioPlayer)
		audioPlayer.stream = load(sfxPath)
		audioPlayer.play()
		audioPlayer.finished.connect(audioPlayer.queue_free)
