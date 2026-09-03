extends Node2D

@export var pointingArrow: PackedScene
@export var document: PackedScene
@onready var fileEditor: Control = $"../../fileEditor"
@onready var itemsParent: Node2D = $"../../items"
@onready var itemInteractionControler: Node2D = $"../../itemInteractionControler"

func _input(event: InputEvent) -> void :
	if not fileEditor.visible and event.is_pressed():
		if event.is_action("newDocument") and not event.is_echo():
			var instanceName = "paper"
			var dupelicateNumber = 1
			while itemsParent.has_node(instanceName):
				dupelicateNumber += 1
				instanceName = "paper" + str(dupelicateNumber)

			var item = document.instantiate()
			item.name = instanceName
			item.set_meta("content", "")
			item.position = self.global_position

			itemInteractionControler.initItem(item)
			itemsParent.add_child(item)
		if event.is_action("point"):
			var item = pointingArrow.instantiate()
			item.position = self.global_position
			get_tree().root.add_child(item)
