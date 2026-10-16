extends Area2D

# InflatableWall / InflatableDoor: an anchored 32x32 membrane. The wall is
# deflated back into a folded piece with the "Deflate" verb (3 s); the door
# opens and closes when used (zip sound, 0.4 s until passable) and can be
# deflated the same way. The Area2D is only for the cursor; the solid part is
# the StaticBody2D, which items bump into.
const size = Vector2(32, 32)
const deflateSeconds = 3.0
const doorPassableAfter = 0.4
const frameSeconds = 0.2
const zipSound = preload("res://sfx/zip.ogg")

var kind = "wall"
var open = false

var _hovering = false
var _deflateEnd = -1
var _animFrames: Array = []
var _animTime = -1.0
var _animOpening = false
var _wallTexture = preload("res://png/structures/inflatable/wall.png")
var _doorClosed = preload("res://png/structures/inflatable/door_closed.png")
var _doorOpen = preload("res://png/structures/inflatable/door_open.png")
@onready var sprite: Sprite2D = $Sprite2D
@onready var body: StaticBody2D = $Body
@onready var itemInteractionControler: Node2D = $"../../itemInteractionControler"
@onready var itemLoader: Node2D = $"../../itemLoader"

func _ready() -> void :
	add_to_group("inflatables")
	mouse_entered.connect(func(): _hovering = true)
	mouse_exited.connect(func(): _hovering = false)
	_apply()

func setup(newKind: String, newOpen: bool = false) -> void :
	kind = newKind
	open = newOpen
	if is_node_ready():
		_apply()

func rect() -> Rect2:
	return Rect2(global_position - size / 2.0, size)

func blocksMovement() -> bool:
	return body.collision_layer != 0

func _apply() -> void :
	sprite.texture = _wallTexture if kind == "wall" else (_doorOpen if open else _doorClosed)
	body.collision_layer = 0 if open else 2

func _process(delta: float) -> void :
	if _animTime >= 0.0:
		_animTime += delta
		if _animOpening and _animTime >= doorPassableAfter and body.collision_layer != 0:
			body.collision_layer = 0
		var index = int(_animTime / frameSeconds)
		if index >= _animFrames.size():
			_animTime = -1.0
			open = _animOpening
			_apply()
			_persist()
		else:
			sprite.texture = _animFrames[index]
	if _deflateEnd >= 0:
		if not _hovering or itemInteractionControler.dragging:
			_deflateEnd = -1
		elif Time.get_ticks_msec() >= _deflateEnd:
			_deflateEnd = -1
			_deflate()

func _input(event: InputEvent) -> void :
	if not _hovering or not event.is_pressed() or event.is_echo() or not event.is_action("orientDocument"):
		return
	if itemInteractionControler.dragging:
		return
	if kind == "door":
		# A tap uses the door; holding nothing over a wall starts the deflate.
		if _animTime < 0.0:
			_toggleDoor()
	elif _deflateEnd < 0:
		_deflateEnd = Time.get_ticks_msec() + int(deflateSeconds * 1000.0)

func _toggleDoor() -> void :
	_animOpening = not open
	_animTime = 0.0
	_animFrames = _frames("res://png/structures/inflatable/door_opening.png" if _animOpening else "res://png/structures/inflatable/door_closing.png")
	if not _animOpening:
		body.collision_layer = 2
	itemInteractionControler.playSoundAt(global_position, zipSound)

# RSI sheets: 3 columns, six 32x32 frames, left to right and top to bottom.
func _frames(path: String) -> Array:
	var texture = load(path)
	var frames = []
	for index in 6:
		var atlas = AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = Rect2((index % 3) * 32, (index / 3) * 32, 32, 32)
		frames.append(atlas)
	return frames

# DisassembleOnAltVerb: one folded piece comes back, joining a nearby stack of the same kind.
func _deflate() -> void :
	itemLoader.addFoldedPiece(kind, global_position)
	itemInteractionControler.playSoundAt(global_position, zipSound)
	remove_from_group("inflatables")
	queue_free()
	_persist()

func _persist() -> void :
	get_parent().saveAll()
