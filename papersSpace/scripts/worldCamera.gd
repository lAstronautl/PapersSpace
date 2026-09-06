extends Camera2D

const worldSize = Vector2(192, 192)
const zoomStepFactor = 1.1
const minZoomMultiplier = 0.5
const maxZoomMultiplier = 4.0

var baseZoom = 1.0
var panning = false
var panLastMouse = Vector2.ZERO

func _ready() -> void :
	position = worldSize / 2

func _unhandled_input(event: InputEvent) -> void :
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_MIDDLE and not event.shift_pressed:
			if event.pressed:
				startPan(event.position)
			else:
				stopPan()
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_setZoom(zoom.x * zoomStepFactor)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_setZoom(zoom.x / zoomStepFactor)

	if event is InputEventMouseMotion and panning:
		updatePan(event.position)

# Shared pan implementation, also driven by itemInteractionControler.gd for
# LMB-drag-on-empty-space panning (mirrors this camera's own middle-mouse
# pan, since item dragging already claims LMB when hovering an item).
func startPan(mousePos: Vector2) -> void :
	panning = true
	panLastMouse = mousePos

func stopPan() -> void :
	panning = false

# The camera can fly freely over the infinite space background - only zoom
# is still clamped (so you can't zoom out past 1:1 pixel scale or zoom in
# absurdly far), position itself is unconstrained.
func updatePan(mousePos: Vector2) -> void :
	var delta = (mousePos - panLastMouse) / zoom.x
	position -= delta
	panLastMouse = mousePos

func _setZoom(newZoom: float) -> void :
	newZoom = clamp(newZoom, baseZoom * minZoomMultiplier, baseZoom * maxZoomMultiplier)
	zoom = Vector2(newZoom, newZoom)
