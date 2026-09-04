extends Control

signal closed

const PaperVariants = preload("res://scripts/paperVariants.gd")

@onready var closeButton: Button = $panel/layout/titleBar/close
@onready var titleBar: HBoxContainer = $panel/layout/titleBar
@onready var variantOption: OptionButton = $panel/layout/variantOption
@onready var copyButton: Button = $panel/layout/buttons/copy
@onready var printButton: Button = $panel/layout/buttons/print
@onready var ejectButton: Button = $panel/layout/buttons/eject
@onready var statusLabel: Label = $panel/layout/status
@onready var tonerLabel: Label = $panel/layout/tonerRow/toner
@onready var tonerBar: ProgressBar = $panel/layout/tonerRow/tonerBar

var currentPrinter
var dragging = false
var dragOffset = Vector2.ZERO

func _ready() -> void :
	closeButton.pressed.connect(func(): closed.emit())
	titleBar.gui_input.connect(_on_titleBar_input)
	copyButton.pressed.connect(_on_copy_pressed)
	printButton.pressed.connect(_on_print_pressed)
	ejectButton.pressed.connect(_on_eject_pressed)

	for variantId in PaperVariants.variants.keys():
		variantOption.add_item(variantId)

	LanguageSwitcher.localeChanged.connect(_refreshLocaleStrings)
	_refreshLocaleStrings()

func _refreshLocaleStrings() -> void :
	closeButton.text = tr("ui_close")
	copyButton.text = tr("ui_printer_copy")
	printButton.text = tr("ui_printer_print")
	ejectButton.text = tr("ui_printer_eject")

func open(printerNode) -> void :
	currentPrinter = printerNode
	_refresh()
	visible = true

func _process(_delta: float) -> void :
	if not visible or not currentPrinter:
		return
	if dragging:
		global_position = get_global_mouse_position() - dragOffset
	_refresh()

func _refresh() -> void :
	var hasPaper = currentPrinter.insertedPaper != null
	copyButton.disabled = currentPrinter.busy or not hasPaper or not currentPrinter.hasToner()
	printButton.disabled = currentPrinter.busy or not currentPrinter.hasToner()
	ejectButton.disabled = currentPrinter.busy or not hasPaper

	tonerLabel.text = tr("ui_printer_toner") % [currentPrinter.toner, currentPrinter.maxToner]
	tonerBar.value = float(currentPrinter.toner) / currentPrinter.maxToner

	if currentPrinter.busy:
		statusLabel.text = tr("ui_printer_busy")
	elif hasPaper:
		statusLabel.text = tr("ui_printer_paper_loaded")
	else:
		statusLabel.text = tr("ui_printer_ready")

func _on_copy_pressed() -> void :
	currentPrinter.startCopy()

func _on_print_pressed() -> void :
	var variantId = variantOption.get_item_text(variantOption.selected) if variantOption.selected >= 0 else "default"
	currentPrinter.startPrint(variantId)

func _on_eject_pressed() -> void :
	currentPrinter.ejectInsertedPaper()

func _on_titleBar_input(event: InputEvent) -> void :
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		dragging = event.pressed
		if dragging:
			dragOffset = get_global_mouse_position() - global_position
