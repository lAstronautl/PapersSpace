extends Control

signal closed

const dragMarginSize = 16.0

@onready var closeButton: Button = $layout/titleBar/close
@onready var textEditor: TextEdit = $layout/ScrollingContents/TextEdit
@onready var previewLabel: RichTextLabel = $layout/ScrollingContents/previewLabel
@onready var saveButton: Button = $layout/bottomBar/save
@onready var paperBackground = $PaperBackground
@onready var stampDisplay: Control = $stampDisplay
@onready var headerImage: TextureRect = $layout/headerImage
@onready var linedBackground: TextureRect = $linedBackground

const StampInfo = preload("res://scripts/stampInfo.gd")
const PaperVariants = preload("res://scripts/paperVariants.gd")
const SpriteDynamic = preload("res://scripts/spriteDynamic.gd")
const stampBorderTexture = preload("res://png/item/paper/stampMarks/stamp_border.png")

var currentItem: RigidBody2D

enum DragMode { NONE = 0, MOVE = 1, TOP = 2, BOTTOM = 4, LEFT = 8, RIGHT = 16 }
var currentDrag = DragMode.NONE
var dragOffset = Vector2.ZERO
var dragStartRect = Rect2()

func _ready():
	textEditor.text_changed.connect(_text_changed)
	saveButton.pressed.connect(_save_button_pressed)
	closeButton.pressed.connect(_close_button_pressed)
	visibility_changed.connect(_visibility_changed)
	paperBackground.gui_input.connect(_background_input)

	LanguageSwitcher.localeChanged.connect(_refreshLocaleStrings)
	_refreshLocaleStrings()

func _refreshLocaleStrings() -> void :
	saveButton.text = tr("ui_save")
	closeButton.text = tr("ui_close")
	# Mirrors SS14: the placeholder is always the same generic
	# "intentionally left blank" notice, regardless of why the page is
	# read-only (no pen used yet, stamped, or permanently uneditable).
	textEditor.placeholder_text = tr("ui_blank_page_placeholder")
	refreshWritingLock()

const allowedTags = ["b", "/b", "i", "/i", "u", "/u", "color=red", "color=blue", "color=green", "/color"]

func open(item: RigidBody2D) -> void :
	textEditor.text = item.get_meta("content")

	currentItem = item

	if item.get_meta("type") == "txt":
		paperBackground.setKind(item.get_meta("paperKind", "default"))
		var paperStyle: String = item.get_meta("paperStyle", "default")
		var styleColor = SpriteDynamic.paperStyles.get(paperStyle, SpriteDynamic.paperStyles["default"])
		paperBackground.modulate = styleColor
		# linedBackground is an opaque sibling drawn on top of PaperBackground's
		# stretched center patch (same 16px inset), so it needs the same tint
		# applied directly - otherwise it paints over the center with
		# unmodulated white, leaving only the nine-patch border ring tinted.
		linedBackground.modulate = styleColor

	var variantConfig = PaperVariants.getConfig(item.get_meta("paperVariant", "default"))
	var headerPath: String = variantConfig.get("header", "")
	headerImage.visible = headerPath != ""
	if headerPath != "":
		headerImage.texture = load(headerPath)

	linedBackground.visible = variantConfig.get("lined", false)
	if linedBackground.visible and not linedBackground.texture:
		linedBackground.texture = load("res://png/item/paper/headers/content_lined.png")

	# Mirrors SS14's PaperSystem.BeforeUIOpen: opening the paper by itself
	# (no pen) always resets it to read-only mode. Only using a pen on the
	# paper (see itemInteractionControler.applyPenToOverlaps) switches it
	# to write mode for as long as this window stays open.
	item.set_meta("writingUnlocked", false)

	refreshStamps()
	refreshWritingLock()

	visible = true

func refreshWritingLock() -> void :
	if not currentItem:
		return

	# Mirrors SS14's Paper.editingDisabled (e.g. AcquisitionSlips): some
	# variants are permanently read-only regardless of pen/stamp state.
	var variantConfig = PaperVariants.getConfig(currentItem.get_meta("paperVariant", "default"))
	var isWriteMode = variantConfig.get("editable", true) and currentItem.get_meta("writingUnlocked", false)

	# Write mode is only entered by using a pen on the paper (see
	# itemInteractionControler.applyPenToOverlaps). A stamped paper additionally
	# requires the pen used to be able to ignore stamps (CyberPen).
	textEditor.editable = isWriteMode

	# Mirrors SS14: read-only papers render their content as rich text
	# (bold/italic/color tags shown formatted) with no separate "preview"
	# toggle - only while actively writing does the raw markup/plain text
	# editor show instead, since that's when you need to see/type the tags.
	textEditor.visible = isWriteMode
	previewLabel.visible = not isWriteMode
	if not isWriteMode:
		previewLabel.text = _toSafeBBCode(textEditor.text)

func refreshStamps() -> void :
	for child in stampDisplay.get_children():
		child.queue_free()

	if not currentItem or not currentItem.has_meta("stamps"):
		return

	var stamps: Array = currentItem.get_meta("stamps")
	if stamps.is_empty():
		return

	# Mirrors SS14's StampCollection.ArrangeOverride: a seeded RNG (per-paper)
	# places stamps in 90-degree steps around a circle from a random starting
	# quadrant, spacing out further past the 5th stamp, each with a small
	# +/-5 degree rotation jitter for a hand-stamped look.
	var rng = RandomNumberGenerator.new()
	rng.seed = currentItem.get_instance_id()

	var containerSize = stampDisplay.size
	if containerSize.x <= 0 or containerSize.y <= 0:
		containerSize = Vector2(240, 240)
	var radius = containerSize.length() * 0.5
	var center = containerSize / 2
	var dtheta = -PI / 2
	var theta0 = rng.randi_range(0, 2) * dtheta

	for i in stamps.size():
		var entry = stamps[i]
		if not entry.has("stampState"):
			continue

		var jitterDegrees = (rng.randf() - 0.5) * 10.0
		var stampOrientation = deg_to_rad(jitterDegrees)

		var theta = theta0 + dtheta * 0.5 + dtheta * i
		if i > 4:
			theta += log(1 + i / 4.0) * dtheta

		var stampCenter = center
		if i > 0:
			stampCenter += Vector2(cos(theta), sin(theta)) * radius

		_addStampWidget(entry.stampState, stampOrientation, stampCenter)

func _addStampWidget(stampState: String, orientation: float, centerPos: Vector2) -> void :
	var stampName = tr(StampInfo.getStampName(stampState))
	var stampColor = StampInfo.getStampColor(stampState)

	var widget = Control.new()
	widget.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var border = TextureRect.new()
	border.texture = stampBorderTexture
	border.stretch_mode = TextureRect.STRETCH_SCALE
	border.modulate = stampColor
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	widget.add_child(border)

	var label = Label.new()
	label.text = stampName
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", stampColor)
	label.add_theme_font_size_override("font_size", 24)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	widget.add_child(label)

	stampDisplay.add_child(widget)

	var widgetSize = Vector2(max(140, stampName.length() * 16 + 32), 64)
	widget.custom_minimum_size = widgetSize
	widget.size = widgetSize
	border.size = widgetSize
	label.size = widgetSize
	widget.pivot_offset = widgetSize / 2
	widget.rotation = orientation
	widget.modulate.a = 0.85

	widget.position = centerPos - widgetSize / 2

func _toSafeBBCode(rawText: String) -> String:
	# Escaping "[" -> "[lb]" then "]" -> "[rb]" sequentially is unsafe: "[lb]"
	# and "[rb]" themselves contain "[" and "]", so the second replace also
	# mangles brackets the first replace just inserted (e.g. "[b]" ends up as
	# "[lb[rb]b[rb]" instead of "[lb]b[rb]"). Route through bracket-free
	# placeholder codepoints first, then restore literal escapes and allowed
	# tags, so neither replace step can corrupt what the other just wrote.
	var leftPlaceholder = String.chr(0xE000)
	var rightPlaceholder = String.chr(0xE001)
	var escaped = rawText.replace("[", leftPlaceholder).replace("]", rightPlaceholder)
	for tag in allowedTags:
		escaped = escaped.replace("%s%s%s" % [leftPlaceholder, tag, rightPlaceholder], "[%s]" % tag)
	escaped = escaped.replace(leftPlaceholder, "[lb]").replace(rightPlaceholder, "[rb]")
	return escaped

func save() -> void :
	currentItem.set_meta("content", textEditor.text)

	if currentItem.get_meta("type") == "txt":
		if currentItem.get_meta("content").length() > 0:
			currentItem.get_node("CollisionShape2D").get_node("Sprite2D").setActiveTexture(true)
		else:
			currentItem.get_node("CollisionShape2D").get_node("Sprite2D").setActiveTexture(false)

	saveButton.visible = false

func _save_button_pressed():
	save()

func _close_button_pressed():
	closed.emit()

func _visibility_changed():
	if not visible:
		currentDrag = DragMode.NONE
		if currentItem:
			currentItem.set_meta("writingUnlocked", false)

func _text_changed():
	save()

func _input(event: InputEvent) -> void :
	if not visible or not event.is_pressed():
		return
	if not Rect2(global_position, size).has_point(get_global_mouse_position()):
		return

	if event.is_action("saveDocument"):
		save()
	if event.is_action("closeEditor"):
		closed.emit()

func _getDragModeFor(localPos: Vector2) -> int:
	var mode = DragMode.NONE
	if localPos.y < dragMarginSize:
		mode |= DragMode.TOP
	elif localPos.y > size.y - dragMarginSize:
		mode |= DragMode.BOTTOM
	if localPos.x < dragMarginSize:
		mode |= DragMode.LEFT
	elif localPos.x > size.x - dragMarginSize:
		mode |= DragMode.RIGHT
	if mode == DragMode.NONE:
		mode = DragMode.MOVE
	return mode

func _startDrag(localPos: Vector2) -> void :
	currentDrag = _getDragModeFor(localPos)
	dragOffset = get_global_mouse_position() - global_position
	dragStartRect = Rect2(global_position, size)

func _gui_input(event: InputEvent) -> void :
	_handleDragInput(event)

func _background_input(event: InputEvent) -> void :
	_handleDragInput(event)

func _handleDragInput(event: InputEvent) -> void :
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_startDrag(get_local_mouse_position())
		else:
			currentDrag = DragMode.NONE

func _process(_delta: float) -> void :
	if currentDrag == DragMode.NONE:
		return

	var mousePos = get_global_mouse_position()

	if currentDrag == DragMode.MOVE:
		global_position = mousePos - dragOffset
		return

	var rect = dragStartRect
	if currentDrag & DragMode.RIGHT:
		rect.size.x = max(custom_minimum_size.x, mousePos.x - dragStartRect.position.x)
	if currentDrag & DragMode.BOTTOM:
		rect.size.y = max(custom_minimum_size.y, mousePos.y - dragStartRect.position.y)
	if currentDrag & DragMode.LEFT:
		var newLeft = min(mousePos.x - dragOffset.x, dragStartRect.position.x + dragStartRect.size.x - custom_minimum_size.x)
		rect.size.x = dragStartRect.position.x + dragStartRect.size.x - newLeft
		rect.position.x = newLeft
	if currentDrag & DragMode.TOP:
		var newTop = min(mousePos.y - dragOffset.y, dragStartRect.position.y + dragStartRect.size.y - custom_minimum_size.y)
		rect.size.y = dragStartRect.position.y + dragStartRect.size.y - newTop
		rect.position.y = newTop

	global_position = rect.position
	size = rect.size
