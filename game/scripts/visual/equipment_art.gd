class_name EquipmentArt
extends RefCounted

const BASE = preload("res://assets/art/pixel_v03/rider_atlas.png")
const ERAS = preload("res://assets/art/pixel_v03/equipment_eras.png")
const NASAL = preload("res://assets/art/pixel_v041/nasal_head.png")
const HorseArt = preload("res://scripts/visual/horse_art.gd")
const SHIELDS = preload("res://assets/art/pixel_v03/shield_fields.png")
const TORSOS = [Rect2(46,33,392,457),Rect2(494,37,385,461),Rect2(913,30,384,466),Rect2(1345,37,386,459)]
const HEADS = [Rect2(122,500,304,356),Rect2(554,510,281,348),Rect2(911,510,382,354),Rect2(1409,503,298,363)]
const FIELDS = [Rect2(132,36,441,575),Rect2(685,36,445,575),Rect2(131,639,443,574),Rect2(683,637,447,576)]
const MANIFEST_PATH = "res://data/equipment_art_v051.json"
static var _manifest: Dictionary = {}
static var _manifest_loaded = false
static var _textures: Dictionary = {}

static func descriptor(stats: Dictionary, slot: String) -> Dictionary:
	if not _manifest_loaded:
		_manifest_loaded = true
		if FileAccess.file_exists(MANIFEST_PATH):
			var parsed = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
			if parsed is Dictionary:
				_manifest = parsed
	return _manifest.get(str(stats.get(slot+"_art","")),{})

static func equipment_texture(stats: Dictionary, slot: String) -> Texture2D:
	var entry = descriptor(stats,slot)
	if entry.is_empty():
		return null
	var id = str(stats.get(slot+"_art",""))
	if not _textures.has(id):
		var path = str(entry.get("image_path",""))
		if not ResourceLoader.exists(path):
			return null
		var texture = load(path) as Texture2D
		if texture==null:
			_textures[id] = null
			return null
		var rectangle: Array = entry.get("source_region",[0,0,texture.get_width(),texture.get_height()])
		_textures[id] = region(texture,Rect2(float(rectangle[0]),float(rectangle[1]),float(rectangle[2]),float(rectangle[3])))
	return _textures[id]

static func torso_for(stats: Dictionary, red: bool = false) -> Texture2D:
	var texture = equipment_texture(stats,"armor")
	return texture if texture!=null else torso(int(stats.get("armor_tier",0)),red)

static func helmet_for(stats: Dictionary) -> Texture2D:
	var texture = equipment_texture(stats,"helmet")
	return texture if texture!=null else helmet(int(stats.get("helmet_tier",0)),bool(stats.get("gilt",false)))

static func torso(tier: int, red: bool = false) -> AtlasTexture:
	if tier > 0:
		return region(ERAS,TORSOS[clampi(tier-1,0,3)])
	return region(BASE,Rect2(40,929,258,294) if red else Rect2(34,40,259,272))

static func helmet(tier: int, gilt: bool = false) -> AtlasTexture:
	if tier == 0:
		return region(NASAL,Rect2(100,38,890,1390))
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
		"armor": return torso_for(item.stats,item.id=="mail_fr")
		"helmet": return helmet_for(item.stats)
		"crest": return shield(str(item.stats.get("heraldry","bend")))
		"shield": return shield({"英格兰":"bend","法兰西":"chevron","德意志":"cross","意大利":"diamond"}.get(str(item.get("region","")),"bend"))
		"horse": return region(HorseArt.ATLAS,HorseArt.PARTS.head)
	return region(BASE,Rect2(935,1048,298,87))
