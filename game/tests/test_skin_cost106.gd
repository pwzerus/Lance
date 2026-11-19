extends SceneTree
const HorseSkin106=preload("res://scripts/visual/horse_skin.gd")
const Gait=preload("res://scripts/visual/horse_gait.gd")
var failures=[]
func _initialize()->void:call_deferred("run")
func check(ok:bool,message:String)->void:
	if not ok and message not in failures:failures.append(message)
func measure(skin,poses:Array)->int:
	var started=Time.get_ticks_usec()
	for repeat in range(8):
		for pose in poses:skin.update(pose.body,pose.hind,pose.fore)
	return Time.get_ticks_usec()-started
func run()->void:
	var folder="";var path=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--folder="):folder=arg.trim_prefix("--folder=")
		if arg.begins_with("--reference="):path=arg.trim_prefix("--reference=")
	if folder.is_empty() or DirAccess.dir_exists_absolute(folder) or path.is_empty() or not "--test-profile" in OS.get_cmdline_user_args() or OS.get_environment("GALUMU_MEMORY_BOUND")!="1024":quit(2);return
	DirAccess.make_dir_recursive_absolute(folder)
	var reference=load(path);var poses=[];var rows=[]
	for n in range(48):
		var speed=[0.0,130.0,240.0,300.0,410.0,500.0][n%6]
		var phase=n*TAU/17.0
		var body=Gait.visual(Gait.body(phase,speed,speed>0,.9,.7,.3,.2),phase,speed,speed>0,.7,.2,n*.1,.7,.6)
		poses.append({"body":body,"hind":Gait.leg(1,phase,speed,speed>0,1.0,INF,Vector2.INF,.7,-1,-1,body),"fore":Gait.leg(3,phase,speed,speed>0,1.0,INF,Vector2.INF,.7,-1,-1,body)})
	for limb in ["","hind","fore"]:
		var fresh=HorseSkin106.new(limb);var old=reference.new(limb)
		for pose in poses:
			fresh.update(pose.body,pose.hind,pose.fore);old.update(pose.body,pose.hind,pose.fore)
			check(fresh.vertices==old.vertices,"All vertices remain bit exact: "+limb)
		check(fresh.uvs==old.uvs and fresh.indices==old.indices,"UVs and topology unchanged: "+limb)
		var times=[]
		for i in range(3):
			if i%2==0:times.append({"old_us":measure(old,poses),"new_us":measure(fresh,poses)})
			else:
				var current=measure(fresh,poses)
				times.append({"new_us":current,"old_us":measure(old,poses)})
		var batched=0
		for group in fresh.hind_rigid_indices:batched+=group.size()
		for group in fresh.fore_rigid_indices:batched+=group.size()
		rows.append({"limb":limb,"vertices":fresh.vertices.size(),"batched_rigid_vertices":batched,"weighted_vertices":fresh.deformed_indices.size(),"samples":poses.size(),"timings":times})
	var out={"passed":failures.is_empty(),"failures":failures,"reference_sha256":FileAccess.get_sha256(path),"rows":rows,"scope":"Local deformation CPU work and exact vertices/UVs/topology, not GPU frame rate."}
	FileAccess.open(folder+"/report.json",FileAccess.WRITE).store_string(JSON.stringify(out,"\t"))
	print("SKIN_COST106 ",JSON.stringify(out));quit(0 if failures.is_empty() else 1)
