extends SceneTree
## Exact mesh equivalence against a supplied pre-cache source snapshot.
const HorseSkinTest=preload("res://scripts/visual/horse_skin.gd")
const Gait=preload("res://scripts/visual/horse_gait.gd")
var failures=[]
func _initialize()->void:call_deferred("run")
func check(ok:bool,message:String)->void:
	if not ok and message not in failures:failures.append(message)
func run()->void:
	var folder="";var reference=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--folder="):folder=arg.trim_prefix("--folder=")
		if arg.begins_with("--reference="):reference=arg.trim_prefix("--reference=")
	if folder.is_empty() or DirAccess.dir_exists_absolute(folder) or reference.is_empty() or not "qa_" in root.get_node("GameState").save_path or OS.get_environment("GALUMU_MEMORY_BOUND")!="1024":quit(2);return
	DirAccess.make_dir_recursive_absolute(folder)
	var old=load(reference)
	if old==null:quit(2);return
	var rows=[]
	for limb in ["","hind","fore"]:
		var fresh=HorseSkinTest.new(limb);var original=old.new(limb);var cases=0
		for speed in [0.0,120.0,240.0,380.0,480.0,640.0]:
			for frame in range(24):
				var phase=TAU*frame/24.0
				var body=Gait.visual(Gait.body(phase,speed,speed>0,1.0,.4,.65,.12),phase,speed,speed>0,.4,.12,frame*.13,.6,.25)
				var hind=Gait.leg(1,phase,speed,speed>0,1.0,INF,Vector2.INF,.4,-1,-1,body)
				var fore=Gait.leg(3,phase,speed,speed>0,1.0,INF,Vector2.INF,.4,-1,-1,body)
				original.update(body,hind,fore);fresh.update(body,hind,fore)
				check(fresh.vertices==original.vertices,"Changed pose differs from original mesh "+limb)
				var uploads=fresh.deformation_uploads
				fresh.update(body.duplicate(true),hind.duplicate(true),fore.duplicate(true))
				check(fresh.deformation_uploads==uploads,"Equal deep-copied pose was uploaded again")
				check(fresh.vertices==original.vertices,"Reuse changed vertex positions")
				# Even a subpixel head change must update rather than being quantized.
				body.head=float(body.head)+.000001
				original.update(body,hind,fore);fresh.update(body,hind,fore)
				var head_upload=1 if limb.is_empty() else 0
				check(fresh.deformation_uploads==uploads+head_upload,"Small head motion must update the body, not unrelated far legs")
				check(fresh.vertices==original.vertices,"Small motion differs from original mesh")
				fresh.mesh=ArrayMesh.new();fresh._create_mesh();fresh.update(body,hind,fore)
				check(fresh.deformation_uploads==uploads+head_upload+1,"Mesh recreation retained a stale cache")
				check(fresh.vertices==original.vertices,"Recreated mesh differs")
				cases+=1
		rows.append({"limb":limb,"cases":cases,"vertices":fresh.vertices.size(),"uploads":fresh.deformation_uploads,"reuses":fresh.deformation_reuses})
	FileAccess.open(folder+"/report.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"failures":failures,"cases":rows,"scope":"432 poses, exact PackedVector2Array equality against supplied pre-change source; repeated inputs, 1e-6 head changes and mesh recreation. No rendered/human quality claim."},"\t"))
	print("SKIN_CACHE105 ",failures);quit(0 if failures.is_empty() else 1)
