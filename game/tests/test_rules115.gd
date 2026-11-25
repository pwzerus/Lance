extends "test_rules098.gd"
## Injury still resolves at contact; physical support is evaluated over time.
## Synthetic contacts use the actual body/helmet/shield anchors, not a single
## shield-centre point reused for every anatomical region.
const Body115=preload("res://scripts/visual/rider_body114.gd")
const Report115=preload("res://scripts/ui/combat_report.gd")

func _initialize() -> void:call_deferred("run115")

func prepare115(tier: int, facing: int, shield_tier: int = -1):
	var stats=kit(tier,"eng_shield_"+str(tier if shield_tier<0 else shield_tier))
	var model=Model.new("arena",stats,stats,11517)
	model.phase="charge";model.drain_events()
	for i in range(2):
		var f:Dictionary=model.fighters[i]
		f.x=0.0 if i==1 else -4000.0*facing
		f.lane_y=0.0;f.direction=facing if i==1 else -facing
		f.speed=380.0;f.gait_moving=true;f.gait_phase=.5;f.aim=-.08;f.guard=.5;f.acted=true
		model._ensure_body115(i)
	for tick in range(120):advance115(model,1.0/120.0)
	return model

func advance115(model,dt: float) -> void:
	for index in range(2):
		var f:Dictionary=model.fighters[index]
		f.x+=float(f.speed)*int(f.direction)*dt
		f.gait_phase+=TAU*Model.Gait.frequency(float(f.speed))*dt
		Model.advance_reaction(f,dt)
		model._advance_body115(index,dt)
	model._consume_seat_exits113()

func physical_contact115(model,zone: String,pace: float=1.0,edge: float=0.0,incidence: float=1.0) -> Dictionary:
	var f:Dictionary=model.fighters[1]
	var point=Model.head_position(f) if zone=="head" else Model.body_position(f) if zone=="body" else Model.flank_position(f) if zone=="flank" else Model.shield_transform(f)*Vector2(0,-42*edge)
	var contact115={"type":"hit","zone":zone,"attacker":0,"defender":1,"speed":960.0*pace,"position":point,
		"head_incidence":incidence,"combat_elevation":0.0,"shaft_alignment":1.0,"eccentricity":edge,
		"shield_region":"rim" if edge>.72 else "center","lever":edge}
	model._apply_contact(contact115)
	return contact115

func run115() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):report=arg.trim_prefix("--report=")
	if report.is_empty() or FileAccess.file_exists(report) or not "--test-profile" in OS.get_cmdline_user_args() or OS.get_environment("GALUMU_MEMORY_BOUND")=="":quit(2);return
	items=Catalogue.load_items()
	var records=[]
	for facing in [1,-1]:
		for tier in [0,5]:
			for zone in ["head","body","flank","shield"]:
				for pace in [.5,1.0]:
					var m=prepare115(tier,facing)
					var f:Dictionary=m.fighters[1]
					var before=Model.rider_origin(f)
					var event=physical_contact115(m,zone,pace)
					check(not f.unseated,"Contact has no threshold teleport: "+str([facing,tier,zone,pace]))
					check(Model.rider_origin(f).distance_to(before)<.001,"Impulse does not jump the visible body")
					var detached=-1.0;var unseat=[];var peak=0.0
					for tick in range(360):
						advance115(m,1.0/120.0)
						peak=maxf(peak,absf(float(f.seat_offset)))
						for e in m.drain_events():
							if e.type=="unseat" and e.defender==1:unseat.append(e)
						if f.unseated and detached<0.0:detached=(tick+1)/120.0
					check(not f.dead,"Tournament contact remains nonfatal")
					check(unseat.size()==(1 if f.unseated else 0),"One event per real support loss")
					if not unseat.is_empty():check(str(unseat[0].zone)==zone and int(unseat[0].attacker)==0,"Delayed support loss retains its anatomical cause")
					records.append({"facing":facing,"tier":tier,"zone":zone,"pace":pace,"damage":event.damage,"impulse":event.impulse,"hp":f.hp,"unconscious":f.unconscious,"detached":detached,"peak_offset":peak,"cause":unseat})
	# Both directions: physical hit and smaller weapon recoil in one exchange.
	for facing in [1,-1]:
		var m=prepare115(0,facing);var rider=m.bodies115[1];var f:Dictionary=m.fighters[1]
		rider.queue_hit({"zone":"head","position":Model.head_position(f),"direction":-facing,"impulse":95.0,"attacker":0})
		rider.queue_hit({"zone":"lance","position":Model.hand_position(f),"direction":-facing,"impulse":8.0,"source":"weapon_reaction"})
		check(rider.last_hit.zone=="head","Own recoil does not overwrite larger received blow")
		var events115=[]
		for tick in range(360):
			advance115(m,1.0/120.0)
			for e in m.drain_events():
				if e.type=="unseat" and e.defender==1:events115.append(e)
		check(events115.size()==1 and events115[0].zone=="head","Large head impulse releases support once")
		var fresh=prepare115(0,facing);var quiet=fresh.bodies115[1]
		quiet.queue_hit({"zone":"body","position":Model.body_position(fresh.fighters[1]),"direction":-facing,"impulse":3.0,"attacker":0})
		for tick in range(600):advance115(fresh,1.0/120.0)
		check(not quiet.detached and not quiet.impact_unrecovered,"A recovered seat clears historical impact attribution")
	# A late physical event must not replace the scored contact in the report.
	var hit115={"type":"hit","zone":"body","attacker":0,"defender":1,"damage":32.0,"points":3,"attaint":true,"balance_left":44.0}
	var loss115={"type":"unseat","zone":"body","attacker":0,"defender":1,"damage":0.0,"points":0,"ko":true,"unseated":true,"ko_reason":"impact"}
	var text115=Report115.summarize([hit115,loss115],"arena",true)
	check(text115.contains("+3 分"),"Delayed unseat preserves the actual scored hit")
	var recoil115=loss115.duplicate();recoil115.zone="lance";recoil115.attacker=-1
	check(Report115.summarize([recoil115]).contains("反冲"),"Weapon recoil loss has a distinct cause")
	FileAccess.open(report,FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"failures":failures,"cases":records,"scope":"Direct resolved damage plus actual physical advance; no probability, sweep or player-difficulty claim."},"\t"))
	print("RULES115 ",failures);quit(0 if failures.is_empty() else 1)
