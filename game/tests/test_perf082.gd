extends SceneTree
const Gait = preload("res://scripts/visual/horse_gait.gd")
var failures: Array = []
func _initialize() -> void: call_deferred("run")
func trial(script, count: int) -> Dictionary:
	var checksum=0.0
	var start=Time.get_ticks_usec()
	for i in range(count):
		var pose: Dictionary=script.body(i*.037,[100.0,210.0,280.0,340.0,410.0,480.0][i%6],true,1.1,.2,.3)
		checksum+=pose.offset.y+pose.rider_pitch
	return {"usec":Time.get_ticks_usec()-start,"checksum":checksum}
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
	var comparisons=0
	var max_error=0.0
	for speed in [0,50,100,135,160,185,205,210,249,250,270,290,310,330,340,369,370,390,410,430,440,480,600]:
		for frame in range(64):
			var phase=frame*TAU/64
			for moving in [false,true]:
				var before: Dictionary=original.body(phase,speed,moving,.9,sin(phase),.5)
				var after: Dictionary=Gait.body(phase,speed,moving,.9,sin(phase),.5)
				for key in before:
					var error=before[key].distance_to(after[key]) if before[key] is Vector2 else absf(float(before[key])-float(after[key]))
					max_error=maxf(max_error,error)
					if error>.000001 and key not in failures: failures.append(key)
				comparisons+=1
	var leg_comparisons=0
	for speed in [0,100,170,210,290,340,410,480]:
		for frame in range(24):
			var phase=frame*TAU/24
			for moving in [false,true]:
				var shared=Gait.body(phase,speed,moving,.9,.2)
				for index in range(4):
					# Default, planted, swing and retimed-cycle paths all consume
					# the same immutable body; compare every returned leg field.
					for variant in range(4):
						var planted=Gait.rest_foot(index).x-12 if variant==1 else INF
						var foot=Gait.rest_foot(index)+Vector2(14,-20) if variant==2 else Vector2.INF
						var swing=.5 if variant==2 else -1.0
						var cycle=.34 if variant==3 else -1.0
						var before: Dictionary=original.leg(index,phase,speed,moving,.9,planted,foot,.2,swing,cycle)
						var after: Dictionary=Gait.leg(index,phase,speed,moving,.9,planted,foot,.2,swing,cycle,shared)
						for key in before:
							var error=before[key].distance_to(after[key]) if before[key] is Vector2 else absf(float(before[key])-float(after[key]))
							max_error=maxf(max_error,error)
							if error>.000001 and key not in failures: failures.append(key)
						leg_comparisons+=1
	var samples: Array=[]
	# Alternate order to reduce warm-up/order bias. Timing is local CPU work,
	# not GPU framerate or an assertion that the game is now smooth.
	trial(original,200); trial(Gait,200)
	for i in range(6):
		var before: Dictionary
		var after: Dictionary
		if i%2==0:
			before=trial(original,3000); after=trial(Gait,3000)
		else:
			after=trial(Gait,3000); before=trial(original,3000)
		samples.append({"before":before,"after":after})
		await process_frame
	var result={"passed":failures.is_empty(),"failures":failures,"pose_comparisons":comparisons,"leg_comparisons":leg_comparisons,"maximum_error":max_error,"samples":samples,"scope":"Same-pose outputs across gait boundaries and reused-body legs, alternating local CPU microbenchmark; not live frame rate."}
	FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("PERF082 ",result)
	quit(0 if failures.is_empty() else 1)
