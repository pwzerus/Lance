extends SceneTree
const Model=preload("res://scripts/core/joust_match.gd")
const Cues=preload("res://scripts/visual/combat_cues.gd")
var failures: Array=[]
var rows: Array=[]
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok and message not in failures: failures.append(message)

func sweep(facing: int, mode: String, height: float, speed: float, helmet: float, stability: float=1.0, broken: bool=false, power: float=1.0, shielded: bool=false) -> Dictionary:
	var stats={"helmet":helmet,"stability":3.0,"power":power,"durability":1000.0}
	var model=Model.new(mode,stats,stats,7600)
	var di=0 if facing==1 else 1
	var ai=1-di
	var defender: Dictionary=model.fighters[di]
	var attacker: Dictionary=model.fighters[ai]
	defender.x=0.0
	defender.lane_y=0.0
	defender.shield=100.0 if shielded else 0.0
	defender.guard=1.0 if shielded else 0.0
	attacker.aim=0.0
	attacker.speed=speed*.5
	attacker.lance_stability=stability
	attacker.broken=broken
	var center=Model.head_position(defender)
	var travel=160.0 if shielded else 40.0
	var start=center+Vector2(facing*(travel-8),height)
	var end=center+Vector2(-facing*8,height)
	attacker.x+=end.x-Model.tip_position(attacker).x
	attacker.lane_y+=end.y-Model.tip_position(attacker).y
	for fighter in model.fighters: model._cache_pose(fighter)
	attacker.prev_hand=start-Vector2(-facing,0)*Model.lance_length(attacker)
	var event=model._detect_contact(ai,travel/speed)
	check(not event.is_empty() and event.get("zone","")==("shield" if shielded else "head"),"Head/guard sweep missing")
	if event.is_empty(): return {}
	model._apply_contact(event)
	return {"event":event,"defender":defender,"model":model}

func run() -> void:
	var report=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): report=arg.trim_prefix("--report=")
	if report.is_empty() or FileAccess.file_exists(report) or OS.get_environment("GALUMU_MEMORY_BOUND")=="" or not root.get_node("GameState").save_path.contains("qa_"):
		quit(2); return
	for facing in [1,-1]:
		var heavy=sweep(facing,"war",0,960,.08)
		var armour=sweep(facing,"war",0,960,.41)
		var glance=sweep(facing,"war",22,960,.08)
		var slow=sweep(facing,"war",0,400,.08)
		var unstable=sweep(facing,"war",0,960,.08,.35)
		var broken=sweep(facing,"war",0,960,.08,1.0,true)
		var arena=sweep(facing,"arena",0,960,.08)
		var shielded=sweep(facing,"war",0,960,.08,1.0,false,1.0,true)
		var overpower=sweep(facing,"war",0,960,.41,1.0,false,2.0)
		if heavy.is_empty() or armour.is_empty() or glance.is_empty(): continue
		check(heavy.defender.dead and heavy.event.head_outcome=="fatal","Full-health committed hit did not end war fighter")
		check(not armour.defender.dead and armour.event.head_outcome=="helmet_block","Helmet did not prevent the comparable fatal hit")
		check(not glance.defender.dead and glance.event.glanced and glance.event.head_incidence<.6,"Glancing entry became a fatal head strike")
		for weak in [slow,unstable,broken]: check(not weak.defender.dead and weak.event.head_outcome!="fatal","Uncommitted head hit became fatal")
		check(not arena.defender.dead and not arena.event.has("head_outcome"),"War head rule leaked into tournament")
		check(not shielded.defender.dead and shielded.event.zone=="shield" and not shielded.event.has("head_outcome"),"Raised shield failed to intercept the head line")
		check(overpower.defender.dead and overpower.event.head_outcome=="fatal","Helmet became absolute immunity")
		check(Cues.contact_name(heavy.event).contains("致命") and Cues.contact_name(armour.event).contains("抵挡"),"Missing player-readable distinction")
		for entry in [heavy,armour,glance,slow,unstable,broken,arena,shielded,overpower]:
			rows.append({"facing":facing,"mode":entry.model.mode,"event":entry.event,"hp":entry.defender.hp,"dead":entry.defender.dead})
	# Actual normal stepping, finite controls, full health, both riders at once.
	var duel=Model.new("war",{"helmet":.08,"power":2.0,"stability":3.0},{"helmet":.08,"power":2.0,"stability":3.0},7602)
	# Equal lane height/stride phase deliberately isolate same-tick contact;
	# the normal staggered lanes do not guarantee simultaneous arrival.
	for f in duel.fighters:
		f.shield=0.0
		f.lane_y=0.0
		f.gait_phase=0.0
	var hits: Array=[]
	for tick in range(120*45):
		for i in range(2):
			var target=Model.head_position(duel.fighters[1-i])
			var hand=Model.hand_position(duel.fighters[i])
			# FEEL-079: reserve the finishing effort; an exhausted full-run charge
			# is intentionally no longer the high-speed lethal fixture.
			duel.set_controls(i,atan2(target.y-hand.y,maxf(1,absf(target.x-hand.x))),0,absf(duel.fighters[0].x-duel.fighters[1].x)<2600,1.0/120)
		duel.step(1.0/120)
		for e in duel.drain_events():
			if e.type=="hit": hits.append(e)
		if duel.phase=="ended": break
	check(duel.phase=="ended" and duel.pass_number==1,"Critical war duel did not finish in first pass")
	check(duel.fighters[0].dead and duel.fighters[1].dead and duel.result.winner==-1,"Simultaneous lethal contacts lost symmetry")
	var hp=[duel.fighters[0].hp,duel.fighters[1].hp]
	for i in range(120): duel.step(1.0/120)
	check(duel.drain_events().is_empty() and hp==[duel.fighters[0].hp,duel.fighters[1].hp],"Ended match kept hitting or settling")
	var clean=Model.new("war")
	check(not clean.fighters[0].dead and clean.fighters[0].hp==100.0,"New match inherited death")
	FileAccess.open(report,FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"failures":failures,"cases":rows,"duel_hits":hits,"duel_result":duel.result},"\t"))
	print("HEAD076 ",failures)
	quit(0 if failures.is_empty() else 1)
