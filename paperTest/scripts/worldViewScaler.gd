extends SubViewportContainer

@export var worldSize := Vector2i(192, 192)

@onready var worldViewport: SubViewport = $worldViewport
@onready var worldCamera: Camera2D = $worldViewport/worldCamera

func _ready() -> void :
	get_tree().root.size_changed.connect(_updateScale)
	_updateScale()

func _updateScale() -> void :
	var windowSize = get_tree().root.size
	var scaleFactor = max(1, floor(min(windowSize.x / float(worldSize.x), windowSize.y / float(worldSize.y))))
	var targetSize = Vector2(worldSize) * scaleFactor
	var targetPosition = ((Vector2(windowSize) - targetSize) / 2).floor()

	offset_left = targetPosition.x
	offset_top = targetPosition.y
	offset_right = targetPosition.x + targetSize.x
	offset_bottom = targetPosition.y + targetSize.y

	worldViewport.size = Vector2i(targetSize)

	var previousZoom = worldCamera.zoom.x
	var wasAtBase = previousZoom <= worldCamera.baseZoom or worldCamera.baseZoom == 0.0
	worldCamera.baseZoom = scaleFactor
	worldCamera._setZoom(scaleFactor if wasAtBase else previousZoom)
