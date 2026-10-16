extends Sprite2D


@export var activeTexture: Texture2D
@export var notActiveTexture: Texture2D
@export var shadowSprite: Sprite2D

# Mirrors SS14's Sprite/PaperVisualLayers.Writing split: most paper variants
# just tint the SAME world sprite states (see PaperCargoInvoice's Sprite
# layers - state "paper"/"paper_words" with a color, nothing else), but a few
# (like AcquisitionSlips) genuinely swap to different RSI states entirely.
# When set, these override activeTexture/notActiveTexture for variants that
# need unique world art instead of just a tint.
var variantActiveTexture: Texture2D
var variantNotActiveTexture: Texture2D

static var paperStyles = {
	"default": Color(1, 1, 1),
	"cream": Color(0.949, 0.902, 0.784),
	"carbon": Color(0.702, 0.702, 0.729),
	"pink": Color(1, 0.788, 0.827),
	"cyan": Color.html("#9ef5ff"),
	"lavender": Color.html("#e6e6fa"),
	"yellow": Color.html("#fff4b5"),
	"green": Color.html("#bae6ba"),
	"red": Color.html("#f4b5b5"),
	"orange": Color.html("#f9c7a1"),
	"blue": Color.html("#b7dcfa"),
	"purple": Color.html("#dfb7fa"),
}

func setActiveTexture(state: bool):
	if state:
		texture = variantActiveTexture if variantActiveTexture else activeTexture
	else:
		texture = variantNotActiveTexture if variantNotActiveTexture else notActiveTexture
	# The shadow is a separate Sprite2D with its own fixed texture, so it has
	# to be kept in sync manually - otherwise it keeps casting the default
	# paper's silhouette instead of matching whatever variant art (receipt,
	# dot-matrix, acquisition form, etc.) is actually showing.
	if shadowSprite:
		shadowSprite.texture = texture

func setPaperStyle(style: String) -> void :
	modulate = styleColor(style)

# A paper style is either one of the named tints above or a raw "#rrggbb" colour
# (the world Sprite colour StarHorizon's paper prototypes set per layer).
static func styleColor(style: String) -> Color:
	if style.begins_with("#"):
		return Color.html(style)
	return paperStyles.get(style, paperStyles["default"])

# Sets unique world-sprite art for variants that don't just tint the default
# paper texture (e.g. AcquisitionSlips use their own "acquisition_form" RSI
# states, not a colored "paper" state). Pass null/null to reset to default.
func setVariantTextures(active: Texture2D, notActive: Texture2D) -> void :
	variantActiveTexture = active
	variantNotActiveTexture = notActive

static func randomPaperStyle() -> String:
	var keys = paperStyles.keys()
	return keys[randi() % keys.size()]
