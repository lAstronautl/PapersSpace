extends Node

# Mirrors SS14's split between the world Sprite (what the physical item on
# the table looks like) and PaperVisuals (what the UI reading window looks
# like) - these are two INDEPENDENT visual layers that don't necessarily
# match.
#
# The "visuals" sub-dictionary is a direct field-for-field copy of
# StarHorizon's Content.Client/Paper/UI/PaperVisualsComponent.cs, with values
# taken verbatim from each prototype's `- type: PaperVisuals` block in
# Resources/Prototypes/Entities/Objects/Misc/paper.yml (and
# Objects/Devices/forensic_scanner.yml for ForensicReportPaper/PaperAccessLogs,
# Objects/Misc/acquisition_slips.yml for the AcquisitionSlip family):
#   backgroundImagePath, backgroundPatchMargin, backgroundModulate,
#   backgroundImageTile, headerImagePath, headerMargin, footerImagePath,
#   footerMargin, contentImagePath, contentImageModulate,
#   contentImageNumLines, contentMargin, maxWritableArea (x,y).
#
# IMPORTANT: in the YAML source, all margin fields are Robust's Box2, whose
# constructor order is (left, BOTTOM, right, TOP) - NOT (left, top, right,
# bottom) like a CSS/UI Thickness. Every Vector4 below has already been
# reordered from that YAML (left,bottom,right,top) into Godot's
# Vector4(left, top, right, bottom) - so .x=left, .y=top, .z=right, .w=bottom
# throughout this file and in paperBackground.gd/fileEditor.gd. Symmetric
# values (top==bottom) are unaffected either way; only asymmetric ones
# (e.g. headerMargin on cargo_invoice/nanotask/artifact_analyzer,
# contentMargin on captains_thoughts/artifact_analyzer) actually needed
# reordering versus the raw YAML text.
#
# Non-PaperVisuals fields kept alongside for this port's own bookkeeping:
# "worldTexture"/"worldTextureEmpty" -> overrides the world Sprite with
#   unique RSI-equivalent art (AcquisitionSlips, NanoTask, ForensicReportPaper/
#   AccessLogs, ArtifactAnalyzer all do this in SS14).
# "content" is fixed/generated text stamped on at creation time.
const variants = {
	# Paper has an empty PaperVisuals in SS14, so its window uses the
	# "PaperDefaultBorder" style (default border tinted light cream) - see
	# paperBackground.gd. Same for the variants below that only add content.
	"default": {
		"visuals": {},
	},
	"office": {
		"visuals": {"backgroundImagePath": "res://png/item/paper/backgrounds/paper_background_default.png", "backgroundPatchMargin": Vector4(16, 16, 16, 16), "contentImagePath": "res://png/item/paper/backgrounds/paper_content_lined.png", "contentMargin": Vector4(16, 16, 16, 16)},
	},
	"cargo_invoice": {
		"visuals": {"backgroundImagePath": "res://png/item/paper/backgrounds/paper_background_default.png", "backgroundPatchMargin": Vector4(16, 16, 16, 16), "backgroundModulate": Color("9ef5ff"), "contentImagePath": "res://png/item/paper/backgrounds/paper_content_lined.png", "contentImageModulate": Color("9ef5ff"), "contentMargin": Vector4(16, 16, 16, 16), "headerImagePath": "res://png/item/paper/headers/header_cargo_invoice.png", "headerMargin": Vector4(0, 0, 0, 12)},
		"color": "#9ef5ff",
	},
	"captains_thoughts": {
		"visuals": {"backgroundImagePath": "res://png/item/paper/backgrounds/paper_background_default.png", "backgroundPatchMargin": Vector4(16, 16, 16, 16), "backgroundModulate": Color("e6e6fa"), "headerImagePath": "res://png/item/paper/headers/header_captains_thoughts.png", "contentMargin": Vector4(32, 0, 32, 16)},
		"color": "#e6e6fa",
	},
	# Mirrors StarHorizon's _NF/Entities/Objects/Misc/paper.yml PaperColored*
	# family: plain Paper (parent: Paper) with only a Sprite color + a
	# PaperVisuals.backgroundModulate override - no unique backgroundImagePath,
	# so the UI reading window falls back to PaperDefaultBorder
	# (paper_background_default, 16px patch margin) tinted by backgroundModulate,
	# same as every other undecorated colored paper variant here.
	"colored_yellow": {"visuals": {"backgroundModulate": Color("fff4b5")}, "color": "yellow"},
	"colored_green": {"visuals": {"backgroundModulate": Color("bae6ba")}, "color": "green"},
	"colored_red": {"visuals": {"backgroundModulate": Color("f4b5b5")}, "color": "red"},
	"colored_orange": {"visuals": {"backgroundModulate": Color("f9c7a1")}, "color": "orange"},
	"colored_blue": {"visuals": {"backgroundModulate": Color("b7dcfa")}, "color": "blue"},
	"colored_purple": {"visuals": {"backgroundModulate": Color("dfb7fa")}, "color": "purple"},
	"forensic_scanner": {
		"visuals": {"backgroundImagePath": "res://png/item/paper/backgrounds/paper_background_perforated.png", "backgroundImageTile": true, "backgroundPatchMargin": Vector4(6, 0, 6, 0), "headerImagePath": "res://png/item/paper/headers/header_forensic_scanner.png", "headerMargin": Vector4(0, 4, 0, 0), "contentMargin": Vector4(12, 0, 6, 0), "maxWritableArea": Vector2(368, 256)},
		"worldTexture": "res://png/item/paper/paper_receipt_horizontal_words.png", "worldTextureEmpty": "res://png/item/paper/paper_receipt_horizontal.png",
	},
	"access_logs": {
		"visuals": {"backgroundImagePath": "res://png/item/paper/backgrounds/paper_background_perforated.png", "backgroundImageTile": true, "backgroundPatchMargin": Vector4(6, 0, 6, 0), "contentMargin": Vector4(12, 0, 6, 0), "maxWritableArea": Vector2(368, 256)},
		"worldTexture": "res://png/item/paper/paper_receipt_horizontal_words.png", "worldTextureEmpty": "res://png/item/paper/paper_receipt_horizontal.png",
	},
	"nanotask": {
		"visuals": {"backgroundImagePath": "res://png/item/paper/backgrounds/paper_background_perforated.png", "backgroundImageTile": true, "backgroundPatchMargin": Vector4(0, 6, 0, 6), "headerImagePath": "res://png/item/paper/headers/header_nanotask.png", "headerMargin": Vector4(0, 6, 0, 0), "contentMargin": Vector4(12, 0, 12, 0), "maxWritableArea": Vector2(256, 0)},
		"worldTexture": "res://png/item/paper/paper_receipt_words.png", "worldTextureEmpty": "res://png/item/paper/paper_receipt.png",
	},
	# Mirrors StarHorizon's DiagnosisReportPaper (Entities/Structures/Machines/
	# Medical/disease_diagnoser.yml) - same perforated receipt look/margins as
	# nanotask, just the virus header and a narrower writable width (128 vs 256).
	"disease_diagnosis": {
		"visuals": {"backgroundImagePath": "res://png/item/paper/backgrounds/paper_background_perforated.png", "backgroundImageTile": true, "backgroundPatchMargin": Vector4(0, 6, 0, 6), "headerImagePath": "res://png/item/paper/headers/header_virus.png", "headerMargin": Vector4(0, 6, 0, 0), "contentMargin": Vector4(12, 0, 12, 0), "maxWritableArea": Vector2(128, 0)},
		"worldTexture": "res://png/item/paper/paper_receipt_words.png", "worldTextureEmpty": "res://png/item/paper/paper_receipt.png",
	},
	"artifact_analyzer": {
		"visuals": {"backgroundImagePath": "res://png/item/paper/backgrounds/paper_background_dotmatrix.png", "backgroundImageTile": true, "backgroundPatchMargin": Vector4(37, 0, 37, 0), "headerImagePath": "res://png/item/paper/headers/header_artifact_analyzer.png", "headerMargin": Vector4(0, 16, 0, 0), "contentImagePath": "res://png/item/paper/backgrounds/paper_content_dotmatrix.png", "contentImageNumLines": 2, "contentMargin": Vector4(16, 0, 16, 16), "maxWritableArea": Vector2(400, 0)},
		"worldTexture": "res://png/item/paper/paper_dotmatrix_words.png", "worldTextureEmpty": "res://png/item/paper/paper_dotmatrix.png",
	},
	"cargo_bounty_manifest": {
		"visuals": {"backgroundImagePath": "res://png/item/paper/backgrounds/paper_background_default.png", "backgroundPatchMargin": Vector4(16, 16, 16, 16), "backgroundModulate": Color("f7e574"), "contentImagePath": "res://png/item/paper/backgrounds/paper_content_lined.png", "contentImageModulate": Color("f7e574"), "contentMargin": Vector4(16, 16, 16, 16), "headerImagePath": "res://png/item/paper/headers/header_cargo_invoice.png", "headerMargin": Vector4(0, 0, 0, 12)},
		"color": "#f7e574",
	},
	"acquisition_medical": {
		"visuals": {"headerImagePath": "res://png/item/paper/headers/header_acquisition_medical.png", "footerImagePath": "res://png/item/paper/footers/footer_barcode.png", "contentMargin": Vector4(16, 16, 16, 16), "maxWritableArea": Vector2(512, 512)},
		"worldTexture": "res://png/item/paper/paper_acquisition_medical_words.png", "worldTextureEmpty": "res://png/item/paper/paper_acquisition_medical.png",
		"editingDisabled": true,
	},
	"acquisition_science": {
		"visuals": {"headerImagePath": "res://png/item/paper/headers/header_acquisition_science.png", "footerImagePath": "res://png/item/paper/footers/footer_barcode.png", "contentMargin": Vector4(16, 16, 16, 16), "maxWritableArea": Vector2(512, 512)},
		"worldTexture": "res://png/item/paper/paper_acquisition_science_words.png", "worldTextureEmpty": "res://png/item/paper/paper_acquisition_science.png",
		"editingDisabled": true,
	},
	"acquisition_security": {
		"visuals": {"headerImagePath": "res://png/item/paper/headers/header_acquisition_security.png", "footerImagePath": "res://png/item/paper/footers/footer_barcode.png", "contentMargin": Vector4(16, 16, 16, 16), "maxWritableArea": Vector2(512, 512)},
		"worldTexture": "res://png/item/paper/paper_acquisition_security_words.png", "worldTextureEmpty": "res://png/item/paper/paper_acquisition_security.png",
		"editingDisabled": true,
	},
	"acquisition_cargo": {
		"visuals": {"headerImagePath": "res://png/item/paper/headers/header_acquisition_cargo.png", "footerImagePath": "res://png/item/paper/footers/footer_barcode.png", "contentMargin": Vector4(16, 16, 16, 16), "maxWritableArea": Vector2(512, 512)},
		"worldTexture": "res://png/item/paper/paper_acquisition_cargo_words.png", "worldTextureEmpty": "res://png/item/paper/paper_acquisition_cargo.png",
		"editingDisabled": true,
	},
	"acquisition_engineering": {
		"visuals": {"headerImagePath": "res://png/item/paper/headers/header_acquisition_engineering.png", "footerImagePath": "res://png/item/paper/footers/footer_barcode.png", "contentMargin": Vector4(16, 16, 16, 16), "maxWritableArea": Vector2(512, 512)},
		"worldTexture": "res://png/item/paper/paper_acquisition_engineering_words.png", "worldTextureEmpty": "res://png/item/paper/paper_acquisition_engineering.png",
		"editingDisabled": true,
	},
	"cnc_sheet": {
		"visuals": {"backgroundImagePath": "res://png/item/paper/backgrounds/paper_background_default.png", "backgroundPatchMargin": Vector4(16, 16, 16, 16), "backgroundModulate": Color("cccccc"), "contentImagePath": "res://png/item/paper/backgrounds/paper_content_lined.png", "contentImageModulate": Color("cccccc"), "contentMargin": Vector4(16, 16, 16, 16)},
		"color": "#cccccc",
		"content": "generateCnc",
	},
	"nuke_code": {
		"visuals": {},
		"content": "generateNukeCode",
	},
	"traitor_codes": {
		"visuals": {},
		"content": "generateTraitorCodes",
	},
	"acquisition_service": {
		"visuals": {"headerImagePath": "res://png/item/paper/headers/header_acquisition_service.png", "footerImagePath": "res://png/item/paper/footers/footer_barcode.png", "contentMargin": Vector4(16, 16, 16, 16), "maxWritableArea": Vector2(512, 512)},
		"worldTexture": "res://png/item/paper/paper_acquisition_service_words.png", "worldTextureEmpty": "res://png/item/paper/paper_acquisition_service.png",
		"editingDisabled": true,
	},
	# Mirrors StarHorizon's MedTek patient record (_NF forms_medical.yml
	# PaperWrittenMedicalMedtekPatientRecord): NanoTask-style perforated receipt
	# with the MedTek header and a 256-wide writable area.
	"medtek_patient_record": {
		"visuals": {"backgroundImagePath": "res://png/item/paper/backgrounds/paper_background_perforated.png", "backgroundImageTile": true, "backgroundPatchMargin": Vector4(0, 6, 0, 6), "headerImagePath": "res://png/item/paper/headers/header_medtek_report.png", "headerMargin": Vector4(0, 6, 0, 0), "contentMargin": Vector4(12, 0, 12, 0), "maxWritableArea": Vector2(256, 0)},
		"worldTexture": "res://png/item/paper/paper_receipt_words.png", "worldTextureEmpty": "res://png/item/paper/paper_receipt.png",
	},
	# Mirrors StarHorizon's Napkin (_NF/.../Service/napkin.yml): tinted default
	# border, 280 characters max, tiny napkin world sprite.
	"napkin": {
		"visuals": {"backgroundImagePath": "res://png/item/paper/backgrounds/paper_background_default.png", "backgroundPatchMargin": Vector4(16, 16, 16, 16), "backgroundModulate": Color("ead4aa"), "contentMargin": Vector4(16, 16, 16, 16), "headerMargin": Vector4(0, 0, 0, 12), "maxWritableArea": Vector2(256, 0)},
		"worldTexture": "res://png/item/paper/paper_napkin_words.png", "worldTextureEmpty": "res://png/item/paper/paper_napkin.png",
		"contentSize": 280,
	},
	# Mirrors StarHorizon's NFBusinessCardBlank / PowerForkCertification.
	"nf_business_card": {
		"visuals": {"backgroundImagePath": "res://png/item/paper/backgrounds/business_card_background_white.png", "backgroundPatchMargin": Vector4(16, 16, 16, 16), "contentMargin": Vector4(4, 4, 4, 4), "maxWritableArea": Vector2(400, 256)},
		"worldTexture": "res://png/item/paper/paper_business_card_words.png", "worldTextureEmpty": "res://png/item/paper/paper_business_card.png",
	},
	# Mirrors StarHorizon's SyndicateBusinessCard (Objects/Misc/business_card.yml).
	"syndicate_business_card": {
		"visuals": {"backgroundImagePath": "res://png/item/paper/backgrounds/paper_background_blood_red.png", "backgroundPatchMargin": Vector4(16, 16, 16, 16), "headerImagePath": "res://png/item/paper/headers/header_syndicate_logo.png", "headerMargin": Vector4(0, 0, 0, 2), "contentMargin": Vector4(4, 4, 4, 4), "maxWritableArea": Vector2(400, 256)},
		"worldTexture": "res://png/item/paper/paper_syndicate_card.png", "worldTextureEmpty": "res://png/item/paper/paper_syndicate_card.png",
		"contentKey": "form_syndicate_business_card_content",
	},
	# Mirrors StarHorizon's AnCoBusinessCard (_Horizon/_Fractions/AnCo).
	"anco_business_card": {
		"visuals": {"backgroundImagePath": "res://png/item/paper/backgrounds/paper_background_black_ardon.png", "backgroundPatchMargin": Vector4(4, 4, 4, 4), "headerImagePath": "res://png/item/paper/headers/header_anco_logo.png", "contentMargin": Vector4(4, 4, 4, 4), "maxWritableArea": Vector2(460, 250)},
		"worldTexture": "res://png/item/paper/paper_anrox_card.png", "worldTextureEmpty": "res://png/item/paper/paper_anrox_card.png",
		"editingDisabled": true,
		"contentKey": "form_anco_business_card_content",
	},
	# Mirrors StarHorizon's Envelope: postage-stamp header offset 216px from the
	# left, no background image (falls back to the default paper border).
	"envelope": {
		"visuals": {"headerImagePath": "res://png/item/paper/headers/header_postage_stamp.png", "headerMargin": Vector4(216, 0, 0, 0), "contentMargin": Vector4(0, 0, 0, 0), "maxWritableArea": Vector2(368, 256)},
		"worldTexture": "res://png/item/paper/envelope_open.png", "worldTextureEmpty": "res://png/item/paper/envelope_open.png",
		"contentKey": "form_envelope_content",
	},
	# Mirrors StarHorizon's BookBase PaperVisuals (Objects/Misc/books.yml).
	# Margin order verified against the YAML Box2 (left, bottom, right, top):
	# "23, 16, 14, 15" -> Vector4(left 23, top 15, right 14, bottom 16).
	"book": {
		"visuals": {"backgroundImagePath": "res://png/item/paper/backgrounds/paper_background_book.png", "backgroundPatchMargin": Vector4(23, 15, 14, 16), "contentMargin": Vector4(20, 20, 20, 20)},
		"contentSize": 12000,
	},
}

# Prewritten documents (forms, manuals, books, cards...). Each entry layers a
# few overrides on one of the visual types above - see paperForms.gd.
const Forms = preload("res://scripts/paperForms.gd")

# Verbatim from StarHorizon's Resources/Locale/en-US/paper/book-dnd.ftl
# (book-cnc-sheet key) - a D&D-parody "Carps & Crypts 5e" character sheet.
const cncSheetText = "C&C 5e Character Sheet
--------------------------------------------------------------------------------------
SECTION 1:  THE BASICS
--------------------------------------------------------------------------------------
Character Name  :
Race / Class    :
Level / Exp Pts :
Background      :

--------------------------------------------------------------------------------------
SECTION 2: ABILITIES
--------------------------------------------------------------------------------------
Strength     =     10   (+0) 10 Base
Dexterity    =     10   (+0) 10 Base
Constitution =     10   (+0) 10 Base
Intelligence =     10   (+0) 10 Base
Wisdom       =     10   (+0) 10 Base
Charisma     =     10   (+0) 10 Base

Proficiency Bonus =
Perception (passive wisdom) =

Racial (Race)

Class (Class)


--------------------------------------------------------------------------------------
SECTION 3:  SAVING THROWS
--------------------------------------------------------------------------------------

( )Strength     =      +0
( )Dexterity    =      +0
( )Constitution =      +0
( )Intelligence =      +0
( )Wisdom       =      +0
( )Charisma     =      +0


--------------------------------------------------------------------------------------
SECTION 4:  SKILLS
--------------------------------------------------------------------------------------

( )  Acrobatics (Dex)      +0       ( )  Medicine (Wis)        +0
( )  Animal Handling (Wis) +0       ( )  Nature (Int)          +0
( )  Arcana (Int)          +0       ( )  Perception (Wis)      +0
( )  Athletics  (Str)      +0       ( )  Performance (Cha)     +0
( )  Deception (Cha)       +0       ( )  Persuasion (Cha)      +0
( )  History (Int)         +0       ( )  Religion (Int)        +0
( )  Insight (Wis)         +0       ( )  Sleight of Hand (Dex) +0
( )  Intimidation (Cha)    +0       ( )  Stealth (Dex)         +0
( )  Investigation (Int)   +0       ( )  Survival (Wis)        +0


--------------------------------------------------------------------------------------
SECTION 5:  COMBAT & HEALTH
--------------------------------------------------------------------------------------


Armor Class          :
Initiative (passive) :
Speed                :

Hit Dice             :
Max Hit Points       :
Current Hit Points   :
Temporary Hit Points :

ATTACKS
Weapon type(Melee or Ranged)   /   Bonus   /   Damage (Type)

--------------------------------------------------------------------------------------
SECTION 6:  BACKGROUND
--------------------------------------------------------------------------------------

Age / Gender         :
Height / Weight      :
Eyes / Skin / Hair   :
Description          :

Background           :
Skill Proficiencies  :
Tool Proficiencies   :
Languages            :

Features             :
Con of Choice        :
Traits               :
Ideal                :
Bonds                :
Flaws                :

--------------------------------------------------------------------------------------
SECTION 7: EXTRAS
--------------------------------------------------------------------------------------
Equipment List
Description                 Cost       Weight


lbs

Wealth
PP         :
EP         :
GP         :
SP         :
CP         :

Gems         :
Jewelry      :
Other        :
Magic Items  :


--------------------------------------------------------------------------------------
SECTION 8: SPELLCASTING
--------------------------------------------------------------------------------------

Spell Level:
Spell Save DC:
Spell Attack Mod:
Spell Slots:
  1: (MAX) (USED)
  2: (MAX) (USED)
  3: (MAX) (USED)
  4: (MAX) (USED)
  5: (MAX) (USED)
  6: (MAX) (USED)
  7: (MAX) (USED)
  8: (MAX) (USED)
  9: (MAX) (USED)

Cantrips
Name  Casting Time  Range  Duration  Components

1: Name  Casting Time  Range  Duration  Components  Ritual?

2: Name  Casting Time  Range  Duration  Components  Ritual?

3: Name  Casting Time  Range  Duration  Components  Ritual?

4: Name  Casting Time  Range  Duration  Components  Ritual?

5: Name  Casting Time  Range  Duration  Components  Ritual?

6: Name  Casting Time  Range  Duration  Components  Ritual?

7: Name  Casting Time  Range  Duration  Components  Ritual?

8: Name  Casting Time  Range  Duration  Components  Ritual?

9: Name  Casting Time  Range  Duration  Components  Ritual?
--------------------------------------------------------------------------------------
Carps and Crypts 5e
"

# Word lists mirror StarHorizon's Datasets/adjectives.yml + verbs.yml
# (localizedDataset prototypes referenced by TraitorCodewordGenerator).
const traitorAdjectives = ["adorable", "adventurous", "aggressive", "alert", "ancient", "brave", "clever", "curious", "eager", "fierce", "gentle", "happy", "jolly", "kind", "lively", "mighty", "nimble", "proud", "quiet", "rapid"]
const traitorVerbs = ["jumps", "runs", "flies", "sings", "dances", "hides", "watches", "builds", "breaks", "climbs", "swims", "writes", "paints", "cooks", "drives", "explores", "laughs", "whispers", "shouts", "wanders"]

# Mirrors SS14's NukeCodePaperSystem exactly: "nuke-codes-message" is
# "[color=red]TOP SECRET![/color]", followed by a newline and
# "nuke-codes-list" = "{$name} code: {$code}" with a random 6-digit code
# (here: generated once per paper instance, since this sandbox has no
# "round" to generate it once for).
static func generateNukeCode() -> String:
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	var code = ""
	for i in 6:
		code += str(rng.randi_range(0, 9))
	return "[color=red]TOP SECRET![/color]\nNuclear Device code: %s" % code

# Mirrors SS14's TraitorCodePaperSystem/CodewordSystem: a header line
# ("syndicate codewords:") followed by each codeword on its own line, one
# per line, no numbering/commas/markup. AllTraitorCodesPaper shows every
# generated codeword (codewordShowAll) rather than just one.
static func generateTraitorCodes() -> String:
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	var lines = ["syndicate codewords:"]
	for i in 4:
		var adjective = traitorAdjectives[rng.randi_range(0, traitorAdjectives.size() - 1)]
		var verb = traitorVerbs[rng.randi_range(0, traitorVerbs.size() - 1)]
		lines.append("%s %s" % [adjective, verb])
	return "\n".join(lines)

static func generateCnc() -> String:
	return cncSheetText

# Printer menu grouping. Visual types are listed here; forms carry their own
# "category" (see paperForms.gd).
const categoryOrder = ["basic", "receipts", "cards", "nfsd", "sr", "stc", "medical", "doc", "frontier", "manuals", "books", "misc"]
const variantCategories = {
	"default": "basic", "office": "basic", "colored_yellow": "basic", "colored_green": "basic", "colored_red": "basic",
	"colored_orange": "basic", "colored_blue": "basic", "colored_purple": "basic", "captains_thoughts": "basic",
	"cargo_invoice": "basic", "cargo_bounty_manifest": "basic", "cnc_sheet": "basic", "nuke_code": "basic",
	"traitor_codes": "basic", "napkin": "basic", "envelope": "basic", "book": "books",
	"forensic_scanner": "receipts", "access_logs": "receipts", "nanotask": "receipts", "disease_diagnosis": "receipts",
	"artifact_analyzer": "receipts", "medtek_patient_record": "receipts",
	"acquisition_medical": "receipts", "acquisition_science": "receipts", "acquisition_security": "receipts",
	"acquisition_cargo": "receipts", "acquisition_engineering": "receipts", "acquisition_service": "receipts",
	"nf_business_card": "cards", "syndicate_business_card": "cards", "anco_business_card": "cards",
}

static func getCategory(variantId: String) -> String:
	if Forms.forms.has(variantId):
		return Forms.forms[variantId].get("category", "misc")
	return variantCategories.get(variantId, "basic")

static func getVariantIdsInCategory(category: String) -> Array:
	return allVariantIds().filter(func(id): return getCategory(id) == category)

# Every printable paper type id: the visual types first, then the forms.
static func allVariantIds() -> Array:
	return variants.keys() + Forms.forms.keys()

static func getContent(variantId: String) -> String:
	var config = getConfig(variantId)
	if config.has("contentKey"):
		return TranslationServer.translate(config.contentKey)
	var generator = config.get("content", "")
	match generator:
		"generateCnc":
			return generateCnc()
		"generateNukeCode":
			return generateNukeCode()
		"generateTraitorCodes":
			return generateTraitorCodes()
	return ""

static func getConfig(variantId: String) -> Dictionary:
	if variants.has(variantId):
		return variants[variantId]
	if Forms.forms.has(variantId):
		var form: Dictionary = Forms.forms[variantId]
		return variants.get(form.get("base", "default"), variants["default"]).merged(form, true)
	return variants["default"]

# Display name of a printable paper type in the current language.
static func getDisplayName(variantId: String) -> String:
	var key: String = getConfig(variantId).get("nameKey", "paper_name_" + variantId)
	var translated = TranslationServer.translate(key)
	return variantId if translated == key else translated

# Prewritten stamps a freshly printed paper of this type carries (e.g. a
# document that comes pre-signed), in the same shape StampOverlay stores them.
static func getPresetStamps(variantId: String) -> Array:
	var stamps: Array = []
	for stampState in getConfig(variantId).get("stamps", []):
		stamps.append({"stampState": stampState, "rotation": 0.0, "position": {"x": 0.0, "y": 0.0}})
	return stamps

# Mirrors SS14's PaperComponent.EditingDisabled: true on the AcquisitionSlip
# family (Resources/Prototypes/Entities/Objects/Misc/acquisition_slips.yml,
# `Paper.editingDisabled: true`) - these forms can never be written on again
# once printed, regardless of pen/CyberPen, only stamped.
static func isEditingDisabled(variantId: String) -> bool:
	return getConfig(variantId).get("editingDisabled", false)

# Mirrors SS14's PaperComponent.ContentSize (default 10000 everywhere in the
# ported prototype set - no variant overrides it to a smaller value).
static func getContentSize(variantId: String) -> int:
	return getConfig(variantId).get("contentSize", 10000)

# Mirrors PaperVisualsComponent's C# field defaults exactly, so callers don't
# need to null-check every field: BackgroundModulate/ContentImageModulate/
# HeaderImageModulate/FooterImageModulate default to Color.White,
# ContentImageNumLines defaults to 1, margins default to zero, MaxWritableArea
# defaults to unset (both axes 0 = unconstrained).
static func getVisuals(variantId: String) -> Dictionary:
	var visuals: Dictionary = getConfig(variantId).get("visuals", {})
	return {
		"backgroundImagePath": visuals.get("backgroundImagePath", ""),
		"backgroundPatchMargin": visuals.get("backgroundPatchMargin", Vector4.ZERO),
		"backgroundModulate": visuals.get("backgroundModulate", Color.WHITE),
		"backgroundImageTile": visuals.get("backgroundImageTile", false),
		"headerImagePath": visuals.get("headerImagePath", ""),
		"headerImageModulate": visuals.get("headerImageModulate", Color.WHITE),
		"headerMargin": visuals.get("headerMargin", Vector4.ZERO),
		"footerImagePath": visuals.get("footerImagePath", ""),
		"footerImageModulate": visuals.get("footerImageModulate", Color.WHITE),
		"footerMargin": visuals.get("footerMargin", Vector4.ZERO),
		"contentImagePath": visuals.get("contentImagePath", ""),
		"contentImageModulate": visuals.get("contentImageModulate", Color.WHITE),
		"contentImageNumLines": visuals.get("contentImageNumLines", 1),
		"contentMargin": visuals.get("contentMargin", Vector4.ZERO),
		"maxWritableArea": visuals.get("maxWritableArea", Vector2.ZERO),
	}
