extends Node

const supportedLocales = ["en", "ru"]
const settingsPath = "user://settings.save"

signal localeChanged

func _ready() -> void :
	var savedLocale = _loadSavedLocale()
	if savedLocale != "":
		TranslationServer.set_locale(savedLocale)
	elif not supportedLocales.has(TranslationServer.get_locale().substr(0, 2)):
		TranslationServer.set_locale("en")

func _input(event: InputEvent) -> void :
	if event.is_action_pressed("switchLanguage"):
		cycleLocale()

func cycleLocale() -> void :
	var currentLocale = TranslationServer.get_locale().substr(0, 2)
	var nextIndex = (supportedLocales.find(currentLocale) + 1) % supportedLocales.size()
	TranslationServer.set_locale(supportedLocales[nextIndex])
	_saveLocale(supportedLocales[nextIndex])
	localeChanged.emit()

func _saveLocale(locale: String) -> void :
	var file = FileAccess.open(settingsPath, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({"locale": locale}))
		file.close()

func _loadSavedLocale() -> String:
	var file = FileAccess.open(settingsPath, FileAccess.READ)
	if not file:
		return ""
	var json = JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return ""
	file.close()
	var data = json.data
	if typeof(data) == TYPE_DICTIONARY and data.has("locale"):
		return data.locale
	return ""
