extends Sprite2D

@export var arr: Array[Texture2D] = []

func _ready() -> void :
	texture = arr.pick_random()
