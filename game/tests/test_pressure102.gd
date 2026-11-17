extends "test_rules098.gd"
const Rider102=preload("res://scripts/visual/rider_view.gd")
const Status102=preload("res://scripts/ui/combat_status098.gd")
const Sound102=preload("res://scripts/visual/sound_bank.gd")

func _initialize() -> void:call_deferred("run")

func run() -> void:
	var path=""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--report="):path=a.trim_prefix("--report=")
	if path.is_empty() or FileAccess.file_exists(path) or not "qa_" in root.get_node("GameState").save_path or OS.get_environment("GALUMU_MEMORY_BOUND")=="":quit(2);return
	items=Catalogue.load_items();var results=[];var bank=Sound102.new()
	for value in [NAN,INF,"invalid",null]:
		check(is_finite(Model.Feedback.shield_loading({"speed":value,"impulse":value,"shield_transfer":value})),"Invalid optional feedback number propagates")
	for side in [-1,1]:
		for eccentricity in [0.0,1.0]:
			var m=prepare(3,"eng_shield_5")
			var f=m.fighters[1];f.direction=side
			var start=Model.head_position(f);var shield_start=Model.shield_position(f)
			var e=contact(m,"shield",1.0,eccentricity,0.0,1.0)
			check(Model.head_position(f).distance_to(start)<.001 and Model.shield_position(f).distance_to(shield_start)<.001,"Contact teleports pose")
			var peak=0.0;var twist=0.0;var compression=0.0;var arm_error=0.0;var step=0.0
			for tick in range(480):
				var before=float(f.reaction_angle)
				Model.advance_reaction(f,1.0/120)
				step=maxf(step,absf(float(f.reaction_angle)-before))
				peak=maxf(peak,absf(float(f.reaction_angle)));twist=maxf(twist,absf(float(f.shield_twist)))
				compression=maxf(compression,float(f.shield_compression))
				var pose=Rider102.arm_pose(f)
				for arm_side in ["left","right"]:
					var arm=pose[arm_side]
					arm_error=maxf(arm_error,absf(arm.shoulder.distance_to(arm.elbow)-Rider102.ARM_UPPER))
					arm_error=maxf(arm_error,absf(arm.hand.distance_to(arm.elbow)-Rider102.ARM_LOWER))
			check(arm_error<.05 and step<.1,"Connected continuous recoil")
			check(absf(float(f.reaction_angle))<.001 and absf(float(f.shield_twist))<.001,"Recoil settles")
			if eccentricity==0:check(peak>.30,"Shield center lacks torso follow through")
			else:check(twist>.20 and peak<.22,"Rim needs rotation, less whole-body kick")
			var cue=bank.impact_cue(e,f.stats)
			check(str(cue.kind)==("solid" if eccentricity==0 else "glance"),"Wrong impact sound family")
			check((Status102.contact_text(e).contains("重击") or Status102.contact_text(e).contains("失衡")) if eccentricity==0 else Status102.contact_text(e).contains("滑开"),"Pressure/sliding label mismatch")
			results.append({"side":side,"eccentricity":eccentricity,"peak_angle":peak,"peak_twist":twist,"peak_compression":compression,"arm_error":arm_error,"cue":cue,"event":e})
	bank.free()
	FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"failures":failures,"rows":results},"\t"))
	print("PRESSURE102 ",failures);quit(0 if failures.is_empty() else 1)
