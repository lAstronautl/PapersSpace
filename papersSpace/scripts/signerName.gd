extends RefCounted

# The name a pen signs with (StampDisplayInfo.StampedName of a Signature is the
# signer's character name in the game). The note-taking sandbox has no character,
# so it is a saved setting ("signer" in settings.save) with a translated default.
const settingsPath = "user://settings.save"

static func get_signer_name() -> String:
	var file = FileAccess.open(settingsPath, FileAccess.READ)
	if file:
		var json = JSON.new()
		var parsed = json.parse(file.get_as_text())
		file.close()
		if parsed == OK and typeof(json.data) == TYPE_DICTIONARY and str(json.data.get("signer", "")) != "":
			return str(json.data.signer)
	return TranslationServer.translate("ui_signer_default")

static func set_signer_name(new_name: String) -> void:
	var data = {}
	var file = FileAccess.open(settingsPath, FileAccess.READ)
	if file:
		var json = JSON.new()
		if json.parse(file.get_as_text()) == OK and typeof(json.data) == TYPE_DICTIONARY:
			data = json.data
		file.close()
	data["signer"] = new_name
	var out = FileAccess.open(settingsPath, FileAccess.WRITE)
	if out:
		out.store_string(JSON.stringify(data))
		out.close()
