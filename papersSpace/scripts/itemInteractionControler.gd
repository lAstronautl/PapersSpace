extends Node2D

const StampInfo = preload("res://scripts/stampInfo.gd")
const PenInfo = preload("res://scripts/penInfo.gd")
const SignerName = preload("res://scripts/signerName.gd")
const penClickSound = preload("res://sfx/pen_click.ogg")
const DoAfterBar = preload("res://scripts/doAfterBar.gd")
const SpriteBounds = preload("res://scripts/spriteBounds.gd")
const ratchetSound = preload("res://sfx/ratchet.ogg")
const PaperSounds = preload("res://scripts/paperSounds.gd")
const PaperVariants = preload("res://scripts/paperVariants.gd")

@export var paperEditorScene: PackedScene
@export var labelerEditorScene: PackedScene
@export var floatingNoticeScene: PackedScene
@export var tonerInsertSound: AudioStream

@onready var mousePin: PinJoint2D = $"../mousePin"
@onready var structuresNode: Node2D = $"../structures"
@onready var fakeBody: StaticBody2D = $"../mousePin/fakeBody"
@onready var itemsParent: Node2D = $"../items"
@onready var label: Label = $"../../../hoverLabel"
@onready var labelBGRect: ColorRect = $"../../../hoverLabel/ColorRect"
@onready var editorsLayer: Control = $"../../../editorsLayer"
@onready var worldCamera: Camera2D = $"../worldCamera"
@onready var worldViewContainer: SubViewportContainer = $"../.."
@onready var printer: Area2D = $"../printer"

const angularDampOnDrag = 8
const heldTorque = 4000.0

# Items flung out past the room walls drift in open space instead of using
# the room's normal (fairly strong) friction-like damping - otherwise a hard
# throw out an airlock would just abruptly stop a few tiles out. Damping is
# still nonzero (not true zero-g) so a wayward item eventually coasts to a
# stop instead of drifting forever and needing physics upkeep indefinitely.
const roomBounds = Rect2(0, 0, 192, 192)
const spaceLinearDamp = 0.05
const spaceAngularDamp = 0.05
var _roomLinearDamp: float
var _roomAngularDamp: float

var dragging = false
var hovering = false
var heldItem
var hoveredItem
var allHovered = []
var openEditors = {}

func startDrag(item: RigidBody2D) -> void :
	mousePin.node_b = mousePin.get_path_to(item)
	item.angular_damp = angularDampOnDrag
	heldItem = item
	dragging = true

func endDrag(item: RigidBody2D) -> void :
	mousePin.node_b = NodePath()
	item.angular_damp = ProjectSettings.get_setting("physics/2d/default_angular_damp")
	getItemSprite(item).position = Vector2(0, 0)
	var overlay = getItemStampOverlay(item)
	if overlay:
		overlay.position = Vector2(0, 0)
	dragging = false
	# heldItem previously stayed pointing at the last-dragged item forever
	# (only ever reassigned by the next startDrag) - _updateSpaceDamping()
	# skips whatever heldItem currently is, so a thrown item kept the room's
	# damping the whole flight and only ever got the near-zero space damping
	# once some later drag moved heldItem off of it (i.e. essentially never,
	# in practice not until it had already coasted to a stop under the much
	# stronger room damping).
	heldItem = null

# remove_child() (used e.g. when a printer takes a paper out of play) doesn't
# emit mouse_exited/tree_exiting, so hover state can otherwise keep pointing
# at an item that's no longer even in the scene tree - making every
# subsequent click anywhere re-trigger an action on that ghost reference.
func forgetItem(item) -> void :
	if allHovered.has(item):
		allHovered.erase(item)
	if hoveredItem == item:
		label.visible = false
		hoveredItem = null
		hovering = false
		if not allHovered.is_empty():
			_hover(allHovered[0])
	if openEditors.has(item):
		openEditors[item].queue_free()
		openEditors.erase(item)

func getItemSprite(item: RigidBody2D) -> Sprite2D:
	return item.get_node("CollisionShape2D").get_node("Sprite2D")


func _ready() -> void :
	mousePin.node_a = mousePin.get_path_to(fakeBody)

	_roomLinearDamp = ProjectSettings.get_setting("physics/2d/default_linear_damp")
	_roomAngularDamp = ProjectSettings.get_setting("physics/2d/default_angular_damp")

	call_deferred("_init_all")

	label.visible = false

func _init_all():
	for child in itemsParent.get_children():
		initItem(child)

func initItem(item: RigidBody2D):
	if item.get_meta("type", "") != "txt":
		SpriteBounds.fitPixels(item)
	item.mouse_entered.connect(_on_mouse_entered.bind(item))
	item.mouse_exited.connect(_on_mouse_exited.bind(item))
	item.tree_exiting.connect(_on_item_removed.bind(item))

func _on_item_removed(item: RigidBody2D) -> void :
	if openEditors.has(item):
		openEditors[item].queue_free()
		openEditors.erase(item)

func openEditorFor(item: RigidBody2D) -> void :
	if openEditors.has(item):
		var editor = openEditors[item]
		editor.visible = true
		editor.move_to_front()
		return

	var editor = paperEditorScene.instantiate()
	editorsLayer.add_child(editor)
	editor.closed.connect(_on_editor_closed.bind(item))
	editor.open(item)
	openEditors[item] = editor

func _on_editor_closed(item: RigidBody2D) -> void :
	if openEditors.has(item):
		openEditors[item].queue_free()
		openEditors.erase(item)

func openLabelerEditorFor(item: RigidBody2D) -> void :
	if openEditors.has(item):
		var editor = openEditors[item]
		editor.visible = true
		return

	var editor = labelerEditorScene.instantiate()
	editorsLayer.add_child(editor)
	editor.closed.connect(_on_editor_closed.bind(item))
	editor.open(item)
	openEditors[item] = editor

const labelerApplyRadius = 18.0
const stampApplyRadius = 16.0
const penApplyRadius = 16.0
const tonerApplyRadius = 20.0

func applyLabelerToOverlaps(labelerItem: RigidBody2D) -> void :
	for body in itemsParent.get_children():
		if body == labelerItem:
			continue
		if body.get_meta("type", "") != "txt":
			continue
		if body.global_position.distance_to(labelerItem.global_position) <= labelerApplyRadius:
			# Mirrors SS14's HandLabelerSystem: the label is appended as a
			# name modifier (not a name replacement) and no sound is played -
			# only a client-side "applied" popup.
			if labelerItem.applyLabelTo(body):
				playFeedback(labelerItem.global_position, null, tr("ui_label_applied"))

# --- stamps, pens (PaperSystem.OnInteractUsing) ---------------------------------------

# UseDelay: a stamp or pen cannot stamp/sign again for a second (the "stamp" delay),
# and a pen cannot click again for 1.5 s.
var _delayedUntil: Dictionary = {}

func _isDelayed(item: RigidBody2D, delayId: String) -> bool:
	return Time.get_ticks_msec() < _delayedUntil.get([item.get_instance_id(), delayId], 0)

func _setDelay(item: RigidBody2D, delayId: String, seconds: float) -> void :
	_delayedUntil[[item.get_instance_id(), delayId]] = Time.get_ticks_msec() + int(seconds * 1000.0)

# The name an item shows when hovered, in the current language.
func getItemDisplayName(item: Node) -> String:
	match item.get_meta("type", ""):
		"wrench":
			return tr("ui_vend_item_wrench")
		"inflatable":
			var count = item.get_meta("count", 1)
			var itemName = tr("ui_vend_item_inflatable_" + item.get_meta("kind", "wall"))
			return itemName if count <= 1 else "%s x%d" % [itemName, count]
		"pen":
			return tr(PenInfo.getName(item.get_meta("penState", "pen")))
		"stamp":
			var key = "stamp_item_" + StampInfo.resolveKey(item.get_meta("stampState", "cap")).replace("-", "_")
			var translated = tr(key)
			return item.name if translated == key else translated
	return item.name

func playSoundAt(atPosition: Vector2, sound: AudioStream, volumeDb: float = 0.0) -> void :
	if not sound:
		return
	var audioPlayer = AudioStreamPlayer2D.new()
	itemsParent.add_child(audioPlayer)
	audioPlayer.global_position = atPosition
	audioPlayer.stream = sound
	audioPlayer.volume_db = volumeDb
	audioPlayer.play()
	audioPlayer.finished.connect(audioPlayer.queue_free)

# PaperSystem.CanStamp: at most stampLimit stamps; a stamp can't be applied twice,
# unless it is a reapply stamp (APPROVED/DENIED), which may be applied up to
# reapplyLimit times.
func _canStamp(stamps: Array, stampState: String) -> bool:
	if stamps.size() >= StampInfo.stampLimit:
		return false
	var sameCount = stamps.filter(func(entry): return StampInfo.resolveKey(entry.get("stampState", "")) == stampState).size()
	if StampInfo.canReapply(stampState):
		return sameCount < StampInfo.reapplyLimit
	return sameCount == 0

func _addStampToPaper(paper: RigidBody2D, entry: Dictionary) -> void :
	var overlay = paper.get_node("CollisionShape2D/StampOverlay")
	overlay.addStamp(entry.stampState, 0.0, Vector2.ZERO, entry)
	paper.set_meta("stamps", overlay.serializeStamps())
	# Mode is not changed by stamping: whoever has the paper open may still write.
	if openEditors.has(paper):
		openEditors[paper].refreshStamps()

func applyStampToOverlaps(stampItem: RigidBody2D) -> void :
	for body in itemsParent.get_children():
		if body == stampItem:
			continue
		if body.get_meta("type", "") != "txt":
			continue
		if body.global_position.distance_to(stampItem.global_position) <= stampApplyRadius:
			if _isDelayed(stampItem, "stamp"):
				return
			var stamps: Array = body.get_meta("stamps", [])
			# PaperSystem.TryStamp reports success even when CanStamp refused to add
			# the stamp, so the sound, message and delay always follow.
			if _canStamp(stamps, stampItem.stampState):
				_addStampToPaper(body, {"stampState": stampItem.stampState})
			playSoundAt(stampItem.global_position, StampInfo.getStampSound(stampItem.stampState), -2.0)
			playFeedback(stampItem.global_position, null, tr("ui_stamp_applied") % [body.name, getItemDisplayName(stampItem)])
			_setDelay(stampItem, "stamp", PenInfo.stampDelaySeconds)

# Pen signature: a stamp of Type Signature, named after the signer, in the pen's colour.
func trySign(paper: RigidBody2D, penItem: RigidBody2D) -> bool:
	if _isDelayed(penItem, "stamp"):
		return false
	var signer = SignerName.get_signer_name()
	var color = PenInfo.getSignatureColor(penItem.penState).to_html(true)
	var stamps: Array = paper.get_meta("stamps", [])
	var duplicate = stamps.any(func(entry): return entry.get("signer", null) == signer and entry.get("color", "") == color)
	if stamps.size() < StampInfo.stampLimit and not duplicate:
		_addStampToPaper(paper, {"stampState": "signature", "signer": signer, "color": color})
	PaperSounds.play(itemsParent, paper.global_position)
	playFeedback(penItem.global_position, null, tr("ui_signed") % paper.name)
	_setDelay(penItem, "stamp", PenInfo.stampDelaySeconds)
	return true

# PaperSystem.OnInteractUsing for a pen. Returns how many papers it acted on.
func applyPenToOverlaps(penItem: RigidBody2D, signOnly: bool = false) -> int:
	var handled = 0
	for body in itemsParent.get_children():
		if body == penItem:
			continue
		if body.get_meta("type", "") != "txt":
			continue
		if body.global_position.distance_to(penItem.global_position) > penApplyRadius:
			continue
		handled += 1

		# The "Sign" verb signs any paper.
		if signOnly:
			trySign(body, penItem)
			continue

		# Only unstamped paper is writable, unless the pen ignores stamps: all of them
		# (WriteIgnoreStamps) or the unprotected ones (NFWriteIgnoreUnprotectedStamps).
		var stamps: Array = body.get_meta("stamps", [])
		var hasProtectedStamp = stamps.any(func(entry): return StampInfo.isProtected(entry.get("stampState", "")))
		var editable = stamps.is_empty() or penItem.canIgnoreProtectedStamps or (penItem.canIgnoreStamps and not hasProtectedStamp)
		if not editable:
			# A pen that cannot write over the stamps signs the paper instead.
			trySign(body, penItem)
			continue

		# EditingDisabled (e.g. printed acquisition slips) is only checked once writing
		# is allowed, and then no pen can bypass it.
		if PaperVariants.isEditingDisabled(body.get_meta("paperVariant", "default")):
			playFeedback(penItem.global_position, null, tr("ui_paper_tamper_proof"), true)
			continue

		# Using a pen on paper opens its UI directly in write mode.
		openEditorFor(body)
		body.set_meta("writingUnlocked", true)
		openEditors[body].refreshWritingLock()
	return handled

# EmitSoundOnUse + UseDelay 1.5: using a pen in the hand clicks it.
func clickPen(penItem: RigidBody2D) -> void :
	if _isDelayed(penItem, "click"):
		return
	playSoundAt(penItem.global_position, penClickSound, -4.0)
	_setDelay(penItem, "click", PenInfo.clickDelaySeconds)

# Mirrors SS14's TonerCartridgeSystem "Refill toner" verb, but single-use:
# using a toner cartridge on the printer dumps its entire charge in at once
# and the cartridge is spent/removed - but only if the printer actually had
# room for it; a cartridge used on an already-full printer is refused
# outright and stays intact so it isn't wasted for nothing.
func applyTonerCartridgeToPrinter(cartridge: RigidBody2D) -> void :
	if cartridge.global_position.distance_to(printer.global_position) > tonerApplyRadius:
		return

	if printer.toner >= printer.maxToner:
		playFeedback(cartridge.global_position, null, tr("ui_printer_full"), true)
		return

	cartridge.refillInto(printer)
	playFeedback(cartridge.global_position, tonerInsertSound, tr("ui_printer_refilled"))
	_consumeCartridge(cartridge)

func _consumeCartridge(cartridge: RigidBody2D) -> void :
	if dragging and heldItem == cartridge:
		endDrag(cartridge)
	forgetItem(cartridge)
	cartridge.queue_free()

var _activeNotices = {}

func worldScale() -> Vector2:
	return worldViewContainer.size / Vector2(worldViewContainer.get_node("worldViewport").size)

# A do-after bar above `target` (see doAfterBar.gd); the caller cancels or finishes it.
func startDoAfter(target: Node2D, seconds: float, halfHeight: float):
	var bar = DoAfterBar.new()
	editorsLayer.add_child(bar)
	bar.begin(target, self, seconds, halfHeight)
	return bar

func worldToScreen(worldPos: Vector2) -> Vector2:
	return _worldToScreen(worldPos)

func _worldToScreen(worldPos: Vector2) -> Vector2:
	# floatingNotice text must render in the crisp UI layer (outside the
	# pixel-art worldViewport) to avoid being upscaled/blurred, so world
	# coordinates need to be projected into the container's screen rect.
	var viewportLocal = worldCamera.get_viewport_transform() * worldPos
	var containerScale = worldViewContainer.size / Vector2(worldViewContainer.get_node("worldViewport").size)
	return worldViewContainer.global_position + viewportLocal * containerScale

func playFeedback(atPosition: Vector2, sound: AudioStream, message: String, caution: bool = false) -> void :
	if sound:
		var audioPlayer = AudioStreamPlayer2D.new()
		itemsParent.add_child(audioPlayer)
		audioPlayer.global_position = atPosition
		audioPlayer.stream = sound
		audioPlayer.play()
		audioPlayer.finished.connect(audioPlayer.queue_free)

	if not floatingNoticeScene:
		return

	var screenPosition = _worldToScreen(atPosition) + Vector2(0, -10)

	# Mirrors SS14's popup-stacking: an identical message repeated at the same
	# spot merges into "message x{count}" and resets its lifetime, instead of
	# spawning overlapping labels.
	var noticeKey = str(atPosition) + "|" + message
	if _activeNotices.has(noticeKey) and is_instance_valid(_activeNotices[noticeKey]):
		var existing = _activeNotices[noticeKey]
		existing.repeat_count += 1
		existing.show_at(screenPosition, "%s x%d" % [message, existing.repeat_count], caution)
		return

	var notice = floatingNoticeScene.instantiate()
	editorsLayer.add_child(notice)
	notice.repeat_count = 1
	notice.show_at(screenPosition, message, caution)
	notice.tree_exiting.connect(func(): _activeNotices.erase(noticeKey))
	_activeNotices[noticeKey] = notice

func _process(_delta: float) -> void :
	if label.visible:
		label.position = label.get_viewport().get_mouse_position() + Vector2(6, -3)
	_updateWrenchAction()
	_updatePlaceAction()

# Using the wrench in hand ("Anchoring" tool quality): the structure under it is
# unbolted or bolted after AnchorableComponent's 1 s delay, with the ratchet
# sound at the start. The do-after is cancelled when the wrench is let go or
# leaves the structure.
var _wrenchAction: Dictionary = {}
const itemBarOffset = 9.0

func isHoldingWrench() -> bool:
	return dragging and heldItem != null and heldItem.get_meta("type", "") == "wrench"

# The structure the wrench works on: the one under the cursor, or else the one
# under the tool itself.
func _anchorableUnder(wrench: RigidBody2D):
	for anchorable in get_tree().get_nodes_in_group("anchorables"):
		if anchorable.rect().has_point(mousePin.global_position) or anchorable.rect().has_point(wrench.global_position):
			return anchorable
	return null

func useWrench(wrench: RigidBody2D) -> void :
	if not _wrenchAction.is_empty():
		return
	var anchorable = _anchorableUnder(wrench)
	if anchorable == null:
		return
	playSoundAt(wrench.global_position, ratchetSound)
	_wrenchAction = {"wrench": wrench, "anchorable": anchorable, "end": Time.get_ticks_msec() + int(anchorable.delaySeconds * 1000.0),
		"bar": startDoAfter(wrench, anchorable.delaySeconds, itemBarOffset)}

func _updateWrenchAction() -> void :
	if _wrenchAction.is_empty():
		return
	var wrench = _wrenchAction.wrench
	var anchorable = _wrenchAction.anchorable
	if not is_instance_valid(wrench) or not isHoldingWrench() or heldItem != wrench \
			or _anchorableUnder(wrench) != anchorable:
		_wrenchAction.bar.cancel()
		_wrenchAction = {}
		return
	if Time.get_ticks_msec() < _wrenchAction.end:
		return
	_wrenchAction.bar.finish()
	_wrenchAction = {}
	anchorable.toggle()
	playFeedback(anchorable.structure.global_position, null, tr("ui_anchored") if anchorable.anchored else tr("ui_unanchored"))

# SpawnAfterInteract (InflatableWallStack / InflatableDoorStack): using the stack
# unfolds one piece on the tile under the cursor after 1 s; the stack is used up
# with its last piece. Cancelled when the stack is let go or the cursor moves
# to another tile.
const tileSize = 32.0
const placeSeconds = 1.0
var _placeAction: Dictionary = {}

func _cellAt(point: Vector2) -> Vector2:
	return (point / tileSize).floor() * tileSize + Vector2(tileSize, tileSize) / 2.0

func _cellFree(cell: Vector2) -> bool:
	var footprint = Rect2(cell - Vector2(tileSize, tileSize) / 2.0, Vector2(tileSize, tileSize))
	for anchorable in get_tree().get_nodes_in_group("anchorables"):
		if footprint.intersects(anchorable.rect()):
			return false
	for inflatable in get_tree().get_nodes_in_group("inflatables"):
		if footprint.intersects(inflatable.rect()):
			return false
	return true

# StackSystem: using a stack on another stack of the same kind lying under it pours
# the held one into it (the folded pieces left by deflated walls join up this way).
const stackMergeRadius = 14.0

func _mergeStacks(held: RigidBody2D) -> bool:
	for other in itemsParent.get_children():
		if other == held or other.get_meta("type", "") != "inflatable" or other.get_meta("kind", "") != held.get_meta("kind", "wall"):
			continue
		if other.global_position.distance_to(held.global_position) > stackMergeRadius:
			continue
		other.set_meta("count", other.get_meta("count", 1) + held.get_meta("count", 1))
		endDrag(held)
		forgetItem(held)
		held.queue_free()
		return true
	return false

func useInflatable(stack: RigidBody2D) -> void :
	if not _placeAction.is_empty():
		return
	if _mergeStacks(stack):
		return
	var cell = _cellAt(mousePin.global_position)
	if not roomBounds.has_point(cell) or not _cellFree(cell):
		playFeedback(stack.global_position, null, tr("ui_tile_occupied"), true)
		return
	_placeAction = {"stack": stack, "cell": cell, "end": Time.get_ticks_msec() + int(placeSeconds * 1000.0),
		"bar": startDoAfter(stack, placeSeconds, itemBarOffset)}

func _updatePlaceAction() -> void :
	if _placeAction.is_empty():
		return
	var stack = _placeAction.stack
	if not is_instance_valid(stack) or not dragging or heldItem != stack \
			or _cellAt(mousePin.global_position) != _placeAction.cell:
		_placeAction.bar.cancel()
		_placeAction = {}
		return
	if Time.get_ticks_msec() < _placeAction.end:
		return
	var cell = _placeAction.cell
	_placeAction.bar.finish()
	_placeAction = {}
	if not _cellFree(cell):
		playFeedback(stack.global_position, null, tr("ui_tile_occupied"), true)
		return
	structuresNode.place("wall" if stack.get_meta("kind", "wall") == "wall" else "door", cell)
	var left = stack.get_meta("count", 1) - 1
	if left <= 0:
		endDrag(stack)
		forgetItem(stack)
		stack.queue_free()
	else:
		stack.set_meta("count", left)

# Whether a left click would grab an unanchored structure.
func structureGrabbable() -> bool:
	for anchorable in get_tree().get_nodes_in_group("anchorables"):
		if anchorable.canGrab():
			return true
	return false

func getItemStampOverlay(item: RigidBody2D) -> Node2D:
	var collisionShape = item.get_node("CollisionShape2D")
	if collisionShape.has_node("StampOverlay"):
		return collisionShape.get_node("StampOverlay")
	return null

func _physics_process(delta: float) -> void :
	if dragging:
		var liftOffset = Vector2(0, -2)
		getItemSprite(heldItem).position = liftOffset
		getItemSprite(heldItem).use_parent_material = true

		var overlay = getItemStampOverlay(heldItem)
		if overlay:
			overlay.position = liftOffset

		if Input.is_action_pressed("rotateLeft"):
			heldItem.apply_torque(-heldTorque)
		if Input.is_action_pressed("rotateRight"):
			heldItem.apply_torque(heldTorque)

		if Input.is_action_just_pressed("orientDocument"):
			var heldType = heldItem.get_meta("type", "")
			if heldType == "labeler":
				applyLabelerToOverlaps(heldItem)
			elif heldType == "stamp":
				applyStampToOverlaps(heldItem)
			elif heldType == "pen":
				# Over a paper: write on it (or sign it); otherwise just click the pen.
				if applyPenToOverlaps(heldItem) == 0:
					clickPen(heldItem)
			elif heldType == "tonerCartridge":
				applyTonerCartridgeToPrinter(heldItem)
			elif heldType == "wrench":
				useWrench(heldItem)
			elif heldType == "inflatable":
				useInflatable(heldItem)

		# The pen's "Sign" verb.
		if Input.is_action_just_pressed("signDocument") and heldItem.get_meta("type", "") == "pen":
			applyPenToOverlaps(heldItem, true)

		if Input.is_action_just_pressed("snapRotation"):
			_snapRotationTo45(heldItem)

	_updateSpaceDamping()

# Items past the room walls get near-zero damping (long, slow coast to a
# stop) instead of the room's normal damping (quick stop) - mirrors the
# "no friction in open space" intuition without making items drift forever.
# Held/dragged item is skipped: its damping is already being managed by
# startDrag/endDrag for the drag-specific angular damp override.
func _updateSpaceDamping() -> void :
	for item in itemsParent.get_children():
		if not item is RigidBody2D or item == heldItem:
			continue
		var inRoom = roomBounds.has_point(item.global_position)
		# RigidBody2D's default DAMP_MODE_COMBINE ADDS the body's own damp on
		# top of the project default (3.5) rather than overriding it, so a
		# body sitting at DAMP_MODE_COMBINE with linear_damp=0.05 was still
		# getting 3.5+0.05=3.55 total damping - REPLACE mode is required in
		# space for the near-zero value to actually take effect.
		var targetDampMode = RigidBody2D.DAMP_MODE_COMBINE if inRoom else RigidBody2D.DAMP_MODE_REPLACE
		var targetLinearDamp = _roomLinearDamp if inRoom else spaceLinearDamp
		var targetAngularDamp = _roomAngularDamp if inRoom else spaceAngularDamp
		if item.linear_damp_mode != targetDampMode:
			item.linear_damp_mode = targetDampMode
			item.angular_damp_mode = targetDampMode
		if not is_equal_approx(item.linear_damp, targetLinearDamp):
			item.linear_damp = targetLinearDamp
		if not is_equal_approx(item.angular_damp, targetAngularDamp):
			item.angular_damp = targetAngularDamp

func _snapRotationTo45(item: RigidBody2D) -> void :
	# Mutating rotation via rotate() races the physics server's own transform
	# sync while a PinJoint2D is actively dragging the body (same class of bug
	# as the A/D rotation), so this writes the snapped angle straight to the
	# physics server's authoritative body state instead.
	var targetRotation = deg_to_rad(round(item.rotation_degrees / 45.0) * 45.0)
	var transform = item.global_transform
	transform = transform.rotated(targetRotation - item.rotation)
	PhysicsServer2D.body_set_state(item.get_rid(), PhysicsServer2D.BODY_STATE_TRANSFORM, transform)

func _hover(item: RigidBody2D):
	getItemSprite(item).use_parent_material = false
	label.text = getItemDisplayName(item)
	labelBGRect.size.x = label.get_theme_font("font").get_string_size(getItemDisplayName(item)).x + 3
	label.visible = true
	hoveredItem = item
	hovering = true

func _on_mouse_entered(item: RigidBody2D):
	allHovered.append(item)
	if not hovering:
		_hover(item)

func _on_mouse_exited(item: RigidBody2D):
	allHovered.remove_at(allHovered.find(item))
	if hovering:
		getItemSprite(item).use_parent_material = true
	if allHovered.size() < 1:
		label.visible = false
		hovering = false
	else:
		_hover(allHovered[0])

func _input(event: InputEvent) -> void :
	if dragging:
		if event is InputEventMouseButton and not event.is_pressed():
			endDrag(heldItem)
		if event is InputEventMouseMotion:
			var worldSize = get_viewport().size
			if event.position.x > worldSize.x\
			or event.position.x < 0\
			or event.position.y > worldSize.y\
			or event.position.y < 0:

				endDrag(heldItem)
	if hovering and not dragging:
		if event.is_pressed():
			if event.is_action("editDocument"):
				var itemType = hoveredItem.get_meta("type", "")
				if itemType == "txt":
					label.visible = false
					openEditorFor(hoveredItem)
				elif itemType == "labeler":
					label.visible = false
					openLabelerEditorFor(hoveredItem)
				return
			if not dragging and event is InputEventMouseButton and event.button_index == 1:
				startDrag(hoveredItem)

	# LMB on empty space (no item under the cursor, nothing being dragged)
	# pans the camera, mirroring the existing middle-mouse pan - clicking an
	# item always takes priority over panning.
	if not hovering and not dragging and not structureGrabbable() and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			worldCamera.startPan(event.position)
		else:
			worldCamera.stopPan()
	if worldCamera.panning and event is InputEventMouseMotion:
		worldCamera.updatePan(event.position)
