extends Area2D

# Mirrors SS14's DisposalUnit: drag an item onto it and press E to insert
# (plays InsertSound), or throw/knock an item into it fast enough and it
# gets sucked in automatically on collision - then its UI offers "Flush"
# (permanently destroys the contents - a simplification of the real unit,
# which routes them through disposal pipes rather than deleting them
# outright, since this sandbox has no pipe network to route anything
# through) and "Eject" (gives all held items back unharmed).

const collideInsertSpeed = 80.0

@export var recyclerEditorScene: PackedScene
@export var insertSound: AudioStream
@export var flushSound: AudioStream

@onready var anchorable: Node = $Anchorable
@onready var sprite: Sprite2D = $Sprite2D
@onready var readyOverlay: Sprite2D = $ReadyOverlay
@onready var itemInteractionControler: Node2D = $"../itemInteractionControler"
@onready var itemsParent: Node2D = $"../items"
@onready var editorsLayer: Control = $"../../../editorsLayer"

var insertedItems: Array = []
var busy = false
var hovering = false
var _openEditor: Control = null
var _insertedCollisionLayers: Dictionary = {}

var _idleTexture: Texture2D
var _flushFrames: Array = []
var _flushFrame = 0
var _flushPlaying = false
var _flushDone: Callable
var _animTimer = 0.0
const _frameDelay = 0.1

func _ready() -> void :
	mouse_entered.connect(func(): hovering = true)
	mouse_exited.connect(func(): hovering = false)
	body_entered.connect(_on_body_entered)

	_idleTexture = load("res://png/machines/recycler/recycler_idle.png")
	_flushFrames = _sliceFrames("res://png/machines/recycler/recycler_flush.png", 3, 3)

	sprite.texture = _idleTexture
	readyOverlay.texture = load("res://png/machines/recycler/recycler_ready.png")

func _sliceFrames(path: String, columns: int, rows: int) -> Array:
	var texture = load(path)
	var frameSize = Vector2(texture.get_width() / columns, texture.get_height() / rows)
	var frames = []
	for row in rows:
		for col in columns:
			var atlas = AtlasTexture.new()
			atlas.atlas = texture
			atlas.region = Rect2(col * frameSize.x, row * frameSize.y, frameSize.x, frameSize.y)
			frames.append(atlas)
	return frames

func _process(delta: float) -> void :
	readyOverlay.visible = not busy and anchorable.isPowered()
	if _openEditor and not anchorable.isPowered():
		_openEditor.closed.emit()

	if not _flushPlaying:
		return

	_animTimer += delta
	if _animTimer < _frameDelay:
		return
	_animTimer -= _frameDelay

	_flushFrame += 1
	if _flushFrame >= _flushFrames.size():
		_flushPlaying = false
		sprite.texture = _idleTexture
		var callback = _flushDone
		_flushDone = Callable()
		if callback.is_valid():
			callback.call()
	else:
		sprite.texture = _flushFrames[_flushFrame]

func _input(event: InputEvent) -> void :
	if not hovering or not event.is_pressed() or not event.is_action("orientDocument") or not anchorable.isPowered():
		return

	if itemInteractionControler.isHoldingWrench():
		return
	var heldItem = itemInteractionControler.heldItem
	if itemInteractionControler.dragging and heldItem:
		_tryInsert(heldItem)
	else:
		_openRecyclerUI()

# Mirrors SS14's DisposalUnit accepting thrown/flung items on physical
# contact, not just deliberate drag+insert - an item knocked into the unit
# hard enough gets sucked in automatically.
func _on_body_entered(body: Node) -> void :
	if not body is RigidBody2D or not anchorable.isPowered():
		return
	# Don't vacuum up whatever the player is currently dragging past the
	# unit - only items thrown/knocked in on their own (physics-driven
	# velocity, no active PinJoint2D drag) count as a "collision insert".
	if itemInteractionControler.dragging and itemInteractionControler.heldItem == body:
		return
	if body.linear_velocity.length() < collideInsertSpeed:
		return
	_tryInsert(body)

func _tryInsert(item: RigidBody2D) -> void :
	if busy or insertedItems.has(item):
		return
	if itemInteractionControler.dragging and itemInteractionControler.heldItem == item:
		itemInteractionControler.endDrag(item)
	itemInteractionControler.forgetItem(item)
	# Stays a child of itemsParent (just hidden/uncollidable) rather than
	# removed from the tree, so it's still picked up by saveItems() if the
	# game closes while items are sitting inside the recycler.
	_insertedCollisionLayers[item] = item.collision_layer
	item.visible = false
	item.input_pickable = false
	item.collision_layer = 0
	# freeze alone doesn't clear the body's existing velocity - without this,
	# an item flung in fast enough to trigger the collision-insert keeps that
	# same velocity in storage, so un-freezing it on eject makes it instantly
	# resume flying off in whatever direction it was originally thrown.
	item.linear_velocity = Vector2.ZERO
	item.angular_velocity = 0.0
	item.freeze = true
	insertedItems.append(item)

	_playSound(insertSound)
	_openRecyclerUI()

func _openRecyclerUI() -> void :
	if _openEditor:
		_openEditor.visible = true
		_openEditor.move_to_front()
		return

	_openEditor = recyclerEditorScene.instantiate()
	editorsLayer.add_child(_openEditor)
	_openEditor.closed.connect(func():
		_openEditor.queue_free()
		_openEditor = null
	)
	_openEditor.open(self)

func flushInsertedItems() -> void :
	if insertedItems.is_empty() or busy:
		return

	busy = true
	var items = insertedItems.duplicate()
	insertedItems.clear()
	_insertedCollisionLayers.clear()

	_playSound(flushSound)
	_flushFrame = 0
	_flushPlaying = true
	sprite.texture = _flushFrames[0]
	_flushDone = func():
		busy = false
		for item in items:
			if is_instance_valid(item):
				item.queue_free()

func ejectInsertedItems() -> void :
	if insertedItems.is_empty() or busy:
		return
	var count = 0
	for item in insertedItems:
		item.visible = true
		item.input_pickable = true
		item.collision_layer = _insertedCollisionLayers.get(item, 2)
		item.freeze = false
		item.global_position = global_position + Vector2(0, 16) + Vector2(count * 6, 0)
		count += 1
	insertedItems.clear()
	_insertedCollisionLayers.clear()

func _playSound(sound: AudioStream) -> void :
	if not sound:
		return
	var audioPlayer = AudioStreamPlayer2D.new()
	itemsParent.add_child(audioPlayer)
	audioPlayer.global_position = global_position
	audioPlayer.stream = sound
	audioPlayer.play()
	audioPlayer.finished.connect(audioPlayer.queue_free)
