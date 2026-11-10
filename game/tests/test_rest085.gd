extends "test_head_visual076.gd"
## Reproduce the exact finite-control live contact, then inspect ground support.
func run() -> void:
	var report=""
	var timeline=""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--report="):report=a.trim_prefix("--report=")
		if a.begins_with("--timeline="):timeline=a.trim_prefix("--timeline=")
	var state=root.get_node("GameState")
	if report.is_empty() or FileAccess.file_exists(report) or not state.save_path.contains("qa_") or OS.get_environment("GALUMU_MEMORY_BOUND")!="1024":quit(2);return
	state.profile=state.default_profile();state.profile.settings.sound=false
	main=load("res://scenes/main.tscn").instantiate();root.add_child(main);main.set_process(false)
	var b=create_battle("war",true)
	var fixture=find_stage(b,0,"head",true)
	var model=b.match_model
	stage_model(model,0,"head",true,fixture.gait_phase)
	var hit={}
	for i in range(fixture.ticks):
		for e in step_staged(model,0,"head"):
			if e.type=="hit":hit=e
	var actor=load("res://scripts/visual/fallen_rider.gd").new();root.add_child(actor)
	var event=hit.duplicate(true);event.direction=int(model.fighters[0].direction)
	actor.setup(model.fighters[1],event,b.riders[1]);actor.set_process(false);actor.visual.set_process(false);actor.far_leg.set_process(false)
	var rows=[]
	var deltas=[]
	if not timeline.is_empty():
		var history=JSON.parse_string(FileAccess.get_file_as_string(timeline));var last=0.0
		for row in history.cases[0].timeline:
			deltas.append(float(row.fallen.age)-last);last=float(row.fallen.age)
	for i in range(1440):
		actor.advance(deltas[i] if i<deltas.size() else 1.0/120)
		if i%12==11:
			var pts=actor.body_points();var ix=0;var max_y=-INF
			for j in range(pts.size()):
				var y=pts[j].rotated(actor.rotation).y
				if y>max_y:max_y=y;ix=j
			rows.append({"age":actor.age,"settled":actor.settled,"gap":actor.support_gap(),"rotation":actor.rotation,"root_velocity":actor.angular_velocity,"highest_index":ix,"joints":actor.joints.duplicate(true),"targets":actor._joint_targets(),"target_angle":actor._supported_rest_angle(actor.target_rotation-actor.joints.spine.angle*.65)})
		if actor.settled:break
	check(actor.settled and actor.age<4.0,"Live head-hit pose must settle before the result fallback",{})
	FileAccess.open(report,FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"failures":failures,"fixture":fixture,"rows":rows,"final_age":actor.age,"settled":actor.settled,"timeline":timeline},"\t"))
	actor.queue_free();main._close_battle();main.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
