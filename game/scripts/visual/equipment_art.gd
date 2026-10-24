class_name EquipmentArt
extends RefCounted

const BASE = preload("res://assets/art/pixel_v03/rider_atlas.png")
const ERAS = preload("res://assets/art/pixel_v03/equipment_eras.png")
const NASAL = preload("res://assets/art/pixel_v03/nasal_head.png")
const SHIELDS = preload("res://assets/art/pixel_v03/shield_fields.png")
const TORSOS = [Rect2(46,33,392,457),Rect2(494,37,385,461),Rect2(913,30,384,466),Rect2(1345,37,386,459)]
const HEADS = [Rect2(122,500,304,356),Rect2(554,510,281,348),Rect2(911,510,382,354),Rect2(1409,503,298,363)]
const FIELDS = [Rect2(132,36,441,575),Rect2(685,36,445,575),Rect2(131,639,443,574),Rect2(683,637,447,576)]

static func torso(tier: int, red: bool = false) -> AtlasTexture:
	if tier > 0:
		return region(ERAS,TORSOS[clampi(tier-1,0,3)])
	return region(BASE,Rect2(40,929,258,294) if red else Rect2(34,40,259,272))

static func helmet(tier: int, gilt: bool = false) -> AtlasTexture:
	if tier == 0:
		return region(NASAL,Rect2(300,112,650,1025))
	if tier >= 2:
		return region(ERAS,HEADS[clampi(tier-2,0,3)])
	return region(BASE,Rect2(391,944,194,258) if gilt else Rect2(388,62,194,237))

static func shield(design: String) -> AtlasTexture:
	var index = {"bend":0,"chevron":1,"cross":2,"diamond":3}.get(design,0)
	return region(SHIELDS,FIELDS[index])

static func region(texture: Texture2D, rectangle: Rect2) -> AtlasTexture:
	var atlas = AtlasTexture.new()
	atlas.atlas = texture
	atlas.region = rectangle
	return atlas

static func item_icon(item: Dictionary) -> Texture2D:
	match str(item.get("slot","")):
		"armor": return torso(int(item.stats.get("armor_tier",0)),item.id=="mail_fr")
		"helmet": return helmet(int(item.stats.get("helmet_tier",0)),item.id=="helm_gilt")
		"crest": return shield(str(item.stats.get("heraldry","bend")))
		"horse": return region(BASE,Rect2(424,324,309,300))
	return region(BASE,Rect2(935,1048,298,87))
