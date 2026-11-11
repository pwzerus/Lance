extends RefCounted
## Observe production motion and resolved contacts, never manufacture a hit.
const Model = preload("res://scripts/core/joust_match.gd")
const Condition = preload("res://scripts/core/horse_condition.gd")
const TITLES = ["催马提速","松手收速","调枪后稳住","举盾护头","前倾再回正","认准接触部位","用盾挡住来枪"]
var step = 0
var hold = 0.0
var initialized = false
var peak_speed = 0.0
var cruise = 210.0
var initial_aim = 0.0
var initial_revision = 0
var moved_aim = false
var leaned = false
var last_contact: Dictionary = {}
var last_block: Dictionary = {}

func complete() -> bool: return step >= TITLES.size()

func begin_attempt(fighter: Dictionary = {}) -> void:
	initialized = false
	hold = 0.0
	moved_aim = false
	leaned = false
	peak_speed = 0.0
	if not fighter.is_empty(): _prime(fighter,{})

func _prime(fighter: Dictionary, controls: Dictionary) -> void:
	initialized = true
	peak_speed = float(fighter.speed)
	initial_aim = float(fighter.aim)
	initial_revision = int(controls.get("aim_revision",0))
	cruise = Model.TROT_SPEED*float(fighter.stats.get("speed",1.0))*Condition.load_speed_factor(fighter.stats)

func _advance(fighter: Dictionary, controls: Dictionary) -> void:
	step += 1
	begin_attempt()
	_prime(fighter,controls)

func observe(fighter: Dictionary, phase: String, delta: float, controls: Dictionary, events: Array) -> void:
	if complete(): return
	# A contact can end a match on this tick; examine it before phase gating.
	if step in [5,6]:
		for event in events:
			if event.get("type","")!="hit": continue
			if step==5 and int(event.attacker)==0:
				last_contact = event.duplicate(true)
				_advance(fighter,controls)
				return
			if step==6 and int(event.attacker)==1 and event.get("zone","")=="shield":
				last_block = event.duplicate(true)
				_advance(fighter,controls)
				return
	if phase!="charge" or bool(fighter.ko):
		hold = 0.0
		if step==1: peak_speed=0.0
		return
	if not initialized:
		_prime(fighter,controls)
	peak_speed = maxf(peak_speed,float(fighter.speed))
	var held = bool(controls.get("boost",false))
	match step:
		0:
			hold = hold+delta if held else 0.0
			if hold>=.8 and float(fighter.speed)>=cruise+75.0: _advance(fighter,controls)
		1:
			hold = hold+delta if not held and peak_speed>=cruise+55.0 else 0.0
			if hold>=.55 and float(fighter.speed)<=peak_speed-25.0: _advance(fighter,controls)
		2:
			if int(controls.get("aim_revision",0))>initial_revision and absf(float(fighter.aim)-initial_aim)>.12: moved_aim = true
			var settled = moved_aim and float(fighter.aim_velocity)<.18 and absf(float(fighter.aim)-float(controls.get("aim",0.0)))<.04 and float(fighter.lance_stability)>.6
			hold = hold+delta if settled else 0.0
			if hold>=.35: _advance(fighter,controls)
		3:
			hold = hold+delta if int(controls.get("guard",1))==0 and float(fighter.guard)>.92 else 0.0
			if hold>=.20: _advance(fighter,controls)
		4:
			if float(controls.get("lean",0.0))>.3 and float(fighter.lean)>.35: leaned = true
			hold = hold+delta if leaned and absf(float(fighter.lean))<.12 and absf(float(controls.get("lean",0.0)))<.1 else 0.0
			if hold>=.25: _advance(fighter,controls)

func instruction(mouse_only: bool = false) -> String:
	if complete(): return "练习完成 · 已完成攻防练习，可返回营地挑战竞技场。"
	var text = [
		"按住左键或空格，等马匹逐步提速。",
		"松开催马，让马匹自然收速。",
		"上下移动鼠标调枪，再停手等枪线稳住。",
		"点击「护头」，等盾牌抬到头部。" if mouse_only else "按 1 或点击「护头」，等盾牌抬到头部。",
		"滚轮向上前倾，再按中键回正。" if mouse_only else "按住 W 前倾，再松开回正。",
		"按住催马并稳住枪线，向盾或胸完成接触。",
		"下一轮教练瞄胸出枪：点击「护胸」，等盾实际挡住。" if mouse_only else "下一轮教练瞄胸出枪：按 2 护胸，等盾实际挡住。"
	][step]
	if step==1 and peak_speed<cruise+55.0: text = "先再次催马提速，再松手感受收速。"
	return "练习 %d/%d · %s" % [step+1,TITLES.size(),text]
