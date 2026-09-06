extends Control

signal closed

@onready var labelInput: LineEdit = $panel/layout/LabelInput
@onready var closeButton: Button = $panel/layout/titleBar/close
@onready var titleBar: HBoxContainer = $panel/layout/titleBar

var currentLabeler: RigidBody2D
var dragging = false
var dragOffset = Vector2.ZERO

func _ready() -> void :
	closeButton.pressed.connect(func(): closed.emit())
	labelInput.text_changed.connect(_on_text_changed)
	titleBar.gui_input.connect(_on_titleBar_input)

func open(labelerItem: RigidBody2D) -> void :
	currentLabeler = labelerItem
	labelInput.text = labelerItem.assignedLabel
	visible = true

func _on_text_changed(newText: String) -> void :
	if currentLabeler:
		currentLabeler.assignedLabel = newText

func _on_titleBar_input(event: InputEvent) -> void :
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		dragging = event.pressed
		if dragging:
			dragOffset = get_global_mouse_position() - global_position

func _process(_delta: float) -> void :
	if dragging:
		global_position = get_global_mouse_position() - dragOffset
