extends Control

# VendingMachineMenu: a window with a search bar over the list of everything the
# machine holds - an icon and the item name per row, ordering disabled while the
# machine ejects - and the "All sales final. / v1.1" footer. The window resizes
# with its content like SetSizeAfterUpdate.
signal closed

const VendingCatalog = preload("res://scripts/vendingCatalog.gd")

const themeResource = preload("res://misc/flatTheme.tres")
const font = preload("res://fonts/NotoSans/NotoSans-Regular.ttf")
const flatStyle = preload("res://misc/flat.tres")
const flatDarkStyle = preload("res://misc/flatDark.tres")

const fontSize = 16
const iconSize = Vector2i(32, 32)

var machine
var _dragging = false
var _dragOffset = Vector2.ZERO
var _enabled = true
var _title: Label
var _titleBar: HBoxContainer
var _closeButton: Button
var _search: LineEdit
var _list: ItemList
var _footerLeft: Label
var _footerRight: Label

func _ready() -> void :
	var panel = PanelContainer.new()
	panel.theme = themeResource
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(panel)

	var layout = VBoxContainer.new()
	panel.add_child(layout)

	_titleBar = HBoxContainer.new()
	_titleBar.gui_input.connect(_on_titleBar_input)
	layout.add_child(_titleBar)
	_title = _label(18)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_titleBar.add_child(_title)
	_closeButton = Button.new()
	_closeButton.add_theme_font_override("font", font)
	_closeButton.add_theme_stylebox_override("normal", flatStyle)
	_closeButton.add_theme_stylebox_override("pressed", flatDarkStyle)
	_closeButton.add_theme_stylebox_override("hover", flatDarkStyle)
	_closeButton.pressed.connect(func(): closed.emit())
	_titleBar.add_child(_closeButton)

	_search = LineEdit.new()
	_search.add_theme_font_override("font", font)
	_search.add_theme_font_size_override("font_size", fontSize)
	_search.text_changed.connect(func(_text): _fillList())
	layout.add_child(_search)

	_list = ItemList.new()
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_list.fixed_icon_size = iconSize
	_list.add_theme_font_override("font", font)
	_list.add_theme_font_size_override("font_size", fontSize)
	_list.item_clicked.connect(_on_item_clicked)
	layout.add_child(_list)

	layout.add_child(HSeparator.new())
	var footer = HBoxContainer.new()
	layout.add_child(footer)
	_footerLeft = _label(fontSize - 4)
	footer.add_child(_footerLeft)
	_footerRight = _label(fontSize - 4)
	_footerRight.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_footerRight.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	footer.add_child(_footerRight)

	LanguageSwitcher.localeChanged.connect(_refreshLocaleStrings)
	_refreshLocaleStrings()

func _label(size: int) -> Label:
	var label = Label.new()
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", size)
	return label

func _refreshLocaleStrings() -> void :
	_title.text = tr("ui_vend_title")
	_closeButton.text = tr("ui_close")
	_search.placeholder_text = tr("ui_vend_search")
	_footerLeft.text = tr("ui_vend_flavor_left")
	_footerRight.text = tr("ui_vend_flavor_right")
	_fillList()

func open(machineNode) -> void :
	machine = machineNode
	position = Vector2(180, 160)
	_fillList()
	visible = true

# Rows are filtered by name, ignoring case (DataFilterCondition).
func _fillList() -> void :
	if machine == null or _list == null:
		return
	var filter = _search.text
	_list.clear()
	var longest = 0
	for entry in machine.inventory:
		var itemName = VendingCatalog.getName(entry)
		if filter != "" and not itemName.containsn(filter):
			continue
		var index = _list.add_item(itemName, VendingCatalog.getIcon(entry))
		_list.set_item_metadata(index, entry)
		longest = maxi(longest, itemName.length())
	_enabled = not machine.ejecting
	_applyEnabled()
	_resize(longest, machine.inventory.size())

# SetSizeAfterUpdate
func _resize(longestEntryLength: int, contentCount: int) -> void :
	size = Vector2(clampf((longestEntryLength + 2) * 12, 250, 400), clampf(contentCount * 50, 150, 350))

func _applyEnabled() -> void :
	for index in _list.item_count:
		_list.set_item_disabled(index, not _enabled)

func _process(_delta: float) -> void :
	if not visible or not machine:
		return
	if _dragging:
		global_position = get_global_mouse_position() - _dragOffset
	if _enabled == machine.ejecting:
		_enabled = not machine.ejecting
		_applyEnabled()

func _on_item_clicked(index: int, _atPosition: Vector2, mouseButton: int) -> void :
	if mouseButton != MOUSE_BUTTON_LEFT or not _enabled:
		return
	if machine.tryEject(_list.get_item_metadata(index)):
		_enabled = false
		_applyEnabled()

func _on_titleBar_input(event: InputEvent) -> void :
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed
		if _dragging:
			_dragOffset = get_global_mouse_position() - global_position
