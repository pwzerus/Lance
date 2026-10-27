extends SceneTree
const Model = preload("res://scripts/core/joust_match.gd")
const Gait = preload("res://scripts/visual/horse_gait.gd")
const Catalogue = preload("res://scripts/core/catalogue.gd")
const Rider = preload("res://scripts/visual/rider_view.gd")
var failures: Array[String] = []
var checks = 0
var max_lower = 0.0
var max_shield_reach = 0.0

func check(value: bool, message: String) -> void:
	checks += 1
	if not value and message not in failures:
		failures.append(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var state = root.get_node("GameState")
	check(state.save_path.contains("qa_"),"Must isolate player save")
	if not state.save_path.contains("qa_"):
		quit(1)
		return
	var items = Catalogue.load_items()
	var ids: Array = []
	var horses: Array = []
	for item in items:
		check(item.id not in ids,"Duplicate equipment ID")
		ids.append(item.id)
		check(item.slot in Catalogue.SLOT_NAMES,"Unsupported equipment slot")
		if item.slot=="horse":
			horses.append(item)
	check(horses.size()==10,"Exactly ten shared horses")
	for region in Catalogue.REGIONS:
		for quality in range(6):
			for slot in ["lance","armor","helmet","shield"]:
				var count = 0
				for item in items:
					if item.region==region and item.slot==slot and int(item.get("quality",-1))==quality:
						count += 1
				check(count==(3 if slot=="lance" else 1),"Every regional quality must contain requested equipment")
	var fastest = 0.0
	var steadiest = 0.0
	for horse in horses:
		fastest = maxf(fastest,float(horse.stats.speed))
		steadiest = maxf(steadiest,float(horse.stats.stability))
	for horse in horses:
		check(not(is_equal_approx(horse.stats.speed,fastest) and is_equal_approx(horse.stats.stability,steadiest)),"No fastest-and-steadiest horse")
		for speed in [210.0*horse.stats.speed,480.0*horse.stats.speed,515.0*horse.stats.speed]:
			for sample in range(120):
				for index in range(4):
					var leg = Gait.leg(index,TAU*sample/120.0,speed,true,horse.stats.stability)
					check(not leg.contact or absf(leg.foot.y-Gait.GROUND)<.01,"Supporting hooves stay on ground for every horse")
					check(leg.foot.y<=Gait.GROUND+.01,"Hoof never penetrates ground")
					max_lower = maxf(max_lower,leg.knee.distance_to(leg.ankle))
					check(leg.knee.distance_to(leg.ankle)<=Gait.LOWER+.1,"Every horse pose stays within lower bone reach")
	var model = Model.new()
	for direction in [-1,1]:
		var f = model.fighters[0]
		f.x = 0
		f.direction = direction
		f.gait_moving = true
		f.speed = 480
		for lean in [-1.0,-.5,0.0,.5,1.0]:
			f.lean = lean
			for guard in [0.0,.5,1.0]:
				f.guard = guard
				for sample in range(16):
					f.gait_phase = TAU*sample/16.0
					var pivot = Model.HIP+Model.saddle_offset(f)
					var hand = (Model.hand_position(f)-Vector2(f.x,f.lane_y))*Vector2(direction,1)
					var shoulder = pivot+Vector2(26,-65).rotated(Model.pose_angle(f))
					var elbow = Rider.arm_elbow(shoulder,hand,38,42)
					check(absf(shoulder.distance_to(elbow)-38)<.01 and absf(elbow.distance_to(hand)-42)<.05,"Lance arm IK must connect at all poses")
					var shield_hand = ((Model.shield_position(f)-Vector2(f.x,f.lane_y))*Vector2(direction,1)-pivot).rotated(-Model.pose_angle(f))+Vector2(-10,9)
					var shield_elbow = Rider.arm_elbow(Vector2(-28,-64),shield_hand,47,53)
					max_shield_reach = maxf(max_shield_reach,Vector2(-28,-64).distance_to(shield_hand))
					check(absf(shield_elbow.distance_to(shield_hand)-53)<.05,"Shield arm must remain reachable")
	# Old save IDs survive; migration adds only the missing starter shield.
	var legacy = state.default_profile()
	legacy.equipped.erase("shield")
	legacy.owned.erase("shield_basic")
	legacy.owned.append("horse_e4")
	legacy.equipped.horse = "horse_e4"
	var migrated = state.sanitize(legacy)
	check(migrated.equipped.horse=="horse_e4" and migrated.equipped.shield=="shield_basic","Legacy collection and new shield slot migrate")
	state.profile = migrated
	state.profile.coins = 999999
	state.profile.renown = 100
	for id in ["de_lance_long_5","fr_armor_4","it_helmet_3","eng_shield_5","horse_steady"]:
		check(state.purchase(id)=="已收入军械库","Expanded equipment can be bought")
		check(state.equip(id),"Expanded equipment can be equipped")
	state.load_profile()
	check(state.profile.equipped.shield=="eng_shield_5" and state.profile.equipped.horse=="horse_steady","New equipment survives reload")
	var stats = state.player_stats()
	var equipped_model = Model.new("arena",stats)
	check(equipped_model.fighters[0].shield==116,"Equipped shield durability reaches combat")
	print("RIG_EQUIPMENT_V042 "+JSON.stringify({"checks":checks,"failures":failures,"passed":failures.is_empty(),"items":items.size(),"horses":horses.size(),"max_lower":max_lower,"max_shield_reach":max_shield_reach}))
	quit(0 if failures.is_empty() else 1)
