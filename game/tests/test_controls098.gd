extends SceneTree
## REQ-098: pause and contact-freeze must not turn convergence tolerances into
## a teleport. Independent displacement bounds, including near-target poses.
const Model=preload("res://scripts/core/joust_match.gd")
var failures=[]
var rows=[]
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var path=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): path=arg.trim_prefix("--report=")
	if path.is_empty() or FileAccess.file_exists(path) or not "qa_" in root.get_node("GameState").save_path or OS.get_environment("GALUMU_MEMORY_BOUND")!="1024": quit(2);return
	for dt in [0.0,.000001,1.0/120*.001,1.0/60*.001,1.0/30*.001,1.0/120,1.0/60,1.0/30]:
		for direction in [-1.0,1.0]:
			var m=Model.new("arena",{}, {},98098)
			m.phase="charge";m.fighters[0].x=-200.0;m.fighters[1].x=200.0
			for rider in m.fighters: rider.speed=Model.TROT_SPEED
			var f:Dictionary=m.fighters[0]
			f.aim=.1;f.guard=.5;f.lean=.2
			m.set_controls(0,.1+.001*direction,.2+.003*direction,false,dt,.5+.001*direction)
			var changes={"aim":absf(f.aim-.1),"guard":absf(f.guard-.5),"lean":absf(f.lean-.2)}
			# Light kit may reach 115% agility. No fatigue/pace effect can exceed
			# that upper envelope; near-target travel must still respect time.
			for pair in [["aim",.95*1.15],["guard",2.8*1.15],["lean",2.3]]:
				if changes[pair[0]]>float(pair[1])*dt+1e-10:
					failures.append({"dt":dt,"direction":direction,"channel":pair[0],"travel":changes[pair[0]],"budget":float(pair[1])*dt})
			rows.append({"dt":dt,"direction":direction,"changes":changes})
	FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"failures":failures,"rows":rows},"\t"))
	print("CONTROLS098 failures=",failures.size())
	quit(0 if failures.is_empty() else 1)
