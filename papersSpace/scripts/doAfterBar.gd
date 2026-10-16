extends Control

# StarHorizon's DoAfterOverlay: a 24x7 progress_bar texture floating above whoever
# is doing the action, with a 1 px bar from x = 2 to x = 22 that fills over the
# delay. The bar goes from red through yellow to green (ProgressColorSystem:
# hue = 5/18 * progress, value 0.75, pure green when done). A cancelled do-after
# flashes red/off every 0.125 s and is gone after 0.5 s.
# It lives in the UI layer (the world is darkened by the room's CanvasModulate),
# at the same pixel scale as the world.
const barTexture = preload("res://png/ui/progress_bar.png")
const startX = 2.0
const endX = 22.0
const flashTime = 0.125
const excessTime = 0.5

var target: Node2D
var controler: Node2D
var delay = 1.0
var halfHeight = 8.0
var _startMsec = 0
var _cancelledMsec = -1
var _cancelRatio = 0.0

static func progressColor(progress: float, alpha: float = 1.0) -> Color:
	if progress >= 1.0:
		return Color(0, 1, 0, alpha)
	return Color.from_hsv(5.0 / 18.0 * progress, 1.0, 0.75, alpha)

func _init() -> void :
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 9

func begin(newTarget: Node2D, newControler: Node2D, seconds: float, newHalfHeight: float) -> void :
	target = newTarget
	controler = newControler
	delay = seconds
	halfHeight = newHalfHeight
	_startMsec = Time.get_ticks_msec()
	_place()

func ratio() -> float:
	return minf(1.0, (Time.get_ticks_msec() - _startMsec) / 1000.0 / delay)

func cancel() -> void :
	if _cancelledMsec >= 0:
		return
	_cancelRatio = ratio()
	_cancelledMsec = Time.get_ticks_msec()

# The action completed: the bar disappears at once.
func finish() -> void :
	queue_free()

func _process(_delta: float) -> void :
	if _cancelledMsec >= 0 and (Time.get_ticks_msec() - _cancelledMsec) / 1000.0 > excessTime:
		queue_free()
		return
	_place()
	queue_redraw()

# The texture's bottom edge sits just above the target's sprite, centred on it.
func _place() -> void :
	if not is_instance_valid(target):
		queue_free()
		return
	var pixel = controler.worldScale()
	size = Vector2(barTexture.get_width(), barTexture.get_height()) * pixel
	var anchor = target.global_position + Vector2(-barTexture.get_width() / 2.0, -(halfHeight + 1.6 + barTexture.get_height()))
	position = controler.worldToScreen(anchor)

func _draw() -> void :
	var pixel = controler.worldScale()
	draw_texture_rect(barTexture, Rect2(Vector2.ZERO, size), false)
	var color: Color
	var progress: float
	if _cancelledMsec >= 0:
		progress = _cancelRatio
		var flash = int(floor((Time.get_ticks_msec() - _cancelledMsec) / 1000.0 / flashTime)) % 2 == 0
		color = progressColor(0.0, 1.0 if flash else 0.0)
	else:
		progress = ratio()
		color = progressColor(progress)
	var right = (endX - startX) * progress + startX
	draw_rect(Rect2(startX * pixel.x, 3.0 * pixel.y, (right - startX) * pixel.x, pixel.y), color)
