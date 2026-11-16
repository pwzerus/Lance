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
		if not dead.is_empty(): return "你阵亡了。" if dead.has(0) else "对手阵亡。"
		if not fallen.is_empty(): return "你被击落了。" if fallen.has(0) else "你击落了对手。"
		return "盾缘容易卸力，打正才能撼动骑手。"
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

