extends Control

signal closed

const dragMarginSize = 16.0

@onready var closeButton: Button = $close
@onready var textEditor: TextEdit = $layout/ScrollingContents/TextEdit
@onready var previewLabel: RichTextLabel = $layout/ScrollingContents/previewLabel
@onready var saveButton: Button = $layout/bottomBar/save
@onready var fillStatus: Label = $layout/bottomBar/fillStatus
@onready var paperBackground = $PaperBackground
@onready var stampDisplay: Control = $stampDisplay
@onready var headerMargin: MarginContainer = $layout/headerMargin
@onready var headerImage: TextureRect = $layout/headerMargin/headerImage
@onready var footerMargin: MarginContainer = $layout/footerMargin
@onready var footerImage: TextureRect = $layout/footerMargin/footerImage
@onready var linedBackground: TextureRect = $linedBackground

const StampInfo = preload("res://scripts/stampInfo.gd")
const PaperMarkup = preload("res://scripts/paperMarkup.gd")
const PaperVariants = preload("res://scripts/paperVariants.gd")
const SpriteDynamic = preload("res://scripts/spriteDynamic.gd")
const stampBorderTexture = preload("res://png/item/paper/stampMarks/stamp_border.png")
# Mirrors StarHorizon's StampWidget XAML: StampedByLabel uses the
# "LabelHeadingBigger" style class, which is notoSansBold20 - stamps read as
# bold, not the regular weight used for the page's own written text.
const stampFont = preload("res://fonts/NotoSans/NotoSans-Bold.ttf")

var currentItem: RigidBody2D
var maxContentLength: int = 10000

enum DragMode { NONE = 0, MOVE = 1, TOP = 2, BOTTOM = 4, LEFT = 8, RIGHT = 16 }
var currentDrag = DragMode.NONE
var dragOffset = Vector2.ZERO
var dragStartRect = Rect2()

# The preview label renders [bold]/[italic]/[bolditalic] from these. Only the
# Regular and Bold Noto Sans files ship with the game, so italics are the
# regular/bold faces skewed (like SS14's NotoSans-Italic stand-in).
const regularFont = preload("res://fonts/NotoSans/NotoSans-Regular.ttf")
const italicSkew = 0.2
const previewFontSize = 12

func _skewed(font: Font) -> FontVariation:
	var variation = FontVariation.new()
	variation.base_font = font
	variation.variation_transform = Transform2D(Vector2(1, 0), Vector2(italicSkew, 1), Vector2.ZERO)
	return variation

func _setupPreviewFonts() -> void :
	previewLabel.add_theme_font_override("normal_font", regularFont)
	previewLabel.add_theme_font_override("bold_font", stampFont)
	previewLabel.add_theme_font_override("italics_font", _skewed(regularFont))
	previewLabel.add_theme_font_override("bold_italics_font", _skewed(stampFont))
	previewLabel.add_theme_font_override("mono_font", regularFont)
	for sizeName in ["normal_font_size", "bold_font_size", "italics_font_size", "bold_italics_font_size", "mono_font_size"]:
		previewLabel.add_theme_font_size_override(sizeName, previewFontSize)

func _ready():
	_setupPreviewFonts()
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

func open(item: RigidBody2D) -> void :
	textEditor.text = item.get_meta("content")

	currentItem = item
	maxContentLength = PaperVariants.getContentSize(item.get_meta("paperVariant", "default"))

	# Mirrors StarHorizon's PaperWindow.xaml.cs InitVisuals(): every visual
	# element (background/header/footer/content image + their margins/tints)
	# is driven directly by the prototype's PaperVisuals fields, copied
	# verbatim into PaperVariants.getVisuals().
	var visuals: Dictionary = PaperVariants.getVisuals(item.get_meta("paperVariant", "default"))

	paperBackground.applyVisuals(visuals)

	var headerPath: String = visuals.get("headerImagePath", "")
	headerImage.visible = headerPath != ""
	if headerPath != "":
		headerImage.texture = load(headerPath)
	headerImage.self_modulate = visuals.get("headerImageModulate", Color.WHITE)
	_applyMargin(headerMargin, visuals.get("headerMargin", Vector4.ZERO))

	var footerPath: String = visuals.get("footerImagePath", "")
	footerImage.visible = footerPath != ""
	if footerPath != "":
		footerImage.texture = load(footerPath)
	footerImage.self_modulate = visuals.get("footerImageModulate", Color.WHITE)
	_applyMargin(footerMargin, visuals.get("footerMargin", Vector4.ZERO))

	var contentPath: String = visuals.get("contentImagePath", "")
	linedBackground.visible = contentPath != ""
	if contentPath != "":
		linedBackground.texture = load(contentPath)
		linedBackground.self_modulate = visuals.get("contentImageModulate", Color.WHITE)

	var contentMargin: Vector4 = visuals.get("contentMargin", Vector4.ZERO)
	linedBackground.offset_left = contentMargin.x
	linedBackground.offset_top = contentMargin.y
	linedBackground.offset_right = -contentMargin.z
	linedBackground.offset_bottom = -contentMargin.w

	# Independent of PaperVisuals: this port's own "paperStyle" random-litter
	# tint (see spriteDynamic.gd's paperStyles) multiplies on top of whatever
	# PaperVisuals.backgroundModulate/contentImageModulate already set, via
	# Godot's separate `modulate` (as opposed to `self_modulate`) property.
	# Variants that carry their own "color" (colored papers, cargo invoices...)
	# already express that tint through PaperVisuals, so applying the style on
	# top would tint the window twice.
	var paperVariant: String = item.get_meta("paperVariant", "default")
	var styleColor = Color.WHITE
	if item.get_meta("type") == "txt" and not PaperVariants.getConfig(paperVariant).has("color"):
		styleColor = SpriteDynamic.styleColor(item.get_meta("paperStyle", "default"))
	paperBackground.modulate = styleColor
	linedBackground.modulate = styleColor

	# Mirrors SS14's PaperVisuals.maxWritableArea: constrains the reading
	# window's content area width/height independently (0 on an axis means
	# unconstrained on that axis, e.g. NanoTask's narrow-but-tall receipt).
	var maxArea: Vector2 = visuals.get("maxWritableArea", Vector2.ZERO)
	if maxArea.x > 0.0:
		custom_minimum_size.x = maxArea.x
		size.x = maxArea.x
	else:
		custom_minimum_size.x = 300.0

	# Mirrors SS14's PaperSystem.BeforeUIOpen: opening the paper by itself
	# (no pen) always resets it to read-only mode. Only using a pen on the
	# paper (see itemInteractionControler.applyPenToOverlaps) switches it
	# to write mode for as long as this window stays open.
	item.set_meta("writingUnlocked", false)

	refreshStamps()
	refreshWritingLock()

	visible = true

# Applies a Robust-style Thickness (left,top,right,bottom) to a
# MarginContainer wrapping a header/footer image, mirroring
# PaperWindow.xaml.cs's `HeaderImage.Margin = new Thickness(...)`.
func _applyMargin(marginContainer: MarginContainer, margin: Vector4) -> void :
	marginContainer.add_theme_constant_override("margin_left", margin.x)
	marginContainer.add_theme_constant_override("margin_top", margin.y)
	marginContainer.add_theme_constant_override("margin_right", margin.z)
	marginContainer.add_theme_constant_override("margin_bottom", margin.w)

func refreshWritingLock() -> void :
	if not currentItem:
		return

	var isWriteMode = currentItem.get_meta("writingUnlocked", false)

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
		# Mirrors SS14's PaperWindow.xaml.cs Populate(): a truly blank page (no
		# text, not currently being written on) shows the generic "intentionally
		# left blank" notice in LabelSecondaryColor gray (BlankPaperIndicator),
		# distinct from actual written content which renders in the darker
		# PaperWrittenText color (#111111, set as previewLabel's default_color
		# in the scene).
		if textEditor.text.is_empty():
			previewLabel.text = tr("ui_blank_page_placeholder")
			previewLabel.add_theme_color_override("default_color", Color(0.098039, 0.098039, 0.098039, 1))
		else:
			previewLabel.text = _toSafeBBCode(textEditor.text)
			previewLabel.add_theme_color_override("default_color", Color("111111"))

	# Mirrors SS14: a read-only paper is just a prop - you can grab and drag
	# the window from anywhere, including on top of its text, not only its
	# empty margins. Only while actively writing does clicking the text need
	# to place a cursor instead, so the label stops eating mouse input then.
	previewLabel.mouse_filter = Control.MOUSE_FILTER_IGNORE if not isWriteMode else Control.MOUSE_FILTER_STOP

	# Mirrors SS14's PaperWindow.xaml: FillStatus only lives inside the
	# write-mode InputContainer, so it's hidden entirely outside write mode.
	fillStatus.visible = isWriteMode
	if isWriteMode:
		_updateFillStatus()

# Mirrors SS14's PaperWindow.xaml.cs UpdateFillState(): shows "current/max"
# and disables the save button once the text exceeds ContentSize (10000 by
# default - see PaperComponent.ContentSize / PaperVariants.getContentSize).
func _updateFillStatus() -> void :
	var currentLength = textEditor.text.length()
	fillStatus.text = "%d/%d" % [currentLength, maxContentLength]
	saveButton.disabled = currentLength > maxContentLength

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
	label.add_theme_font_override("font", stampFont)
	label.add_theme_font_size_override("font_size", 20)
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
	return PaperMarkup.toBBCode(rawText)

func save() -> void :
	# Mirrors SS14's OnInputTextMessage: text longer than ContentSize is
	# rejected outright (the paper keeps its previous content) rather than
	# truncated - the fill indicator/disabled save button already warn the
	# player before they'd hit this.
	if textEditor.text.length() > maxContentLength:
		return

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
	_updateFillStatus()
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
