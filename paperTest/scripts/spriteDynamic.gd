extends Sprite2D


@export var activeTexture: Texture2D
@export var notActiveTexture: Texture2D




func setActiveTexture(state: bool):
	if state:
		texture = activeTexture
	else:
		texture = notActiveTexture
