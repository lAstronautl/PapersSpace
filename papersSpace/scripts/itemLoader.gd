extends Node2D

const PaperVariants = preload("res://scripts/paperVariants.gd")

@onready var itemsParent = $"../items"
@onready var backgroundTextureRect = $"../env/floor"

@export var diskScene: PackedScene
@export var paperScene: PackedScene
@export var wehScene: PackedScene
@export var labelerScene: PackedScene
@export var stampScene: PackedScene
@export var penScene: PackedScene
@export var tonerCartridgeScene: PackedScene
@export var paperScrapScene: PackedScene
@export var wrenchScene: PackedScene

var saveFilePath = "user://items.save"
var customBGPath = "user://background.png"

func saveItems(path: String):
	var saveData = []

	for child in itemsParent.get_children():
		# Sound players and other transient nodes live next to the items; only real
		# items (which carry a type) are saved.
		if not child.has_meta("type"):
			continue
		var nodeData = {
			"name": child.name, 
			"position": {
				"x": child.position.x, 
				"y": child.position.y
			}, 
			"rotation": child.rotation, 
			"meta": {}
		}


		for key in child.get_meta_list():
			nodeData.meta[key] = child.get_meta(key)

		saveData.append(nodeData)

	var file = FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(saveData, "\t"))
		file.close()
		print("Game saved successfully!")
	else:
		print("Failed to save game")

func loadItems(path: String):
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		print("Failed to open save file")
		return

	var json_string = file.get_as_text()
	file.close()

	var json = JSON.new()
	var parse_result = json.parse(json_string)
	if parse_result != OK:
		print("Failed to parse save file")
		return

	var save_data = json.data


	for child in itemsParent.get_children():
		child.queue_free()

	for node_data in save_data:
		if not node_data.has("meta") or not node_data.meta.has("type"):
			continue
		# Saves from before every pen had its own state: "cyberPen" was the Cybersun pen.
		if node_data.meta.type == "cyberPen":
			node_data.meta.type = "pen"
			node_data.meta.penState = "cyber"
		var scene = getSceneFromType(node_data.meta.type)
		if scene == null:
			continue
		var instance = scene.instantiate()
		instance.name = node_data.name
		instance.position = Vector2(node_data.position.x, node_data.position.y)
		instance.rotation = node_data.rotation


		for key in node_data.meta:
			instance.set_meta(key, node_data.meta[key])

		if instance.get_meta("type") == "txt":
			var sprite = instance.get_node("CollisionShape2D").get_node("Sprite2D")
			if instance.has_meta("paperStyle"):
				sprite.setPaperStyle(instance.get_meta("paperStyle"))
			var variantConfig = PaperVariants.getConfig(instance.get_meta("paperVariant", "default"))
			if variantConfig.has("worldTexture"):
				sprite.setVariantTextures(load(variantConfig.worldTexture), load(variantConfig.get("worldTextureEmpty", variantConfig.worldTexture)))
			if str(instance.get_meta("content", "")).length() > 0:
				sprite.setActiveTexture(true)
			else:
				sprite.setActiveTexture(false)
			if instance.has_meta("stamps"):
				instance.get_node("CollisionShape2D/StampOverlay").loadStamps(instance.get_meta("stamps"))

		if instance.get_meta("type") == "stamp" and instance.has_meta("stampState"):
			instance.setVariant(instance.get_meta("stampState"))

		if instance.get_meta("type") == "pen":
			instance.setVariant(instance.get_meta("penState", "pen"))

		itemsParent.add_child(instance)

	print("Loaded successfully")

# A fresh paper of the given visual type: the printer prints these and the
# vending machine dispenses them. `baseName` gets a number appended until it is
# unique among the items.
func createPaper(paperVariant: String, content: String, stamps: Array, baseName: String, at: Vector2) -> RigidBody2D:
	var config = PaperVariants.getConfig(paperVariant)

	var item = paperScene.instantiate()
	var instanceName = baseName
	var duplicateNumber = 1
	while itemsParent.has_node(instanceName):
		duplicateNumber += 1
		instanceName = baseName + str(duplicateNumber)
	item.name = instanceName

	item.set_meta("content", content)
	item.set_meta("paperVariant", paperVariant)
	item.set_meta("paperStyle", config.get("color", "default"))
	item.global_position = at

	itemsParent.add_child(item)
	$"../itemInteractionControler".initItem(item)

	var sprite2D = item.get_node("CollisionShape2D").get_node("Sprite2D")
	sprite2D.setPaperStyle(config.get("color", "default"))
	if config.has("worldTexture"):
		sprite2D.setVariantTextures(load(config.worldTexture), load(config.get("worldTextureEmpty", config.worldTexture)))
	sprite2D.setActiveTexture(content.length() > 0)

	if not stamps.is_empty():
		item.set_meta("stamps", stamps)
		item.get_node("CollisionShape2D/StampOverlay").loadStamps(stamps)
	return item

func getSceneFromType(type: String) -> PackedScene:
	match type:
		"txt":
			return paperScene
		"flop":
			return diskScene
		"weh":
			return wehScene
		"labeler":
			return labelerScene
		"stamp":
			return stampScene
		"pen":
			return penScene
		"tonerCartridge":
			return tonerCartridgeScene
		"paperScrap":
			return paperScrapScene
		"wrench":
			return wrenchScene
	return null

func loadBG(path: String):
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		print("Failed to open custom bg file")
		return

	var image = Image.new()
	var error = image.load(path)

	if error != OK:
		print("Error loading image: ", error)
		return

	var texture = ImageTexture.create_from_image(image)
	backgroundTextureRect.texture = texture

func _ready() -> void :
	if OS.is_debug_build():
		saveFilePath = "user://DEBUG.save"

	# The tutorial paper is a regular item placed directly in mainRoom.tscn
	# (node "tutorialPaper") rather than spawned here, so it behaves exactly
	# like any other item (movable, stampable, saved/loaded normally). Its
	# localized name/content is only filled in once, the first time the game
	# ever runs (i.e. before any save file exists to load over it).
	var hasSaveFile = FileAccess.file_exists(saveFilePath)

	loadItems(saveFilePath)
	loadBG(customBGPath)

	if not hasSaveFile and itemsParent.has_node("tutorialPaper"):
		var tutorial = itemsParent.get_node("tutorialPaper")
		tutorial.name = tr("item_tutorial_name")
		tutorial.set_meta("content", tr("item_tutorial_content"))
		tutorial.get_node("CollisionShape2D").get_node("Sprite2D").setActiveTexture(true)

func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		saveItems(saveFilePath)
		get_tree().quit()
