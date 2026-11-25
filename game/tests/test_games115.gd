extends "test_games114.gd"
## Retain an exact deterministic fall state from a full Battle for diagnosis.
var body_dump_count115=0
func configure_game(index: int, battle) -> void:
	# Stable contact/AI random streams make a new complete match reproducible.
	battle.match_model.rng.seed=115000+index
	battle.ai_rng.seed=115431+index

func fall_shape(actor) -> Dictionary:
	var result=super.fall_shape(actor)
	var body=actor.body
	var values={}
	for property in body.get_property_list():
		if int(property.usage)&PROPERTY_USAGE_SCRIPT_VARIABLE:
			var value=body.get(property.name)
			if typeof(value)!=TYPE_OBJECT:values[property.name]=value
	var state={"body":values,"fighter":actor.fighter,"captured":actor.capture115,"snapshot":actor.render_current115,
		"initial_pose":actor.initial_pose,"initial_legs":actor.initial_legs,"age":actor.age,"ground_age":actor.ground_age,
		"position":actor.position,"rotation":actor.rotation,"initial_position":actor.initial_position,
		"zone":actor.zone,"direction":actor.direction,"strength":actor.strength,"conscious":actor.conscious114,
		"body_grounded":actor.grounded,"body_settled":actor.settled,"surface_correction":actor.surface_correction115}
	FileAccess.open(folder+"/body%02d.var" % body_dump_count115,FileAccess.WRITE).store_var(state)
	body_dump_count115+=1
	result["body_snapshot"]=body_dump_count115-1
	result["spine"]=body.spine_flex()
	result["pelvis_angle"]=body.pelvis_theta
	result["surface_correction"]=actor.surface_correction115
	result["hip_flex"]=[body.flex("near_hip"),body.flex("far_hip")]
	result["knee_flex"]=[body.flex("near_knee"),body.flex("far_knee")]
	result["contacts"]=body.contacts.keys()
	result["muscle_tone"]=body.tone
	result["shared_body"]=actor.shared115
	result["unsupported_leg"]=actor._unsupported_leg115()
	# The original 114 harness only required an image, even if the body was
	# still hanging on its joint stops. This is an acceptance failure, not a
	# successful rest capture. Preserve the exact state for deterministic QA.
	if actor._unsupported_leg115():failures.append("Fall %d has an unsupported raised leg" % (body_dump_count115-1))
	if not actor.settled and actor.age>=4.5:failures.append("Fall %d did not settle within 4.5 game seconds" % (body_dump_count115-1))
	return result
