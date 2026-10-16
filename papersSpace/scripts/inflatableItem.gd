extends RigidBody2D

# InflatableWallStack / InflatableDoorStack: a folded stack that is unfolded into
# the structure with SpawnAfterInteract (1 s per use). Only metadata is saved:
# kind ("wall" or "door") and the number of pieces left.
const SpriteBounds = preload("res://scripts/spriteBounds.gd")
const kinds = {
	"wall": {"texture": "res://png/item/inflatable/item_wall.png", "count": 10},
	"door": {"texture": "res://png/item/inflatable/item_door.png", "count": 4},
}

func _ready() -> void :
	setVariant(get_meta("kind", "wall"), get_meta("count", -1))

func setVariant(kind: String, count: int = -1) -> void :
	if not kinds.has(kind):
		kind = "wall"
	set_meta("kind", kind)
	set_meta("count", count if count > 0 else kinds[kind].count)
	var texture = load(kinds[kind].texture)
	get_node("CollisionShape2D/Sprite2D").texture = texture
	get_node("CollisionShape2D/shadow").texture = texture
	SpriteBounds.fitPixels(self)
