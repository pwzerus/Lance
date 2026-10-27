extends RefCounted
## Presentation only: explanations come from resolved contacts, never guessed
## from a sprite overlap or the opponent's intended target.
const ZONES = {"head":"头盔 / 头部","body":"胸甲","flank":"腰腹","shield":"盾牌"}
const CAUSES = {"fatal":"致命伤","health":"骑手状态耗尽","impact":"冲击超过坐稳能力","balance":"连续受击耗尽平衡"}

static func summarize(events: Array) -> String:
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
		var detail = "擦盾后损伤" if hit.zone=="shield" and hit.get("glanced",false) else ("格挡后损伤" if hit.zone=="shield" else "骑手损伤")
		lines.append("%s：%s · %s %d · 平衡余量 %d" % [prefix,ZONES.get(hit.zone,hit.zone),detail,roundi(hit.damage),roundi(hit.balance_left)])
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
		lines.append("调整建议：催马积累速度；1 / 2 / 3 选择护头、护胸或护腹。")
	return "\n".join(lines)

