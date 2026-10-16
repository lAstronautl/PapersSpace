extends Node

# Every writing pen of StarHorizon (Resources/Prototypes/Entities/Objects/Misc/pen.yml,
# _NF/.../pen.yml, _Horizon/_Fractions/AnCo/.../pen.yml). The pen item sprite is
# png/item/pens/pen-<key>.png. "ignore" is how the pen treats stamped paper:
#   none        - cannot write over stamps (it signs instead)
#   unprotected - Tag NFWriteIgnoreUnprotectedStamps: writes over stamps, but not over
#                 paper carrying a protected stamp (Cybersun pen, wizard pen)
#   all         - Tag WriteIgnoreStamps: writes over any stamp (CentComm pen)
# signatureColor is the Stamp.stampedColor of the pen (the colour its signature has).

const penData = {
	"pen": {"name": "pen_name_pen", "ignore": "none", "color": "#333333"},  # Pen
	"luxury": {"name": "pen_name_luxury", "ignore": "none", "color": "#333333"},  # LuxuryPen
	"cyber": {"name": "pen_name_cyber", "ignore": "unprotected", "color": "#333333"},  # CyberPen
	"centcom": {"name": "pen_name_centcom", "ignore": "all", "color": "#333333"},  # PenCentcom
	"cap": {"name": "pen_name_cap", "ignore": "none", "color": "#333333"},  # PenCap
	"hop": {"name": "pen_name_hop", "ignore": "none", "color": "#333333"},  # PenHop
	"wizard": {"name": "pen_name_wizard", "ignore": "unprotected", "color": "#333333"},  # PenWiz
	"anco": {"name": "pen_name_anco", "ignore": "none", "color": "#333333"},  # PenAnCo
	"pal": {"name": "pen_name_pal", "ignore": "none", "color": "#333333"},  # PublicAffairsPen
}

# Stamp delay (UseDelay "stamp" in Pen) and the click delay (UseDelay delay).
const stampDelaySeconds = 1.0
const clickDelaySeconds = 1.5

static func getPenKeys() -> Array:
	return penData.keys()

static func getName(penState: String) -> String:
	return penData.get(penState, penData["pen"]).name

static func getSignatureColor(penState: String) -> Color:
	return Color.html(penData.get(penState, penData["pen"]).color)

static func ignoresAllStamps(penState: String) -> bool:
	return penData.get(penState, {}).get("ignore", "none") == "all"

static func ignoresUnprotectedStamps(penState: String) -> bool:
	return penData.get(penState, {}).get("ignore", "none") == "unprotected"
