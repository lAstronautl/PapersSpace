extends Node2D

@export var pointingArrow: PackedScene
@onready var worldViewport: SubViewport = $"../.."

var nextStampVariantIndex = 0
var nextPenIndex = 0

func _input(event: InputEvent) -> void :
	if event.is_pressed():
		if event.is_action("point"):
			var item = pointingArrow.instantiate()
			item.position = self.global_position
			worldViewport.add_child(item)
