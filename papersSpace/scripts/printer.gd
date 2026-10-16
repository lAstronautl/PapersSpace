extends Area2D

signal opened(printerNode)

const PaperVariants = preload("res://scripts/paperVariants.gd")

const maxToner = 30
const tonerPerPage = 1

@export var printerEditorScene: PackedScene
@export var scanSound: AudioStream
@export var printSound: AudioStream

@onready var sprite: Sprite2D = $Sprite2D
@onready var lightOverlay: Sprite2D = $LightOverlay
@onready var insertOverlay: Sprite2D = $InsertOverlay
@onready var itemInteractionControler: Node2D = $"../itemInteractionControler"
@onready var anchorable: Node = $Anchorable
@onready var itemLoader: Node2D = $"../itemLoader"
@onready var itemsParent: Node2D = $"../items"
@onready var editorsLayer: Control = $"../../../editorsLayer"

var toner: int = maxToner
var busy = false
var insertedPaper: RigidBody2D = null
var hovering = false
var _openEditor: Control = null

# Three sprites layer independently instead of one state replacing another:
# - sprite: the body. "icon" (idle/ready) or the "building" animation
#   (printing/copying in progress) - these two are mutually exclusive body
#   poses.
# - lightOverlay: a tiny blinking ready-light ("idle" state) that overlays
#   the body at all times except while actively building.
# - insertOverlay: a small paper-feed icon ("inserting" state) shown only
#   while a sheet is being fed in, on top of icon+light.
var _idleFrames: Array = []
var _insertingFrames: Array = []
var _buildingFrames: Array = []
var _iconTexture: Texture2D
var _animTimer = 0.0
const _frameDelay = 0.1

var _lightFrame = 0
var _insertFrame = 0
var _insertPlaying = false
var _insertDone: Callable
var _buildFrame = 0
var _buildPlaying = false
var _buildDone: Callable

func _ready() -> void :
	mouse_entered.connect(func(): hovering = true)
	mouse_exited.connect(func(): hovering = false)

	_iconTexture = load("res://png/machines/printer/printer_icon.png")
	_idleFrames = _sliceFrames("res://png/machines/printer/printer_idle.png", 2, 1)
	_insertingFrames = _sliceFrames("res://png/machines/printer/printer_inserting.png", 3, 3)
	_buildingFrames = _sliceFrames("res://png/machines/printer/printer_building.png", 10, 2)

	sprite.texture = _iconTexture
	lightOverlay.texture = _idleFrames[0]
	insertOverlay.visible = false

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

func _playInsertAnim(onDone: Callable) -> void :
	_insertFrame = 0
	_insertPlaying = true
	insertOverlay.visible = true
	insertOverlay.texture = _insertingFrames[0]
	_insertDone = onDone

func _playBuildAnim(onDone: Callable) -> void :
	_buildFrame = 0
	_buildPlaying = true
	sprite.texture = _buildingFrames[0]
	_buildDone = onDone

func _process(delta: float) -> void :
	lightOverlay.visible = anchorable.isPowered()
	if _openEditor and not anchorable.isPowered():
		_openEditor.closed.emit()
	_animTimer += delta
	if _animTimer < _frameDelay:
		return
	_animTimer -= _frameDelay

	# The ready-light keeps blinking at all times except mid-print, when the
	# body sprite itself is showing the building animation instead.
	if not _buildPlaying:
		_lightFrame = (_lightFrame + 1) % _idleFrames.size()
		lightOverlay.texture = _idleFrames[_lightFrame]

	if _insertPlaying:
		_insertFrame += 1
		if _insertFrame >= _insertingFrames.size():
			_insertPlaying = false
			insertOverlay.visible = false
			var callback = _insertDone
			_insertDone = Callable()
			if callback.is_valid():
				callback.call()
		else:
			insertOverlay.texture = _insertingFrames[_insertFrame]

	if _buildPlaying:
		_buildFrame += 1
		if _buildFrame >= _buildingFrames.size():
			_buildPlaying = false
			sprite.texture = _iconTexture
			var callback = _buildDone
			_buildDone = Callable()
			if callback.is_valid():
				callback.call()
		else:
			sprite.texture = _buildingFrames[_buildFrame]

func hasToner() -> bool:
	return toner >= tonerPerPage

func refillToner() -> void :
	toner = maxToner

func _input(event: InputEvent) -> void :
	if not hovering or not event.is_pressed() or not event.is_action("orientDocument") or not anchorable.isPowered():
		return

	if itemInteractionControler.isHoldingWrench():
		return
	var heldItem = itemInteractionControler.heldItem
	var isHoldingPaper = itemInteractionControler.dragging and heldItem and heldItem.get_meta("type", "") == "txt"

	if isHoldingPaper:
		_tryInsert(heldItem)
	else:
		_openPrinterUI()

func _tryInsert(paper: RigidBody2D) -> void :
	if busy or insertedPaper:
		return
	itemInteractionControler.endDrag(paper)
	itemInteractionControler.forgetItem(paper)
	# Stays a child of itemsParent (just hidden/uncollidable) rather than
	# being removed from the tree, so it's still picked up by saveItems() if
	# the game is closed while a paper is sitting inside the printer.
	paper.visible = false
	paper.input_pickable = false
	paper.collision_layer = 0
	paper.freeze = true
	insertedPaper = paper
	_openPrinterUI()

func _openPrinterUI() -> void :
	if _openEditor:
		_openEditor.visible = true
		_openEditor.move_to_front()
		return

	_openEditor = printerEditorScene.instantiate()
	editorsLayer.add_child(_openEditor)
	_openEditor.closed.connect(func():
		_openEditor.queue_free()
		_openEditor = null
	)
	_openEditor.open(self)

# Mirrors SS14's PhotocopierSystem copy mode: scans the inserted paper
# (Content + StampedBy list, i.e. stamps included) and queues a duplicate.
func startCopy() -> void :
	if busy or not insertedPaper or not hasToner():
		return

	busy = true
	var sourceContent: String = insertedPaper.get_meta("content", "")
	var sourceStamps: Array = insertedPaper.get_meta("stamps", []).duplicate(true)
	var sourceVariant: String = insertedPaper.get_meta("paperVariant", "default")
	var sourceName: String = insertedPaper.name

	_playSound(scanSound)
	_playInsertAnim(func():
		_playSound(printSound)
		_playBuildAnim(func():
			toner -= tonerPerPage
			busy = false
			_spawnPaper(sourceVariant, sourceContent, sourceStamps, sourceName)
		)
	)

# Mirrors SS14's PhotocopierSystem print mode: prints a blank sheet of the
# chosen paper variant, no source paper required. Variants with generated
# content (CNC sheet, nuke code, traitor codewords) get it filled in fresh.
func startPrint(paperVariant: String) -> void :
	if busy or not hasToner():
		return

	busy = true
	_playSound(printSound)
	_playBuildAnim(func():
		toner -= tonerPerPage
		busy = false
		_spawnPaper(paperVariant, PaperVariants.getContent(paperVariant), PaperVariants.getPresetStamps(paperVariant))
	)

func ejectInsertedPaper() -> void :
	if not insertedPaper or busy:
		return
	insertedPaper.visible = true
	insertedPaper.input_pickable = true
	insertedPaper.collision_layer = 2
	insertedPaper.freeze = false
	insertedPaper.global_position = global_position + Vector2(0, 16)
	insertedPaper = null

func _spawnPaper(paperVariant: String, content: String, stamps: Array, baseName: String = "paper") -> void :
	itemLoader.createPaper(paperVariant, content, stamps, baseName, global_position + Vector2(0, 16))

func _playSound(sound: AudioStream) -> void :
	if not sound:
		return
	var audioPlayer = AudioStreamPlayer2D.new()
	itemsParent.add_child(audioPlayer)
	audioPlayer.global_position = global_position
	audioPlayer.stream = sound
	audioPlayer.play()
	audioPlayer.finished.connect(audioPlayer.queue_free)
