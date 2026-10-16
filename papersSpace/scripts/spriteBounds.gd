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
