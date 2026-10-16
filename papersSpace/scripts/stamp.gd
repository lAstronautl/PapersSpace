extends RigidBody2D

@export var stampState: String = "cap"

const SpriteBounds = preload("res://scripts/spriteBounds.gd")
const StampInfo = preload("res://scripts/stampInfo.gd")

const itemSpritesPath = "res://png/item/stamps/"

func _ready() -> void :
	setVariant(stampState)

func setVariant(newStampState: String) -> void :
	stampState = StampInfo.resolveKey(newStampState)
	# Only metadata is saved, so the state has to live there too.
	set_meta("stampState", stampState)
	var texturePath = itemSpritesPath + "stamp-" + stampState + ".png"
	if not ResourceLoader.exists(texturePath):
		return
	var texture = load(texturePath)
	get_node("CollisionShape2D/Sprite2D").texture = texture
	get_node("CollisionShape2D/shadow").texture = texture
	SpriteBounds.fit(self)
