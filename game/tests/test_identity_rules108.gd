extends SceneTree
## Cosmetic A/B: identical production matches with and without the new
## appearance payload. Checks hit anchors, RNG, events and final result.
const Model=preload("res://scripts/core/joust_match.gd")
const Catalogue=preload("res://scripts/core/catalogue.gd")
const Campaign=preload("res://scripts/core/campaign.gd")
const Appearance=preload("res://scripts/core/character_appearance.gd")
const Brain=preload("res://scripts/core/opponent_ai.gd")
const DT=1.0/120.0
var failures=[]
func _initialize()->void:call_deferred("run")
func trial(items:Array,n:int,side:int,seed_value:int)->Dictionary:
	var level=Campaign.level(items,n);var stats=Catalogue.stats(items,level.equipment)
	var dressed=stats.duplicate(true);dressed.appearance=level.appearance.duplicate()
	var a=Model.new(level.mode,stats,stats,seed_value);var b=Model.new(level.mode,dressed,dressed,seed_value)
	var brains=[Brain.new(),Brain.new()];var rngs=[RandomNumberGenerator.new(),RandomNumberGenerator.new()]
	for i in range(2):brains[i].configure(level.ai);rngs[i].seed=seed_value+431
	var count=0;var hits=0;var error=""
	for tick in range(10800):
		var p=a.fighters[side];var enemy=a.fighters[1-side]
		var target=Model.head_position(enemy) if (tick/180)%2==0 else Model.body_position(enemy)
		var aim=asin(clampf((target.y-Model.hand_position(p).y)/Model.lance_length(p),-.629,.548))
		var gap=absf(p.x-enemy.x);var lean=.55 if gap<1600 else 0.0
		var guard=[.0,.43,1.0][(tick/120)%3]
		for m in [a,b]:m.set_controls(side,aim,lean,gap<2700,DT,guard)
		if a.phase=="charge":
			brains[0].update(a,1-side,1,DT,rngs[0]);brains[1].update(b,1-side,1,DT,rngs[1])
		a.step(DT);b.step(DT);count=tick+1
		var events_a=a.drain_events();var events_b=b.drain_events()
		if events_a!=events_b or a.rng.state!=b.rng.state or rngs[0].state!=rngs[1].state:error="events/RNG differ";break
		for e in events_a:
			if e.type=="hit":hits+=1
		for i in range(2):
			for key in ["hp","head_load","score","balance","stamina","arm","aim","guard","lean","speed","x","ko","dead"]:
				if a.fighters[i].get(key)!=b.fighters[i].get(key):error="fighter differs: "+key;break
			if Model.head_position(a.fighters[i])!=Model.head_position(b.fighters[i]) or Model.tip_position(a.fighters[i])!=Model.tip_position(b.fighters[i]):error="hit anchors differ"
		if not error.is_empty() or a.phase=="ended":break
	if error.is_empty() and (a.phase!="ended" or b.phase!="ended" or a.result!=b.result):error="result/termination differs"
	if not error.is_empty():failures.append("%d/%d/%d: %s"%[n,side,seed_value,error])
	return {"level":n,"side":side,"seed":seed_value,"ticks":count,"hits":hits,"identical":error.is_empty(),"result":a.result}
func run()->void:
	var path=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):path=arg.trim_prefix("--report=")
	if path.is_empty() or FileAccess.file_exists(path) or not "qa_" in root.get_node("GameState").save_path or OS.get_environment("GALUMU_MEMORY_BOUND").is_empty():quit(2);return
	var items=Catalogue.load_items();var rows=[]
	seed(10801);var expected=[randf(),randf()];seed(10801);var actual=[randf()]
	Campaign._cache.clear()
	for n in range(1,81):Campaign.level(items,n)
	actual.append(randf())
	if expected!=actual:failures.append("Appearance generation advanced global RNG")
	for n in [1,8,15,24,43,80]:
		for side in [0,1]:
			for seed_value in [10801,10819]:rows.append(trial(items,n,side,seed_value))
		await process_frame
		print("IDENTITY108 level=",n," rows=",rows.size())
	FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"failures":failures,"rows":rows,"scope":"24 paired 120Hz production rule matches; cosmetic payload must not affect anchors, events, AI RNG, combat RNG or outcomes. Not visual acceptance."},"\t"))
	quit(0 if failures.is_empty() else 1)
