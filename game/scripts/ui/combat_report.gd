extends RefCounted
## Presentation only: explanations come from resolved contacts, never guessed
## from a sprite overlap or the opponent's intended target.
const ZONES = {"head":"头盔 / 头部","body":"胸甲","flank":"腰腹","shield":"盾牌"}
const CAUSES = {"fatal":"致命伤","health":"骑手状态耗尽","impact":"被重击掀下马","balance":"连吃重击，没坐稳"}
const ContactCues = preload("res://scripts/visual/combat_cues.gd")

static func summarize(events: Array, mode: String = "arena", detailed: bool = false) -> String:
	if not detailed:
		# Resolve the whole exchange before wording its outcome. Simultaneous
		# knockouts cannot be described using whichever hit was listed first.
		var fallen={}
		var dead={}
		for event in events:
			if event.get("dead",false): dead[int(event.defender)]=true
			if event.get("ko",false) or event.get("dead",false): fallen[int(event.defender)]=true
		if fallen.size()==2:
			if dead.size()==2: return "双方阵亡。"
			if dead.has(0): return "双方落马，你阵亡了。"
			if dead.has(1): return "双方落马，对手阵亡。"
			return "双方落马。"
		if not fallen.is_empty():
			var defender = 0 if fallen.has(0) else 1
			for index in range(events.size()-1,-1,-1):
				var hit: Dictionary = events[index]
				if int(hit.get("defender",-1))==defender and (hit.get("ko",false) or hit.get("dead",false)):
					return _terminal_cause(hit)
		return "双方均未接触骑手或盾牌。" if events.is_empty() else "双方仍在马上，按本场规则比较结果。"
	var latest: Dictionary = {}
	for event in events:
		latest[int(event.attacker)] = event
	var lines: Array[String] = []
	for attacker in range(2):
		var prefix = "你的最后一击" if attacker==0 else "对手的最后一击"
		if not latest.has(attacker):
			lines.append(prefix+"：未接触骑手或盾牌")
			continue
		var hit: Dictionary = latest[attacker]
		var note = "擦偏" if hit.get("glanced",false) else "盾牌承受冲击"
		if hit.zone!="shield" and not hit.get("glanced",false):
			if mode=="war":
				note = "骑手受创" if float(hit.get("damage",0.0))>0.0 else "护具抵挡"
				if hit.zone=="head" and float(hit.get("head_load_added",0.0))>0.0 and not hit.get("dead",false):
					note = "头部伤势累积"
			else:
				note = "实击" if hit.get("attaint",false) else "护甲化解"
		if hit.get("broke",false):
			note += " · 断枪"
		if hit.get("shield_broke",false): note += " · 盾已破损"
		# War is decided by rider outcomes, never tournament points. Keep its
		# result explanation consistent even though shared events carry points.
		if mode=="arena":
			note += " · +%d 分" % int(hit.points) if int(hit.get("points",0))>0 else " · 未计分"
		var line = "%s：%s · %s" % [prefix,ContactCues.contact_name(hit),note]
		if detailed:
			line += "\n  骑手损伤 %d · 平衡余量 %d · 自身速度系数 ×%.2f" % [roundi(hit.damage),roundi(hit.balance_left),float(hit.get("drive",1.0))]
		lines.append(line)
	var cause = ""
	for event in events:
		if event.get("ko",false):
			var who = "你" if int(event.defender)==0 else "对手"
			cause += ("；" if not cause.is_empty() else "")+who+"落马："+CAUSES.get(event.get("ko_reason",""),"失去战斗能力")
			# FEEL-094: say when flailing made the fall easier.
			if float(event.get("unsteady",0.0))>=.25 and str(event.get("ko_reason","")) in ["impact","balance"]:
				cause += "（受击时重心不稳 %d%%）" % roundi(float(event.unsteady)*100)
	if not cause.is_empty():
		lines.append(cause)
	elif latest.has(1) and float(latest[1].get("unsteady",0.0))>=.35:
		lines.append("接近后少扭身、甩枪。坐稳才扛得住。")
	elif latest.has(0) and float(latest[0].get("support",1.0))<.70:
		lines.append("接近后少甩枪，稳住枪尖才有力。")
	elif latest.has(0) and latest[0].zone=="shield":
		lines.append("看对手挡住哪里，瞄他露出的地方。")
	else:
		lines.append("马累了就松开催马，趁机调好枪盾。")
	return "\n".join(lines)

static func _terminal_cause(hit: Dictionary) -> String:
	var who = "你" if int(hit.get("defender",-1))==0 else "对手"
	var zone = str(hit.get("zone",""))
	var part = {"head":"头部","body":"胸部","flank":"腰腹","shield":"盾牌"}.get(zone,"身体")
	var cause = str(hit.get("ko_reason",""))
	if hit.get("dead",false):
		return who+"伤势致命，实战结束。" if cause=="health" else who+"的"+part+"承受致命伤，实战结束。"
	if cause=="health": return who+"累积伤势过重，无法继续骑乘。"
	if zone=="shield":
		return who+"虽用盾挡住来枪，仍被冲击掀下马。" if cause=="impact" else who+"持盾承压后失去平衡，落马出局。"
	if cause=="impact": return who+"的"+part+"遭重击，被掀下马。"
	if cause=="balance": return who+"的"+part+"受击后失去平衡，落马出局。"
	return who+"被击落了。"

static func next_action(events: Array, mouse_only: bool = false) -> String:
	# Explain resolved contacts across the match. The final contact need not
	# account for most of the injury, and a shield contact is not a flesh hit.
	var injury = {"head":0.0,"body":0.0,"flank":0.0}
	var shield_load = 0.0
	var unstable_fall = false
	var outgoing = 0
	var shields = 0
	var glances = 0
	for event in events:
		var zone = str(event.get("zone",""))
		if int(event.get("defender",-1))==0:
			if injury.has(zone): injury[zone]+=maxf(0,float(event.get("damage",0)))
			if zone=="shield": shield_load+=maxf(0,float(event.get("impulse",0)))
			if event.get("ko",false) and zone=="shield": shield_load+=100
			if event.get("ko",false) and str(event.get("ko_reason","")) in ["impact","balance"] and float(event.get("unsteady",0))>=.25: unstable_fall=true
		if int(event.get("attacker",-1))==0:
			outgoing+=1
			if zone=="shield": shields+=1
			if event.get("glanced",false): glances+=1
	if unstable_fall:
		return "受击时重心不稳：提前调好枪盾，"+("滚轮向上前倾支撑。" if mouse_only else "按住 W 前倾支撑。")
	var most = "head"
	for zone in ["body","flank"]:
		if injury[zone]>injury[most]: most=zone
	if injury[most]>0:
		return {"head":"头部受创最多：看清来枪，提前把盾抬高护头。","body":"胸部受创最多：提前用盾护胸，接触前稳住姿势。","flank":"腰腹受创最多：留意低枪，提前把盾放低护住腰腹。"}[most]
	if shield_load>0: return "盾牌挡住了来枪，但冲击仍会传给骑手；提前前倾支撑。"
	if outgoing==0: return "这场没有击中对手：先在练习场熟悉枪尖与目标的位置。"
	if glances*2>=outgoing: return "多次擦过：接触前稳住枪尖，避免临近时大幅甩枪。"
	if shields*2>=outgoing: return "来枪多被盾挡住：观察对手换盾，瞄准露出的部位。"
	return "保留这次有效命中的时机，下一场仍要留意对手来枪。"

