class_name EquipmentCatalogue
extends RefCounted

const REGIONS = ["英格兰", "法兰西", "德意志", "意大利"]
const REGION_COLORS = [Color("416f8e"), Color("a75042"), Color("b39758"), Color("598077")]
const ERAS = ["1100–1300", "1300–1400", "1400–1470", "1470–1530", "1530–1600"]
const ERA_NAMES = ["锁甲与纹章", "板片的时代", "钢铁的轮廓", "比武的盛世", "宫廷与工坊"]
const ERA_REQUIREMENTS = [0, 6, 16, 30, 48]
const SLOT_NAMES = {"armor": "胸甲", "helmet": "头盔", "lance": "骑枪", "shield": "盾牌", "horse": "坐骑", "crest": "纹章"}
const HISTORY_FILES = ["res://data/history_v051_en_fr.json","res://data/history_v051_de_it.json"]

static func load_items() -> Array:
	var raw = FileAccess.get_file_as_string("res://data/equipment.json")
	var parsed = JSON.parse_string(raw)
	var items: Array = parsed if parsed is Array else []
	var expansion = JSON.parse_string(FileAccess.get_file_as_string("res://data/equipment_expansion.json"))
	if expansion is Array:
		for item in expansion:
			var previous = find(items,str(item.id))
			if not previous.is_empty():
				items[items.find(previous)] = item
			else:
				items.append(item)
	items.append({"id":"shield_basic","name":"旧式绘饰盾","slot":"shield","era":0,"price":0,"region":"欧洲共通","stats":{"shield_capacity":78.0,"shield_handling":1.0,"shield_quality":0},"description":"已有骑手的基础盾牌。","source":"S33 · 游戏改编","historical_note":"沿用旧版基础防护，新增槽位不删除已有收藏。"})
	_apply_history(items)
	return items

static func _apply_history(items: Array) -> void:
	# Partial overrides preserve owned IDs, prices and existing numerical balance.
	for path in HISTORY_FILES:
		if not FileAccess.file_exists(path):
			continue
		var records = JSON.parse_string(FileAccess.get_file_as_string(path))
		if not records is Array:
			push_error("Invalid equipment history: "+path)
			continue
		for record in records:
			var item = find(items,str(record.get("id","")))
			if item.is_empty():
				push_error("Unknown historical equipment ID: "+str(record.get("id","")))
				continue
			item["progression_era"] = int(item.get("progression_era",item.era))
			for key in record:
				if key=="stats":
					item.stats.merge(record.stats,true)
				elif key not in ["id","slot","price","renown","quality","quality_name"]:
					item[key] = record[key]
			item.stats["armor_art" if item.slot=="armor" else "helmet_art"] = str(record.get("art_id",item.id))
	# Existing starter and old-era purchases remain usable with new matching art.
	# Only shape/period-compatible legacy matches; unmatched old-era pieces
	# retain their existing art instead of silently becoming later imports.
	var aliases = {"mail_basic":"eng_armor_1","mail_eng":"eng_armor_1","mail_fr":"fr_armor_1","mail_de":"de_armor_0","mail_it":"it_armor_1","helm_nasal":"eng_helmet_0","helm_great":"eng_helmet_1","helm_gilt":"fr_helmet_1","armor_e1":"fr_armor_2","helm_e1":"fr_helmet_2","armor_e3":"de_armor_3","helm_e3":"de_helmet_3","armor_e4":"it_armor_5","helm_e4":"it_helmet_5"}
	for item_id in aliases:
		var old = find(items,item_id)
		var reference = find(items,aliases[item_id])
		if old.is_empty() or reference.is_empty():
			continue
		var art_key = "armor_art" if old.slot=="armor" else "helmet_art"
		old.stats[art_key] = reference.stats.get(art_key,aliases[item_id])
		old["name"] = str(reference.name).split(" · ")[-1]+"（旧藏）"
		old["description"] = reference.description
		old["historical_window"] = reference.get("historical_window",ERAS[int(old.era)])
		old["source"] = reference.source
		old["source_url"] = reference.get("source_url","")
		old["manufacture"] = reference.get("manufacture","")
		old["use_context"] = reference.get("use_context","")
		old["historical_note"] = str(reference.historical_note)+" 旧藏沿用原数值，新外观为上述形制改编。"
	for item in items:
		if item.slot in ["armor","helmet"]:
			item["legacy"] = not item.has("art_id")
		if item.slot=="lance":
			item.stats["lance_era"] = int(item.era)
			item.stats["lance_region"] = str(item.region)
			item.stats["lance_style"] = str(item.stats.get("lance_type","standard"))
		elif item.slot=="armor":
			# Cosmetic pattern only: no leg protection, hitbox or stat contribution.
			item.stats["leg_decoration"] = REGIONS.find(str(item.region))+1

static func required_renown(item: Dictionary) -> int:
	return maxi(int(item.get("renown",0)),ERA_REQUIREMENTS[unlock_era(item)])

static func unlock_era(item: Dictionary) -> int:
	# Historical display dates may be corrected without silently increasing
	# the price/progression gate of an existing purchasable ID.
	return int(item.get("progression_era",item.era))

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
	var result = {"armor": 0.10, "helmet": 0.08, "power": 1.0, "speed": 1.0, "stability": 1.0, "durability": 100.0, "reach": 247.0, "horse_color": "a87950", "armor_tier": 0, "helmet_tier": 0, "heraldry": "bend", "shield_capacity":78.0,"shield_handling":1.0,"lance_handling":1.0}
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
