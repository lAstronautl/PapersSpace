extends Node2D

@onready var itemsParent = $"../items"
@onready var backgroundTextureRect = $"../env/floor"

@export var diskScene: PackedScene
@export var paperScene: PackedScene
@export var wehScene: PackedScene

var saveFilePath = "user://items.save"
var customBGPath = "user://background.png"

func saveItems(path: String):
	var saveData = []

	for child in itemsParent.get_children():
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
		var instance = getSceneFromType(node_data.meta.type).instantiate()
		instance.name = node_data.name
		instance.position = Vector2(node_data.position.x, node_data.position.y)
		instance.rotation = node_data.rotation


		for key in node_data.meta:
			instance.set_meta(key, node_data.meta[key])

		if instance.get_meta("type") == "txt":
			if instance.get_meta("content").length() > 0:
				instance.get_node("CollisionShape2D").get_node("Sprite2D").setActiveTexture(true)
			else:
				instance.get_node("CollisionShape2D").get_node("Sprite2D").setActiveTexture(false)

		itemsParent.add_child(instance)

	print("Loaded successfully")

func getSceneFromType(type: String) -> PackedScene:
	match type:
		"txt":
			return paperScene
		"flop":
			return diskScene
		"weh":
			return wehScene
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

	loadItems(saveFilePath)
	loadBG(customBGPath)

	if itemsParent.get_child_count() < 1:
		var tutorial = paperScene.instantiate()
		tutorial.name = "right click me"
		tutorial.set_meta("content", "hi! :3\nthis is a note-taking program i made for fun. i hope you enjoy it.\n\ncontrols:\nLMB - drag item around\nRMB - edit hovered item\nA/D - rotate held item\nE - snap to 45d angle\nspace - make new paper\nESC - close item editor\n\nall your items are saved when you close the program.")
		tutorial.get_node("CollisionShape2D").get_node("Sprite2D").setActiveTexture(true)
		itemsParent.add_child(tutorial)

func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		saveItems(saveFilePath)
		get_tree().quit()
