extends Node2D

const StampInfo = preload("res://scripts/stampInfo.gd")

@export var paperEditorScene: PackedScene
@export var labelerEditorScene: PackedScene
@export var floatingNoticeScene: PackedScene
@export var stampAppliedSound: AudioStream
@export var tonerInsertSound: AudioStream

@onready var mousePin: PinJoint2D = $"../mousePin"
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
				_playFeedback(labelerItem.global_position, null, tr("ui_label_applied"))

func applyStampToOverlaps(stampItem: RigidBody2D) -> void :
	for body in itemsParent.get_children():
		if body == stampItem:
			continue
		if body.get_meta("type", "") != "txt":
			continue
		if body.global_position.distance_to(stampItem.global_position) <= stampApplyRadius:
			# Mirrors SS14's PaperSystem.CanStamp: a non-reapply stamp can't
			# be applied twice with the same stamp state on the same paper.
			var stamps: Array = body.get_meta("stamps", [])
			var alreadyStamped = stamps.any(func(entry): return entry.get("stampState", "") == stampItem.stampState)
			if alreadyStamped:
				continue

			var overlay = body.get_node("CollisionShape2D/StampOverlay")
			overlay.addRandomizedStamp(stampItem.stampState)
			body.set_meta("stamps", overlay.serializeStamps())
			body.set_meta("writingUnlocked", false)
			if openEditors.has(body):
				openEditors[body].refreshStamps()
				openEditors[body].refreshWritingLock()
			_playFeedback(stampItem.global_position, stampAppliedSound, tr("ui_stamp_applied"))

func applyPenToOverlaps(penItem: RigidBody2D) -> void :
	for body in itemsParent.get_children():
		if body == penItem:
			continue
		if body.get_meta("type", "") != "txt":
			continue
		if body.global_position.distance_to(penItem.global_position) <= penApplyRadius:
			var stamps: Array = body.get_meta("stamps", [])
			# Mirrors SS14's OnInteractUsing editable check: unstamped paper is
			# always writable; a stamped paper needs WriteIgnoreStamps (full
			# bypass) or, for ordinary (non-Protected) stamps only,
			# NFWriteIgnoreUnprotectedStamps (canIgnoreStamps here).
			if not stamps.is_empty():
				var hasProtectedStamp = stamps.any(func(entry): return StampInfo.isProtected(entry.get("stampState", "")))
				var canBypass = penItem.canIgnoreProtectedStamps or (penItem.canIgnoreStamps and not hasProtectedStamp)
				if not canBypass:
					_playFeedback(penItem.global_position, null, tr("ui_pen_blocked"), true)
					continue

			# Mirrors SS14's OnInteractUsing: using a pen on paper opens (or
			# refreshes) its UI directly into write mode, same as clicking a
			# pen on paper does in-game - the player doesn't need to open the
			# paper separately first.
			openEditorFor(body)
			body.set_meta("writingUnlocked", true)
			openEditors[body].refreshWritingLock()

# Mirrors SS14's TonerCartridgeSystem "Refill toner" verb, but single-use:
# using a toner cartridge on the printer dumps its entire charge in at once
# and the cartridge is spent/removed - but only if the printer actually had
# room for it; a cartridge used on an already-full printer is refused
# outright and stays intact so it isn't wasted for nothing.
func applyTonerCartridgeToPrinter(cartridge: RigidBody2D) -> void :
	if cartridge.global_position.distance_to(printer.global_position) > tonerApplyRadius:
		return

	if printer.toner >= printer.maxToner:
		_playFeedback(cartridge.global_position, null, tr("ui_printer_full"), true)
		return

	cartridge.refillInto(printer)
	_playFeedback(cartridge.global_position, tonerInsertSound, tr("ui_printer_refilled"))
	_consumeCartridge(cartridge)

func _consumeCartridge(cartridge: RigidBody2D) -> void :
	if dragging and heldItem == cartridge:
		endDrag(cartridge)
	forgetItem(cartridge)
	cartridge.queue_free()

var _activeNotices = {}

func _worldToScreen(worldPos: Vector2) -> Vector2:
	# floatingNotice text must render in the crisp UI layer (outside the
	# pixel-art worldViewport) to avoid being upscaled/blurred, so world
	# coordinates need to be projected into the container's screen rect.
	var viewportLocal = worldCamera.get_viewport_transform() * worldPos
	var containerScale = worldViewContainer.size / Vector2(worldViewContainer.get_node("worldViewport").size)
	return worldViewContainer.global_position + viewportLocal * containerScale

func _playFeedback(atPosition: Vector2, sound: AudioStream, message: String, caution: bool = false) -> void :
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
			elif heldType == "pen" or heldType == "cyberPen":
				applyPenToOverlaps(heldItem)
			elif heldType == "tonerCartridge":
				applyTonerCartridgeToPrinter(heldItem)

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
	label.text = item.name
	labelBGRect.size.x = label.get_theme_font("font").get_string_size(item.name).x + 3
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
	if not hovering and not dragging and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			worldCamera.startPan(event.position)
		else:
			worldCamera.stopPan()
	if worldCamera.panning and event is InputEventMouseMotion:
		worldCamera.updatePan(event.position)
