extends Node2D

const StampInfo = preload("res://scripts/stampInfo.gd")
const PaperVariants = preload("res://scripts/paperVariants.gd")

@export var paperEditorScene: PackedScene
@export var labelerEditorScene: PackedScene
@export var floatingNoticeScene: PackedScene
@export var stampAppliedSound: AudioStream

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
			# Mirrors SS14's Paper.editingDisabled: some variants (e.g.
			# AcquisitionSlips) can never be written on, no pen bypasses this.
			var variantConfig = PaperVariants.getConfig(body.get_meta("paperVariant", "default"))
			if not variantConfig.get("editable", true):
				continue

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

# Mirrors SS14's TonerCartridgeSystem "Refill toner" verb: using a toner
# cartridge on the printer transfers its remaining charge into the printer
# (capped by the printer's free capacity), draining the cartridge itself.
func applyTonerCartridgeToPrinter(cartridge: RigidBody2D) -> void :
	if cartridge.global_position.distance_to(printer.global_position) > tonerApplyRadius:
		return

	if printer.toner >= printer.maxToner:
		_playFeedback(cartridge.global_position, null, tr("ui_printer_full"), true)
		return

	var transferred = cartridge.refillInto(printer)
	if transferred > 0:
		_playFeedback(cartridge.global_position, null, tr("ui_printer_refilled"))
	if cartridge.currentAmount <= 0:
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
