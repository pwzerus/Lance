extends RefCounted
## A preview of this exact replacement in the player's current loadout.
## Descriptions use production fatigue/control functions, never item tiers.
const Catalogue = preload("res://scripts/core/catalogue.gd")
const Condition = preload("res://scripts/core/horse_condition.gd")

static func direction(before: float, after: float, tolerance: float = .005) -> int:
	var difference = after-before
	if absf(difference)<=tolerance: return 0
	return 1 if difference>0 else -1

static func summarize(items: Array, equipped: Dictionary, item: Dictionary) -> Dictionary:
	var slot = str(item.get("slot",""))
	var current = Catalogue.find(items,str(equipped.get(slot,"")))
	var replacement = equipped.duplicate()
	replacement[slot] = str(item.get("id",""))
	var before = Catalogue.stats(items,equipped)
	var after = Catalogue.stats(items,replacement)
	var rows: Array[String] = []
	var changes: Dictionary = {}
	for key in ["armor","helmet","power","reach","durability","shield_capacity","speed","stability","caparison_renown"]:
		changes[key] = direction(float(before.get(key,0)),float(after.get(key,0)))
	changes.fatigue = direction(Condition.drain_rate(before),Condition.drain_rate(after),.05)
	changes.lance_handling = direction(Condition.agility(before)*float(before.get("lance_handling",1)),Condition.agility(after)*float(after.get("lance_handling",1)))
	changes.shield_handling = direction(Condition.agility(before)*float(before.get("shield_handling",1)),Condition.agility(after)*float(after.get("shield_handling",1)))
	changes.loaded_speed = direction(float(before.speed)*Condition.load_speed_factor(before),float(after.speed)*Condition.load_speed_factor(after),.003)
	changes.load = direction(Condition.load_kg(before),Condition.load_kg(after),.01)
	var same = str(current.get("id",""))==str(item.get("id",""))
	if same:
		rows.append("这是目前装备的物品。")
	else:
		match slot:
			"armor": rows.append(_change(changes.armor,"胸腹防护提高","胸腹防护降低","胸腹防护不变"))
			"helmet": rows.append(_change(changes.helmet,"头部防护提高","头部防护降低","头部防护不变"))
			"lance":
				rows.append(_change(changes.reach,"枪更长","枪更短","枪长相同")+" · "+_change(changes.power,"冲击更强","冲击较弱","冲击修正相同"))
			"shield": rows.append(_change(changes.shield_capacity,"盾牌更耐打","盾牌耐久较低","盾牌耐久相同"))
			"horse": rows.append(_change(changes.stability,"鞍上更稳定","鞍上稳定性降低","鞍上稳定性相同"))
			"caparison": rows.append(_change(changes.caparison_renown,"胜场声望增加","胜场声望减少","胜场声望相同")+" · 不提供防护")
			"crest": rows.append("只更换纹章，不改变防护与速度。")
		if slot!="crest":
			rows.append(_change(changes.fatigue,"催马更易疲劳","催马更耐久","催马消耗相同"))
			if changes.lance_handling!=0 or changes.shield_handling!=0:
				rows.append(_change(changes.lance_handling,"调枪更快","调枪更慢","调枪不变")+" · "+_change(changes.shield_handling,"换盾更快","换盾更慢","换盾不变"))
			if changes.loaded_speed!=0:
				rows.append(_change(changes.loaded_speed,"满体力冲速提高","满体力冲速降低","满体力冲速不变"))
	if rows.size()<4:
		match slot:
			"armor": rows.append("腿甲花纹仅作装饰，不增加防护。")
			"helmet": rows.append("有效头部重击仍可能结束实战。")
			"horse": rows.append("速度与稳定性有取舍，配装越重越易累。")
			"lance": rows.append("大幅调枪会耗臂力，稳住后再接触。")
			"shield": rows.append("盾面承力；盾缘命中更容易偏转。")
			"caparison": rows.append("装饰也有重量，会计入坐骑负担。")
	if same: rows.append("可在「数值与考据」查看参数与来源。")
	return {"current_name":str(current.get("name","当前同类装备")),"same":same,"lines":rows,"changes":changes,"before":before,"after":after}

static func _change(value: int, higher: String, lower: String, unchanged: String) -> String:
	return higher if value>0 else (lower if value<0 else unchanged)
