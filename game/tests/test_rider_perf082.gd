extends SceneTree
const Rider=preload("res://scripts/visual/rider_view.gd")
const Model=preload("res://scripts/core/joust_match.gd")
const Gait=preload("res://scripts/visual/horse_gait.gd")
var failures: Array=[]
func _initialize() -> void: call_deferred("run")
func trial(script, compare: bool = false, facing: int = 1) -> Dictionary:
	var view=script.new()
	var reference=Rider.new() if compare else null
	var f=Model.new().fighters[0]
	f.direction=facing
	view.fighter=f
	view.moving=true
	if compare:
		reference.fighter=f
		reference.moving=true
	var usec=0
	var maximum_error=0.0
	for tick in range(720):
		var t=tick/60.0
		f.speed=lerpf(0,480,smoothstep(0,4,t)) if t<6 else lerpf(480,100,smoothstep(6,10,t))
		f.gait_phase+=Gait.frequency(f.speed)*TAU/60
		f.motion_drive=sin(t*.6)*.4
		f.x+=f.speed/60*facing
		view.position.x=f.x
		var started=Time.get_ticks_usec()
		view._process(1.0/60)
		usec+=Time.get_ticks_usec()-started
		if compare:
			reference.position.x=f.x
			reference._process(1.0/60)
			for index in range(4):
				for key in view.leg_poses[index]:
					var a=view.leg_poses[index][key]
					var b=reference.leg_poses[index][key]
					var error=a.distance_to(b) if a is Vector2 else absf(float(a)-float(b))
					maximum_error=maxf(maximum_error,error)
	view.free()
	if compare: reference.free()
	return {"usec":usec,"maximum_error":maximum_error}
func run() -> void:
	var path=""
	var baseline=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): path=arg.trim_prefix("--report=")
		if arg.begins_with("--baseline="): baseline=arg.trim_prefix("--baseline=")
	if path.is_empty() or baseline.is_empty() or FileAccess.file_exists(path) or OS.get_environment("GALUMU_MEMORY_BOUND")=="" or not root.get_node("GameState").save_path.contains("qa_"):
		quit(2); return
	var original=load(baseline)
	if original==null: quit(2); return
	var comparisons=[]
	for facing in [-1,1]:
		var row=trial(original,true,facing)
		comparisons.append(row)
		if row.maximum_error>.000001: failures.append("Rider retained-foot or retiming pose differs")
	var samples=[]
	for i in range(6):
		var before: Dictionary
		var after: Dictionary
		if i%2==0:
			before=trial(original); after=trial(Rider)
		else:
			after=trial(Rider); before=trial(original)
		samples.append({"before":before,"after":after})
		await process_frame
	var result={"passed":failures.is_empty(),"failures":failures,"comparisons":comparisons,"samples":samples,"scope":"Full retained-hoof Rider._process across 12s acceleration/deceleration both directions; CPU timing without renderer, not framerate. Baseline uses same current Gait but does not reuse body pose."}
	FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("RIDER_PERF082 ",result)
	quit(0 if failures.is_empty() else 1)
