extends NinePatchRect

const paperKinds = {
	"default": {
		"texture": "res://png/item/paper/backgrounds/paper_background_default.png",
		"marginLeft": 16, "marginTop": 16, "marginRight": 16, "marginBottom": 16,
	},
	# Mirrors ForensicReportPaper's PaperVisuals exactly: backgroundImagePath
	# is paper_background_perforated (13x13, a single soft-edged dot), with
	# backgroundPatchMargin 6,0,6,0 (left,bottom,right,top in Robust's Box2
	# order) and backgroundImageTile true. Only left/right patches exist (no
	# top/bottom margin) - a column of repeating dots down each side edge.
	"perforated": {
		"texture": "res://png/item/paper/backgrounds/paper_background_perforated.png",
		"marginLeft": 6, "marginTop": 0, "marginRight": 6, "marginBottom": 0,
		"tile": true,
	},
	# Mirrors PaperNanoTaskItem's PaperVisuals: same dot texture, but the
	# patch margin is rotated 90 degrees (0,6,0,6 - top/bottom instead of
	# left/right), matching its horizontally-oriented paper_receipt world
	# sprite - a row of repeating dots along the top/bottom edges instead.
	"perforated_horizontal": {
		"texture": "res://png/item/paper/backgrounds/paper_background_perforated.png",
		"marginLeft": 0, "marginTop": 6, "marginRight": 0, "marginBottom": 6,
		"tile": true,
	},
	# Mirrors PaperArtifactAnalyzer's PaperVisuals: backgroundImagePath is
	# the plain dot-matrix background (not the "_grey" variant, which isn't
	# used by any confirmed SS14 prototype), also tiled.
	"dotmatrix": {
		"texture": "res://png/item/paper/backgrounds/paper_background_dotmatrix.png",
		"marginLeft": 8, "marginTop": 8, "marginRight": 8, "marginBottom": 8,
		"tile": true,
	},
}

func setKind(kind: String) -> void :
	var config = paperKinds.get(kind, paperKinds["default"])
	texture = load(config.texture)
	patch_margin_left = config.marginLeft
	patch_margin_top = config.marginTop
	patch_margin_right = config.marginRight
	patch_margin_bottom = config.marginBottom

	# perforated/dot-matrix backgrounds are small decorative tile patterns
	# meant to repeat to fill the page, not stretch (stretching them
	# smears/distorts the pattern into an unrecognizable blob).
	var stretchMode = NinePatchRect.AXIS_STRETCH_MODE_TILE if config.get("tile", false) else NinePatchRect.AXIS_STRETCH_MODE_STRETCH
	axis_stretch_horizontal = stretchMode
	axis_stretch_vertical = stretchMode

static func randomKind() -> String:
	var keys = paperKinds.keys()
	return keys[randi() % keys.size()]
