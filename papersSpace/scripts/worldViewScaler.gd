extends SubViewportContainer

# The world is no longer a fixed-size room letterboxed into the window - the
# viewport now fills the entire window, and the camera can fly freely over
# the infinite space background around the small room. Pixel art still needs
# integer scaling to stay crisp, so the camera's zoom is snapped to the
# largest integer factor that fits the window (same idea as before, just
# without capping the viewport's own size to worldSize * scaleFactor).
@export var worldSize := Vector2i(192, 192)

@onready var worldViewport: SubViewport = $worldViewport
@onready var worldCamera: Camera2D = $worldViewport/worldCamera

func _ready() -> void :
	anchors_preset = Control.PRESET_FULL_RECT
	get_tree().root.size_changed.connect(_updateScale)
	_updateScale()

func _updateScale() -> void :
	var windowSize = get_tree().root.size
	worldViewport.size = windowSize

	var scaleFactor = max(1, floor(min(windowSize.x / float(worldSize.x), windowSize.y / float(worldSize.y))))
	var previousZoom = worldCamera.zoom.x
	var wasAtBase = previousZoom <= worldCamera.baseZoom * worldCamera.minZoomMultiplier or worldCamera.baseZoom == 0.0
	worldCamera.baseZoom = scaleFactor
	worldCamera._setZoom(scaleFactor if wasAtBase else previousZoom)
