class_name EquipmentCatalogue
extends RefCounted

const REGIONS = ["英格兰", "法兰西", "德意志", "意大利"]
const REGION_COLORS = [Color("416f8e"), Color("a75042"), Color("b39758"), Color("598077")]
const ERAS = ["1100–1300", "1300–1400", "1400–1470", "1470–1530", "1530–1600"]
const ERA_NAMES = ["锁甲与纹章", "板片的时代", "钢铁的轮廓", "比武的盛世", "宫廷与工坊"]
const ERA_REQUIREMENTS = [0, 6, 16, 30, 48]
const SLOT_NAMES = {"armor": "甲胄", "helmet": "头盔", "lance": "骑枪", "horse": "坐骑", "crest": "纹章"}

static func load_items() -> Array:
	var raw = FileAccess.get_file_as_string("res://data/equipment.json")
	var parsed = JSON.parse_string(raw)
	return parsed if parsed is Array else []

static func find(items: Array, item_id: String) -> Dictionary:
	for item in items:
		if item.get("id", "") == item_id:
			return item
	return {}

static func era_for_renown(renown: int) -> int:
	var era = 0
	for i in range(ERA_REQUIREMENTS.size()):
		if renown >= ERA_REQUIREMENTS[i]:
			era = i
	return era

static func stats(items: Array, equipped: Dictionary) -> Dictionary:
	var result = {"armor": 0.10, "helmet": 0.08, "power": 1.0, "speed": 1.0, "stability": 1.0, "durability": 100.0, "reach": 247.0, "horse_color": "a87950", "armor_tier": 0, "helmet_tier": 0, "heraldry": "bend"}
	for slot in equipped:
		var item = find(items, str(equipped[slot]))
		for key in item.get("stats", {}):
			result[key] = item.stats[key]
	return result

static func opponent_stats(items: Array, era: int) -> Dictionary:
	var equipment = {"armor":"mail_basic","helmet":"helm_nasal","lance":"lance_ash","horse":"horse_bay","crest":"crest_chevron"}
	if era > 0:
		for slot in ["armor","helmet","lance","horse"]:
			var prefix = "helm" if slot == "helmet" else slot
			equipment[slot] = "%s_e%d" % [prefix,clampi(era,1,4)]
	return stats(items,equipment)
