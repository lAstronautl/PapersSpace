extends Control

signal closed

# The paper window, rebuilt from StarHorizon's PaperWindow.xaml / PaperWindow.xaml.cs
# (Content.Client/Paper/UI) with Robust's layout rules (Control.Layout.cs,
# PanelContainer, BoxContainer, ScrollContainer) written out by hand, in logical
# pixels with every position and size truncated to whole pixels as Robust does:
#
#   ContentsRoot (vertical box)
#     close row   PanelContainer "AngleRect", Margin 6, top right, holding the X button
#     PaperBackground (vertical expand): StyleBoxTexture from PaperVisuals, or the
#                     "PaperDefaultBorder" cream panel
#       ScrollingContents (MinSize/MaxWidth/MaxHeight = PaperVisuals.MaxWritableArea)
#         PaperContent (MaxWidth 600, Margin = ContentMargin, style = lined texture)
#           vertical box: HeaderImage, TextAlignmentPadding, BlankPaperIndicator,
#                         WrittenTextLabel, InputContainer, FooterImage
#           StampCollection (min 150x150, Margin 6, bottom aligned)
#     edit row    Save button, Margin 6, only while writing
const RobustFont = preload("res://scripts/robustFont.gd")
const RichTextScript = preload("res://scripts/robustRichText.gd")
const StyleBoxScript = preload("res://scripts/robustStyleBox.gd")
const StampWidgetScript = preload("res://scripts/paperStampWidget.gd")
const StampInfo = preload("res://scripts/stampInfo.gd")
const PaperVariants = preload("res://scripts/paperVariants.gd")
const PaperSounds = preload("res://scripts/paperSounds.gd")

const angleRectTexture = preload("res://png/ui/button.png")
const crossTexture = preload("res://png/ui/cross.png")
const inputPanelTexture = preload("res://png/ui/transparent_window_bordered.png")
const defaultBackgroundTexture = preload("res://png/item/paper/backgrounds/paper_background_default.png")

# PaperWindow.xaml
const defaultWindowSize = Vector2(510, 660)             # SetSize
const minWindowSize = Vector2(150, 150)                 # MinSize
const dragMarginSize = 16.0                             # DRAG_MARGIN_SIZE
const contentMaxWidth = 600.0                           # PaperContent MaxWidth
const closePanelMargin = 6.0
const angleRectPatch = 10.0                             # BaseAngleRect patch margin
const closeIconSize = Vector2(22, 22)                   # cross.svg.png
const editRowMargin = 6.0
const stampDisplayMin = 150.0
const stampDisplayMargin = 6.0
const inputMinHeight = 100.0
const inputPanelPatch = 2.0                             # transparent bordered window panel

# Stylesheet
const regularPoints = 12                                # notoSans12
const textColor = Color8(25, 25, 25)                    # PaperWindow.DefaultTextColor
const secondaryTextColor = Color8(169, 169, 169)        # Color.DarkGray
const defaultBorderModulate = Color("eaedde")           # "A light cream"
const angleRectModulate = Color("252725")                # "AngleRect" ModulateSelf
const nanoGold = Color("a88b5e")                        # window close button
const closeHoverColor = Color("7f3636")
const closePressedColor = Color("753131")
const buttonColor = Color("464b46")
const buttonHoverColor = Color("575b57")
const buttonPressedColor = Color("3e6c45")
const buttonDisabledColor = Color("303331")
const buttonPatch = 10.0
const buttonContentMargin = Vector2(15, 3)              # override 14/2 + padding 1
const scrollBarWidth = 10.0                             # DefaultGrabberSize
const scrollSpeed = 50.0                                # ScrollContainer.ScrollSpeedY
const scrollGrabberColor = Color(0.5019608, 0.5019608, 0.5019608, 0.35)
const allowedTags = ["bold", "italic", "bolditalic", "bullet", "color", "head", "mono"]   # _allowedTags

enum DragMode { NONE = 0, MOVE = 1, TOP = 2, BOTTOM = 4, LEFT = 8, RIGHT = 16 }

var currentItem: RigidBody2D
var maxContentLength: int = 10000
var currentDrag = DragMode.NONE
var dragOffset = Vector2.ZERO
var dragStartRect = Rect2()

var vis: Dictionary = {}
var isEditing = false
var _scroll = 0.0
var _scrollMax = 0.0
var _stampWidgets: Array = []
var _stampSeed = 0
var _regular = RobustFont.noto_regular(regularPoints)
var _built = false

# Nodes
var _closePanel: Control
var _closeButton: TextureButton
var _paperBackground: Control
var _viewport: Control
var _content: Control
var _contentPanel: Control
var _header: TextureRect
var _footer: TextureRect
var _blank: Control
var _written: Control
var _inputPanel: Control
var _textEdit: TextEdit
var _fillStatus: Label
var _stampLayer: Control
var _scrollBar: Control
var _saveStyle: Control
var _saveButton: Button

func _ready() -> void:
	_build()
	LanguageSwitcher.localeChanged.connect(_refreshLocaleStrings)
	_textEdit.text_changed.connect(_text_changed)
	_saveButton.pressed.connect(_save_button_pressed)
	_closeButton.pressed.connect(_close_button_pressed)
	visibility_changed.connect(_visibility_changed)
	resized.connect(_layout)
	_refreshLocaleStrings()

func _build() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	# --- close row
	_closePanel = StyleBoxScript.new()
	_closePanel.texture = angleRectTexture
	_closePanel.patchMargin = Vector4(angleRectPatch, angleRectPatch, angleRectPatch, angleRectPatch)
	_closePanel.self_modulate = angleRectModulate
	add_child(_closePanel)
	_closeButton = TextureButton.new()
	_closeButton.texture_normal = crossTexture
	_closeButton.ignore_texture_size = true
	_closeButton.stretch_mode = TextureButton.STRETCH_KEEP
	_closeButton.self_modulate = nanoGold
	_closeButton.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_closeButton.mouse_entered.connect(func(): _closeButton.self_modulate = closeHoverColor)
	_closeButton.mouse_exited.connect(func(): _closeButton.self_modulate = nanoGold)
	_closeButton.button_down.connect(func(): _closeButton.self_modulate = closePressedColor)
	_closeButton.button_up.connect(func(): _closeButton.self_modulate = closeHoverColor if _closeButton.is_hovered() else nanoGold)
	_closePanel.add_child(_closeButton)

	# --- paper background
	_paperBackground = StyleBoxScript.new()
	_paperBackground.mouse_filter = Control.MOUSE_FILTER_STOP
	_paperBackground.gui_input.connect(_background_input)
	add_child(_paperBackground)

	# --- scrolling contents
	_viewport = Control.new()
	_viewport.clip_contents = true
	_viewport.mouse_filter = Control.MOUSE_FILTER_PASS
	_viewport.gui_input.connect(_viewport_input)
	add_child(_viewport)
	_content = Control.new()
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_viewport.add_child(_content)

	_contentPanel = StyleBoxScript.new()
	_content.add_child(_contentPanel)

	_header = _make_image()
	_content.add_child(_header)

	_blank = RichTextScript.new()
	_blank.defaultFont = _regular
	_blank.defaultColor = textColor
	_blank.tagsAllowed = allowedTags
	_blank.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(_blank)

	_written = RichTextScript.new()
	_written.defaultFont = _regular
	_written.defaultColor = textColor
	_written.tagsAllowed = allowedTags
	_written.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(_written)

	_inputPanel = StyleBoxScript.new()
	_inputPanel.texture = inputPanelTexture
	_inputPanel.patchMargin = Vector4(inputPanelPatch, inputPanelPatch, inputPanelPatch, inputPanelPatch)
	_content.add_child(_inputPanel)

	_textEdit = TextEdit.new()
	_textEdit.add_theme_font_override("font", RobustFont.face("regular"))
	_textEdit.add_theme_font_size_override("font_size", _regular.ppem())
	_textEdit.add_theme_color_override("font_color", Color.WHITE)
	_textEdit.add_theme_color_override("font_readonly_color", Color.WHITE)
	_textEdit.add_theme_color_override("font_placeholder_color", Color.GRAY)
	_textEdit.add_theme_color_override("caret_color", Color.WHITE)
	var empty = StyleBoxEmpty.new()
	for style_name in ["normal", "focus", "read_only"]:
		_textEdit.add_theme_stylebox_override(style_name, empty)
	_textEdit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_content.add_child(_textEdit)

	_fillStatus = Label.new()
	_fillStatus.add_theme_font_override("font", RobustFont.face("regular"))
	_fillStatus.add_theme_font_size_override("font_size", _regular.ppem())
	_fillStatus.add_theme_color_override("font_color", secondaryTextColor)
	_fillStatus.add_theme_constant_override("line_spacing", _regular.line_height() - _regular.height())
	_content.add_child(_fillStatus)

	_footer = _make_image()
	_content.add_child(_footer)

	_stampLayer = Control.new()
	_stampLayer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(_stampLayer)

	_scrollBar = Control.new()
	_scrollBar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scrollBar.draw.connect(_draw_scroll_bar)
	_viewport.add_child(_scrollBar)

	# --- edit row
	_saveStyle = StyleBoxScript.new()
	_saveStyle.texture = angleRectTexture
	_saveStyle.patchMargin = Vector4(buttonPatch, buttonPatch, buttonPatch, buttonPatch)
	_saveStyle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_saveStyle)
	_saveButton = Button.new()
	_saveButton.flat = true
	_saveButton.focus_mode = Control.FOCUS_NONE
	_saveButton.add_theme_font_override("font", RobustFont.face("regular"))
	_saveButton.add_theme_font_size_override("font_size", _regular.ppem())
	_saveButton.add_theme_color_override("font_color", Color("e5e5e5"))
	_saveButton.add_theme_color_override("font_disabled_color", Color("8d8d8d"))
	var empty_button = StyleBoxEmpty.new()
	for style_name in ["normal", "hover", "pressed", "disabled", "focus"]:
		_saveButton.add_theme_stylebox_override(style_name, empty_button)
	_saveButton.mouse_entered.connect(_refresh_save_color)
	_saveButton.mouse_exited.connect(_refresh_save_color)
	_saveButton.button_down.connect(_refresh_save_color)
	_saveButton.button_up.connect(_refresh_save_color)
	add_child(_saveButton)
	_built = true

func _make_image() -> TextureRect:
	var image = TextureRect.new()
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP
	image.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return image

func _refreshLocaleStrings() -> void:
	_saveButton.text = tr("ui_save")
	# Mirrors SS14: the placeholder is always the same generic "intentionally left
	# blank" notice, regardless of why the page is read-only.
	_textEdit.placeholder_text = tr("ui_blank_page_placeholder")
	if currentItem:
		refreshWritingLock()

func _refresh_save_color() -> void:
	var color = buttonColor
	if _saveButton.disabled:
		color = buttonDisabledColor
	elif _saveButton.button_pressed:
		color = buttonPressedColor
	elif _saveButton.is_hovered():
		color = buttonHoverColor
	_saveStyle.self_modulate = color

# --- opening / visuals ----------------------------------------------------------------

func open(item: RigidBody2D) -> void:
	currentItem = item
	var variantId: String = item.get_meta("paperVariant", "default")
	vis = PaperVariants.getVisuals(variantId)
	maxContentLength = PaperVariants.getContentSize(variantId)
	_textEdit.text = item.get_meta("content", "")

	# Mirrors SS14's PaperSystem.BeforeUIOpen: opening the paper by itself (no pen)
	# always resets it to read-only mode.
	item.set_meta("writingUnlocked", false)
	isEditing = false
	_scroll = 0.0

	_apply_visuals()
	_stampSeed = item.get_instance_id()
	refreshStamps()
	refreshWritingLock()
	_apply_window_size()
	var parent_size = get_parent_control().size if get_parent_control() else get_viewport_rect().size
	position = Vector2(int((parent_size.x - size.x) / 2.0), int((parent_size.y - size.y) / 2.0))
	visible = true
	_layout()

# PaperWindow.InitVisuals
func _apply_visuals() -> void:
	var path: String = vis.get("backgroundImagePath", "")
	var background_modulate: Color = vis.get("backgroundModulate", Color.WHITE)
	if path != "":
		_paperBackground.texture = load(path)
		_paperBackground.patchMargin = vis.get("backgroundPatchMargin", Vector4.ZERO)
		_paperBackground.tile = vis.get("backgroundImageTile", false)
		_paperBackground.textureScale = vis.get("backgroundScale", Vector2.ONE)
		_paperBackground.self_modulate = background_modulate
	else:
		# PanelOverride = null: the stylesheet's "PaperDefaultBorder" panel
		# (paper_background_default, patch margin 16, tinted light cream).
		_paperBackground.texture = defaultBackgroundTexture
		_paperBackground.patchMargin = Vector4(16, 16, 16, 16)
		_paperBackground.tile = false
		_paperBackground.textureScale = Vector2.ONE
		_paperBackground.self_modulate = defaultBorderModulate * background_modulate

	var header_path: String = vis.get("headerImagePath", "")
	_header.texture = load(header_path) if header_path != "" else null
	_header.self_modulate = vis.get("headerImageModulate", Color.WHITE)
	var footer_path: String = vis.get("footerImagePath", "")
	_footer.texture = load(footer_path) if footer_path != "" else null
	_footer.self_modulate = vis.get("footerImageModulate", Color.WHITE)

	var content_path: String = vis.get("contentImagePath", "")
	_contentPanel.visible = content_path != ""
	if content_path != "":
		# Content image: tiled, scaled so one tile is one text line (ContentImageNumLines
		# lines), shifted up by the font descent so the rules sit on the baseline.
		var texture: Texture2D = load(content_path)
		var lines: int = vis.get("contentImageNumLines", 1)
		_contentPanel.texture = texture
		_contentPanel.patchMargin = Vector4.ZERO
		_contentPanel.tile = true
		_contentPanel.textureScale = Vector2(1.0, (lines * _regular.line_height()) / float(texture.get_height()))
		_contentPanel.expandMargin = Vector4(0, _regular.descent(), 0, 0)
		_contentPanel.self_modulate = vis.get("contentImageModulate", Color.WHITE)

	# FontAccentColor: modulates the written text and the fill status.
	_written.self_modulate = vis.get("fontAccentColor", Color8(223, 223, 213))
	_fillStatus.self_modulate = vis.get("fontAccentColor", Color8(223, 223, 213))

# Window size as PaperWindow sizes itself: SetSize 510x660, unless MaxWritableArea
# fixes an axis, in which case that axis follows the content.
func _apply_window_size() -> void:
	var area: Vector2 = vis.get("maxWritableArea", Vector2.ZERO)
	var inset: Vector4 = _paperBackground.content_margin()
	var window_size = defaultWindowSize
	if area.x > 0:
		window_size.x = maxf(area.x + inset.x + inset.z, _close_row_size().x)
	if area.y > 0:
		window_size.y = _close_row_size().y + area.y + inset.y + inset.w + _edit_row_height()
	size = Vector2(int(window_size.x), int(window_size.y))

func _close_row_size() -> Vector2:
	return closeIconSize + Vector2(angleRectPatch * 2.0, angleRectPatch * 2.0) + Vector2(closePanelMargin * 2.0, closePanelMargin * 2.0)

func _save_button_size() -> Vector2:
	var text_width = 0
	for index in _saveButton.text.length():
		var advance = _regular.char_advance(_saveButton.text.unicode_at(index))
		if advance > 0:
			text_width += advance
	# A Button holds a Label (font height) inside the BaseButton style box.
	return Vector2(text_width + buttonContentMargin.x * 2.0, _regular.height() + buttonContentMargin.y * 2.0)

func _edit_row_height() -> float:
	return _save_button_size().y + editRowMargin * 2.0 if isEditing else 0.0

func _allowed_resize() -> int:
	var allowed = DragMode.TOP | DragMode.BOTTOM | DragMode.LEFT | DragMode.RIGHT
	var area: Vector2 = vis.get("maxWritableArea", Vector2.ZERO)
	if area.x > 0:
		allowed &= ~(DragMode.LEFT | DragMode.RIGHT)
	if area.y > 0:
		allowed &= ~(DragMode.TOP | DragMode.BOTTOM)
	return allowed

# --- text / editing state ---------------------------------------------------------------

func refreshWritingLock() -> void:
	if not currentItem or not _built:
		return
	var was_editing = isEditing
	# Write mode is only entered by using a pen on the paper (see
	# itemInteractionControler.applyPenToOverlaps).
	isEditing = currentItem.get_meta("writingUnlocked", false)
	_textEdit.editable = isEditing

	# PaperWindow.Populate: WrittenTextLabel shows while reading text, the blank
	# indicator while reading an empty page, the input area while writing.
	var text = _textEdit.text
	_written.set_message(text)
	_blank.set_plain_message(tr("ui_blank_page_placeholder"))
	_written.visible = not isEditing and text.length() > 0
	_blank.visible = not isEditing and text.length() == 0
	_inputPanel.visible = isEditing
	_textEdit.visible = isEditing
	_fillStatus.visible = isEditing
	_saveButton.visible = isEditing
	_saveStyle.visible = isEditing
	if isEditing:
		_updateFillStatus()
	if was_editing != isEditing:
		_apply_window_size()
	_layout()

# PaperWindow.UpdateFillState
func _updateFillStatus() -> void:
	var current_length = _textEdit.text.length()
	_fillStatus.text = "%d/%d" % [current_length, maxContentLength]
	_saveButton.disabled = current_length > maxContentLength
	_refresh_save_color()

func refreshStamps() -> void:
	for widget in _stampWidgets:
		widget.queue_free()
	_stampWidgets.clear()
	if not currentItem or not currentItem.has_meta("stamps"):
		_layout()
		return

	for entry in currentItem.get_meta("stamps"):
		if not entry.has("stampState"):
			continue
		var widget = StampWidgetScript.new()
		if entry.stampState == "signature":
			# A pen signature: the signer's name in the pen's colour, without a border.
			widget.setup(str(entry.get("signer", "")), Color.html(str(entry.get("color", "#333333ff"))), true)
		else:
			widget.setup(tr(StampInfo.getStampName(entry.stampState)), StampInfo.getStampColor(entry.stampState))
		_stampLayer.add_child(widget)
		_stampWidgets.append(widget)
	_layout()

# --- layout -------------------------------------------------------------------------------

static func _trunc(value: Vector2) -> Vector2:
	return Vector2(int(value.x), int(value.y))

# Measures the page content for a viewport `view_width` wide.
func _measure_content(view_width: float) -> Dictionary:
	var margin: Vector4 = vis.get("contentMargin", Vector4.ZERO)
	var inner_available = maxf(view_width - margin.x - margin.z, 0.0)
	var box_width = minf(inner_available, contentMaxWidth)

	var header_margin: Vector4 = vis.get("headerMargin", Vector4.ZERO)
	var header_size = _header.texture.get_size() if _header.texture else Vector2.ZERO
	var header_desired = Vector2(header_size.x + header_margin.x + header_margin.z, header_size.y + header_margin.y + header_margin.w)
	var footer_margin: Vector4 = vis.get("footerMargin", Vector4.ZERO)
	var footer_size = _footer.texture.get_size() if _footer.texture else Vector2.ZERO
	var footer_desired = Vector2(footer_size.x + footer_margin.x + footer_margin.z, footer_size.y + footer_margin.y + footer_margin.w)

	# TextAlignmentPadding: keeps the first text line on a content-image rule however
	# tall the header is (PaperWindow.Draw).
	var lines: int = vis.get("contentImageNumLines", 1)
	var line_height = _regular.line_height()
	var header_in_lines = header_desired.y / float(line_height * lines)
	var padding_lines = ceil(header_in_lines) - header_in_lines
	var padding = line_height * padding_lines * lines

	var blank_size = _blank.measure(box_width) if _blank.visible else Vector2.ZERO
	var written_size = _written.measure(box_width) if _written.visible else Vector2.ZERO
	var input_desired = inputMinHeight + _regular.height() if isEditing else 0.0

	var stack_height = header_desired.y + padding + blank_size.y + written_size.y + input_desired + footer_desired.y
	var inner_height = maxf(stack_height, stampDisplayMin + stampDisplayMargin * 2.0)
	return {
		"margin": margin, "innerAvailable": inner_available, "boxWidth": box_width,
		"headerMargin": header_margin, "headerSize": header_size, "headerDesired": header_desired,
		"footerMargin": footer_margin, "footerSize": footer_size, "footerDesired": footer_desired,
		"padding": padding, "blankSize": blank_size, "writtenSize": written_size,
		"inputDesired": input_desired, "stackHeight": stack_height, "innerHeight": inner_height,
		"totalHeight": inner_height + margin.y + margin.w,
	}

func _layout() -> void:
	if not _built or not currentItem:
		return
	var window = size
	var area: Vector2 = vis.get("maxWritableArea", Vector2.ZERO)
	var inset: Vector4 = _paperBackground.content_margin()

	# --- close row: AngleRect panel, Margin 6, top right
	var close_panel = closeIconSize + Vector2(angleRectPatch * 2.0, angleRectPatch * 2.0)
	_closePanel.size = _trunc(close_panel)
	_closePanel.position = _trunc(Vector2(window.x - closePanelMargin - close_panel.x, closePanelMargin))
	_closeButton.position = Vector2(angleRectPatch, angleRectPatch)
	_closeButton.size = closeIconSize
	var close_row = _close_row_size().y

	# --- paper background (vertical expand)
	var edit_row = _edit_row_height()
	var background_rect = Rect2(0, close_row, window.x, maxf(window.y - close_row - edit_row, 0.0))
	_paperBackground.position = _trunc(background_rect.position)
	_paperBackground.size = _trunc(background_rect.size)

	# --- ScrollingContents: Stretch inside the border, constrained by MaxWritableArea
	var view_area = Vector2(maxf(background_rect.size.x - inset.x - inset.z, 0.0), maxf(background_rect.size.y - inset.y - inset.w, 0.0))
	var view_size = view_area
	if area.x > 0:
		view_size.x = area.x
	if area.y > 0:
		view_size.y = area.y
	var view_position = background_rect.position + Vector2(inset.x, inset.y) + Vector2((view_area.x - view_size.x) / 2.0, (view_area.y - view_size.y) / 2.0)
	view_size = _trunc(view_size)
	_viewport.position = _trunc(view_position)
	_viewport.size = view_size

	# --- ScrollContainer: a vertical bar appears when the content is taller
	var measured = _measure_content(view_size.x)
	var bar_width = 0.0
	if measured.totalHeight > view_size.y:
		bar_width = scrollBarWidth
		measured = _measure_content(view_size.x - bar_width)
	var content_width = view_size.x - bar_width
	var content_height = maxf(measured.totalHeight, view_size.y)
	_scrollMax = maxf(content_height - view_size.y, 0.0)
	_scroll = clampf(_scroll, 0.0, _scrollMax)

	_arrange_content(measured, content_width, content_height)

	_scrollBar.visible = bar_width > 0.0
	_scrollBar.position = Vector2(view_size.x - scrollBarWidth, 0)
	_scrollBar.size = Vector2(scrollBarWidth, view_size.y)
	_scrollBar.queue_redraw()

	# --- edit row: Save button, Margin 6, right aligned
	if isEditing:
		var button_size = _save_button_size()
		var row_top = window.y - edit_row
		var button_position = Vector2(window.x - editRowMargin - button_size.x, row_top + editRowMargin)
		_saveStyle.size = _trunc(button_size)
		_saveStyle.position = _trunc(button_position)
		_saveButton.size = _trunc(button_size)
		_saveButton.position = _trunc(button_position)

func _arrange_content(m: Dictionary, content_width: float, content_height: float) -> void:
	var margin: Vector4 = m.margin
	var box_width: float = m.boxWidth
	var inner_height = content_height - margin.y - margin.w

	# PaperContent: inside its margin, Stretch but at most 600 wide, so centred.
	var content_position = Vector2(margin.x + (m.innerAvailable - box_width) / 2.0, margin.y - _scroll)
	_content.position = _trunc(content_position)
	_content.size = _trunc(Vector2(box_width, inner_height))
	_contentPanel.position = Vector2.ZERO
	_contentPanel.size = _content.size

	var cursor = 0.0
	# HeaderImage: Center / Top inside its Margin.
	_place_image(_header, m.headerSize, m.headerMargin, box_width, cursor)
	cursor += m.headerDesired.y
	cursor += m.padding

	var blank_size: Vector2 = m.blankSize
	_blank.position = _trunc(Vector2((box_width - minf(box_width, blank_size.x)) / 2.0, cursor))
	_blank.size = _trunc(Vector2(minf(box_width, blank_size.x), blank_size.y))
	cursor += blank_size.y

	var written_size: Vector2 = m.writtenSize
	_written.position = _trunc(Vector2(0, cursor))
	_written.size = _trunc(Vector2(box_width, written_size.y))
	cursor += written_size.y

	# InputContainer (vertical expand): takes what is left of the page.
	if isEditing:
		var remaining = inner_height - (m.stackHeight - m.inputDesired)
		var input_height = maxf(m.inputDesired, remaining)
		var fill_height = _regular.height()
		var panel_height = input_height - fill_height
		_inputPanel.position = _trunc(Vector2(0, cursor))
		_inputPanel.size = _trunc(Vector2(box_width, panel_height))
		var panel_inset = _inputPanel.content_box(_inputPanel.size)
		_textEdit.position = _inputPanel.position + panel_inset.position
		_textEdit.size = panel_inset.size
		_fillStatus.position = _trunc(Vector2(0, cursor + panel_height))
		_fillStatus.size = _trunc(Vector2(box_width, fill_height))
		cursor += input_height

	_place_image(_footer, m.footerSize, m.footerMargin, box_width, cursor)

	# StampCollection: Margin 6, stretched across the page, 150 tall, bottom aligned.
	var stamp_area = Vector2(maxf(box_width - stampDisplayMargin * 2.0, 0.0), stampDisplayMin)
	_stampLayer.position = _trunc(Vector2(stampDisplayMargin, inner_height - stampDisplayMargin - stampDisplayMin))
	_stampLayer.size = _trunc(stamp_area)
	_arrange_stamps(stamp_area, box_width)

# Control with HorizontalAlignment Center and a Margin, in a slot `box_width` wide.
func _place_image(image: TextureRect, tex_size: Vector2, image_margin: Vector4, box_width: float, top: float) -> void:
	var free_width = box_width - image_margin.x - image_margin.z
	var width = minf(free_width, tex_size.x)
	image.position = _trunc(Vector2(image_margin.x + (free_width - width) / 2.0, top + image_margin.y))
	image.size = _trunc(Vector2(width, tex_size.y))

# StampCollection.ArrangeOverride: the first stamp sits in the centre, the others
# move out around a circle in 90 degree steps with a small random tilt.
func _arrange_stamps(final_size: Vector2, box_width: float) -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = _stampSeed
	var radius = (final_size * 0.5).length()
	var dtheta = -deg_to_rad(90.0)
	var theta0 = rng.randi_range(0, 2) * dtheta
	var this_center = final_size * 0.5

	for i in _stampWidgets.size():
		var widget = _stampWidgets[i]
		var orientation = deg_to_rad((rng.randf() - 0.5) * 10.0)
		var theta = theta0 + dtheta * 0.5 + dtheta * i
		if i > 4:
			# Integer division, exactly as MathF.Log(1 + i / 4) does in C#.
			theta += log(1 + i / 4) * dtheta
		var child_center = this_center
		if i > 0:
			child_center += Vector2(cos(theta), sin(theta)) * radius

		# The label may shrink to fit the width the collection can give a stamp.
		widget.measure(Vector2(maxf(box_width - stampDisplayMargin * 2.0, 0.0), INF))
		var desired: Vector2 = widget.desired_size()
		var half = desired * 0.5
		var c = half * absf(cos(orientation))
		var s = half * absf(sin(orientation))
		var page_half = Vector2(c.x + s.y, s.x + c.y)
		var low = page_half
		var high = final_size - page_half
		var clamped = Vector2(minf(high.x, maxf(low.x, child_center.x)), minf(high.y, maxf(low.y, child_center.y)))
		var final_position = clamped - page_half
		var integer_position = Vector2(int(final_position.x), int(final_position.y))
		widget.place(integer_position + Vector2(widgetMargin(), widgetMargin()), orientation)

static func widgetMargin() -> float:
	return StampWidgetScript.outerMargin

func _draw_scroll_bar() -> void:
	if _scrollMax <= 0.0 or _viewport.size.y <= 0.0:
		return
	var track = _viewport.size.y
	var page = track
	var total = track + _scrollMax
	var grabber_height = maxf(track * page / total, scrollBarWidth)
	var grabber_top = (track - grabber_height) * (_scroll / _scrollMax)
	_scrollBar.draw_rect(Rect2(0, int(grabber_top), scrollBarWidth, int(grabber_height)), scrollGrabberColor)

# --- saving / closing -------------------------------------------------------------------

func save() -> void:
	# Mirrors SS14's OnInputTextMessage: text longer than ContentSize is rejected
	# outright (the paper keeps its previous content) rather than truncated.
	if _textEdit.text.length() > maxContentLength:
		return

	currentItem.set_meta("content", _textEdit.text)

	if currentItem.get_meta("type") == "txt":
		var sprite = currentItem.get_node("CollisionShape2D").get_node("Sprite2D")
		sprite.setActiveTexture(currentItem.get_meta("content").length() > 0)

# PaperSystem.OnInputTextMessage: saving writes the text, plays the paper's scribble
# sound and returns the paper to read mode.
func _commit() -> void:
	if _textEdit.text.length() <= maxContentLength:
		save()
		PaperSounds.play(self)
	currentItem.set_meta("writingUnlocked", false)
	refreshWritingLock()

func _save_button_pressed() -> void:
	_commit()

func _close_button_pressed() -> void:
	closed.emit()

func _visibility_changed() -> void:
	if not visible:
		currentDrag = DragMode.NONE
		if currentItem:
			currentItem.set_meta("writingUnlocked", false)

func _text_changed() -> void:
	_updateFillStatus()
	save()

func _input(event: InputEvent) -> void:
	if not visible or not event.is_pressed():
		return
	if not Rect2(global_position, size).has_point(get_global_mouse_position()):
		return

	if event.is_action("saveDocument") and isEditing:
		_commit()
	if event.is_action("closeEditor"):
		closed.emit()

# --- dragging / resizing (BaseWindow) -----------------------------------------------------

func _getDragModeFor(local_position: Vector2) -> int:
	var mode = DragMode.NONE
	if local_position.y < dragMarginSize:
		mode |= DragMode.TOP
	elif local_position.y > size.y - dragMarginSize:
		mode |= DragMode.BOTTOM
	if local_position.x < dragMarginSize:
		mode |= DragMode.LEFT
	elif local_position.x > size.x - dragMarginSize:
		mode |= DragMode.RIGHT
	# PaperWindow.GetDragModeFor: axes MaxWritableArea fixes cannot be resized.
	if (mode & _allowed_resize()) == DragMode.NONE:
		return DragMode.MOVE
	return mode & _allowed_resize()

func _startDrag(local_position: Vector2) -> void:
	currentDrag = _getDragModeFor(local_position)
	dragOffset = get_global_mouse_position() - global_position
	dragStartRect = Rect2(global_position, size)

func _gui_input(event: InputEvent) -> void:
	_handleDragInput(event)

func _background_input(event: InputEvent) -> void:
	_handleDragInput(event)

func _viewport_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_scroll_by(-scrollSpeed)
			return
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_scroll_by(scrollSpeed)
			return
	_handleDragInput(event)

func _scroll_by(amount: float) -> void:
	_scroll = clampf(_scroll + amount, 0.0, _scrollMax)
	_layout()

func _handleDragInput(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_startDrag(get_local_mouse_position())
		else:
			currentDrag = DragMode.NONE

func _process(_delta: float) -> void:
	if currentDrag == DragMode.NONE:
		return

	var mouse = get_global_mouse_position()
	if currentDrag == DragMode.MOVE:
		global_position = mouse - dragOffset
		return

	var rect = dragStartRect
	if currentDrag & DragMode.RIGHT:
		rect.size.x = maxf(minWindowSize.x, mouse.x - dragStartRect.position.x)
	if currentDrag & DragMode.BOTTOM:
		rect.size.y = maxf(minWindowSize.y, mouse.y - dragStartRect.position.y)
	if currentDrag & DragMode.LEFT:
		var new_left = minf(mouse.x - dragOffset.x, dragStartRect.position.x + dragStartRect.size.x - minWindowSize.x)
		rect.size.x = dragStartRect.position.x + dragStartRect.size.x - new_left
		rect.position.x = new_left
	if currentDrag & DragMode.TOP:
		var new_top = minf(mouse.y - dragOffset.y, dragStartRect.position.y + dragStartRect.size.y - minWindowSize.y)
		rect.size.y = dragStartRect.position.y + dragStartRect.size.y - new_top
		rect.position.y = new_top

	global_position = rect.position
	size = rect.size
