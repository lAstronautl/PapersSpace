extends PinJoint2D

func _physics_process(_delta: float) -> void :
	global_position = get_global_mouse_position()
