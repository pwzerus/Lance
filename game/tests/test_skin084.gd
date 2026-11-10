extends SceneTree
## Compare every submitted vertex against the unchanged mesh implementation.
const HorseSkin=preload("res://scripts/visual/horse_skin.gd")
const Gait=preload("res://scripts/visual/horse_gait.gd")
var failures: Array=[]
func _initialize() -> void: call_deferred("run")
func fixture(phase: float, speed: float) -> Array:
	return [Gait.body(phase,speed,true,.9,sin(phase),.6),Gait.leg(1,phase,speed,true,.9),Gait.leg(3,phase,speed,true,.9)]
func trial(skins: Array, fixtures: Array, loops: int) -> int:
	var start=Time.get_ticks_usec()
	for index in range(loops):
		var f: Array=fixtures[index%fixtures.size()]
		for skin in skins: skin.update(f[0],f[1],f[2])
	return Time.get_ticks_usec()-start
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
	var before: Array=[]
	var after: Array=[]
	for part in ["","hind","fore"]:
		before.append(original.new(part)); after.append(HorseSkin.new(part))
	var fixtures: Array=[]
	var comparisons=0
	var max_error=0.0
	for speed in [0,100,160,210,270,340,410,480,600]:
		for frame in range(24):
			var f=fixture(frame*TAU/24,speed)
			fixtures.append(f)
			for part in range(3):
				before[part].update(f[0],f[1],f[2]); after[part].update(f[0],f[1],f[2])
				if before[part].indices!=after[part].indices or before[part].uvs!=after[part].uvs:
					if "Topology/UV changed" not in failures: failures.append("Topology/UV changed")
				for i in range(before[part].vertices.size()):
					max_error=maxf(max_error,before[part].vertices[i].distance_to(after[part].vertices[i]))
					comparisons+=1
			await process_frame
	if max_error>.000001: failures.append("Submitted vertex positions differ")
	var samples: Array=[]
	trial(before,fixtures,5); trial(after,fixtures,5)
	for index in range(6):
		var a=0; var b=0
		if index%2==0:
			a=trial(before,fixtures,600); b=trial(after,fixtures,600)
		else:
			b=trial(after,fixtures,600); a=trial(before,fixtures,600)
		samples.append({"before_usec":a,"after_usec":b,"ratio":float(b)/maxi(a,1)})
		await process_frame
	var init_samples=[]
	for index in range(12):
		var start=Time.get_ticks_usec()
		var old_skins=[]
		for part in ["","hind","fore"]: old_skins.append(original.new(part))
		var midpoint=Time.get_ticks_usec()
		var new_skins=[]
		for part in ["","hind","fore"]: new_skins.append(HorseSkin.new(part))
		init_samples.append({"old_us":midpoint-start,"new_us":Time.get_ticks_usec()-midpoint})
	var result={"initialization":init_samples,"deformed_counts":[after[0].deformed_indices.size(),after[1].deformed_indices.size(),after[2].deformed_indices.size()],"passed":failures.is_empty(),"failures":failures,"vertex_comparisons":comparisons,"maximum_error":max_error,"samples":samples,"scope":"Whole horse plus far hind/fore mesh; same UVs, topology and all submitted vertices. Timings include existing surface update. No frame-rate or visual acceptance claim."}
	FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("SKIN_PERF082 ",result)
	quit(0 if failures.is_empty() else 1)
