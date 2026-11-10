extends SceneTree
## Bounded production-rule soak, with actual AI and three horse-control scripts.
## A sampled tracking bot is not a player skill model or a balance approval.
const Model=preload("res://scripts/core/joust_match.gd")
const Brain=preload("res://scripts/core/opponent_ai.gd")
const Catalogue=preload("res://scripts/core/catalogue.gd")
const DT=1.0/120.0
var failures: Array=[]
var rows: Array=[]
var path=""
func _initialize() -> void: call_deferred("run")
func urge(style: String, gap: float) -> bool:
	if style=="hold": return true
	if style=="reserve": return gap<1700
	return gap<3600 and gap>1000
func trial(stats: Dictionary, kit: String, mode: String, style: String, zone: String, seed_value: int) -> Dictionary:
	var model=Model.new(mode,stats,stats,seed_value)
	var brain=Brain.new()
	var rng=RandomNumberGenerator.new()
	rng.seed=seed_value+991
	var tick=0
	var hits: Array=[]
	var aim=0.0
	var min_stamina=100.0
	var invariant=true
	while model.phase!="ended" and tick<120*100:
		var f: Dictionary=model.fighters[0]
		if tick%36==0:
			var target=Model.head_position(model.fighters[1]) if zone=="head" else Model.body_position(model.fighters[1])
			var hand=Model.hand_position(f)
			aim=asin(clampf((target.y-hand.y)/Model.lance_length(f),-.629,.548))
		model.set_controls(0,aim,.15,urge(style,absf(model.fighters[1].x-f.x)),DT,.43)
		brain.update(model,1,1,DT,rng)
		model.step(DT)
		for event in model.drain_events():
			if event.type=="hit":
				hits.append({"attacker":event.attacker,"zone":event.zone,"points":event.points,"damage":event.damage,"speed":event.speed,"ko":event.ko,"dead":event.dead,"glanced":event.glanced,"own_speed":model.fighters[event.attacker].speed,"stamina":model.fighters[event.attacker].stamina})
		for actor in model.fighters:
			invariant=invariant and is_finite(actor.hp) and actor.hp>=0 and actor.hp<=100 and actor.arm>=0 and actor.arm<=100 and actor.stamina>=0 and actor.stamina<=100 and Model.tip_position(actor).is_finite()
			if mode=="arena": invariant=invariant and not actor.dead
		min_stamina=minf(min_stamina,f.stamina)
		tick+=1
	var id="%s/%s/%s/%s/%d" % [kit,mode,style,zone,seed_value]
	if model.phase!="ended": failures.append(id+" did not finish")
	if not invariant: failures.append(id+" violated numeric/mode invariant")
	return {"id":id,"kit":kit,"mode":mode,"style":style,"target":zone,"seed":seed_value,"duration":tick*DT,"result":model.result,"hits":hits,"minimum_player_stamina":min_stamina,"finished":model.phase=="ended","invariants":invariant}
func save(complete: bool) -> void:
	FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify({"passed":complete and failures.is_empty(),"complete":complete,"failures":failures,"rows":rows,"scope":"Production 120Hz rules and normal delayed AI, same equipment both sides; scripted player samples target every .3s and holds chest guard. Strategy observations, not human skill/win-rate proof."},"\t"))
func run() -> void:
	var kit="starter"
	var budget=360.0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): path=arg.trim_prefix("--report=")
		if arg.begins_with("--kit="): kit=arg.trim_prefix("--kit=")
		if arg.begins_with("--budget="): budget=float(arg.trim_prefix("--budget="))
	if path.is_empty() or FileAccess.file_exists(path) or OS.get_environment("GALUMU_MEMORY_BOUND")=="" or not root.get_node("GameState").save_path.contains("qa_"):
		quit(2); return
	var items=Catalogue.load_items()
	var equipment=root.get_node("GameState").default_profile().equipped
	if kit=="heavy":
		equipment.merge({"armor":"eng_armor_5","helmet":"eng_helmet_5","shield":"eng_shield_5","lance":"eng_lance_stout_5","horse":"horse_bay"},true)
	var stats=Catalogue.stats(items,equipment)
	var started=Time.get_ticks_msec()
	for mode in ["arena","war"]:
		for style in ["hold","reserve","brake"]:
			for zone in ["head","body"]:
				for seed_value in [8201,8202,8203]:
					if (Time.get_ticks_msec()-started)/1000.0>budget:
						save(false); quit(3); return
					rows.append(trial(stats,kit,mode,style,zone,seed_value))
					save(false)
					print("TACTICS082 ",rows.size()," ",rows[-1].id," finished=",rows[-1].finished)
					await process_frame
	save(true)
	print("TACTICS082 failures=",failures)
	quit(0 if failures.is_empty() else 1)
