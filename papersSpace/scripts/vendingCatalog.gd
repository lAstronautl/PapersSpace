extends RefCounted

# What the vending machine stocks: every item the game can produce. An entry is
# {kind, key}; kind decides how the item is spawned and where its name and icon
# come from. The order follows the vanilla list (small tools first, bulky stock
# last), papers grouped by the printer's categories.
const PaperVariants = preload("res://scripts/paperVariants.gd")
const StampInfo = preload("res://scripts/stampInfo.gd")
const PenInfo = preload("res://scripts/penInfo.gd")

const otherItems = {
	"flop": "res://png/item/disk/disk0.png",
	"weh": "res://png/item/icon.png",
	"labeler": "res://png/item/labeler/labeler.png",
	"tonerCartridge": "res://png/machines/printer/toner_cartridge.png",
	"paperScrap": "res://png/item/paper/paper_scrap.png",
	"wrench": "res://png/item/wrench/wrench.png",
}

static func entries() -> Array:
	var list: Array = []
	for key in PenInfo.getPenKeys():
		list.append({"kind": "pen", "key": key})
	for key in StampInfo.getStampKeys():
		list.append({"kind": "stamp", "key": key})
	for key in otherItems:
		list.append({"kind": "item", "key": key})
	for category in PaperVariants.categoryOrder:
		for variantId in PaperVariants.getVariantIdsInCategory(category):
			list.append({"kind": "paper", "key": variantId})
	return list

# Name in the current language (what Identity.Name shows in the vendor list).
static func getName(entry: Dictionary) -> String:
	var key: String = entry.key
	match entry.kind:
		"pen":
			return TranslationServer.translate(PenInfo.getName(key))
		"stamp":
			var nameKey = "stamp_item_" + StampInfo.resolveKey(key).replace("-", "_")
			var translated = TranslationServer.translate(nameKey)
			return key if translated == nameKey else translated
		"paper":
			return PaperVariants.getDisplayName(key)
	return TranslationServer.translate("ui_vend_item_" + key)

static func getIcon(entry: Dictionary) -> Texture2D:
	var key: String = entry.key
	var path = ""
	match entry.kind:
		"pen":
			path = "res://png/item/pens/pen-" + key + ".png"
		"stamp":
			path = "res://png/item/stamps/stamp-" + StampInfo.resolveKey(key) + ".png"
		"paper":
			path = PaperVariants.getConfig(key).get("worldTexture", "res://png/item/paper/paper.png")
		_:
			path = otherItems[key]
	return load(path) if ResourceLoader.exists(path) else null
