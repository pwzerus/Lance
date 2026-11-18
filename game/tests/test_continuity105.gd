extends SceneTree
## Boundary derivatives and mirrored/shared anchors, independent of artwork.
const Model=preload("res://scripts/core/joust_match.gd")
const Rider=preload("res://scripts/visual/rider_view.gd")
const Gait=preload("res://scripts/visual/horse_gait.gd")
var failures=[]
var rows=[]
func _initialize()->void:call_deferred("run")
func check(ok:bool, message:String)->void:
	if not ok and message not in failures:failures.append(message);push_error(message)
func run()->void:
	var path=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):path=arg.trim_prefix("--report=")
	if path.is_empty() or FileAccess.file_exists(path) or not "qa_" in root.get_node("GameState").save_path or OS.get_environment("GALUMU_MEMORY_BOUND")=="":quit(2);return
	var mirror_max=0.0;var grip_max=0.0;var shield_max=0.0
	for lean in [-1.0,-.5,0.0,.5,1.0]:
		for aim in [-.68,-.3,-.08,0.0,.3,.58]:
			for compression in [0.0,5.0,12.0]:
				var m=Model.new();var a=m.fighters[0];var b=m.fighters[1]
				for f in m.fighters:
					f.x=0.0;f.lane_y=0.0;f.gait_phase=.6;f.lean=lean;f.aim=aim;f.guard=.43
					f.lance_compression=compression;f.speed=440;f.gait_moving=true;f.motion_drive=.3;f.seat_drive=.2
				mirror_max=maxf(mirror_max,(Model.hand_position(a)*Vector2(-1,1)).distance_to(Model.hand_position(b)))
				for f in m.fighters:
					var hand=Model.hand_position(f);var arm=Rider.arm_pose(f)
					grip_max=maxf(grip_max,hand.distance_to(arm.right.hand))
					var shield_frame=Rider.shield_pose_transform(arm,f)
					for point in [Vector2.ZERO,Vector2(-10,4),Vector2(18,-40)]:
						shield_max=maxf(shield_max,(shield_frame*point).distance_to(Model.shield_transform(f)*point))
					var ray=(Model.tip_position(f)-hand).normalized()
					check(ray.distance_to(Vector2(cos(aim)*f.direction,sin(aim)))<.00001,"Visible grip preserves the actual lance ray")
	check(mirror_max<.001,"Mirrored grips are identical in both lanes")
	check(grip_max<.002,"Displayed hand remains on the swept hit anchor")
	check(shield_max<.002,"Mounted shield still exactly follows its rule surface")
	rows.append({"kind":"grip","mirror_error":mirror_max,"visual_anchor_error":grip_max,"mounted_shield_error":shield_max,"poses":180})
	for speed in [120.0,220.0,440.0]:
		for unrest in [.25,1.0]:
			for boundary in [0.0,PI,TAU]:
				var f=Model.new().fighters[0];f.speed=speed;f.gait_moving=true;f.unsteady=unrest
				var e=.0001;var heights=[]
				for offset in [-e,0.0,e]:
					f.gait_phase=boundary-.4+offset;heights.append(Model.seat_lift(f))
				var omega=TAU*Gait.frequency(speed)
				var before=(float(heights[1])-float(heights[0]))/e*omega
				var after=(float(heights[2])-float(heights[1]))/e*omega
				var jump=absf(after-before)
				check(jump<2.0,"Seat contact has no abrupt velocity reversal at "+str([speed,unrest,boundary]))
				rows.append({"kind":"seat_boundary","speed":speed,"unrest":unrest,"phase":boundary,"before_velocity":before,"after_velocity":after,"velocity_jump":jump})
	var steady=Model.new().fighters[0];steady.speed=440;steady.gait_moving=true;steady.unsteady=0.0
	for i in range(120):
		steady.gait_phase=i*TAU/120.0;check(Model.seat_lift(steady)==0,"Steady riders gain no artificial seat bounce")
	# A rein tug must build and release rather than change neck velocity at
	# the half-wave boundary. Compare only the added unrest channel.
	for speed in [220.0,440.0]:
		for unrest in [.25,1.0]:
			var base=Gait.body(.9,speed,true)
			for clock_value in [0.0,PI/5.1,TAU/5.1]:
				var e=.0001;var turns=[]
				for offset in [-e,0.0,e]:
					var calm=Gait.visual(base,.9,speed,true,0,0,clock_value+offset,0)
					var tug=Gait.visual(base,.9,speed,true,0,0,clock_value+offset,unrest)
					turns.append(float(tug.neck)-float(calm.neck))
				var jump=absf((turns[2]-2*turns[1]+turns[0])/e)
				check(jump<.03,"Rein tug neck velocity stays continuous: "+str([speed,unrest,clock_value]))
				rows.append({"kind":"neck_boundary","speed":speed,"unrest":unrest,"clock":clock_value,"velocity_jump":jump})
			var calm=Gait.visual(base,.9,speed,true,0,0,PI/10.2,0)
			var peak=Gait.visual(base,.9,speed,true,0,0,PI/10.2,unrest)
			check(absf((peak.neck-calm.neck)+.07*unrest)<.0001,"Smoothing preserves the authored rein-tug peak")
	FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"failures":failures,"rows":rows,"scope":"Shared hand/CCD anchors and mirror symmetry; one-sided seat velocity at saddle contact. Numeric continuity is not human motion approval."},"\t"))
	print("CONTINUITY105 ",failures);quit(0 if failures.is_empty() else 1)
