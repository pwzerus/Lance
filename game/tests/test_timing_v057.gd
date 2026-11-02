extends "test_exchange_timing_v049.gd"
## DEV-057 keeps the original rate, controls, miss and lifecycle regressions.
## Only the changed contact contract differs: load the actual pose, then hold.
## Relative inheritance also supports an external script against an export.

func _initialize() -> void:
	report_path = "E:/GALUMU/docs/development/logs/v057/timing01.json"
	call_deferred("run")

func inspect(sample: Dictionary, label: String) -> void:
	super.inspect(sample,label)
	check(sample.has("contact_loading"),"Director exposes whether contact is loading",{"label":label,"sample":sample})
	if sample.has("contact_loading"):
		check(not (sample.contact_loading and sample.hitstop),"Loading and frozen contact are mutually exclusive",{"label":label,"sample":sample})
		check(not sample.contact_loading or sample.state=="contact" and sample.pass_connected,"Loading requires an actual contact notification",{"label":label,"sample":sample})

func close_sample(a: Dictionary, b: Dictionary, label: String) -> void:
	super.close_sample(a,b,label)
	check(a.contact_loading==b.contact_loading,label+": loading state diverged",{"a":a,"b":b})
	check(absf(float(a.stage_elapsed)-float(b.stage_elapsed))<.0001,label+": stage clock diverged",{"a":a,"b":b})

func impact_trial(hz: int, zone: String) -> void:
	var director = Director.new()
	director.reset(1)
	director.notify_contacts([contact(0,80,zone)])
	var sample = director.advance(0,context(200))
	inspect(sample,"first contact")
	check(sample.contact_loading and not sample.hitstop and sample.pass_connected and is_equal_approx(float(sample.scale),Director.CONTACT_LOAD_SCALE),"A contact begins continuous loading before the short freeze",{"hz":hz,"zone":zone,"sample":sample})
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
	var load_seconds = 0.0
	var stop_seconds = 0.0
	var read_seconds = 0.0
	var release_seconds = 0.0
	var game_seconds = 0.0
	while elapsed<1.5:
		var game_dt = dt*float(sample.scale)
		game_seconds += game_dt
		if sample.contact_loading:
			load_seconds += dt
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
	check(load_seconds>=Director.CONTACT_LOAD_DURATION-dt and load_seconds<=Director.CONTACT_LOAD_DURATION+dt,"Contact loading has its declared real-time duration",{"hz":hz,"zone":zone,"seconds":load_seconds})
	check(stop_seconds>=Director.HITSTOP_MIN_DURATION-Director.CONTACT_LOAD_DURATION-dt and stop_seconds<=Director.HITSTOP_MAX_DURATION-Director.CONTACT_LOAD_DURATION+dt,"Frozen contact duration excludes the preceding loading interval",{"hz":hz,"zone":zone,"seconds":stop_seconds})
	check(read_seconds>0 and release_seconds>0,"Slow motion reads the actual hit then releases continuously",{"hz":hz,"read":read_seconds,"release":release_seconds})
	check(elapsed<=Director.MAX_IMPACT_DURATION+2*dt,"The ended phase cannot trap the impact sequence",{"hz":hz,"elapsed":elapsed})
	check(is_equal_approx(sample.scale,1.0),"Completed impact releases back to normal time",{"hz":hz,"sample":sample})
	rows.append({"kind":"impact_budget_and_controls","hz":hz,"zone":zone,"duration":elapsed,"load_seconds":load_seconds,"stop_seconds":stop_seconds,"read_seconds":read_seconds,"release_seconds":release_seconds,"game_seconds":game_seconds,"final_guard":model.fighters[0].guard,"final_aim":model.fighters[0].aim})

func pause_and_reset(hz: int) -> void:
	# Parent covers the new contact-loading first frame, read/release and reset.
	super.pause_and_reset(hz)
	# Frozen contact now starts later inside the same state; cover it as well.
	var paused_clock = Director.new()
	var reference = Director.new()
	paused_clock.notify_contacts([contact()])
	reference.notify_contacts([contact()])
	var sample = paused_clock.advance(Director.CONTACT_LOAD_DURATION+.002,context(200))
	reference.advance(Director.CONTACT_LOAD_DURATION+.002,context(200))
	check(sample.hitstop and not sample.contact_loading,"Pause fixture reaches frozen contact after loading",{"hz":hz,"sample":sample})
	paused_clock.set_paused(true)
	close_sample(paused_clock.advance(2.0,context(200,"ended")),sample,"Frozen contact pause preserves its budget")
	paused_clock.notify_contacts([contact(1,1000)])
	paused_clock.set_paused(false)
	close_sample(paused_clock.advance(1.0/hz,context(200)),reference.advance(1.0/hz,context(200)),"Frozen contact resumes at the same age")
	rows.append({"kind":"pause_frozen_contact_after_loading","hz":hz})

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
	check(sample.contact_loading and not sample.hitstop,"Slow motion off still begins with continuous contact loading",{"hz":hz,"sample":sample})
	sample = director.advance(Director.CONTACT_LOAD_DURATION+.002,context(200,"charge",false))
	check(sample.hitstop and not sample.contact_loading,"Slow motion off retains the short freeze after loading",{"hz":hz,"sample":sample})
	sample = director.advance(2.0,context(200,"ended",false))
	check(is_equal_approx(sample.scale,1.0) and not sample.impact_active,"A large real delta consumes all pending effect phases",{"hz":hz,"sample":sample})
	director.reset(1)
	director.notify_contacts([{"type":"charge","impulse":1000.0}])
	sample = director.advance(.01,context(4000))
	check(not sample.pass_connected and not sample.hitstop and not sample.contact_loading,"A non-hit event cannot create an impact",{"sample":sample})
	rows.append({"kind":"settings_and_large_delta","hz":hz})

func run() -> void:
	var args = OS.get_cmdline_user_args()
	for i in range(args.size()):
		var arg = str(args[i])
		if arg.begins_with("--report="): report_path = arg.trim_prefix("--report=")
		elif arg.begins_with("--report-path="): report_path = arg.trim_prefix("--report-path=")
		elif arg in ["--report","--report-path"] and i+1<args.size(): report_path = str(args[i+1])
	var state = root.get_node_or_null("GameState")
	if state==null or not str(state.save_path).contains("qa_"):
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
	var report = {"passed":failures.is_empty(),"failures":failures,"examples":examples,"rows":rows,
		"scope":"Production director and Model at30/60/120Hz. Inherits v049 approach, simultaneous/repeated contact, pause/reset, late-toggle and actual swept-miss regressions. Contact first loads continuously, then freezes for total contact duration minus CONTACT_LOAD_DURATION; controls remain limited by scaled game time. No rendered-scene, OS input or human-feel claim."}
	var file = FileAccess.open(report_path,FileAccess.WRITE)
	if not file:
		push_error("Cannot write timing report")
		quit(2)
		return
	file.store_string(JSON.stringify(report,"\t"))
	file.close()
	print("EXCHANGE_TIMING_V057 ",report.passed," failures=",failures)
	quit(0 if failures.is_empty() else 1)
