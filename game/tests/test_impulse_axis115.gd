extends "test_rules115.gd"
## Whole-body momentum is measured before constraints, so support reactions
## cannot conceal a wrong shaft direction or a teleport at contact.
func momentum115(body) -> Vector2:
	var total=body.v*body.mass+body.pelvis_v*body.pelvis_mass
	for i in range(Body115.COUNT):total+=body.vel[i]/body.inv_mass[i]
	return total

func run115() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):report=arg.trim_prefix("--report=")
	if report.is_empty() or FileAccess.file_exists(report) or not "--test-profile" in OS.get_cmdline_user_args():quit(2);return
	items=Catalogue.load_items();var records=[]
	for facing in [-1,1]:
		for elevation in [-.35,0.0,.35]:
			for zone in ["head","body","shield"]:
				var m=prepare115(3,facing,5)
				var d=m.bodies115[1];var a=m.bodies115[0]
				var before_d=momentum115(d.body);var before_a=momentum115(a.body)
				var position_d=d.body.p.duplicate();var position_a=a.body.p.duplicate()
				var contact={"type":"hit","zone":zone,"attacker":0,"defender":1,"speed":480.0,"combat_elevation":elevation,"head_incidence":1.0,"shaft_alignment":cos(elevation),"eccentricity":0.0,"shield_region":"center","lever":0.0,
					"position":Model.head_position(m.fighters[1]) if zone=="head" else Model.body_position(m.fighters[1]) if zone=="body" else Model.shield_position(m.fighters[1])}
				m._apply_contact(contact)
				d._deliver(Model.Mounted115.CONTACT_TIME);a._deliver(Model.Mounted115.CONTACT_TIME)
				var axis=Vector2(-facing*cos(elevation),sin(elevation))
				var expected=axis*float(contact.impulse)*Model.Mounted115.IMPULSE_SCALE
				var d_error=(momentum115(d.body)-before_d-expected).length()
				var a_error=(momentum115(a.body)-before_a+expected*.32).length()
				check(d_error<.08 and a_error<.08,"Received and returned momentum follows the actual shaft: "+str([facing,elevation,zone]))
				check(position_d==d.body.p and position_a==a.body.p,"Force delivery never changes joint positions immediately")
				records.append({"facing":facing,"elevation":elevation,"zone":zone,"defender_error":d_error,"attacker_error":a_error})
	FileAccess.open(report,FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"failures":failures,"cases":records},"\t"))
	quit(0 if failures.is_empty() else 1)
