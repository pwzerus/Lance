extends "test_horse_catalogue_v050.gd"
## Fixed 120Hz production model; irregular visual updates and rapid spur taps.
## Reuse existing geometry limits; do not infer naturalness from passing bounds.
func run() -> void:
	var path = ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report-path="): path=arg.trim_prefix("--report-path=")
	if OS.get_environment("GALUMU_MEMORY_BOUND")!="1024" or not root.get_node("GameState").save_path.contains("qa_") or path.is_empty() or FileAccess.file_exists(path):
		quit(2)
		return
	var items=Catalogue.load_items()
	var rows=[]
	var cadence=[1,2,5,3,6,2,4]
	for id in ["horse_bay","horse_courser","horse_steady"]:
		active_horse=Catalogue.find(items,id)
		active_stats=Catalogue.stats(items,{"horse":id})
		for facing in [1,-1]:
			var fixture=make_fixture(facing,110.0)
			var metrics=new_metrics()
			var tick=0
			var visual_frames=0
			var changes=0
			var previous_held=false
			while tick<1200:
				var count=mini(cadence[visual_frames%cadence.size()],1200-tick)
				for substep in range(count):
					var seconds=tick/120.0
					var held=seconds<2.0 or (seconds>=4.0 and seconds<6.0)
					if seconds>=2.0 and seconds<4.0: held=int((seconds-2.0)/.12)%2==0
					if seconds>=7.0: held=int((seconds-7.0)/.27)%2==0
					if held!=previous_held: changes+=1
					previous_held=held
					fixture.model.set_controls(fixture.index,-.08,0.0,held,1.0/120.0,.43)
					fixture.model.step(1.0/120.0)
					tick+=1
				fixture.view.position=Vector2(fixture.fighter.x,0)
				fixture.view._process(count/120.0)
				inspect_pose(fixture.fighter,fixture.view,count/120.0,metrics,"Irregular cadence / "+str(facing))
				visual_frames+=1
			check(changes>20,"Rapid-spur fixture did not exercise repeated input changes")
			rows.append({"horse":id,"facing":facing,"input_changes":changes,"model_ticks":tick,"visual_frames":visual_frames,"metrics":finish_metrics(metrics,"Irregular cadence / "+str(facing))})
			fixture.view.queue_free()
			await process_frame
	var file=FileAccess.open(path,FileAccess.WRITE)
	if file==null:
		quit(2)
		return
	file.store_string(JSON.stringify({"passed":failures.is_empty(),"failures":failures,"cases":rows,"scope":"Fixed 120Hz production Model and world-translated Rider with irregular 20-120Hz visual intervals, rapid spur changes, three representative horse configurations and both facings. Original v050 geometry bounds retained. No GPU or OS input and no real-time FPS/naturalness verdict."},"\t"))
	file.close()
	print("MOTION_CADENCE061 "+str(failures.is_empty())+" "+str(failures))
	quit(0 if failures.is_empty() else 1)
