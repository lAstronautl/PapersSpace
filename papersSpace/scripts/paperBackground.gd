extends NinePatchRect

# Mirrors StarHorizon's StyleNano.cs "PaperDefaultBorder" style class: the
# fallback background used whenever a prototype's PaperVisuals doesn't set
# its own backgroundImagePath (e.g. AcquisitionSlips) - paper_background_default
# tinted light cream, 16px patch margin, stretched (not tiled).
const defaultTexture = "res://png/item/paper/backgrounds/paper_background_default.png"
const defaultModulate = Color("eaedde")
const defaultMargin = Vector4(16, 16, 16, 16)

# StarHorizon's perforated/dot-matrix backgrounds tile a small (13x13)
# diamond-shaped texture across the ENTIRE page (confirmed against real
# screenshots - not just a border strip). Two Godot approaches were tried
# and both hit real engine quirks rather than working as intended:
#   1. NinePatchRect tiling: patch margins slice a region OUT of the source
#      texture (9-slice style), so the "center" tile ends up a near-blank
#      sliver instead of the whole diamond.
#   2. A separate TextureRect with texture_repeat=true layered as a sibling
#      after any other CanvasItem (NinePatchRect, TextureRect, even a plain
#      ColorRect) in the same Control: the tile pattern silently fails to
#      repeat and only renders at the very edges, regardless of stretch/
#      expand_mode combination or use_parent_material - reproducible in
#      isolation, so it looks like a Godot 4.7 canvas-batching bug rather
#      than a config mistake.
# So the diamond lattice is instead drawn procedurally as small rotated
# squares via _draw(), fully independent of both quirks above.
@onready var perforation: Control = $"../perforation"

var _perforated := false
const _dotSpacing = 13.0
const _dotSize = 5.0
const _dotColor = Color(0, 0, 0, 0.15)

func _ready() -> void :
	perforation.draw.connect(_drawPerforation)
	resized.connect(perforation.queue_redraw)

func applyVisuals(visuals: Dictionary) -> void :
	var path: String = visuals.get("backgroundImagePath", "")

	if path == "":
		_applyBase(defaultTexture, defaultMargin, defaultModulate, false)
		_perforated = false
		perforation.queue_redraw()
		return

	var margin: Vector4 = visuals.get("backgroundPatchMargin", Vector4.ZERO)
	var tile: bool = visuals.get("backgroundImageTile", false)
	var tint: Color = visuals.get("backgroundModulate", Color.WHITE)

	if not tile or margin == Vector4.ZERO:
		_applyBase(path, margin, tint, false)
		_perforated = false
	else:
		# The tiled texture still draws its own jagged/torn edge (the diamond
		# pattern's transparent corners) via NinePatchRect's margin regions -
		# the full-page diamond lattice is layered separately on top of that.
		_applyBase(path, margin, tint, true)
		_perforated = true
	perforation.queue_redraw()

func _applyBase(path: String, margin: Vector4, tint: Color, tile: bool) -> void :
	visible = true
	texture = load(path)
	patch_margin_left = margin.x
	patch_margin_top = margin.y
	patch_margin_right = margin.z
	patch_margin_bottom = margin.w

	var stretchMode = NinePatchRect.AXIS_STRETCH_MODE_TILE if tile else NinePatchRect.AXIS_STRETCH_MODE_STRETCH
	axis_stretch_horizontal = stretchMode
	axis_stretch_vertical = stretchMode

	self_modulate = tint

func _drawPerforation() -> void :
	if not _perforated:
		return

	var rect = perforation.size
	if rect.x <= 0 or rect.y <= 0:
		return

	var half = _dotSize * 0.5
	var cols = int(rect.x / _dotSpacing) + 1
	var rows = int(rect.y / _dotSpacing) + 1
	for row in rows:
		var y = row * _dotSpacing + _dotSpacing * 0.5
		if y > rect.y:
			break
		for col in cols:
			var x = col * _dotSpacing + _dotSpacing * 0.5
			if x > rect.x:
				break
			var points = PackedVector2Array([
				Vector2(x, y - half),
				Vector2(x + half, y),
				Vector2(x, y + half),
				Vector2(x - half, y),
			])
			perforation.draw_colored_polygon(points, _dotColor)
