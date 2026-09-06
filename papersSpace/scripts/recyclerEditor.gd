extends Control

signal closed

@onready var closeButton: Button = $panel/layout/titleBar/close
@onready var titleBar: HBoxContainer = $panel/layout/titleBar
@onready var flushButton: Button = $panel/layout/buttons/flush
@onready var ejectButton: Button = $panel/layout/buttons/eject
@onready var statusLabel: Label = $panel/layout/status

var currentRecycler
var dragging = false
var dragOffset = Vector2.ZERO

func _ready() -> void :
	closeButton.pressed.connect(func(): closed.emit())
	titleBar.gui_input.connect(_on_titleBar_input)
	flushButton.pressed.connect(_on_flush_pressed)
	ejectButton.pressed.connect(_on_eject_pressed)

	LanguageSwitcher.localeChanged.connect(_refreshLocaleStrings)
	_refreshLocaleStrings()

func _refreshLocaleStrings() -> void :
	closeButton.text = tr("ui_close")
	flushButton.text = tr("ui_recycler_flush")
	ejectButton.text = tr("ui_recycler_eject")

func open(recyclerNode) -> void :
	currentRecycler = recyclerNode
	_refresh()
	visible = true

func _process(_delta: float) -> void :
	if not visible or not currentRecycler:
		return
	if dragging:
		global_position = get_global_mouse_position() - dragOffset
	_refresh()

func _refresh() -> void :
	var itemCount = currentRecycler.insertedItems.size()
	var hasItems = itemCount > 0
	flushButton.disabled = currentRecycler.busy or not hasItems
	ejectButton.disabled = currentRecycler.busy or not hasItems

	if currentRecycler.busy:
		statusLabel.text = tr("ui_recycler_busy")
	elif hasItems:
		statusLabel.text = tr("ui_recycler_item_loaded") % itemCount
	else:
		statusLabel.text = tr("ui_recycler_ready")

func _on_flush_pressed() -> void :
	currentRecycler.flushInsertedItems()
	closed.emit()

func _on_eject_pressed() -> void :
	currentRecycler.ejectInsertedItems()

func _on_titleBar_input(event: InputEvent) -> void :
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		dragging = event.pressed
		if dragging:
			dragOffset = get_global_mouse_position() - global_position
