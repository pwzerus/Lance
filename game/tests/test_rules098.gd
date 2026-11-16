extends SceneTree
## Fixed-contact contracts and complete loadout invariants, not player feel.
const Model = preload("res://scripts/core/joust_match.gd")
const Catalogue = preload("res://scripts/core/catalogue.gd")
const Geometry = preload("res://scripts/core/shield_geometry.gd")
var report = ""
var items: Array = []
var rows: Array = []
var failures: Array = []

func check(ok: bool, label: String) -> void:
	if not ok: failures.append(label)

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): report=arg.trim_prefix("--report=")
	if report.is_empty() or FileAccess.file_exists(report) or OS.get_environment("GALUMU_MEMORY_BOUND")=="":
		quit(2)
		return
	items=Catalogue.load_items()
	for tier in [0,3,5]:
		var full=hit("head",tier,"eng_shield_0")
		check(float(full.damage)>=70 and float(full.damage)<=85.01,"full head damage tier "+str(tier))
		var half=hit("head",tier,"eng_shield_0",.5)
		check(not half.ko,"half head stays mounted "+str(tier))
		check(float(half.damage)/float(full.damage)>.35 and float(half.damage)/float(full.damage)<.45,"half head damage ~40%")
		var glance=hit("head",tier,"eng_shield_0",1,0,0,.4)
		check(float(glance.damage)>=10 and float(glance.damage)<=25 and not glance.ko,"head glance survives")
		var body=hit("body",tier,"eng_shield_0")
		check(float(body.damage)>=35 and float(body.damage)<=50,"body damage tier "+str(tier))
	var center=hit("shield",3,"eng_shield_0")
	check(float(center.damage)>=6 and float(center.damage)<=10.01,"light center damage")
	check(float(center.impulse_ratio)>=1.02 and float(center.impulse_ratio)<=1.20,"light center unhorse ratio")
	check(100-float(center.balance_left)>=80 and 100-float(center.balance_left)<=89,"light center balance")
	var heavy=hit("shield",3,"eng_shield_5")
	check(absf(float(heavy.damage)-3)<.01,"heavy center damage")
	check(float(heavy.impulse_ratio)>=.89 and float(heavy.impulse_ratio)<=1.01,"heavy center ratio")
	check(100-float(heavy.balance_left)>=65 and 100-float(heavy.balance_left)<=75,"heavy center balance")
	var face=hit("shield",3,"eng_shield_0",1,.65)
	check(float(face.damage)>=2 and float(face.damage)<=6,"off-center damage")
	check(float(face.impulse_ratio)>=.6 and float(face.impulse_ratio)<=.8,"off-center ratio")
	check(100-float(face.balance_left)>=50 and 100-float(face.balance_left)<=60,"off-center balance")
	for angled in [false,true]:
		var edge=hit("shield",3,"eng_shield_0",1,0 if angled else 1,deg_to_rad(40) if angled else 0)
		check(float(edge.damage)<=2 and float(edge.impulse_ratio)>=.29 and float(edge.impulse_ratio)<=.4,"edge/angle transfer")
		check(not edge.ko and int(edge.points)==0,"edge/angle survives without points")
		check(100-float(edge.balance_left)>=24 and 100-float(edge.balance_left)<=35,"edge/angle balance")
	sequence("eng_shield_5",0,true)
	sequence("eng_shield_5",1,false)
	var slip=prepare(3,"eng_shield_0")
	var old_aim=float(slip.fighters[0].aim)
	var old_guard=float(slip.fighters[1].guard)
	contact(slip,"shield",1,1,0,1)
	check(slip.fighters[0].aim==old_aim and slip.fighters[1].guard==old_guard,"sliding contact must not teleport lance or shield")
	check(slip.fighters[0].lance_stability<1.0 and absf(slip.fighters[0].aim_rate)>0,"slide must deflect lance via velocity")
	check(slip.fighters[1].guard_stun>0,"slide must briefly slow the shield arm")
	for zone in ["body","flank","shield"]:
		var half=hit(zone,3,"eng_shield_0",.5)
		check(not half.ko,"half speed cannot unhorse: "+zone)
	var slow_mount=prepare(3,"eng_shield_5")
	slow_mount.fighters[1].speed=100.0
	var slow_event=contact(slow_mount,"shield",1,0,0,1)
	check(slow_event.ko,"same heavy shield hit can unhorse a near-stationary mount")
	for posture in ["lean","unsteady"]:
		var unsettled=prepare(3,"eng_shield_5")
		unsettled.fighters[1][posture]=-1.0 if posture=="lean" else .45
		# Keep the same square shield impact. Lean also tilts the shield;
		# without counter-rotation this would test a slide, not lost bracing.
		var counter_angle=-Model.pose_angle(unsettled.fighters[1])
		check(contact(unsettled,"shield",1,0,counter_angle,1).ko,"heavy shield does not protect an unsettled seat: "+posture)
	for mode in ["arena","war"]:
		var twice=prepare(5,"eng_shield_5")
		twice.mode=mode
		contact(twice,"head",1,0,0,1)
		twice.fighters[0].broken=false
		contact(twice,"head",1,0,0,1)
		check(twice.fighters[1].ko,"second full head hit ends fight: "+mode)
		check(bool(twice.fighters[1].dead)==(mode=="war"),"arena cannot kill, war can")
	for region in ["eng","fr","de","it"]:
		for q in range(6):
			var s=kit(3,region+"_shield_"+str(q))
			var desired=[1.0,.8,1.08,.86,1.15,.92][q]
			check(absf(float(s.shield_handling)*Model.Condition.agility(s)-desired)<.0001,"shield handling "+region+str(q))
			check(float(s.shield_protection.absorb)<=.15,"absorption cap")
			var scale=float(s.shield_scale)
			for direction in [-1,1]:
				var local=Geometry.polygon(str(s.shield_shape),scale)
				var world=Geometry.world_polygon(Vector2(100,100),.3,direction,str(s.shield_shape),scale)
				for i in range(local.size()):
					check(world[i].distance_to(Vector2(100,100)+local[i].rotated(.3)*Vector2(direction,1))<.001,"scaled mirrored outline")
	var previous=1.0
	for i in range(1001):
		var transfer=Model.shield_transfer(float(i)/1000,0,0)
		check(float(transfer.factor)<=previous+.000001 and previous-float(transfer.factor)<.004,"continuous positional transfer")
		previous=transfer.factor
	var file=FileAccess.open(report,FileAccess.WRITE)
	file.store_string(JSON.stringify({"rows":rows,"failures":failures,"passed":failures.is_empty()},"  "))
	file.close()
	print("RULES098 "+JSON.stringify({"failures":failures,"cases":rows.size()}))
	quit(0 if failures.is_empty() else 1)

func kit(tier: int, shield: String) -> Dictionary:
	return Catalogue.stats(items,{"armor":"eng_armor_"+str(tier),"helmet":"eng_helmet_"+str(tier),"shield":shield,"lance":"lance_ash","horse":"horse_bay","crest":"crest_bend"})

func prepare(tier: int, shield: String, pace: float=1) -> RefCounted:
	var stats=kit(tier,shield)
	var model=Model.new("arena",stats,stats,981)
	model.phase="charge"
	for f in model.fighters:
		f.speed=Model.GALLOP_SPEED*pace
		f.aim=0.0
		f.lean=0.0
		f.lance_stability=1.0
		f.stats.power=1.0
		f.stats.stability=1.0
	model.drain_events()
	return model

func contact(model,zone: String,pace: float,eccentricity: float,angle: float,incidence: float) -> Dictionary:
	model.fighters[1].shield_twist=angle
	var event={"type":"hit","zone":zone,"attacker":0,"defender":1,"speed":960*pace,"position":Model.shield_position(model.fighters[1]),
		"head_incidence":incidence,"combat_elevation":0.0,"shaft_alignment":1.0,"eccentricity":eccentricity,
		"shield_region":"rim" if eccentricity>.72 else ("face" if eccentricity>.38 else "center"),"lever":eccentricity}
	model._apply_contact(event)
	return event

func hit(zone: String,tier: int,shield: String,pace: float=1,eccentricity: float=0,angle: float=0,incidence: float=1) -> Dictionary:
	var model=prepare(tier,shield,pace)
	var e=contact(model,zone,pace,eccentricity,angle,incidence)
	var row={"zone":zone,"tier":tier,"shield":shield,"pace":pace,"eccentricity":eccentricity,"angle":angle,"incidence":incidence}
	for key in ["damage","impulse","impulse_ratio","ko_threshold","balance_left","ko","points","glanced"]: row[key]=e[key]
	rows.append(row)
	return e

func sequence(shield: String,offset: float,expect_ko: bool) -> void:
	var m=prepare(3,shield)
	contact(m,"shield",1,offset,0,1)
	var first_ko=bool(m.fighters[1].ko)
	m.fighters[1].balance=minf(100,float(m.fighters[1].balance)+8)
	m.fighters[0].broken=false
	m.fighters[0].lance_stability=1.0
	contact(m,"shield",1,offset,0,1)
	check(not first_ko,"heavy first strike survives "+str(offset))
	check(bool(m.fighters[1].ko)==expect_ko,"heavy two contacts "+str(offset))
