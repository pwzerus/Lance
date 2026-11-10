extends RefCounted
## Presentation only: explanations come from resolved contacts, never guessed
## from a sprite overlap or the opponent's intended target.
const ZONES = {"head":"头盔 / 头部","body":"胸甲","flank":"腰腹","shield":"盾牌"}
const CAUSES = {"fatal":"致命伤","health":"骑手状态耗尽","impact":"冲击超过坐稳能力","balance":"连续受击耗尽平衡"}
const ContactCues = preload("res://scripts/visual/combat_cues.gd")

static func summarize(events: Array, mode: String = "arena", detailed: bool = false) -> String:
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
	if not cause.is_empty():
		lines.append(cause)
	elif latest.has(0) and float(latest[0].get("support",1.0))<.70:
		lines.append("调整建议：接近时提前稳住枪线，大幅换目标会损失冲击。")
	elif latest.has(0) and latest[0].zone=="shield":
		lines.append("调整建议：观察对手护头、护胸或护腹，提前选择另一处空当。")
	else:
		lines.append("调整建议：留意马力；加速换冲力，收速留出调枪时间。")
	return "\n".join(lines)

