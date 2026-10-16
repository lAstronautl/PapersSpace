extends Control

# StarHorizon's StampWidget + StampLabel (Content.Client/Paper/UI): a stamp is a
# PanelContainer with outer Margin 6 whose style is the paper_stamp_border
# texture (patch margin 7) tinted with the stamp colour, holding a Label in the
# bold 20 pt "LabelHeadingBigger" font with Margin 12 6 12 6. Border and text are
# drawn through the PaperStamp shader (noisy, partly transparent ink) and rotated
# as one rigid body around the panel's top-left corner; only the text is scaled
# down when it does not fit (StampLabel.MeasureOverride).
const RobustFont = preload("res://scripts/robustFont.gd")
const StyleBoxScript = preload("res://scripts/robustStyleBox.gd")
const borderTexture = preload("res://png/ui/paper_stamp_border.png")
const stampShader = preload("res://shaders/paperStamp.gdshader")

const outerMargin = 6.0
const patchMargin = 7.0
const labelMargin = Vector4(12, 6, 12, 6)    # left, top, right, bottom
const textScalingStep = 0.1                  # StampLabel "shimmerReduction"

var stampText: String = ""
var stampColor: Color = Color.WHITE
# StampType.Signature: no border panel (PanelOverride = null), just the name.
var isSignature: bool = false
var textScaling: float = 1.0
var _font = RobustFont.noto_bold(20)
var _border: Control
var _material: ShaderMaterial

func _init() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	pivot_offset = Vector2.ZERO
	_material = ShaderMaterial.new()
	_material.shader = stampShader
	material = _material

	_border = StyleBoxScript.new()
	_border.texture = borderTexture
	_border.patchMargin = Vector4(patchMargin, patchMargin, patchMargin, patchMargin)
	_border.use_parent_material = true
	_border.show_behind_parent = true   # the panel is drawn before the label
	add_child(_border)

func setup(text: String, color: Color, signature: bool = false) -> void:
	stampText = text
	stampColor = color
	isSignature = signature
	_border.visible = not signature
	_material.set_shader_parameter("tint", color)
	queue_redraw()

# Label desired size: widest line by the font's advances, height = font height.
func text_size() -> Vector2:
	var width = 0
	for index in stampText.length():
		var advance = _font.char_advance(stampText.unicode_at(index))
		if advance > 0:
			width += advance
	return Vector2(width, _font.height() if stampText.length() > 0 else 0)

# Content inset of the panel style: the border's patch margin, none for signatures.
func _inset() -> float:
	return 0.0 if isSignature else patchMargin

# The panel (without the outer Margin 6).
func panel_size() -> Vector2:
	var text = text_size()
	return Vector2(text.x + labelMargin.x + labelMargin.z + _inset() * 2.0,
		text.y + labelMargin.y + labelMargin.w + _inset() * 2.0)

# Control.DesiredSize: the panel plus the widget's Margin.
func desired_size() -> Vector2:
	return panel_size() + Vector2(outerMargin * 2.0, outerMargin * 2.0)

# StampLabel.MeasureOverride: `available` is the space the stamp collection gives
# the widget; the label gets what is left after both margins and the border.
func measure(available: Vector2) -> void:
	var label_available = available - Vector2(outerMargin * 2.0 + _inset() * 2.0 + labelMargin.x + labelMargin.z,
		outerMargin * 2.0 + _inset() * 2.0 + labelMargin.y + labelMargin.w)
	var desired = text_size()
	var scale = Vector2(1.0, 1.0)
	if desired.x > 0:
		scale.x = minf(label_available.x / desired.x, 1.0)
	if desired.y > 0:
		scale.y = minf(label_available.y / desired.y, 1.0)
	var keep_aspect = minf(scale.x, scale.y)
	textScaling = roundf(keep_aspect / textScalingStep) * textScalingStep
	queue_redraw()

func place(panel_position: Vector2, orientation: float) -> void:
	position = panel_position
	size = panel_size()
	rotation = orientation
	_border.position = Vector2.ZERO
	_border.size = size
	_material.set_shader_parameter("objCoord", global_position)
	queue_redraw()

func _draw() -> void:
	if stampText == "":
		return
	var origin = Vector2(_inset() + labelMargin.x, _inset() + labelMargin.y)
	draw_set_transform(origin, 0.0, Vector2(textScaling, textScaling))
	var baseline = Vector2(0, _font.ascent())
	for index in stampText.length():
		baseline.x += _font.draw_char(self, stampText.unicode_at(index), baseline, Color.WHITE)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
