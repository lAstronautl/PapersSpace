extends NinePatchRect

# Mirrors StarHorizon's StyleNano.cs "PaperDefaultBorder" style class: the
# fallback background used whenever a prototype's PaperVisuals doesn't set
# its own backgroundImagePath (e.g. AcquisitionSlips) - paper_background_default
# tinted light cream, 16px patch margin, stretched (not tiled).
const defaultTexture = "res://png/item/paper/backgrounds/paper_background_default.png"
const defaultModulate = Color("eaedde")
const defaultMargin = Vector4(16, 16, 16, 16)

const perforatedTexturePath = "res://png/item/paper/backgrounds/paper_background_perforated.png"
const perforatedShader = preload("res://shaders/perforatedTile.gdshader")
# The reference texture is natively 13x13 UI px in StarHorizon (SVG viewBox
# 13x13 at 96dpi = 1:1 logical UI pixels). Rendered at that literal size in
# this port's fixed 768x768 viewport, the tiles read visibly larger/coarser
# and more densely-packed than on real StarHorizon screenshots - most likely
# because a typical StarHorizon client runs at a higher UI scale, where the
# same 13 LOGICAL pixels cover more PHYSICAL screen pixels than our fixed
# viewport does, so matching the raw number doesn't match the apparent
# density. This value + perforatedDiamondScale below were chosen by
# rendering side-by-side against reference screenshots and picking what
# actually looks equivalent, not by reproducing the literal source numbers.
# X spacing kept at 12 (unchanged); Y spacing halved to 6 so rows repeat
# twice as often vertically - a denser lattice along the page's long axis
# without also cramming dots closer together horizontally.
const perforatedTileSizePx = Vector2(12, 6)
# Shrinks the diamond within its own tile cell (sampled from a smaller,
# centered region of the source texture) so there's visible empty space
# between repeats, instead of the diamonds sitting edge-to-edge as the raw
# texture does by construction. Values >1 shrink the diamond; 1.0 = same
# size as the tile cell (edge-to-edge, no gap). Both axes are scaled by this
# SAME factor (see the shader) regardless of tileSizePx being anisotropic,
# so the diamond's own proportions stay intact instead of stretching.
const perforatedDiamondScale = 1.5

# StarHorizon's real StyleBoxTexture 9-slice, applied to PaperNanoTaskItem's
# margin (0,6,0,6) on this 13x13 texture, mathematically reduces the tiled
# center region to a 1px-tall slice of the source - yet a real client
# screenshot shows the perforation as a fine dot lattice across the WHOLE
# page, with the reference's PatchMarginTop/Bottom (6px in the source
# texture) instead showing up as a genuinely jagged/torn top+bottom
# silhouette (no such margin on left/right, so those stay straight). Godot's
# NinePatchRect can't reproduce a plain uncropped full-texture repeat
# (patch_margin always slices the source first, degenerating this texture's
# tiny center region into an unusable sliver), so the background is instead
# drawn via `perforatedTile.gdshader`: a canvas_item shader that repeats the
# full, uncropped tile across the whole control, punches a true alpha cutout
# within `edgeMarginPx` of the top/bottom edges (producing the jagged
# silhouette), and elsewhere composites the diamond's alpha between
# `paperColor` (opaque diamond) and a visibly distinct `holeColor` for the
# seams (a plain rgb-only blend against an equally-white paperColor was
# tried first and visually failed - the diamond IS white, so blending it
# against equally-white paper made every pixel white regardless of alpha).
func applyVisuals(visuals: Dictionary) -> void :
	var path: String = visuals.get("backgroundImagePath", "")

	if path == "":
		# PaperDefaultBorder's cream style tint is multiplied by the prototype's
		# own backgroundModulate (colored papers), as Robust multiplies a
		# StyleBoxTexture's Modulate with its control's ModulateSelf.
		_applyBase(defaultTexture, defaultMargin, defaultModulate * visuals.get("backgroundModulate", Color.WHITE), false)
		return

	var margin: Vector4 = visuals.get("backgroundPatchMargin", Vector4.ZERO)
	var tile: bool = visuals.get("backgroundImageTile", false)
	var tint: Color = visuals.get("backgroundModulate", Color.WHITE)

	if path == perforatedTexturePath and tile:
		_applyPerforatedTile(path, tint)
	else:
		material = null
		_applyBase(path, margin, tint, tile)

func _applyPerforatedTile(path: String, tint: Color) -> void :
	visible = true
	self_modulate = Color.WHITE
	texture = load(path)
	patch_margin_left = 0
	patch_margin_top = 0
	patch_margin_right = 0
	patch_margin_bottom = 0
	axis_stretch_horizontal = NinePatchRect.AXIS_STRETCH_MODE_STRETCH
	axis_stretch_vertical = NinePatchRect.AXIS_STRETCH_MODE_STRETCH

	var shaderMat := material as ShaderMaterial
	if shaderMat == null or shaderMat.shader != perforatedShader:
		shaderMat = ShaderMaterial.new()
		shaderMat.shader = perforatedShader
		material = shaderMat

	shaderMat.set_shader_parameter("tileTexture", texture)
	shaderMat.set_shader_parameter("tileSizePx", perforatedTileSizePx)
	shaderMat.set_shader_parameter("diamondScale", perforatedDiamondScale)
	shaderMat.set_shader_parameter("paperColor", tint)
	shaderMat.set_shader_parameter("holeColor", tint * Color(0.92, 0.92, 0.92, 1.0))
	set_process(true)
	_updateShaderNodeSize()

# The control's layout isn't finalized yet at the point applyVisuals() runs
# (custom_minimum_size/anchors changes from fileEditor.open() only take
# effect on the NEXT layout pass), so `size` read immediately after
# _applyPerforatedTile() can still be stale (e.g. left over from whichever
# paper was open before, or zero on first open) - polling every frame while
# this background is active (cheap: one Vector2 uniform write on one node)
# keeps the shader's tile count correct as soon as the real size lands,
# instead of a one-shot resized-signal race that can miss the first frame.
func _process(_delta: float) -> void :
	_updateShaderNodeSize()

func _updateShaderNodeSize() -> void :
	var shaderMat := material as ShaderMaterial
	if shaderMat == null:
		set_process(false)
		return
	shaderMat.set_shader_parameter("nodeSizePx", size)

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
