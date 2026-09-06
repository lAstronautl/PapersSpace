extends Label

const minLifetime = 0.7
const maxLifetime = 5.0
const lifetimePerChar = 0.04
const maxDriftPixels = 8.0

const normalColor = Color(1, 1, 1, 1)
const cautionColor = Color(1, 0.2, 0.2, 1)

var _age: float = 0.0
var _lifetime: float = minLifetime
var _basePosition: Vector2 = Vector2.ZERO
var repeat_count: int = 1

func _process(delta: float) -> void :
	_age += delta
	if _age >= _lifetime:
		queue_free()
		return

	var t = _age / _lifetime
	modulate.a = minf(1.0, 1.0 - maxf(0.0, t - 0.5) * 2.0)

	var drift = minf(maxDriftPixels, 12.0 * (t * t + t))
	global_position = _basePosition - Vector2(0, drift)

func show_at(worldPosition: Vector2, message: String, caution: bool = false) -> void :
	_age = 0.0
	_lifetime = clampf(lifetimePerChar * message.length(), minLifetime, maxLifetime)
	_basePosition = worldPosition
	global_position = worldPosition
	text = message
	modulate.a = 1.0
	add_theme_color_override("font_color", cautionColor if caution else normalColor)
