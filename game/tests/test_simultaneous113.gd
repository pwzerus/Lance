extends "test_rules098.gd"
## Inject controlled raw contact candidates into the real Model.step batch.
## Reverse enumeration order without changing either rider's initial state.
class PairModel:
	extends "res://scripts/core/joust_match.gd"
	var candidates: Array = [{},{}]
	func _detect_contact(index: int, _delta: float) -> Dictionary:
		return candidates[index].duplicate(true)

func _initialize() -> void:
	var folder = ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--folder="): folder=arg.trim_prefix("--folder=")
	if folder.is_empty() or DirAccess.dir_exists_absolute(folder) or OS.get_environment("GALUMU_MEMORY_BOUND")=="":
		quit(2);return
	DirAccess.make_dir_recursive_absolute(folder)
	items=Catalogue.load_items()
	var records=[]
	var maximum_difference=0.0
	for mode in ["arena","war"]:
		for zones in [["head","head"],["body","body"],["flank","flank"],["shield","shield"],["head","body"],["shield","flank"]]:
			for pace in [.5,1.0]:
				for prior in [[0.0,0.0],[.65,.10]]:
					var forward=resolve(mode,zones,pace,prior,false)
					var reverse=resolve(mode,zones,pace,prior,true)
					var difference=0.0
					for side in range(2):
						for key in ["damage","impulse","impulse_ratio","ko_threshold"]:
							difference=maxf(difference,absf(float(forward.hits[side][key])-float(reverse.hits[side][key])))
						for key in ["hp","balance","injury","consciousness","seat_velocity"]:
							difference=maxf(difference,absf(float(forward.states[side][key])-float(reverse.states[side][key])))
						for key in ["ko","dead","unseated","unconscious"]:
							check(forward.states[side][key]==reverse.states[side][key],"Batch order preserves terminal state: "+str([mode,zones,pace,prior,side,key]))
						var solo=resolve(mode,zones,pace,prior,false,side)
						check(absf(float(forward.hits[side].impulse)-float(solo.hits[side].impulse))<.00001,"Simultaneous incoming injury cannot retroactively weaken an already committed strike: "+str([mode,zones,pace,prior,side]))
					check(difference<.00001,"Reverse contact enumeration preserves both loads: "+str([mode,zones,pace,prior,difference]))
					maximum_difference=maxf(maximum_difference,difference)
					records.append({"mode":mode,"zones":zones,"pace":pace,"prior_injury":prior,"maximum_difference":difference,"forward":forward,"reverse":reverse})
	var healthy=resolve("arena",["body","body"],.5,[0.0,0.0],false,0)
	var wounded=resolve("arena",["body","body"],.5,[.65,0.0],false,0)
	check(float(wounded.hits[0].impulse)<float(healthy.hits[0].impulse)*.95,"Injury from earlier contacts still reduces later weapon strength")
	FileAccess.open(folder+"/report.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"failures":failures,"cases":records,"maximum_order_difference":maximum_difference,"scope":"Controlled raw candidates in production Model.step; forward/reverse enumeration, isolated strike comparison and pre-existing injuries. No natural-sweep, GPU or player-feel claim."},"\t"))
	print("SIMULTANEOUS113 failures=",failures.size()," maximum_difference=",maximum_difference)
	quit(0 if failures.is_empty() else 1)

func resolve(mode: String,zones: Array,pace: float,prior: Array,reverse: bool,only: int=-1) -> Dictionary:
	var stats=kit(3,"eng_shield_5")
	var model=PairModel.new(mode,stats,stats,981)
	model.phase="charge"
	for side in range(2):
		var f:Dictionary=model.fighters[side]
		f.speed=Model.GALLOP_SPEED*pace;f.aim=0.0;f.lean=0.0;f.lance_stability=1.0;f.boost=true
		f.stats.power=1.0;f.stats.stability=1.0;f.injury=prior[side]
		model._cache_pose(f)
	var contacts=[]
	for side in range(2):
		contacts.append({"type":"hit","zone":zones[side],"attacker":side,"defender":1-side,"speed":960.0*pace,
			"position":Model.shield_position(model.fighters[1-side]),"head_incidence":1.0,"combat_elevation":0.0,
			"shaft_alignment":1.0,"eccentricity":0.0,"shield_region":"center","lever":0.0} if only<0 or side==only else {})
	if reverse: contacts.reverse()
	model.candidates=contacts
	model.step(1.0/120.0)
	var hits=[{},{}]
	for event in model.drain_events():
		if event.type!="hit":continue
		var row={}
		for key in ["damage","impulse","impulse_ratio","ko_threshold","attacker_strength113"]:
			if event.has(key):row[key]=event[key]
		hits[int(event.attacker)]=row
	var states=[]
	for fighter in model.fighters:
		var state={}
		for key in ["hp","balance","injury","consciousness","seat_velocity","ko","dead","unseated","unconscious"]:state[key]=fighter[key]
		states.append(state)
	return {"hits":hits,"states":states}
