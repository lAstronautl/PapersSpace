extends TextureRect

const lifetime = 3000
var statTime = Time.get_ticks_msec()

func _process(_delta: float) -> void :
	position.y = sin(statTime + Time.get_ticks_msec() * 0.01) * 4 - 24
	if Time.get_ticks_msec() > statTime + lifetime:
		queue_free()
