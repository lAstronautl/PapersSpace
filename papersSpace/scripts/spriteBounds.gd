extends RefCounted

# Fits an item's collision shape to what its sprite really draws: the opaque pixels'
# bounds, taken symmetrically around the sprite centre (the shape sits at the body's
# origin, the sprite is its child).
const minSide = 4.0
const alphaThreshold = 0.1

static var _cache: Dictionary = {}

static func halfExtents(texture: Texture2D) -> Vector2:
	if texture == null:
		return Vector2.ZERO
	var key = texture.resource_path if texture.resource_path != "" else str(texture.get_instance_id())
	if _cache.has(key):
		return _cache[key]
	var image = texture.get_image()
	if image and image.is_compressed():
		image.decompress()
	if image and image.get_format() != Image.FORMAT_RGBA8:
		image.convert(Image.FORMAT_RGBA8)
	var used = image.get_used_rect() if image else Rect2i()
	var half = Vector2.ZERO
	if image and used.size.x > 0:
		var minX = used.end.x
		var minY = used.end.y
		var maxX = used.position.x
		var maxY = used.position.y
		for y in range(used.position.y, used.end.y):
			for x in range(used.position.x, used.end.x):
				if image.get_pixel(x, y).a > alphaThreshold:
					minX = mini(minX, x)
					maxX = maxi(maxX, x + 1)
					minY = mini(minY, y)
					maxY = maxi(maxY, y + 1)
		var center = Vector2(image.get_width(), image.get_height()) / 2.0
		half = Vector2(maxf(center.x - minX, maxX - center.x), maxf(center.y - minY, maxY - center.y))
	_cache[key] = half
	return half

# Outlines of the opaque pixels, in the sprite's local space (centre = origin).
static var _outlines: Dictionary = {}
const outlineEpsilon = 0.8

static func outlines(texture: Texture2D) -> Array:
	if texture == null:
		return []
	var key = texture.resource_path if texture.resource_path != "" else str(texture.get_instance_id())
	if _outlines.has(key):
		return _outlines[key]
	var result = []
	var image = texture.get_image()
	if image:
		if image.is_compressed():
			image.decompress()
		var bitmap = BitMap.new()
		bitmap.create_from_image_alpha(image, alphaThreshold)
		var half = Vector2(image.get_width(), image.get_height()) / 2.0
		for polygon in bitmap.opaque_to_polygons(Rect2i(Vector2i.ZERO, image.get_size()), outlineEpsilon):
			if polygon.size() < 3:
				continue
			var shifted = PackedVector2Array()
			for point in polygon:
				shifted.append(point - half)
			result.append(shifted)
	_outlines[key] = result
	return result

# The body collides only where the sprite has colour: the rectangle fit is kept as
# the fallback for a sprite without a usable outline.
static func fitPixels(item: RigidBody2D) -> void :
	fit(item)
	var shapeNode = item.get_node_or_null("CollisionShape2D")
	var sprite = item.get_node_or_null("CollisionShape2D/Sprite2D")
	if shapeNode == null or sprite == null:
		return
	for old in item.get_children():
		if old.name.begins_with("PixelShape"):
			item.remove_child(old)
			old.queue_free()
	var polygons = outlines(sprite.texture)
	if polygons.is_empty():
		shapeNode.disabled = false
		return
	shapeNode.disabled = true
	var index = 0
	for polygon in polygons:
		var node = CollisionPolygon2D.new()
		node.name = "PixelShape%d" % index
		node.polygon = polygon
		item.add_child(node)
		index += 1

static func fit(item: RigidBody2D) -> void :
	var shapeNode = item.get_node_or_null("CollisionShape2D")
	var sprite = item.get_node_or_null("CollisionShape2D/Sprite2D")
	if shapeNode == null or sprite == null or not shapeNode.shape is RectangleShape2D:
		return
	var half = halfExtents(sprite.texture)
	if half == Vector2.ZERO:
		return
	# The scene's shape resource is shared by every instance: give this item its own.
	var shape = shapeNode.shape.duplicate()
	shape.size = Vector2(maxf(half.x * 2.0, minSide), maxf(half.y * 2.0, minSide))
	shapeNode.shape = shape
