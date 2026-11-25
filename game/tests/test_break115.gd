extends SceneTree
## Breaking a shield changes its mass and outline, not its grip or pose.
const Model=preload("res://scripts/core/joust_match.gd")
const Rig=preload("res://scripts/core/rider_rig115.gd")
const Body=preload("res://scripts/visual/rider_body114.gd")
const Catalogue=preload("res://scripts/core/catalogue.gd")
var failures=[]
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var path=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):path=arg.trim_prefix("--report=")
	if path.is_empty() or FileAccess.file_exists(path) or not "--test-profile" in OS.get_cmdline_user_args():quit(2);return
	var rows=[];var items=Catalogue.load_items()
	for facing in [1,-1]:
		for tier in [0,5]:
			var stats=Catalogue.stats(items,{"helmet":"eng_helmet_"+str(tier),"armor":"eng_armor_"+str(tier),"shield":"eng_shield_"+str(tier)})
			var m=Model.new("arena",stats,stats);var f:Dictionary=m.fighters[0]
			f.x=0.0;f.lane_y=0.0;f.direction=facing;f.speed=480.0;f.gait_moving=true;f.guard=.4
			m._ensure_body115(0)
			for tick in range(120):
				f.x+=480.0*facing/120.0;f.gait_phase+=TAU*Model.Gait.frequency(480.0)/120.0;m._advance_body115(0,1.0/120.0)
			var rider=m.bodies115[0];var body=rider.body
			var old_hand=body.p[Body.HAND_L];var old_turn=body.shield_theta115;var old_velocity=body.vel[Body.HAND_L];var old_mass=1.0/body.inv_mass[Body.HAND_L]
			f.shield=0.0;rider._break_shield115(f)
			var hand_jump=old_hand.distance_to(body.p[Body.HAND_L]);var angle_jump=absf(wrapf(body.shield_theta115-old_turn,-PI,PI));var velocity_jump=old_velocity.distance_to(body.vel[Body.HAND_L])
			var raw=Rig.body_pose(body,rider.captured)
			var outline=Rig.ShieldArt.remnant_polygon(stats);var error=0.0
			for i in range(outline.size()):
				var collision=body._extension_point(body.extensions.shield,false,body.extensions.shield.offsets[i])
				var expected=Transform2D(raw.shield_transform)*outline[i]
				error=maxf(error,collision.distance_to(expected))
			if error>.05:failures.append("Remnant collision/render mismatch: "+str([facing,tier,error]))
			if hand_jump>.001 or angle_jump>.0001 or velocity_jump>.001:failures.append("Break teleports grip or momentum")
			var removed=old_mass-1.0/body.inv_mass[Body.HAND_L]
			if absf(removed-maxf(0.0,float(stats.get("shield_kg",3.0))-1.0))>.0001:failures.append("Broken mass not removed")
			rows.append({"facing":facing,"tier":tier,"outline_error":error,"hand_jump":hand_jump,"angle_jump":angle_jump,"velocity_jump":velocity_jump,"removed_mass":removed})
	FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"failures":failures,"cases":rows},"\t"))
	print("BREAK115 ",failures);quit(0 if failures.is_empty() else 1)
