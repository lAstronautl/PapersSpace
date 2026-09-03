extends Control

@onready var textEditor: TextEdit = $TextEdit
@onready var nameEditor: TextEdit = $NameEdit
@onready var saveButton: Button = $save
@onready var closeButton: Button = $close
@onready var rmButton: Button = $rm
@onready var rmConfirmButton: Button = $rmConfirm

var currentItem: RigidBody2D

func _ready():
	textEditor.text_changed.connect(_text_changed)
	nameEditor.text_changed.connect(_name_changed)
	saveButton.pressed.connect(_save_button_pressed)
	closeButton.pressed.connect(_close_button_pressed)
	rmButton.pressed.connect(_rm_button_pressed)
	rmConfirmButton.pressed.connect(_rm_confirm_button_pressed)
	visibility_changed.connect(_visibility_changed)

func open(item: RigidBody2D) -> void :
	nameEditor.text = item.name
	textEditor.text = item.get_meta("content")

	currentItem = item
	visible = true

func save() -> void :
	currentItem.name = nameEditor.text
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
	visible = false

func _rm_button_pressed():
	rmConfirmButton.visible = not rmConfirmButton.visible

func _rm_confirm_button_pressed():
	currentItem.queue_free()
	visible = false

func _visibility_changed():
	rmConfirmButton.visible = false

func _text_changed():
	save()

func _name_changed():
	save()

func _input(event: InputEvent) -> void :
	if visible and event.is_pressed():
		if event.is_action("saveDocument"):
			save()
		if event.is_action("closeEditor"):
			visible = false
