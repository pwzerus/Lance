extends SceneTree

const Model = preload("res://scripts/core/joust_match.gd")
const Catalogue = preload("res://scripts/core/catalogue.gd")
var checks = 0
var failures: Array = []

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)

func simulate(mode: String, seed_value: int, aim_head: bool, boost: bool) -> Dictionary:
	var model = Model.new(mode,{}, {},seed_value)
	var hits: Array = []
	var phases: Array = []
	for frame in range(120*75):
		for i in range(2):
			var target = Model.head_position(model.fighters[1-i]) if aim_head else Model.shield_position(model.fighters[1-i])
			var hand = Model.hand_position(model.fighters[i])
			var aim = atan2(target.y-hand.y,maxf(absf(target.x-hand.x),35))
			model.set_controls(i,aim,0.0,boost,1.0/120)
		model.step(1.0/120)
		for event in model.drain_events():
			if event.type == "hit":
				hits.append(event)
			if event.type in ["turn","rerack"]:
				phases.append(event)
		if model.phase == "ended":
			return {"model":model,"hits":hits,"phases":phases,"frames":frame}
	return {"model":model,"hits":hits,"phases":phases,"frames":9000}

func _run() -> void:
	var fraction = Model.swept_circle(Vector2(-200,0),Vector2(200,0),Vector2.ZERO,Vector2.ZERO,20)
	check(fraction >= 0 and fraction <= 1,"A fast lance must hit a target crossed between physics steps")
	check(Model.swept_circle(Vector2(-200,80),Vector2(200,80),Vector2.ZERO,Vector2.ZERO,20) < 0,"A clean miss must not turn into a swept hit")
	check(Model.swept_circle(Vector2(-100,0),Vector2(-20,0),Vector2(100,0),Vector2(-100,0),20)>=0,"Relative motion of a defender must be included")
	var arc = Model.swept_lance(Vector2.ZERO,Vector2.ZERO,-.65,.65,247,247,1,Vector2(247,0),Vector2(247,0),5,.1)
	check(not arc.is_empty(),"A rotating lance arc must hit even when its endpoint chord misses")
	var mirror_arc = Model.swept_lance(Vector2.ZERO,Vector2.ZERO,-.65,.65,247,247,-1,Vector2(-247,0),Vector2(-247,0),5,.1)
	check(not mirror_arc.is_empty() and is_equal_approx(float(arc.fraction),float(mirror_arc.fraction)),"Rotating sweep must be symmetric for the two facing directions")
	check(Model.swept_lance(Vector2.ZERO,Vector2.ZERO,-.65,.65,247,247,1,Vector2(290,0),Vector2(290,0),5,.1).is_empty(),"Arc sweep must not enlarge actual weapon reach")
	check(not Model.swept_lance(Vector2.ZERO,Vector2.ZERO,-.65,.65,66,66,1,Vector2(66,0),Vector2(66,0),.02,.1).is_empty(),"The short broken lance must also cover the gap between rotational chords")
	var surge = Model.new("arena")
	surge.phase = "charge"
	surge.fighters[0].surge = .20
	surge.time_effect_active = true
	surge.step(.05)
	check(is_equal_approx(surge.fighters[0].surge,.20),"Hitstop and slow motion must not consume post-impact surge")
	surge.time_effect_active = false
	surge.step(.05)
	check(is_equal_approx(surge.fighters[0].surge,.15) and surge.fighters[0].speed>=325,"After slow motion the horse must maintain maximum surge speed for 0.2 game seconds")
	for impulse in [0.0,35.0,70.0,120.0]:
		check(Model.break_chance("war",impulse)<Model.break_chance("arena",impulse),"War weapons must have lower break tendency at comparable impact")
	var match_a = simulate("arena",33,true,true)
	check(match_a.model.phase=="ended","An arena match must terminate")
	check(not match_a.model.fighters[0].dead and not match_a.model.fighters[1].dead,"Arena must never produce deaths")
	check(match_a.hits.size()>0,"Scripted aimed riders must actually make contact")
	check(match_a.hits.size()<=match_a.model.pass_number*2,"Each attacker may hit only once per pass")
	check(match_a.model.pass_number<=3,"Matches must not exceed three passes")
	var repeat_a = simulate("arena",33,true,true)
	check(match_a.model.result==repeat_a.model.result,"Identical seed and controls must reproduce the result")
	var death_seen = false
	var kos_seen = false
	for seed_value in range(1,17):
		var war = simulate("war",seed_value,true,true)
		death_seen = death_seen or war.model.fighters[0].dead or war.model.fighters[1].dead
		kos_seen = kos_seen or war.model.fighters[0].ko or war.model.fighters[1].ko
	check(death_seen,"War mode must allow actual death, not merely KO")
	check(kos_seen,"Heavy impacts must be able to unhorse a rider")
	var shielded = simulate("arena",5,false,false)
	check(shielded.model.pass_number==3,"Nonterminal low-energy exchanges should reach the third pass")
	check(shielded.model.result.reason=="hp","Three-pass tiebreak must compare rider HP")
	var reset = Model.new("arena")
	reset.fighters[0].broken = true
	reset.fighters[0].hp = 54.0
	reset._reset_positions()
	check(not reset.fighters[0].broken,"Arena must issue a fresh lance between passes")
	check(reset.fighters[0].hp==54.0,"Receiving a new lance must not heal the rider")
	var persistent = Model.new("war")
	persistent.fighters[0].broken = true
	persistent._reset_positions()
	check(persistent.fighters[0].broken,"A broken war lance must persist between passes")
	check(Model.lance_length(persistent.fighters[0])<100,"Broken lance collision reach must shrink")
	var terminal = Model.new("arena")
	terminal.phase = "charge"
	terminal.fighters[0].ko = true
	terminal.fighters[1].ko = true
	terminal._finish("terminal")
	check(terminal.result.winner==-1,"Simultaneous defeat must draw")
	var before = terminal.fighters[0].x
	terminal.step(1.0)
	check(terminal.fighters[0].x==before,"Terminal matches must not continue charging")
	var pose = Model.new()
	var hand_before = Model.hand_position(pose.fighters[0])
	pose.fighters[0].lean = 1.0
	check(Model.hand_position(pose.fighters[0]).x>hand_before.x,"Forward lean must extend the attacking pose")
	pose.fighters[0].direction = -1
	pose.fighters[0].x = 0.0
	check(Model.tip_position(pose.fighters[0]).x<0,"Left-facing lances must attack left, not merely flip visually")
	var items = Catalogue.load_items()
	check(Catalogue.opponent_stats(items,0).reach==247,"A new player's opponent must use its own loadout, independent of purchases")
	check(items.size()>=30,"Equipment catalogue must ship representative content")
	var ids: Dictionary = {}
	for item in items:
		check(not ids.has(item.id),"Equipment IDs must be unique: " + item.id)
		ids[item.id] = true
		check(Catalogue.SLOT_NAMES.has(item.slot),"Equipment must use a supported slot")
	check(Catalogue.era_for_renown(0)==0,"New players must begin in 1100–1300")
	check(Catalogue.era_for_renown(6)==1,"Era unlock must respect the renown threshold")
	check(Catalogue.era_for_renown(500)==4,"Era lookup must remain in range")
	var state = root.get_node("GameState")
	var original = state.profile.duplicate(true)
	state.profile = state.default_profile()
	var coins_before = state.profile.coins
	check(state.purchase("lance_long")=="已收入军械库","An unlocked affordable item must be purchasable")
	check(state.profile.coins==coins_before-230,"A purchase must deduct the exact price once")
	var remaining = state.profile.coins
	check(state.purchase("lance_long")=="已经拥有" and state.profile.coins==remaining,"Duplicate purchases must not deduct money")
	check(state.purchase("armor_e4")=="尚未解锁这个时代","Locked eras must reject purchases")
	check(state.equip("lance_long"),"Owned gear can be equipped")
	check(not state.equip("armor_e4"),"Unowned gear cannot be equipped")
	var award = state.award_match("test-one",1,"arena")
	check(not award.is_empty(),"A completed match should award progress")
	var after_award = state.profile.coins
	check(state.award_match("test-one",1,"arena").is_empty() and state.profile.coins==after_award,"The same match cannot award twice")
	var clean = state.sanitize({"version":1,"coins":-2,"region":999,"owned":["missing"],"equipped":{"armor":"missing"},"settings":{"blood":"wrong"}})
	check(clean.coins==0 and clean.region==3,"Save normalization must reject negative balances and invalid regions")
	check(clean.equipped.armor=="mail_basic" and not clean.settings.blood,"Corrupt equipment/settings must fall back safely")
	state.profile = original
	state.save_profile()
	var report = {"checks":checks,"failures":failures,"arena_hits":match_a.hits.size(),"war_death_observed":death_seen,"passed":failures.is_empty()}
	var file = FileAccess.open("res://tests/rules_v042_results.json",FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(report,"\t"))
	print("RULE_TEST_REPORT " + JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)

