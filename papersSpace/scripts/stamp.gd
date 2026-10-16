extends RigidBody2D

@export var stampState: String = "cap"

const StampInfo = preload("res://scripts/stampInfo.gd")

const itemSpritesPath = "res://png/item/stamps/"

func _ready() -> void :
	setVariant(stampState)

func setVariant(newStampState: String) -> void :
	stampState = StampInfo.resolveKey(newStampState)
	var texturePath = itemSpritesPath + "stamp-" + stampState + ".png"
	if not ResourceLoader.exists(texturePath):
		return
	var texture = load(texturePath)
	get_node("CollisionShape2D/Sprite2D").texture = texture
	get_node("CollisionShape2D/shadow").texture = texture
