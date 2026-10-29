extends SceneTree
## Pure director contracts + Model bridge. Synthetic contact fixtures here test
## presentation timing; actual swept hits belong to test_exchange_scene_v049.
const Director = preload("res://scripts/visual/exchange_director.gd")
const Model = preload("res://scripts/core/joust_match.gd")
var failures: Array[String] = []
var examples: Array = []
var rows: Array = []
var report_path = "E:/GALUMU/docs/development/logs/v049/timing-01.json"

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String, context: Dictionary = {}) -> void:
	if ok:
		return
	if message not in failures:
		failures.append(message)
		push_error(message)
	if examples.size()<24:
		examples.append({"message":message,"context":context.duplicate(true)})

func context(gap: float = 200.0, phase: String = "charge", slow: bool = true, pass_id: int = 1) -> Dictionary:
	return {"phase":phase,"pass_id":pass_id,"gap":gap,"slow_motion":slow,"closing_speed":420.0,"reach":250.0}

func contact(attacker: int = 0, impulse: float = 80.0, zone: String = "body") -> Dictionary:
	return {"type":"hit","attacker":attacker,"defender":1-attacker,"impulse":impulse,"damage":10.0,"position":Vector2(20.0 if attacker==0 else -20.0,-210.0),"zone":zone,"broke":false,"ko":false,"dead":false}

func inspect(sample: Dictionary, label: String) -> void:
	check(sample.has_all(["state","scale","approach","focus","focus_weight","audio_duck","release","strength","hitstop","pass_connected","impact_active"]),"Director sample is missing a documented field",{"label":label,"sample":sample})
	if not sample.has("scale"):
		return
	check(is_finite(float(sample.scale)) and float(sample.scale)>=0 and float(sample.scale)<=1.0001,"Director scale stays finite within normal-speed bounds",{"label":label,"sample":sample})
	check(sample.state in ["runup","approach","contact","read","release"],"Director exposes a documented state",{"label":label,"state":sample.state})
	for key in ["approach","focus_weight","audio_duck","release","strength"]:
		check(is_finite(float(sample[key])) and float(sample[key])>=0 and float(sample[key])<=1.0001,"Director weight stays finite and normalized",{"label":label,"key":key,"value":sample[key]})
	check(not sample.hitstop or sample.pass_connected,"No hitstop occurs before a contact event",{"label":label,"sample":sample})
	check(not sample.impact_active or sample.pass_connected,"Only a real-hit notification owns the impact sequence",{"label":label,"sample":sample})

func close_sample(a: Dictionary, b: Dictionary, label: String) -> void:
	for key in ["state","hitstop","pass_connected","impact_active","approach"]:
		check(a[key]==b[key],label+": state diverged",{"key":key,"a":a,"b":b})
	for key in ["scale","strength","focus_weight","audio_duck"]:
		check(absf(float(a[key])-float(b[key]))<.0001,label+": scalar diverged",{"key":key,"a":a[key],"b":b[key]})
	if a.focus is Vector2 and b.focus is Vector2:
		check(a.focus.distance_to(b.focus)<.0001,label+": focus diverged",{"a":str(a.focus),"b":str(b.focus)})

func approach_trial(hz: int) -> void:
	var director = Director.new()
	director.reset(1)
	var dt = 1.0/hz
	var approach_seconds = 0.0
	var minimum_scale = 1.0
	var total_slow_seconds = 0.0
	var states: Array = []
	var sample: Dictionary = {}
	for tick in range(hz*3):
		sample = director.advance(dt,context())
		inspect(sample,"stationary near/miss")
		if sample.state=="approach":
			approach_seconds += dt
		if sample.scale<.9999:
			total_slow_seconds += dt
		minimum_scale = minf(minimum_scale,sample.scale)
		check(not sample.hitstop and not sample.impact_active,"Proximity alone cannot create hitstop or impact",{"hz":hz,"tick":tick,"sample":sample})
		if states.is_empty() or states.back()!=sample.state:
			states.append(sample.state)
	check(approach_seconds>0 and approach_seconds<=Director.APPROACH_MAX_DURATION+2*dt,"Approach has a finite real-time budget even when the gap stops changing",{"hz":hz,"seconds":approach_seconds})
	check(minimum_scale>=Director.APPROACH_MIN_SCALE-.0001,"Approach slowdown never falls below its own lower scale bound",{"hz":hz,"minimum":minimum_scale})
	check(absf(minimum_scale-Director.APPROACH_MIN_SCALE)<.001,"Close approach reaches its declared restrained slow scale",{"hz":hz,"minimum":minimum_scale})
	check(total_slow_seconds<=Director.APPROACH_MAX_DURATION+Director.RELEASE_DURATION+2*dt,"A miss's approach plus release has one bounded episode",{"hz":hz,"seconds":total_slow_seconds})
	check(is_equal_approx(sample.scale,1.0) and not sample.approach,"Expired approach cannot restart while the same pass remains near",{"hz":hz,"sample":sample})
	var released = director.advance(.5,context(-100.0))
	check(not released.hitstop and not released.impact_active and is_equal_approx(released.scale,1.0),"An empty crossing restores normal time",{"hz":hz,"sample":released})
	rows.append({"kind":"approach_budget","hz":hz,"approach_seconds":approach_seconds,"total_slow_seconds":total_slow_seconds,"minimum_scale":minimum_scale,"states":states})

func impact_trial(hz: int, zone: String) -> void:
	var director = Director.new()
	director.reset(1)
	director.notify_contacts([contact(0,80,zone)])
	var sample = director.advance(0,context(200))
	inspect(sample,"first contact")
	check(sample.hitstop and sample.pass_connected,"A contact fixture begins the short hitstop stage",{"hz":hz,"zone":zone,"sample":sample})
	var model = Model.new("arena",{}, {},4903)
	model.phase = "charge"
	model.fighters[0].x = -300.0
	model.fighters[1].x = 300.0
	for fighter in model.fighters:
		fighter.acted = true
		fighter.aim = -.68
		fighter.guard = 0.0
		fighter.guard_target = 0.0
	var dt = 1.0/hz
	var elapsed = 0.0
	var stop_seconds = 0.0
	var read_seconds = 0.0
	var release_seconds = 0.0
	var game_seconds = 0.0
	while elapsed<1.5:
		var game_dt = dt*float(sample.scale)
		game_seconds += game_dt
		if sample.hitstop:
			stop_seconds += dt
		if sample.state=="read":
			read_seconds += dt
		if sample.state=="release" and sample.impact_active:
			release_seconds += dt
		for index in range(2):
			var fighter = model.fighters[index]
			var old_aim = float(fighter.aim)
			var old_guard = float(fighter.guard)
			model.set_controls(index,.58,0.0,true,game_dt,1.0)
			check(absf(float(fighter.aim)-old_aim)<=.95*game_dt*float(fighter.stats.get("lance_handling",1.0))+.0001,"Near-contact lance movement is limited by scaled game time",{"hz":hz,"state":sample.state,"game_dt":game_dt})
			check(absf(float(fighter.guard)-old_guard)<=2.8*game_dt*float(fighter.stats.get("shield_handling",1.0))+.0001,"Shield movement is limited by scaled game time",{"hz":hz,"state":sample.state,"game_dt":game_dt})
		model.step(game_dt)
		elapsed += dt
		sample = director.advance(dt,context(200,"ended"))
		inspect(sample,"impact/ended")
		if not sample.impact_active:
			break
	check(stop_seconds>=Director.HITSTOP_MIN_DURATION-dt and stop_seconds<=Director.HITSTOP_MAX_DURATION+dt,"Contact hitstop respects its short real-time duration",{"hz":hz,"zone":zone,"seconds":stop_seconds})
	check(read_seconds>0 and release_seconds>0,"Slow motion reads the actual hit then releases continuously",{"hz":hz,"read":read_seconds,"release":release_seconds})
	check(elapsed<=Director.MAX_IMPACT_DURATION+2*dt,"The ended phase cannot trap the impact sequence",{"hz":hz,"elapsed":elapsed})
	check(is_equal_approx(sample.scale,1.0),"Completed impact releases back to normal time",{"hz":hz,"sample":sample})
	rows.append({"kind":"impact_budget_and_controls","hz":hz,"zone":zone,"duration":elapsed,"stop_seconds":stop_seconds,"read_seconds":read_seconds,"release_seconds":release_seconds,"game_seconds":game_seconds,"final_guard":model.fighters[0].guard,"final_aim":model.fighters[0].aim})

func simultaneous_and_repeat(hz: int) -> void:
	var a = Director.new()
	var b = Director.new()
	a.reset(1)
	b.reset(1)
	var hits = [contact(0,80),contact(1,80,"shield")]
	a.notify_contacts(hits)
	b.notify_contacts([hits[1],hits[0]])
	for tick in range(hz):
		var sa = a.advance(1.0/hz,context(200))
		var sb = b.advance(1.0/hz,context(200))
		close_sample(sa,sb,"Simultaneous-hit order")
	var ended = a.sample()
	check(not ended.impact_active,"Simultaneous contacts do not concatenate two impact sequences",{"hz":hz,"sample":ended})
	a.notify_contacts([contact(1,100)])
	var repeated = a.advance(0,context(180))
	check(not repeated.hitstop and not repeated.impact_active,"A later hit in the same pass cannot restart the read sequence",{"hz":hz,"sample":repeated})
	rows.append({"kind":"simultaneous_order_and_repeated_contact","hz":hz,"sample":repeated})

func pause_and_reset(hz: int) -> void:
	var dt = 1.0/hz
	for target_state in ["contact","read","release"]:
		var paused_clock = Director.new()
		var reference = Director.new()
		paused_clock.notify_contacts([contact()])
		reference.notify_contacts([contact()])
		var sample = paused_clock.advance(0,context(200))
		reference.advance(0,context(200))
		for tick in range(hz):
			if sample.state==target_state:
				break
			sample = paused_clock.advance(dt,context(200))
			reference.advance(dt,context(200))
		check(sample.state==target_state,"Pause fixture reached the requested timing stage",{"hz":hz,"requested":target_state,"sample":sample})
		paused_clock.set_paused(true)
		var frozen = paused_clock.advance(2.0,context(200,"ended"))
		close_sample(frozen,sample,"Paused director freezes its remaining budget")
		paused_clock.notify_contacts([contact(1,1000)])
		paused_clock.set_paused(false)
		close_sample(paused_clock.advance(dt,context(200)),reference.advance(dt,context(200)),"Resumed director matches unpaused remaining time")
	var director = Director.new()
	director.notify_contacts([contact()])
	director.advance(0,context(200))
	for phase in ["ready","turn"]:
		var cleared = director.advance(.01,context(4000,phase))
		check(is_equal_approx(cleared.scale,1.0) and not cleared.pass_connected and not cleared.impact_active,"Ready/turn clears presentation time effects",{"phase":phase,"sample":cleared})
	director.notify_contacts([contact()])
	director.advance(0,context(200))
	var new_pass = director.advance(.01,context(4000,"charge",true,2))
	check(is_equal_approx(new_pass.scale,1.0) and not new_pass.impact_active and not new_pass.pass_connected,"A new pass clears old contact and timing state",{"sample":new_pass})
	director.set_paused(true)
	director.reset(3)
	var reset = director.advance(0,context(4000,"charge",true,3))
	check(is_equal_approx(reset.scale,1.0) and not reset.impact_active,"Explicit restart resets pause and effect state",{"sample":reset})
	rows.append({"kind":"pause_and_phase_reset","hz":hz})

func disabled_and_large_delta(hz: int) -> void:
	var director = Director.new()
	director.advance(.5,context())
	var sample: Dictionary = {}
	for tick in range(ceili((Director.FAST_RELEASE_DURATION+.10)*hz)):
		sample = director.advance(1.0/hz,context(350,"charge",false))
	check(is_equal_approx(sample.scale,1.0) and not sample.hitstop,"Disabling slow motion releases proximity slowdown promptly",{"hz":hz,"sample":sample})
	director.reset(1)
	director.notify_contacts([contact()])
	sample = director.advance(0,context(200,"charge",false))
	check(sample.hitstop,"Slow motion off still keeps the short physical contact stop",{"hz":hz,"sample":sample})
	sample = director.advance(2.0,context(200,"ended",false))
	check(is_equal_approx(sample.scale,1.0) and not sample.impact_active,"A large real delta consumes all pending effect phases",{"hz":hz,"sample":sample})
	director.reset(1)
	director.notify_contacts([{"type":"charge","impulse":1000.0}])
	sample = director.advance(.01,context(4000))
	check(not sample.pass_connected and not sample.hitstop,"A non-hit event cannot create an impact",{"sample":sample})
	rows.append({"kind":"settings_and_large_delta","hz":hz})

func late_release_setting_change(hz: int) -> void:
	var director = Director.new()
	director.notify_contacts([contact()])
	var sample = director.advance(0,context(200))
	for tick in range(hz):
		if sample.state=="release":
			break
		sample = director.advance(1.0/hz,context(200))
	check(sample.state=="release","Late-setting fixture reached release",{"hz":hz,"sample":sample})
	var to_last_twenty_ms = maxf(0.0,Director.RELEASE_DURATION-float(sample.stage_elapsed)-.020)
	sample = director.advance(to_last_twenty_ms,context(200))
	var before = sample.duplicate(true)
	var switched = director.advance(0,context(200,"charge",false))
	check(float(switched.scale)>=float(before.scale)-.0001,"Disabling slow motion late cannot jump back to an earlier slow scale",{"hz":hz,"before":before,"after":switched})
	var complete = director.advance(.030,context(200,"charge",false))
	check(not complete.impact_active and is_equal_approx(complete.scale,1.0),"Changing slow motion in the last 20ms cannot restart a full fast-release budget",{"hz":hz,"sample":complete})
	check(float(complete.impact_elapsed)<=Director.MAX_IMPACT_DURATION+.0001,"A late setting change cannot extend the total impact budget",{"hz":hz,"sample":complete})
	rows.append({"kind":"late_release_setting_change","hz":hz,"before":before,"after":complete})

func actual_miss_trial(hz: int, mode: String) -> void:
	var model = Model.new(mode,{}, {},4904)
	model.phase = "charge"
	for fighter in model.fighters:
		fighter.aim = .58
		fighter.guard = .43
		fighter.guard_target = .43
		model._cache_pose(fighter)
	var director = Director.new()
	director.reset(1)
	var dt = 1.0/hz
	var real_seconds = 0.0
	var hit_count = 0
	var crossed = false
	var max_slow_seconds = 0.0
	for tick in range(hz*12):
		var gap = float(model.fighters[1].x)-float(model.fighters[0].x)
		var ctx = context(gap,model.phase,true,model.pass_number)
		ctx.closing_speed = float(model.fighters[0].speed)+float(model.fighters[1].speed)
		var sample = director.advance(dt,ctx)
		inspect(sample,"actual miss")
		if sample.state=="approach":
			max_slow_seconds += dt
		var game_dt = dt*float(sample.scale)
		for index in range(2):
			model.set_controls(index,.58,0,true,game_dt,.43)
		model.step(game_dt)
		var events = model.drain_events()
		for event in events:
			if event.type=="hit":
				hit_count += 1
		director.notify_contacts(events)
		check(not sample.hitstop and not sample.impact_active,"A genuine swept miss cannot trigger contact presentation",{"mode":mode,"hz":hz,"sample":sample})
		real_seconds += dt
		if float(model.fighters[0].x)>float(model.fighters[1].x)+200:
			crossed = true
			break
	check(hit_count==0,"The deliberate-miss fixture actually missed all shield/body contacts",{"mode":mode,"hz":hz,"hits":hit_count})
	check(crossed and real_seconds<12,"A miss is not held indefinitely by cinematic slowdown",{"mode":mode,"hz":hz,"seconds":real_seconds})
	check(max_slow_seconds<=Director.APPROACH_MAX_DURATION+2*dt,"Actual missed charge obeys the approach real-time budget",{"mode":mode,"hz":hz,"seconds":max_slow_seconds})
	rows.append({"kind":"actual_swept_miss","mode":mode,"hz":hz,"crossed":crossed,"real_seconds":real_seconds,"approach_seconds":max_slow_seconds,"hit_count":hit_count})

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report-path="):
			report_path = arg.trim_prefix("--report-path=")
	var state = root.get_node_or_null("GameState")
	if state==null or not state.save_path.contains("qa_"):
		push_error("Timing tests require -- --test-profile")
		quit(1)
		return
	if FileAccess.file_exists(report_path):
		push_error("Choose a fresh timing report path")
		quit(2)
		return
	for hz in [30,60,120]:
		approach_trial(hz)
		impact_trial(hz,"body")
		impact_trial(hz,"shield")
		simultaneous_and_repeat(hz)
		pause_and_reset(hz)
		disabled_and_large_delta(hz)
		late_release_setting_change(hz)
		for mode in ["arena","war"]:
			actual_miss_trial(hz,mode)
	DirAccess.make_dir_recursive_absolute(report_path.get_base_dir())
	var report = {"passed":failures.is_empty(),"failures":failures,"examples":examples,"rows":rows,"scope":"Pure production director with real-delta budgets at 30/60/120Hz; synthetic impact fixtures for clock/control limits, actual Model swept misses in both modes, pause/resume, phase resets and large deltas. No Engine time-scale restoration, rendered scene, OS input or human experience claim; formal Battle integration is separate."}
	var file = FileAccess.open(report_path,FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	file.close()
	print("EXCHANGE_TIMING_V049 ",report.passed," failures=",failures)
	quit(0 if failures.is_empty() else 1)
