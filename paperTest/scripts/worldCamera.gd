extends Camera2D

const worldSize = Vector2(192, 192)
const zoomStepFactor = 1.1
const maxZoomMultiplier = 4.0

var baseZoom = 1.0
var panning = false
var panLastMouse = Vector2.ZERO

func _ready() -> void :
	position = worldSize / 2

func _unhandled_input(event: InputEvent) -> void :
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_MIDDLE and not event.shift_pressed:
			panning = event.pressed
			panLastMouse = event.position
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_setZoom(zoom.x * zoomStepFactor)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_setZoom(zoom.x / zoomStepFactor)

	if event is InputEventMouseMotion and panning:
		var delta = (event.position - panLastMouse) / zoom.x
		position -= delta
		panLastMouse = event.position
		_clampPosition()

func _setZoom(newZoom: float) -> void :
	newZoom = clamp(newZoom, baseZoom, baseZoom * maxZoomMultiplier)
	zoom = Vector2(newZoom, newZoom)
	_clampPosition()

func _clampPosition() -> void :
	var viewHalfSize = (get_viewport_rect().size / zoom.x) / 2
	position.x = clamp(position.x, viewHalfSize.x, worldSize.x - viewHalfSize.x) if worldSize.x > viewHalfSize.x * 2 else worldSize.x / 2
	position.y = clamp(position.y, viewHalfSize.y, worldSize.y - viewHalfSize.y) if worldSize.y > viewHalfSize.y * 2 else worldSize.y / 2
