extends Node2D

const StampInfo = preload("res://scripts/stampInfo.gd")

const stampMarksPath = "res://png/item/paper/stampMarks/"
const stampScale = 1.0

# Mirrors SS14's PaperComponent.StampedBy: every stamp ever applied is kept
# here for the UI's StampCollection widget, but PaperVisualizerSystem only
# ever renders a single world-sprite state (the first one applied, never
# overwritten), so the visible mark on the paper in the world stays singular.
#
# z_index intentionally stays at the default 0 here: a positive z_index
# bypasses y_sort_enabled on the items parent, making the stamp render above
# OTHER items sitting on top of the paper (e.g. a pen dropped on it) instead
# of staying beneath them like the paper's own texture does. At 0 it
# participates in normal y-sort/draw-order like everything else - it's still
# drawn after Sprite2D/shadow (added later, same CollisionShape2D parent) so
# it stays above the paper's own texture.
var _allStamps: Array = []
var _visibleStamp: Sprite2D

func addStamp(stampState: String, stampRotation: float, stampPosition: Vector2) -> void :
	_allStamps.append({
		"stampState": stampState,
		"rotation": stampRotation,
		"position": {"x": stampPosition.x, "y": stampPosition.y},
	})

	if _visibleStamp:
		return

	var markState = StampInfo.getStampMark(stampState)
	var texturePath = stampMarksPath + "paper_stamp-" + markState + ".png"
	if not ResourceLoader.exists(texturePath):
		return

	var stamp = Sprite2D.new()
	stamp.texture = load(texturePath)
	stamp.scale = Vector2(stampScale, stampScale)
	stamp.rotation = stampRotation
	stamp.position = stampPosition
	stamp.modulate.a = 0.85
	add_child(stamp)
	_visibleStamp = stamp

func addRandomizedStamp(stampState: String) -> void :
	# Mirrors SS14's world-sprite stamp mark: a single fixed RSI state
	# centered on the page, no random offset/rotation (randomization only
	# applies to the UI's StampCollection arrangement, not the world sprite).
	addStamp(stampState, 0.0, Vector2.ZERO)

func clearStamps() -> void :
	_allStamps.clear()
	if _visibleStamp:
		_visibleStamp.queue_free()
		_visibleStamp = null

func serializeStamps() -> Array:
	return _allStamps.duplicate(true)

func loadStamps(data: Array) -> void :
	clearStamps()
	for entry in data:
		if not entry.has("stampState"):
			continue
		addStamp(entry.stampState, entry.rotation, Vector2(entry.position.x, entry.position.y))
