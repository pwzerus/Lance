extends RefCounted
## Resolved-contact presentation only. No RNG, damage or control writes.
static func number(value: Variant, fallback: float=0.0) -> float:
	return float(value) if (value is float or value is int) and is_finite(float(value)) else fallback

static func shield_loading(event: Dictionary) -> float:
	var transfer=clampf(number(event.get("shield_transfer"),.30 if event.get("glanced",false) else 1.0),0.0,1.0)
	# A scrape should not inherit the same speed-driven whole-body kick as a
	# square blow. Incoming energy still excites the shield, proportionally
	# to the actual transfer. Damage is deliberately not the volume control.
	return clampf(maxf(number(event.get("impulse"))/85.0,clampf(number(event.get("speed"))/900.0,0,1)*.82*transfer),0,1)

static func shield_text(event: Dictionary) -> String:
	var region=str(event.get("shield_region","face"))
	var part={"center":"盾心","face":"盾面","rim":"盾缘"}.get(region,"盾面")
	if event.get("glanced",false):return part+"滑开"
	if float(event.get("balance_left",100))<35 and float(event.get("impulse",0))>=30:return part+"失衡"
	if float(event.get("impulse",0))>=40:return part+"重击"
	return part+"挡住"
