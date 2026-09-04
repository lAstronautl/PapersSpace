extends Node

# Mirrors SS14's split between the world Sprite (what the physical item on
# the table looks like) and PaperVisuals (what the UI reading window looks
# like) - these are two INDEPENDENT visual layers that don't necessarily
# match, confirmed against real prototypes:
# - PaperCargoInvoice: Sprite is the ordinary "paper"/"paper_words" states
#   tinted via `color:`; PaperVisuals separately sets backgroundImagePath/
#   contentImagePath/headerImagePath (same shared images as most papers).
# - PaperNanoTaskItem/ForensicReportPaper: Sprite uses unique "paper_receipt"/
#   "paper_receipt_horizontal" world states, but PaperVisuals.backgroundImagePath
#   is "paper_background_perforated" - a DIFFERENT look in the UI than in
#   the world (receipt-shaped item, perforated-paper reading window).
# - PaperArtifactAnalyzer: Sprite uses "paper_dotmatrix", PaperVisuals uses
#   the matching "paper_background_dotmatrix" - same theme, still two
#   separate texture assets for the two separate layers.
# - AcquisitionSlips: Sprite uses unique "acquisition_form" world states;
#   PaperVisuals sets no backgroundImagePath at all (falls back to default).
#
# "kind" -> UI NinePatchRect background (paperBackground.gd) - stays
# "default" for almost everything; only structurally different paper TYPES
# (perforated, dot-matrix) actually swap this image.
# "color" -> tints both the world sprite AND the UI background/content
# images together (mirrors PaperVisuals.backgroundModulate/contentImageModulate
# always matching the Sprite's own `color:`).
# "worldTexture"/"worldTextureEmpty" -> overrides the world sprite with
# unique RSI-equivalent art instead of just tinting the default paper
# texture (AcquisitionSlips, NanoTask, ForensicReportPaper/AccessLogs,
# ArtifactAnalyzer all do this in SS14 - each with their own state, which
# may or may not match their UI kind).
# "header" -> UI-only header image drawn above the text area.
# "lined" -> UI-only lined content image drawn behind the text area.
# "editable" false mirrors Paper.editingDisabled (AcquisitionSlips).
# "content" is fixed/generated text stamped on at creation time.
const variants = {
	"default": {"kind": "default", "color": "default"},
	"office": {"kind": "default", "color": "default", "lined": true},
	"cargo_invoice": {"kind": "default", "color": "cyan", "header": "res://png/item/paper/headers/header_cargo_invoice.png", "lined": true},
	"captains_thoughts": {"kind": "default", "color": "lavender", "header": "res://png/item/paper/headers/header_captains_thoughts.png"},
	"colored_yellow": {"kind": "default", "color": "yellow"},
	"colored_green": {"kind": "default", "color": "green"},
	"colored_red": {"kind": "default", "color": "red"},
	"colored_orange": {"kind": "default", "color": "orange"},
	"colored_blue": {"kind": "default", "color": "blue"},
	"colored_purple": {"kind": "default", "color": "purple"},
	"forensic_scanner": {"kind": "perforated", "color": "default", "header": "res://png/item/paper/headers/header_forensic_scanner.png", "worldTexture": "res://png/item/paper/paper_receipt_horizontal_words.png", "worldTextureEmpty": "res://png/item/paper/paper_receipt_horizontal.png"},
	"access_logs": {"kind": "perforated", "color": "default", "worldTexture": "res://png/item/paper/paper_receipt_horizontal_words.png", "worldTextureEmpty": "res://png/item/paper/paper_receipt_horizontal.png"},
	"nanotask": {"kind": "perforated_horizontal", "color": "default", "header": "res://png/item/paper/headers/header_nanotask.png", "worldTexture": "res://png/item/paper/paper_receipt_words.png", "worldTextureEmpty": "res://png/item/paper/paper_receipt.png"},
	"artifact_analyzer": {"kind": "dotmatrix", "color": "default", "header": "res://png/item/paper/headers/header_artifact_analyzer.png", "worldTexture": "res://png/item/paper/paper_dotmatrix_words.png", "worldTextureEmpty": "res://png/item/paper/paper_dotmatrix.png"},
	"cargo_bounty_manifest": {"kind": "default", "color": "yellow", "header": "res://png/item/paper/headers/header_cargo_invoice.png"},
	"acquisition_medical": {"kind": "default", "color": "default", "header": "res://png/item/paper/headers/header_acquisition_medical.png", "editable": false, "worldTexture": "res://png/item/paper/paper_acquisition_form_words.png", "worldTextureEmpty": "res://png/item/paper/paper_acquisition_form.png"},
	"acquisition_science": {"kind": "default", "color": "default", "header": "res://png/item/paper/headers/header_acquisition_science.png", "editable": false, "worldTexture": "res://png/item/paper/paper_acquisition_form_words.png", "worldTextureEmpty": "res://png/item/paper/paper_acquisition_form.png"},
	"acquisition_security": {"kind": "default", "color": "default", "header": "res://png/item/paper/headers/header_acquisition_security.png", "editable": false, "worldTexture": "res://png/item/paper/paper_acquisition_form_words.png", "worldTextureEmpty": "res://png/item/paper/paper_acquisition_form.png"},
	"acquisition_cargo": {"kind": "default", "color": "default", "header": "res://png/item/paper/headers/header_acquisition_cargo.png", "editable": false, "worldTexture": "res://png/item/paper/paper_acquisition_form_words.png", "worldTextureEmpty": "res://png/item/paper/paper_acquisition_form.png"},
	"acquisition_engineering": {"kind": "default", "color": "default", "header": "res://png/item/paper/headers/header_acquisition_engineering.png", "editable": false, "worldTexture": "res://png/item/paper/paper_acquisition_form_words.png", "worldTextureEmpty": "res://png/item/paper/paper_acquisition_form.png"},
	"cnc_sheet": {"kind": "default", "color": "default", "content": "generateCnc"},
	"nuke_code": {"kind": "default", "color": "default", "content": "generateNukeCode"},
	"traitor_codes": {"kind": "default", "color": "default", "content": "generateTraitorCodes"},
}

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

static func getContent(variantId: String) -> String:
	var config = variants.get(variantId, {})
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
	return variants.get(variantId, variants["default"])
