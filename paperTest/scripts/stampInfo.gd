extends Node

const stampData = {
	"cap": {"name": "stamp_name_cap", "color": "#3681bb"},
	"ce": {"name": "stamp_name_ce", "color": "#c69b17"},
	"centcom": {"name": "stamp_name_centcom", "color": "#006600", "protected": true},
	"chaplain": {"name": "stamp_name_chaplain", "color": "#d70601"},
	"clown": {"name": "stamp_name_clown", "color": "#ff33cc"},
	"cmo": {"name": "stamp_name_cmo", "color": "#33ccff"},
	"deny": {"name": "stamp_name_deny", "color": "#a23e3e"},
	"detective": {"name": "stamp_name_detective", "color": "#754d36"},
	"greytide": {"name": "stamp_name_greytide", "color": "#323232"},
	"hop": {"name": "stamp_name_hop", "color": "#6ec0ea"},
	"hos": {"name": "stamp_name_hos", "color": "#cc0000"},
	"lawyer": {"name": "stamp_name_lawyer", "color": "#233d57"},
	"mime": {"name": "stamp_name_mime", "color": "#777777"},
	"nf-bailiff": {"name": "stamp_name_nf_bailiff", "color": "#5b0000"},
	"nf-doc": {"name": "stamp_name_nf_doc", "color": "#33ccff"},
	"nf-doctor": {"name": "stamp_name_nf_doctor", "color": "#33ccff"},
	"nf-engineer": {"name": "stamp_name_nf_engineer", "color": "#c69b17"},
	"nf-pal": {"name": "stamp_name_nf_pal", "color": "#6ec0ea"},
	"nf-plant-manager": {"name": "stamp_name_nf_plant_manager", "color": "#c69b17"},
	"nf-psychologist": {"name": "stamp_name_nf_psychologist", "color": "#3366ff"},
	"nf-sheriff": {"name": "stamp_name_nf_sheriff", "color": "#cc0000"},
	"nf-stc": {"name": "stamp_name_nf_stc", "color": "#6ec0ea"},
	"ok": {"name": "stamp_name_ok", "color": "#00be00"},
	"psychologist": {"name": "stamp_name_psychologist", "color": "#3366ff"},
	"qm": {"name": "stamp_name_qm", "color": "#a23e3e"},
	"rd": {"name": "stamp_name_rd", "color": "#1f66a0"},
	"syndicate": {"name": "stamp_name_syndicate", "color": "#850000"},
	"trader": {"name": "stamp_name_trader", "color": "#000000"},
	"warden": {"name": "stamp_name_warden", "color": "#5b0000"},
	"wizard": {"name": "stamp_name_wizard", "color": "#881bc1"},
}

static func getStampName(stampState: String) -> String:
	return stampData.get(stampState, {}).get("name", "stamp_name_default")

static func getStampColor(stampState: String) -> Color:
	var hex = stampData.get(stampState, {}).get("color", "#a23e3e")
	return Color.html(hex)

static func isProtected(stampState: String) -> bool:
	return stampData.get(stampState, {}).get("protected", false)
