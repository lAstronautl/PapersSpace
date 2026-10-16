extends Node

# Mirrors every spawnable RubberStamp* prototype in StarHorizon
# (Resources/Prototypes/Entities/Objects/Misc/rubber_stamp.yml, _NF/.../rubber_stamp.yml,
# _Horizon/_Fractions/**/rubber_stamp.yml). One entry per prototype - several
# prototypes share a paper mark but differ in name/colour/item sprite, so the
# key identifies the prototype, NOT the mark:
#   name      - translation key of Stamp.stampedName
#   color     - Stamp.stampedColor
#   mark      - paper_stamp-<mark> state drawn on the paper (defaults to the key)
#   protected - Stamp.protected (blocks Frontier's unprotected-stamp pen bypass)
#   reapply   - Stamp.reapply (may be applied repeatedly, up to reapplyLimit)
# The item sprite is png/item/stamps/stamp-<key>.png.
const stampLimit = 100
const reapplyLimit = 10

const stampData = {
	"cap": {"name": "stamp_name_cap", "color": "#3681bb"},  # RubberStampCaptain
	"centcom": {"name": "stamp_name_centcom", "color": "#006600", "protected": true},  # RubberStampCentcom
	"chaplain": {"name": "stamp_name_chaplain", "color": "#d70601"},  # RubberStampChaplain
	"lawyer": {"name": "stamp_name_lawyer", "color": "#233d57"},  # RubberStampLawyer
	"clown": {"name": "stamp_name_clown", "color": "#ff33cc"},  # RubberStampClown
	"ce": {"name": "stamp_name_ce", "color": "#c69b17"},  # RubberStampCE
	"cmo": {"name": "stamp_name_cmo", "color": "#33ccff"},  # RubberStampCMO
	"hop": {"name": "stamp_name_hop", "color": "#6ec0ea"},  # RubberStampHop
	"hos": {"name": "stamp_name_hos", "color": "#cc0000"},  # RubberStampHos
	"mime": {"name": "stamp_name_mime", "color": "#777777"},  # RubberStampMime
	"qm": {"name": "stamp_name_qm", "color": "#a23e3e"},  # RubberStampQm
	"rd": {"name": "stamp_name_rd", "color": "#1f66a0"},  # RubberStampRd
	"trader": {"name": "stamp_name_trader", "color": "#000000"},  # RubberStampTrader
	"syndicate": {"name": "stamp_name_syndicate", "color": "#850000"},  # RubberStampSyndicate
	"warden": {"name": "stamp_name_warden", "color": "#5b0000"},  # RubberStampWarden
	"ok": {"name": "stamp_name_ok", "color": "#00be00", "reapply": true},  # RubberStampApproved
	"deny": {"name": "stamp_name_deny", "color": "#a23e3e", "reapply": true},  # RubberStampDenied
	"detective": {"name": "stamp_name_detective", "color": "#754d36"},  # RubberStampDetective
	"greytide": {"name": "stamp_name_greytide", "color": "#323232"},  # RubberStampGreytide
	"psychologist": {"name": "stamp_name_psychologist", "color": "#3366ff", "mark": "nf-psychologist"},  # RubberStampPsychologist
	"wizard": {"name": "stamp_name_wizard", "color": "#881bc1"},  # RubberStampWizard
	"sr": {"name": "stamp_name_sr", "color": "#6ec0ea", "mark": "hop", "protected": true},  # RubberStampSr
	"nf-stc": {"name": "stamp_name_nf_stc", "color": "#cc6633"},  # RubberStampStc
	"nf-sheriff": {"name": "stamp_name_nf_sheriff", "color": "#4c653a", "protected": true},  # RubberStampSheriff
	"nf-doctor": {"name": "stamp_name_nf_doctor", "color": "#2ea5e6"},  # RubberStampDoctor
	"nf-engineer": {"name": "stamp_name_nf_engineer", "color": "#db8727"},  # RubberStampEngineer
	"nf-pal": {"name": "stamp_name_nf_pal", "color": "#61943a"},  # RubberStampPal
	"nf-doc": {"name": "stamp_name_nf_doc", "color": "#5b97bc", "mark": "cmo"},  # RubberStampDoc
	"nf-bailiff": {"name": "stamp_name_nf_bailiff", "color": "#51703b"},  # RubberStampBailiff
	"nf-plant-manager": {"name": "stamp_name_nf_plant_manager", "color": "#d4760b"},  # RubberStampPlantManager
	"anco": {"name": "stamp_name_anco", "color": "#b30e0e"},  # RubberStampAnCo
	"dipp": {"name": "stamp_name_dipp", "color": "#b30e0e"},  # RubberStampAnCoDIPP
	"dcs": {"name": "stamp_name_dcs", "color": "#b30e0e"},  # RubberStampAnCoDCS
	"stardust": {"name": "stamp_name_stardust", "color": "#b30e0e"},  # RubberStampAnCoStarDust
	"miligalax": {"name": "stamp_name_miligalax", "color": "#b30e0e"},  # RubberStampAnCoMiliGalax
	"subea": {"name": "stamp_name_subea", "color": "#b30e0e"},  # RubberStampAnCoSubea
	"lvhi": {"name": "stamp_name_lvhi", "color": "#e26817", "mark": "nf-engineer"},  # RubberStampLVHI
	"trauma": {"name": "stamp_name_trauma", "color": "#ff0303", "mark": "nf-stc"},  # RubberStampTrauma
}

# Keys that older saves used before every prototype got its own entry.
const keyAliases = {
	"nf-psychologist": "psychologist",
}

static func resolveKey(stampState: String) -> String:
	return keyAliases.get(stampState, stampState)

static func getStampKeys() -> Array:
	return stampData.keys()

static func getStampName(stampState: String) -> String:
	return stampData.get(resolveKey(stampState), {}).get("name", "stamp_name_default")

static func getStampColor(stampState: String) -> Color:
	var hex = stampData.get(resolveKey(stampState), {}).get("color", "#a23e3e")
	return Color.html(hex)

static func getStampMark(stampState: String) -> String:
	var key = resolveKey(stampState)
	return stampData.get(key, {}).get("mark", key)

static func isProtected(stampState: String) -> bool:
	return stampData.get(resolveKey(stampState), {}).get("protected", false)

static func canReapply(stampState: String) -> bool:
	return stampData.get(resolveKey(stampState), {}).get("reapply", false)
