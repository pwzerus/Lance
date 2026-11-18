extends SceneTree
## Ground contact marks belong to the struck rider's lane and lie beneath
## riders and the rail. Switching visual blood off never changes injury.
const Model=preload("res://scripts/core/joust_match.gd")
const FX=preload("res://scripts/visual/impact_fx.gd")
var failures=[]
func _initialize()->void:call_deferred("run")
func check(ok:bool,message:String)->void:
	if not ok and message not in failures:failures.append(message);push_error(message)
func run()->void:
	var report=""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--report="):report=a.trim_prefix("--report=")
	if report.is_empty() or FileAccess.file_exists(report) or not root.get_node("GameState").save_path.contains("qa_") or OS.get_environment("GALUMU_MEMORY_BOUND")!="1024":quit(2);return
	var rows=[]
	for mode in ["arena","war"]:
		for di in [0,1]:
			var model=Model.new(mode,{}, {},10504)
			var defender:Dictionary=model.fighters[di]
			model.fighters[1-di].speed=480;defender.speed=480
			var event={"type":"hit","attacker":1-di,"defender":di,"zone":"body","speed":960.0,"position":Model.body_position(defender)}
			model._apply_contact(event)
			var fx=FX.new();fx.z_index=10;root.add_child(fx);fx.set_process(false);fx.blood_enabled=true;fx.rng.seed=10504
			fx.hit(event.position,model.fighters[1-di].direction,event.damage,false,event.broke,"body",.8,event)
			check(fx.stains.size()==1,"Damaging nonshield contact produces one optional ground mark")
			var floor=float(defender.lane_y)+12.0
			var stamp=Vector2(fx.stains[0].p) if not fx.stains.is_empty() else Vector2.INF
			check(event.has("defender_ground_y") and absf(float(event.get("defender_ground_y",INF))-floor)<.001,"Contact supplies actual defender lane floor")
			check(stamp.y>=floor-2.001 and stamp.y<=floor+8.001,"Ground mark lies on the struck lane, not the rail centerline")
			var before=defender.duplicate(true);var rng_state=model.rng.state
			var nonblood=fx.particles.filter(func(p):return not p.blood).size()
			fx.clear_blood();fx.blood_enabled=false
			check(fx.stains.is_empty() and fx.particles.size()==nonblood,"Blood off removes marks and only blood particles")
			check(defender==before and model.rng.state==rng_state,"Visual cleanup preserves wounds, outcome and rule RNG")
			fx.hit(event.position,1,event.damage,false,false,"body",.8,event)
			check(fx.stains.is_empty(),"Blood-off subsequent contacts cannot recreate ground marks")
			rows.append({"mode":mode,"defender":di,"lane_y":defender.lane_y,"expected_floor":floor,"stamp":stamp,"damage":event.damage})
			fx.free()
	FileAccess.open(report,FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"failures":failures,"rows":rows,"scope":"Four explicit high-force rule-contact fixtures and actual effect data; no sweep, GPU or player quality verdict. Pause-menu rendered cleanup is covered separately."},"\t"))
	print("GROUND105 ",failures);quit(0 if failures.is_empty() else 1)
