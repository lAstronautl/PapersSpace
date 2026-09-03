extends Label

@export var decay: float
@export var delay: int

func _process(delta: float) -> void :
	if Time.get_ticks_msec() < delay:
		return
	modulate.a -= decay * delta
	if modulate.a <= 0:
		queue_free()
