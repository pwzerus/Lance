extends SceneTree
const Model=preload("res://scripts/core/joust_match.gd")
const Campaign=preload("res://scripts/core/campaign.gd")
const Catalogue=preload("res://scripts/core/catalogue.gd")
const Brain=preload("res://scripts/core/opponent_ai.gd")
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var path="";var legacy=false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--report="):path=a.trim_prefix("--report=")
		if a=="--legacy":legacy=true
	if path.is_empty() or FileAccess.file_exists(path) or not "qa_" in root.get_node("GameState").save_path or OS.get_environment("GALUMU_MEMORY_BOUND")=="":quit(2);return
	var items=Catalogue.load_items();var rows=[]
	var campaign_source=load("E:/GALUMU/docs/development/logs/feel102-old-campaign.gd") if legacy else Campaign
	var brain_source=load("E:/GALUMU/docs/development/logs/feel102-old-opponent_ai.gd") if legacy else Brain
	for n in [12,24]:
		var level=campaign_source.level(items,n);var stats=Catalogue.stats(items,level.equipment)
		for strategy in ["head","shield_center","opening"]:
			for side in range(2):
				var m=Model.new("arena",stats,stats,10201+side)
				var brain=brain_source.new();brain.configure(level.ai)
				var rng=RandomNumberGenerator.new();rng.seed=10231+side
				var aim=-.08;var guard=.43;var hits=[]
				for tick in range(6000):
					var p=m.fighters[side];var enemy=m.fighters[1-side]
					if tick%36==0:
						var target=Model.head_position(enemy)
						if strategy=="shield_center":target=Model.shield_position(enemy)
						elif strategy=="opening" and float(enemy.guard)>.65:target=Model.flank_position(enemy)
						aim=asin(clampf((target.y+(-8 if side==0 else 8)-Model.hand_position(p).y)/Model.lance_length(p),-.629,.548))
						var incoming=Model.tip_position(enemy).y
						guard=1.0 if incoming<Model.body_position(p).y-30 else (0.0 if incoming>Model.body_position(p).y+22 else .43)
					m.set_controls(side,aim,0.0,absf(p.x-enemy.x)<3000,1.0/60,guard)
					if m.phase=="charge":brain.update(m,1-side,1,1.0/60,rng)
					m.step(1.0/60)
					for e in m.drain_events():
						if e.type=="hit":hits.append({"player":e.attacker==side,"zone":e.zone,"glanced":e.glanced,"impulse":e.impulse,"ko":e.ko})
					if m.phase=="ended":break
				rows.append({"level":n,"strategy":strategy,"side":side,"ended":m.phase=="ended","winner":-1 if m.result.get("winner",-1)==-1 else (0 if m.result.winner==side else 1),"hits":hits})
			FileAccess.open(path+".partial",FileAccess.WRITE).store_string(JSON.stringify(rows))
			print("TACTICS102 ",n," ",strategy)
	FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify({"legacy_ai":legacy,"rows":rows,"scope":"12 matched-equipment arena matches vs levels 12/24 lessons, 600ms aim and visible-tip guard updates, +/-8px fixed error. Direction pair is not a population win rate; no human acceptance claim."},"\t"))
	quit(0)
