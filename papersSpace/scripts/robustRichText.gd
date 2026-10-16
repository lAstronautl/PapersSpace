extends Control

# A literal port of Robust's RichTextLabel / RichTextEntry / WordWrap plus the
# markup parser and the tags StarHorizon's PaperWindow allows (bold, italic,
# bolditalic, bullet, color, head, mono), so paper text wraps, spaces its lines
# and is drawn exactly the way the game does it. See
# RobustToolbox/Robust.Client/UserInterface/{RichTextEntry,WordWrap}.cs and
# Robust.Shared/Utility/FormattedMessage.MarkupParser.cs.
#
# Use: set the font/colour, set_message(), then measure(width) with the width
# the layout gives the label; the control draws what the last measure() laid out.
const RobustFont = preload("res://scripts/robustFont.gd")

const defaultFontSize = 12              # FontTag.DefaultSize
const tagFallbackColor = Color8(200, 200, 200)   # ColorTag.DefaultColor
const bulletText = " · "                # BulletTag.TextBefore
const knownTags = ["bold", "italic", "bolditalic", "bullet", "color", "head", "mono"]

var defaultFont
var defaultColor: Color = Color8(25, 25, 25)
# Tag names the owner permits (PaperWindow._allowedTags). Empty: all known tags.
var tagsAllowed: Array = []
var lineHeightScale: float = 1.0

var _nodes: Array = []
var _hasEntry = false
var _lineBreaks: Array = []
var _entryWidth: int = 0
var _entryHeight: int = 0

# --- markup parsing (FormattedMessage.ParsePermissive) ------------------------

static func _is_letter(character: String) -> bool:
	return character.to_lower() != character.to_upper()

static func _is_letter_or_digit(character: String) -> bool:
	return _is_letter(character) or (character >= "0" and character <= "9" and character.length() == 1)

static func _skip_whitespace(input: String, position: int) -> int:
	while position < input.length() and input[position].strip_edges() == "" and input[position] != "":
		position += 1
	return position

static func _parse_identifier(input: String, position: int):
	if position >= input.length() or not _is_letter(input[position]):
		return null
	var end = position + 1
	while end < input.length() and _is_letter_or_digit(input[end]):
		end += 1
	return {"name": input.substr(position, end - position), "end": end}

static func _create_color(name_or_hex: String) -> Color:
	# Color.TryFromName(...) ?? Color.TryFromHex(...) ?? Color.Black
	var sentinel = Color(-1, -1, -1, -1)
	var parsed = Color.from_string(name_or_hex, sentinel)
	if parsed == sentinel:
		return Color.BLACK
	return parsed

static func _valid_color_char(character: String) -> bool:
	return character == "#" or _is_letter(character) and character.unicode_at(0) < 128 \
		or (character >= "0" and character <= "9" and character.length() == 1)

# Returns {"name", "param", "end"} or null. param is {"type": none|string|long|color, "v"}.
static func _parse_key_value(input: String, position: int):
	position = _skip_whitespace(input, position)
	var identifier = _parse_identifier(input, position)
	if identifier == null:
		return null
	position = _skip_whitespace(input, identifier.end)
	var param = {"type": "none"}
	if position < input.length() and input[position] == "=":
		position = _skip_whitespace(input, position + 1)
		if position >= input.length():
			return null
		var first = input[position]
		if first == "\"":
			var close = input.find("\"", position + 1)
			if close == -1:
				return null
			param = {"type": "string", "v": input.substr(position + 1, close - position - 1)}
			position = close + 1
		elif first == "#" or _is_letter(first):
			var end = position + 1
			while end < input.length() and _valid_color_char(input[end]):
				end += 1
			param = {"type": "color", "v": _create_color(input.substr(position, end - position))}
			position = end
		else:
			var end = position
			if input[end] == "-":
				end += 1
			var digits = end
			while end < input.length() and input[end] >= "0" and input[end] <= "9":
				end += 1
			if end == digits:
				return null
			param = {"type": "long", "v": input.substr(position, end - position).to_int()}
			position = end
	position = _skip_whitespace(input, position)
	return {"name": identifier.name, "param": param, "end": position}

# `position` is just after the "[". Returns {"nodes", "end"} or null.
static func _try_parse_tag(input: String, position: int):
	if position < input.length() and input[position] == "/":
		position = _skip_whitespace(input, position + 1)
		var identifier = _parse_identifier(input, position)
		if identifier == null:
			return null
		position = _skip_whitespace(input, identifier.end)
		if position < input.length() and input[position] == "]":
			return {"nodes": [{"name": identifier.name, "closing": true}], "end": position + 1}
		return null

	var first = _parse_key_value(input, position)
	if first == null:
		return null
	position = first.end
	var attributes = {}
	while true:
		var next = _parse_key_value(input, position)
		if next == null:
			break
		if not attributes.has(next.name):
			attributes[next.name] = next.param
		position = next.end

	var nodes = [{"name": first.name, "param": first.param, "attrs": attributes, "closing": false}]
	if position < input.length() and input[position] == "/":
		var after = _skip_whitespace(input, position + 1)
		if after < input.length() and input[after] == "]":
			nodes.append({"name": first.name, "closing": true})
			return {"nodes": nodes, "end": after + 1}
		return null
	if position < input.length() and input[position] == "]":
		return {"nodes": nodes, "end": position + 1}
	return null

static func parse_permissive(input: String) -> Array:
	var nodes: Array = []
	var text = ""
	var i = 0
	var count = input.length()
	while i < count:
		var character = input[i]
		if character == "\\":
			if i + 1 < count and (input[i + 1] == "\\" or input[i + 1] == "[" or input[i + 1] == "]" or input[i + 1] == "/"):
				text += input[i + 1]
				i += 2
				continue
			text += character
			i += 1
			continue
		if character == "[":
			var tag = _try_parse_tag(input, i + 1)
			if tag != null:
				if text != "":
					nodes.append({"name": "", "text": text})
					text = ""
				nodes.append_array(tag.nodes)
				i = tag.end
				continue
			text += character
			i += 1
			continue
		text += character
		i += 1
	if text != "":
		nodes.append({"name": "", "text": text})
	return nodes

# --- RichTextLabel API ----------------------------------------------------------

func set_message(markup: String) -> void:
	_nodes = parse_permissive(markup)
	_hasEntry = true
	queue_redraw()

# SetMessage(string): plain text, no markup.
func set_plain_message(text: String) -> void:
	_nodes = [{"name": "", "text": text}]
	_hasEntry = true
	queue_redraw()

func clear() -> void:
	_nodes = []
	_hasEntry = false
	_lineBreaks.clear()
	_entryWidth = 0
	_entryHeight = 0
	queue_redraw()

func has_message() -> bool:
	return _hasEntry

# RichTextLabel.MeasureOverride: lays the text out for `available_width` and
# returns the desired size.
func measure(available_width: float) -> Vector2:
	if not _hasEntry:
		return Vector2.ZERO
	_update_entry(available_width)
	queue_redraw()
	return Vector2(_entryWidth, _entryHeight)

func _draw() -> void:
	if _hasEntry:
		_draw_entry(Vector2.ZERO)

# --- tag handlers ------------------------------------------------------------------

func _tag_font(fonts: Array, node: Dictionary, face_id: String, size_override: int = -1):
	# FontTag.CreateFont: size comes from the previous font, or the "size" attribute.
	var size = defaultFontSize
	if not fonts.is_empty():
		size = fonts.back().pt
	if size_override > 0:
		size = size_override
	elif node.has("attrs") and node.attrs.has("size") and node.attrs.size.type == "long":
		size = int(node.attrs.size.v)
	return RobustFont.vector(face_id, size)

func _process_node(node: Dictionary, fonts: Array, colors: Array) -> String:
	if node.name == "":
		return node.text
	var name: String = node.name
	if not knownTags.has(name):
		return ""
	if not tagsAllowed.is_empty() and not tagsAllowed.has(name):
		return ""
	if not node.closing:
		match name:
			"bold":
				fonts.push_back(_tag_font(fonts, node, "bold"))
			"italic":
				# Robust's ItalicTag asks the draw context whether a BoldTag is open,
				# but nothing ever fills that list, so nesting never merges the faces.
				fonts.push_back(_tag_font(fonts, node, "italic"))
			"bolditalic":
				fonts.push_back(_tag_font(fonts, node, "bolditalic"))
			"mono":
				fonts.push_back(_tag_font(fonts, node, "mono"))
			"head":
				# HeadingTag: level clamped to 1..3, size ceil(DefaultSize * 2 / sqrt(level)).
				if node.param.type == "long":
					var level = clampi(int(node.param.v), 1, 3)
					fonts.push_back(_tag_font(fonts, node, "bold", int(ceil(defaultFontSize * 2.0 / sqrt(level)))))
			"color":
				colors.push_back(node.param.v if node.param.type == "color" else tagFallbackColor)
		return bulletText if name == "bullet" else ""
	match name:
		"bold", "italic", "bolditalic", "mono", "head":
			if not fonts.is_empty():
				fonts.pop_back()
		"color":
			if not colors.is_empty():
				colors.pop_back()
	return ""

# --- WordWrap -----------------------------------------------------------------------

class WordWrap:
	var maxSizeX: float
	var maxUsedWidth: float = 0.0
	var breakIndexCounter: int = 0
	var nextBreakIndexCounter: int = 0
	var wordStartBreakIndex = null   # [index, lineSize] or null
	var wordSizePixels: int = 0
	var posX: int = 0
	var lastRune: int = 65           # 'A'
	var forceSplitData = null        # [breakIndex, wordSizePixels] or null

	# Results of the last call.
	var breakLine = null
	var breakNewLine = null
	var skip = false
	var abort = false

	func _init(max_size_x: float) -> void:
		maxSizeX = max_size_x

	static func _is_word_boundary(a: int, b: int) -> bool:
		return a == 32 or b == 32 or a == 45 or b == 45

	func next_rune(rune: int) -> void:
		breakIndexCounter = nextBreakIndexCounter
		nextBreakIndexCounter += 1
		breakLine = null
		breakNewLine = null
		skip = false

		if _is_word_boundary(lastRune, rune) or rune == 10:
			if posX > maxSizeX and lastRune != 32:
				if wordStartBreakIndex == null:
					return
				breakLine = wordStartBreakIndex[0]
				maxUsedWidth = maxf(maxUsedWidth, wordStartBreakIndex[1])
				posX = wordSizePixels
			wordSizePixels = 0
			wordStartBreakIndex = [breakIndexCounter, posX]
			forceSplitData = null
			if rune == 10:
				maxUsedWidth = maxf(maxUsedWidth, posX)
				posX = 0
				wordStartBreakIndex = null
				skip = true
				breakNewLine = breakIndexCounter
		lastRune = rune

	func next_metrics(advance: int) -> void:
		abort = false
		breakLine = null
		var oldWordSizePixels = wordSizePixels
		wordSizePixels += advance
		posX += advance
		if posX <= maxSizeX:
			return
		if forceSplitData == null:
			forceSplitData = [breakIndexCounter, oldWordSizePixels]
		if wordSizePixels > maxSizeX:
			var breakIndex: int = forceSplitData[0]
			var splitWordSize: int = forceSplitData[1]
			if splitWordSize == 0:
				abort = true
				return
			forceSplitData = null
			breakLine = breakIndex
			wordSizePixels -= splitWordSize
			wordStartBreakIndex = null
			maxUsedWidth = maxf(maxUsedWidth, maxSizeX)
			posX = wordSizePixels

	# Returns the used width; sets breakLine for the final word.
	func finalize_text() -> int:
		if posX > maxSizeX:
			if wordStartBreakIndex == null:
				breakLine = null
				return int(maxUsedWidth)
			breakLine = wordStartBreakIndex[0]
			maxUsedWidth = maxf(maxUsedWidth, wordStartBreakIndex[1])
		else:
			breakLine = null
			maxUsedWidth = maxf(maxUsedWidth, posX)
		return int(maxUsedWidth)

# --- RichTextEntry.Update / Draw ----------------------------------------------------

func _line_height(font) -> int:
	return int(font.line_height() * lineHeightScale)

func _update_entry(max_size_x: float) -> void:
	_entryHeight = defaultFont.height()
	_entryWidth = 0
	_lineBreaks.clear()

	var wordWrap = WordWrap.new(max_size_x)
	var fonts: Array = [defaultFont]
	var colors: Array = [defaultColor]

	for node in _nodes:
		var text = _process_node(node, fonts, colors)
		var font = fonts.back() if not fonts.is_empty() else defaultFont

		for index in text.length():
			var rune = text.unicode_at(index)
			wordWrap.next_rune(rune)
			_check_line_break(wordWrap.breakLine, fonts)
			_check_line_break(wordWrap.breakNewLine, fonts)
			if wordWrap.skip:
				continue

			var advance = font.char_advance(rune)
			if advance < 0:
				continue

			wordWrap.next_metrics(advance)
			_check_line_break(wordWrap.breakLine, fonts)
			if wordWrap.abort:
				return

	_entryWidth = wordWrap.finalize_text()
	_check_line_break(wordWrap.breakLine, fonts)

func _check_line_break(line, fonts: Array) -> void:
	if line == null:
		return
	_lineBreaks.append(line)
	var font = fonts.back() if not fonts.is_empty() else defaultFont
	_entryHeight += _line_height(font)

func _draw_entry(origin: Vector2) -> void:
	var fonts: Array = [defaultFont]
	var colors: Array = [defaultColor]
	var globalBreakCounter = 0
	var lineBreakIndex = 0
	var baseLine = origin + Vector2(0, defaultFont.ascent())

	for node in _nodes:
		var text = _process_node(node, fonts, colors)
		var color: Color
		var font
		if colors.is_empty() or fonts.is_empty():
			color = defaultColor
			font = defaultFont
		else:
			color = colors.back()
			font = fonts.back()

		for index in text.length():
			if lineBreakIndex < _lineBreaks.size() and _lineBreaks[lineBreakIndex] == globalBreakCounter:
				baseLine = Vector2(origin.x, baseLine.y + _line_height(font))
				lineBreakIndex += 1
			var advance = font.draw_char(self, text.unicode_at(index), baseLine, color)
			baseLine.x += advance
			globalBreakCounter += 1
