extends SceneTree
const Model=preload("res://scripts/core/joust_match.gd")
const Condition=preload("res://scripts/core/horse_condition.gd")
var results={}
var failures=[]
func check(ok: bool, message: String):
	if not ok: failures.append(message)
func _initialize(): call_deferred("run")
func charge(policy: String) -> Dictionary:
	var model=Model.new("arena",{}, {},7901)
	model.phase="charge"
	for f in model.fighters: f.acted=true
	var max_step=0.0
	for tick in range(60*20):
		var gap=absf(model.fighters[0].x-model.fighters[1].x)
		var boost=policy=="hold" or gap<2600
		var previous=float(model.fighters[0].speed)
		for i in range(2): model.set_controls(i,-.08,0,boost,1.0/60,.43)
		model.step(1.0/60)
		max_step=maxf(max_step,absf(model.fighters[0].speed-previous))
		if gap<400:
			return {"speed":model.fighters[0].speed,"stamina":model.fighters[0].stamina,"seconds":tick/60.0,"max_step":max_step}
	return {}
func run():
	var report=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): report=arg.trim_prefix("--report=")
	if report.is_empty() or FileAccess.file_exists(report) or OS.get_environment("GALUMU_MEMORY_BOUND")=="" or not root.get_node("GameState").save_path.contains("qa_"):
		quit(2);return
	results.hold=charge("hold")
	results.reserve=charge("reserve")
	check(results.reserve.speed>results.hold.speed*1.2,"Reserving effort has no finishing-speed benefit")
	check(results.reserve.stamina>results.hold.stamina+20,"Urging all the way has no meaningful cost")
	check(results.hold.max_step<10 and results.reserve.max_step<10,"Speed changes discontinuously")
	for waving in [false,true]:
		var m=Model.new("arena")
		for tick in range(60*4):
			m.set_controls(0,(.58 if tick%60<30 else -.68) if waving else -.08,0,false,1.0/60)
		results["waving" if waving else "steady"]=m.fighters[0].arm
	check(results.steady>95 and results.waving<25,"Arm cost punishes bracing or barely penalises waving")
	var resting=Model.new("arena")
	resting.fighters[0].arm=0.0
	for tick in range(60*10): resting.set_controls(0,-.08,0,false,1.0/60)
	check(resting.fighters[0].arm>85,"Tired arm cannot recover by steady holding")
	results.arm_recovered=resting.fighters[0].arm
	for zone in ["body","flank","head"]:
		var m=Model.new("arena",{}, {"stability":3.0},7901)
		m._apply_contact({"type":"hit","attacker":0,"defender":1,"zone":zone,"speed":850.0,"position":Model.body_position(m.fighters[1])})
		var peak=0.0
		for tick in range(120):
			Model.advance_reaction(m.fighters[1],1.0/120)
			peak=maxf(peak,absf(m.fighters[1].reaction_angle))
		results[zone]={"peak_degrees":rad_to_deg(peak),"after_one_second":m.fighters[1].reaction_angle,"ko":m.fighters[1].ko}
		check(not m.fighters[1].ko and absf(m.fighters[1].reaction_angle)<.03,"Nonterminal reaction does not recover")
	check(results.body.peak_degrees>20 and results.flank.peak_degrees>18,"Body reaction still barely moves")
	results.passed=failures.is_empty()
	results.failures=failures
	FileAccess.open(report,FileAccess.WRITE).store_string(JSON.stringify(results,"\t"))
	quit(0 if failures.is_empty() else 1)
