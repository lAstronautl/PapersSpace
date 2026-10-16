extends Node2D

const StampInfo = preload("res://scripts/stampInfo.gd")
const PenInfo = preload("res://scripts/penInfo.gd")

var stampVariants: Array = StampInfo.getStampKeys()

@export var pointingArrow: PackedScene
@export var stampScene: PackedScene
@export var penScene: PackedScene
@onready var itemsParent: Node2D = $"../../items"
@onready var itemInteractionControler: Node2D = $"../../itemInteractionControler"
@onready var worldViewport: SubViewport = $"../.."

var nextStampVariantIndex = 0
var nextPenIndex = 0

func spawnStamp() -> void :
	var variant = stampVariants[nextStampVariantIndex % stampVariants.size()]
	nextStampVariantIndex += 1

	var item = stampScene.instantiate()
	item.name = "stamp-" + variant
	item.set_meta("stampState", variant)
	item.position = self.global_position

	itemInteractionControler.initItem(item)
	itemsParent.add_child(item)
	item.setVariant(variant)

func spawnPen() -> void :
	var keys = PenInfo.getPenKeys()
	var variant = keys[nextPenIndex % keys.size()]
	nextPenIndex += 1

	var item = penScene.instantiate()
	item.name = "pen-" + variant
	item.position = self.global_position

	itemInteractionControler.initItem(item)
	itemsParent.add_child(item)
	item.setVariant(variant)

func _input(event: InputEvent) -> void :
	if event.is_pressed():
		if event.is_action("spawnStamp") and not event.is_echo():
			spawnStamp()
		if event.is_action("spawnPen") and not event.is_echo():
			spawnPen()
		if event.is_action("point"):
			var item = pointingArrow.instantiate()
			item.position = self.global_position
			worldViewport.add_child(item)
