extends Area2D

# StarHorizon's VendingMachine (Content.Shared/VendingMachines) as the Vendomat:
# pick an item in its list and, after EjectDelay with the eject animation and
# SoundVend, the item drops out below. Stock is unlimited (the uint.MaxValue
# amount the list shows without a counter), so nothing ever runs out. A request
# for an item the pack does not hold plays the deny animation and SoundDeny
# for DenyDelay. While ejecting, ordering is disabled. The machine advertises
# itself every 8-10 minutes (Vocalizer) and thanks the user once the menu is
# closed after a purchase (SpeakOnUIClosed).
const VendingCatalog = preload("res://scripts/vendingCatalog.gd")
const PaperVariants = preload("res://scripts/paperVariants.gd")

const ejectDelay = 1.2
const denyDelay = 2.0
const adCount = 7
const minAdSeconds = 8.0 * 60.0
const maxAdSeconds = 10.0 * 60.0
const vendVolumeDb = -4.0
const vendPitchVariation = 0.15
const denyVolumeDb = -2.0
const dropOffset = Vector2(0, 20)

# vendomat.rsi frame delays in seconds
const normalDelays = [2.5, 0.05, 3.4, 0.05]
const denyDelays = [0.1, 0.1, 0.1]
const ejectDelays = [0.1, 0.1, 0.8, 0.1, 0.1]

@export var vendingEditorScene: PackedScene
@export var vendSound: AudioStream
@export var denySound: AudioStream

@onready var sprite: Sprite2D = $Sprite2D
@onready var screen: Sprite2D = $Screen
@onready var itemInteractionControler: Node2D = $"../itemInteractionControler"
@onready var itemLoader: Node2D = $"../itemLoader"
@onready var itemsParent: Node2D = $"../items"
@onready var editorsLayer: Control = $"../../../editorsLayer"

enum State { NORMAL, EJECT, DENY }

var inventory: Array = []
var ejecting = false
var denying = false
var hovering = false

var _state = State.NORMAL
var _stateTime = 0.0
var _normalFrames: Array
var _denyFrames: Array
var _ejectFrames: Array
var _pendingEntry: Dictionary = {}
var _thanksPending = false
var _adTimer = 0.0
var _openEditor: Control = null

func _ready() -> void :
	mouse_entered.connect(func(): hovering = true)
	mouse_exited.connect(func(): hovering = false)

	sprite.texture = load("res://png/machines/vending/vendomat_off.png")
	_normalFrames = _sliceFrames("res://png/machines/vending/vendomat_normal.png", 3, normalDelays.size())
	_denyFrames = _sliceFrames("res://png/machines/vending/vendomat_deny.png", 2, denyDelays.size())
	_ejectFrames = _sliceFrames("res://png/machines/vending/vendomat_eject.png", 3, ejectDelays.size())
	inventory = VendingCatalog.entries()
	_setState(State.NORMAL)
	_adTimer = randf_range(minAdSeconds, maxAdSeconds)

# RSI sheets are laid out left to right, top to bottom.
func _sliceFrames(path: String, columns: int, count: int) -> Array:
	var texture = load(path)
	var frames = []
	for index in count:
		var atlas = AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = Rect2((index % columns) * 32, (index / columns) * 32, 32, 32)
		frames.append(atlas)
	return frames

func _setState(newState: int) -> void :
	_state = newState
	_stateTime = 0.0
	_showFrame()

func _showFrame() -> void :
	var frames = _normalFrames
	var delays = normalDelays
	match _state:
		State.EJECT:
			frames = _ejectFrames
			delays = ejectDelays
		State.DENY:
			frames = _denyFrames
			delays = denyDelays
	var total = 0.0
	for delay in delays:
		total += delay
	# Normal and deny loop, eject plays through once (the machine leaves the state first).
	var time = fmod(_stateTime, total)
	var index = 0
	for delay in delays:
		if time < delay:
			break
		time -= delay
		index += 1
	screen.texture = frames[mini(index, frames.size() - 1)]

func _process(delta: float) -> void :
	_stateTime += delta
	_showFrame()

	_adTimer -= delta
	if _adTimer <= 0.0:
		_adTimer = randf_range(minAdSeconds, maxAdSeconds)
		_say(tr("ui_vend_ad_%d" % (randi() % adCount + 1)))

	if ejecting and _stateTime >= ejectDelay:
		_finishEject()
	elif denying and _stateTime >= denyDelay:
		denying = false
		_setState(State.NORMAL)

func _input(event: InputEvent) -> void :
	if not hovering or not event.is_pressed() or not event.is_action("orientDocument"):
		return
	if itemInteractionControler.dragging:
		return
	_openVendingUI()

func _openVendingUI() -> void :
	if _openEditor:
		_openEditor.visible = true
		_openEditor.move_to_front()
		return

	_openEditor = vendingEditorScene.instantiate()
	editorsLayer.add_child(_openEditor)
	_openEditor.closed.connect(func():
		_openEditor.queue_free()
		_openEditor = null
		# SpeakOnUIClosed: the thanks come once the menu is closed after a purchase.
		if _thanksPending:
			_thanksPending = false
			_say(tr("ui_vend_thanks") % tr("ui_vend_title"))
	)
	_openEditor.open(self)

# SharedVendingMachineSystem.TryEjectVendorItem
func tryEject(entry: Dictionary) -> bool:
	if ejecting:
		return false
	if not inventory.has(entry):
		_popup(tr("ui_vend_invalid_item"))
		deny()
		return false

	ejecting = true
	_pendingEntry = entry
	_thanksPending = true
	_setState(State.EJECT)
	_playSound(vendSound, vendVolumeDb, 1.0 + randf_range(-vendPitchVariation, vendPitchVariation))
	return true

# SharedVendingMachineSystem.Deny
func deny() -> void :
	if denying:
		return
	denying = true
	_setState(State.DENY)
	_playSound(denySound, denyVolumeDb)

func _finishEject() -> void :
	ejecting = false
	_setState(State.NORMAL)
	_spawn(_pendingEntry)
	_pendingEntry = {}

func _spawn(entry: Dictionary) -> void :
	var at = global_position + dropOffset
	var key: String = entry.key
	var item: RigidBody2D = null
	match entry.kind:
		"paper":
			itemLoader.createPaper(key, PaperVariants.getContent(key), PaperVariants.getPresetStamps(key), "paper", at)
			return
		"pen":
			item = itemLoader.penScene.instantiate()
			item.name = _uniqueName("pen-" + key)
		"inflatable":
			item = itemLoader.inflatableScene.instantiate()
			item.name = _uniqueName("inflatable-" + key)
		"stamp":
			item = itemLoader.stampScene.instantiate()
			item.name = _uniqueName("stamp-" + key)
		_:
			item = itemLoader.getSceneFromType(key).instantiate()
			item.name = _uniqueName(item.name)
	item.position = at
	itemInteractionControler.initItem(item)
	itemsParent.add_child(item)
	match entry.kind:
		"pen", "stamp", "inflatable":
			item.setVariant(key)

func _uniqueName(baseName: String) -> String:
	var instanceName = baseName
	var number = 1
	while itemsParent.has_node(instanceName):
		number += 1
		instanceName = baseName + str(number)
	return instanceName

func _say(message: String) -> void :
	itemInteractionControler.playFeedback(global_position + Vector2(0, -16), null, message)

func _popup(message: String) -> void :
	itemInteractionControler.playFeedback(global_position, null, message, true)

func _playSound(sound: AudioStream, volumeDb: float, pitch: float = 1.0) -> void :
	if not sound:
		return
	var audioPlayer = AudioStreamPlayer2D.new()
	itemsParent.add_child(audioPlayer)
	audioPlayer.global_position = global_position
	audioPlayer.stream = sound
	audioPlayer.volume_db = volumeDb
	audioPlayer.pitch_scale = pitch
	audioPlayer.play()
	audioPlayer.finished.connect(audioPlayer.queue_free)
