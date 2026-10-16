extends Control

# A literal port of Robust's StyleBoxTexture (Robust.Client/Graphics/Drawing/
# StyleBoxTexture.cs): 9-patch drawing with Stretch or Tile centre/edges,
# TextureScale and ExpandMargin, plus the default content margin (the patch
# margin scaled by TextureScale) PanelContainer insets its child by.
#
# patchMargin / expandMargin are Vector4(left, top, right, bottom).
var texture: Texture2D:
	set(value):
		texture = value
		queue_redraw()
var patchMargin: Vector4 = Vector4.ZERO:
	set(value):
		patchMargin = value
		queue_redraw()
var textureScale: Vector2 = Vector2.ONE:
	set(value):
		textureScale = value
		queue_redraw()
var expandMargin: Vector4 = Vector4.ZERO:
	set(value):
		expandMargin = value
		queue_redraw()
var tile: bool = false:
	set(value):
		tile = value
		queue_redraw()

func _init() -> void:
	# Robust samples UI textures with nearest-pixel filtering.
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_IGNORE

# StyleBox.GetContentMargin for each side (StyleBoxTexture.GetDefaultContentMargin).
func content_margin() -> Vector4:
	return Vector4(patchMargin.x * textureScale.x, patchMargin.y * textureScale.y,
		patchMargin.z * textureScale.x, patchMargin.w * textureScale.y)

# StyleBox.MinimumSize
func minimum_size() -> Vector2:
	var margin = content_margin()
	return Vector2(margin.x + margin.z, margin.y + margin.w)

# StyleBox.GetContentBox(box): the area a child is arranged in.
func content_box(box_size: Vector2) -> Rect2:
	var margin = content_margin()
	return Rect2(margin.x, margin.y, box_size.x - margin.x - margin.z, box_size.y - margin.y - margin.w)

func _draw() -> void:
	if texture == null:
		return

	var box = Rect2(-expandMargin.x, -expandMargin.y,
		size.x + expandMargin.x + expandMargin.z, size.y + expandMargin.y + expandMargin.w)
	var left = patchMargin.x
	var top = patchMargin.y
	var right = patchMargin.z
	var bottom = patchMargin.w
	var scaled = Vector4(left * textureScale.x, top * textureScale.y, right * textureScale.x, bottom * textureScale.y)
	var textureWidth = float(texture.get_width())
	var textureHeight = float(texture.get_height())
	var origin = box.position

	if left > 0:
		if top > 0:
			_draw_region(Rect2(origin, Vector2(scaled.x, scaled.y)), Rect2(0, 0, left, top))
		_draw_area(Rect2(origin + Vector2(0, scaled.y), Vector2(scaled.x, box.size.y - scaled.w - scaled.y)),
			Rect2(0, top, left, textureHeight - bottom - top))
		if bottom > 0:
			_draw_region(Rect2(origin + Vector2(0, box.size.y - scaled.w), Vector2(scaled.x, scaled.w)),
				Rect2(0, textureHeight - bottom, left, bottom))

	if right > 0:
		if top > 0:
			_draw_region(Rect2(origin + Vector2(box.size.x - scaled.z, 0), Vector2(scaled.z, scaled.y)),
				Rect2(textureWidth - right, 0, right, top))
		_draw_area(Rect2(origin + Vector2(box.size.x - scaled.z, scaled.y), Vector2(scaled.z, box.size.y - scaled.w - scaled.y)),
			Rect2(textureWidth - right, top, right, textureHeight - bottom - top))
		if bottom > 0:
			_draw_region(Rect2(origin + Vector2(box.size.x - scaled.z, box.size.y - scaled.w), Vector2(scaled.z, scaled.w)),
				Rect2(textureWidth - right, textureHeight - bottom, right, bottom))

	if top > 0:
		_draw_area(Rect2(origin + Vector2(scaled.x, 0), Vector2(box.size.x - scaled.z - scaled.x, scaled.y)),
			Rect2(left, 0, textureWidth - right - left, top))

	if bottom > 0:
		_draw_area(Rect2(origin + Vector2(scaled.x, box.size.y - scaled.w), Vector2(box.size.x - scaled.z - scaled.x, scaled.w)),
			Rect2(left, textureHeight - bottom, textureWidth - right - left, bottom))

	_draw_area(Rect2(origin + Vector2(scaled.x, scaled.y), Vector2(box.size.x - scaled.z - scaled.x, box.size.y - scaled.w - scaled.y)),
		Rect2(left, top, textureWidth - right - left, textureHeight - bottom - top))

func _draw_region(destination: Rect2, source: Rect2) -> void:
	if destination.size.x <= 0 or destination.size.y <= 0 or source.size.x <= 0 or source.size.y <= 0:
		return
	draw_texture_rect_region(texture, destination, source)

# DrawStretchingArea
func _draw_area(area: Rect2, source: Rect2) -> void:
	if area.size.x <= 0 or area.size.y <= 0 or source.size.x <= 0 or source.size.y <= 0:
		return
	if not tile:
		draw_texture_rect_region(texture, area, source)
		return

	var sectionWidth = source.size.x * textureScale.x
	var sectionHeight = source.size.y * textureScale.y
	var inverse = Vector2(1.0 / textureScale.x, 1.0 / textureScale.y)
	var right = area.position.x + area.size.x
	var bottom = area.position.y + area.size.y

	var x = area.position.x
	while right - x > 0:
		var y = area.position.y
		while bottom - y > 0:
			var destinationWidth = minf(right - x, sectionWidth)
			var destinationHeight = minf(bottom - y, sectionHeight)
			var sourceWidth = minf((right - x) * inverse.x, source.size.x)
			var sourceHeight = minf((bottom - y) * inverse.y, source.size.y)
			draw_texture_rect_region(texture, Rect2(x, y, destinationWidth, destinationHeight),
				Rect2(source.position.x, source.position.y, sourceWidth, sourceHeight))
			y += sectionHeight
		x += sectionWidth
