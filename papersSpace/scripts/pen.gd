extends RigidBody2D

# A writing pen. penState selects which of StarHorizon's pens it is (penInfo.gd);
# the item sprite is png/item/pens/pen-<penState>.png.
const PenInfo = preload("res://scripts/penInfo.gd")

const itemSpritesPath = "res://png/item/pens/pen-"

@export var penState: String = "pen"

# Tag NFWriteIgnoreUnprotectedStamps: writes over stamps unless one is protected.
var canIgnoreStamps: bool = false
# Tag WriteIgnoreStamps: writes over any stamp.
var canIgnoreProtectedStamps: bool = false

func _ready() -> void :
	setVariant(penState)

func setVariant(newPenState: String) -> void :
	penState = newPenState if PenInfo.penData.has(newPenState) else "pen"
	# Only metadata is saved, so the state has to live there too.
	set_meta("penState", penState)
	canIgnoreStamps = PenInfo.ignoresUnprotectedStamps(penState)
	canIgnoreProtectedStamps = PenInfo.ignoresAllStamps(penState)
	var texturePath = itemSpritesPath + penState + ".png"
	if not ResourceLoader.exists(texturePath):
		return
	var texture = load(texturePath)
	get_node("CollisionShape2D/Sprite2D").texture = texture
	get_node("CollisionShape2D/shadow").texture = texture
