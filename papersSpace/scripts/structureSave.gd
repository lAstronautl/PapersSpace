extends RefCounted

# The one file that remembers what the player changed about structures: moved
# or bolted machines (keyed by name) and the inflatable walls and doors
# ("_inflatables"). Callers read, change their own key and write back.
const savePath = "user://structures.save"

static func read() -> Dictionary:
	var file = FileAccess.open(savePath, FileAccess.READ)
	if not file:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	return parsed if parsed is Dictionary else {}

static func write(data: Dictionary) -> void :
	var file = FileAccess.open(savePath, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))
