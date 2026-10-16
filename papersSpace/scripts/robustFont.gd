extends RefCounted

# A font as StarHorizon's engine (Robust) sees it, so text lays out and draws
# the same way:
#  - sizes are in POINTS and become pixels at 96 DPI (12 pt -> 16 px);
#  - metrics are the integers FreeType reports (see robustFontMetrics.gd), which
#    differ from Godot's own ascent+descent line height;
#  - a "stacked" font is a list of faces: the first face that owns a glyph draws
#    it (Noto Sans -> Symbols -> Symbols 2, which is where the box-drawing marks
#    in forms such as the NFSD header come from). A single-face font is Robust's
#    plain VectorFont and has no such fallback.
# Glyphs are hinted with whole-pixel advances exactly like FreeType's default
# load mode.
const FontMetrics = preload("res://scripts/robustFontMetrics.gd")

const dpi = 96.0
const replacementRune = 0xFFFD

const facePaths = {
	"regular": "res://fonts/NotoSans/NotoSans-Regular.ttf",
	"bold": "res://fonts/NotoSans/NotoSans-Bold.ttf",
	"italic": "res://fonts/NotoSans/NotoSans-Italic.ttf",
	"bolditalic": "res://fonts/NotoSans/NotoSans-BoldItalic.ttf",
	"mono": "res://fonts/NotoSans/NotoSansMono-Regular.ttf",
	"symbols": "res://fonts/NotoSans/NotoSansSymbols-Regular.ttf",
	"symbols_bold": "res://fonts/NotoSans/NotoSansSymbols-Bold.ttf",
	"symbols2": "res://fonts/NotoSans/NotoSansSymbols2-Regular.ttf",
}

static var _faces: Dictionary = {}

var faceIds: Array = []
var pt: int = 12
var stacked: bool = false

static func face(id: String) -> FontFile:
	if not _faces.has(id):
		var font: FontFile = load(facePaths[id])
		font.hinting = TextServer.HINTING_NORMAL
		font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
		_faces[id] = font
	return _faces[id]

# Resources.NotoStack(variation: "Regular", size)
static func noto_regular(points: int):
	return make(["regular", "symbols", "symbols2"], points, true)

# Resources.NotoStack(variation: "Bold", size)
static func noto_bold(points: int):
	return make(["bold", "symbols_bold", "symbols2"], points, true)

# new VectorFont(FontResource, size)
static func vector(id: String, points: int):
	return make([id], points, false)

static func make(ids: Array, points: int, is_stacked: bool):
	var font = new()
	font.faceIds = ids
	font.pt = points
	font.stacked = is_stacked
	return font

func _row() -> Array:
	var table: Dictionary = FontMetrics.metrics[faceIds[0]]
	if table.has(pt):
		return table[pt]
	# Sizes that were not tabulated: round like FreeType does.
	var px = roundi(pt * dpi / 72.0)
	var main = face(faceIds[0])
	var ascent = main.get_ascent(px)
	var descent = main.get_descent(px)
	return [px, ascent, descent, ascent + descent]

func ppem() -> int:
	return _row()[0]

func ascent() -> int:
	return _row()[1]

func descent() -> int:
	return _row()[2]

# Font.GetHeight: ascent + descent.
func height() -> int:
	var row = _row()
	return row[1] + row[2]

# Font.GetLineHeight: FT_Size_Metrics.height, the distance between baselines.
func line_height() -> int:
	return _row()[3]

# Rune.IsWhiteSpace
static func is_whitespace(rune: int) -> bool:
	return (rune >= 0x09 and rune <= 0x0D) or rune == 0x20 or rune == 0x85 or rune == 0xA0 \
		or rune == 0x1680 or (rune >= 0x2000 and rune <= 0x200A) or rune == 0x2028 \
		or rune == 0x2029 or rune == 0x202F or rune == 0x205F or rune == 0x3000

func _advance(font: FontFile, rune: int) -> int:
	return int(font.get_char_size(rune, ppem()).x)

# Font.TryGetCharMetrics(...).Advance, or -1 when the font has nothing to draw
# (and nothing to substitute) for this rune.
func char_advance(rune: int) -> int:
	if stacked:
		for id in faceIds:
			var font = face(id)
			if font.has_char(rune):
				return _advance(font, rune)
		return _fallback_advance(rune)
	var single = face(faceIds[0])
	if single.has_char(rune):
		return _advance(single, rune)
	return _fallback_advance(rune)

func _fallback_advance(rune: int) -> int:
	if is_whitespace(rune):
		return -1
	var main = face(faceIds[0])
	if main.has_char(replacementRune):
		return _advance(main, replacementRune)
	return -1

# Font.DrawChar: draws the rune with its baseline origin at `baseline` and
# returns the advance in pixels.
func draw_char(item: CanvasItem, rune: int, baseline: Vector2, color: Color) -> int:
	var rid = item.get_canvas_item()
	var px = ppem()
	if stacked:
		for id in faceIds:
			var font = face(id)
			if font.has_char(rune):
				font.draw_char(rid, baseline, rune, px, color)
				var advance = _advance(font, rune)
				if advance != 0:
					return advance
	var main = face(faceIds[0])
	if main.has_char(rune):
		main.draw_char(rid, baseline, rune, px, color)
		return _advance(main, rune)
	if is_whitespace(rune):
		return 0
	if main.has_char(replacementRune):
		main.draw_char(rid, baseline, replacementRune, px, color)
		return _advance(main, replacementRune)
	return 0
