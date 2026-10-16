extends RefCounted

# Converts paper text into Godot BBCode, mirroring the tag whitelist of
# StarHorizon's PaperWindow.xaml.cs (_allowedTags): bold, italic, bolditalic,
# bullet, color, head, mono. Anything else - including every other
# "[...]" sequence - is shown literally, the same way SS14's
# AddMarkupPermissive + tag whitelist leaves unknown markup as plain text.
#
# The short tags this port always accepted ([b] [i] [u], and [color=red|blue|green])
# keep working too, so papers saved before this converter existed look the same.
#
# [head=N] mirrors Robust's HeadingTag: level clamped to 1..3, font size
# ceil(DefaultSize * 2 / sqrt(level)) in bold, with DefaultSize = 12 (the
# same size paper body text uses in this port).
const defaultFontSize = 12

static var _tagRegex: RegEx

static func _regex() -> RegEx:
	if _tagRegex == null:
		_tagRegex = RegEx.new()
		_tagRegex.compile("\\[(/?)([A-Za-z]+)(?:=([^\\[\\]]*))?\\]")
	return _tagRegex

static func headingSize(level: int) -> int:
	return int(ceil(defaultFontSize * 2.0 / sqrt(clampi(level, 1, 3))))

# Literal brackets are first swapped for bracket-free placeholder codepoints
# and only turned into [lb]/[rb] at the very end - escaping "[" -> "[lb]" and
# then "]" -> "[rb]" in sequence would also mangle the "]" of the "[lb]" just
# written.
const _leftPlaceholder = "\uE000"
const _rightPlaceholder = "\uE001"

static func _escape(text: String) -> String:
	return text.replace("[", _leftPlaceholder).replace("]", _rightPlaceholder)

static func _isValidColor(value: String) -> bool:
	var hex = RegEx.new()
	hex.compile("^(#[0-9A-Fa-f]{3,8}|[A-Za-z]+)$")
	return hex.search(value) != null

# Returns the BBCode for one tag, or "" when the tag isn't a known one
# (the caller then shows the original text literally).
static func _convertTag(closing: bool, name: String, value: String) -> String:
	match name.to_lower():
		"bold", "b":
			return "[/b]" if closing else "[b]"
		"italic", "i":
			return "[/i]" if closing else "[i]"
		"bolditalic":
			return "[/i][/b]" if closing else "[b][i]"
		"u":
			return "[/u]" if closing else "[u]"
		"mono":
			return "[/code]" if closing else "[code]"
		"bullet":
			return "" if closing else " · "
		"color":
			if closing:
				return "[/color]"
			if value != "" and _isValidColor(value):
				return "[color=%s]" % value
		"head":
			if closing:
				return "[/b][/font_size]"
			if value.is_valid_int():
				return "[font_size=%d][b]" % headingSize(value.to_int())
	return ""

static func toBBCode(rawText: String) -> String:
	var out = ""
	var cursor = 0
	# Open-tag depth per tag name, so a closing tag with nothing to close is
	# shown literally instead of emitting a dangling BBCode closer.
	var depth = {}
	for found in _regex().search_all(rawText):
		out += _escape(rawText.substr(cursor, found.get_start() - cursor))
		cursor = found.get_end()
		var closing = found.get_string(1) == "/"
		var name = found.get_string(2).to_lower()
		var converted = _convertTag(closing, name, found.get_string(3))
		var isBulletClose = closing and name == "bullet"
		var known = converted != "" or isBulletClose
		if known and closing and not isBulletClose:
			if depth.get(name, 0) <= 0:
				known = false
			else:
				depth[name] -= 1
		elif known and not closing and name != "bullet":
			depth[name] = depth.get(name, 0) + 1
		out += converted if known else _escape(found.get_string())
	out += _escape(rawText.substr(cursor))
	return out.replace(_leftPlaceholder, "[lb]").replace(_rightPlaceholder, "[rb]")
