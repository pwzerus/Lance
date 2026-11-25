extends SceneTree
## PHYS-114: real matches through Main (random seeds, player on Battle
## autoplay, real AI opponent), recording every fall: mid-air and resting
## captures, settle time, raised legs/hands and trunk support, frame times.
## Engine-injected control on an isolated desktop; no OS input, not a human
## playtest, autoplay is not a player.
const Catalogue = preload("res://scripts/core/catalogue.gd")
var folder = ""
var first = 0
var count = 5
# --gear=N: renown N and the dearest unlocked item in every slot (QA profile
# only), so the player can survive and unhorse; starter gear lost every game
# on injury with no fall at all (phys114-games01..03).
var gear_renown = 0
var main
var games: Array = []
var failures: Array = []

func _initialize() -> void:
	call_deferred("run")

func capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder+"/"+name+".png")

func world(actor, local: Vector2) -> Vector2:
	return actor.position+local.rotated(actor.rotation)

func fall_shape(actor) -> Dictionary:
	var facing = int(actor.fighter.direction)
	var mirror = Vector2(facing,1)
	var raised = -INF
	for side in ["near","far"]:
		var leg: Dictionary = actor.visual.detached_legs[side]
		var hip = world(actor,leg.hip*mirror)
		raised = maxf(raised,maxf(hip.y-world(actor,leg.knee*mirror).y,hip.y-world(actor,leg.foot*mirror).y))
	var top = INF
	for point in actor.TORSO_OUTLINE114:
		top = minf(top,world(actor,actor.initial_pose.torso_transform*point).y)
	var hand = -INF
	for side in ["left","right"]:
		hand = maxf(hand,top-world(actor,actor.visual.detached_pose[side].hand).y)
	return {"legs_above_hip":raised,"hand_above_trunk":hand,"support_gap":actor.support_gap(),
		"trunk_degrees":rad_to_deg(wrapf(actor.rotation+float(actor.initial_pose.torso_transform.get_rotation()),-PI,PI))}

func configure_game(_index: int, _battle) -> void:
	pass

func inspect_game(_index: int, _battle, _row: Dictionary) -> void:
	pass

func play(index: int) -> void:
	var mode = "arena" if index%2==0 else "war"
	var state = root.get_node("GameState")
	state.profile.renown = gear_renown if gear_renown>0 else (0 if index<5 else 40)
	main._start_match(mode,false)
	var battle = main.battle
	# An isolated desktop has no real focus; do not let a focus event pause.
	if root.focus_exited.is_connected(battle._on_focus_lost): root.focus_exited.disconnect(battle._on_focus_lost)
	battle.autoplay = true
	configure_game(index,battle)
	var row = {"game":index,"mode":mode,"renown":state.profile.renown,"falls":[],"result":{},"max_frame_ms":0.0,"frames_over_33ms":0,"frames":0,"captures":0}
	var result_seen = false
	battle.finished.connect(func(result): row.result = {"winner":result.get("winner",-2),"reason":str(result.get("reason","")),"score":result.get("score",[])})
	var tracked = {}
	var started = Time.get_ticks_msec()
	var last = Time.get_ticks_usec()
	var finished_at = -1
	while Time.get_ticks_msec()-started<150000:
		await process_frame
		var now = Time.get_ticks_usec()
		var frame_ms = (now-last)/1000.0
		last = now
		row.frames += 1
		row.max_frame_ms = maxf(row.max_frame_ms,frame_ms)
		if frame_ms>33.0: row.frames_over_33ms += 1
		if not is_instance_valid(battle): break
		for actor in battle.effects.bodies:
			if not is_instance_valid(actor): continue
			var id = actor.get_instance_id()
			if not tracked.has(id):
				tracked[id] = {"rider":"player" if int(actor.fighter.direction)==int(battle.match_model.fighters[0].direction) else "opponent",
					"zone":actor.zone,"strength":actor.strength,"toppled":actor.toppled,"conscious":actor.conscious114,"air_shot":false,"rest_shot":false,"settled_age":-1.0}
				row.falls.append(tracked[id])
			var fall: Dictionary = tracked[id]
			if not fall.air_shot and actor.age>=.45:
				fall.air_shot = true
				await capture("g%02d_fall%d_air" % [index,row.falls.find(fall)])
				# The PNG save is the harness, not the game: do not count it.
				last = Time.get_ticks_usec()
				row.captures += 1
			if actor.settled and float(fall.settled_age)<0.0:
				fall.settled_age = actor.age
			if not fall.rest_shot and (actor.settled or actor.age>=4.5):
				fall.rest_shot = true
				fall.merge(fall_shape(actor))
				fall.age_at_rest_shot = actor.age
				await capture("g%02d_fall%d_rest" % [index,row.falls.find(fall)])
				last = Time.get_ticks_usec()
				row.captures += 1
		if battle.is_finished and finished_at<0:
			finished_at = Time.get_ticks_msec()
		if finished_at>0 and Time.get_ticks_msec()-finished_at>5000:
			result_seen = true
			break
	if not result_seen: failures.append("Game %d did not finish within 150 s" % index)
	await capture("g%02d_end" % index)
	row.wall_seconds = (Time.get_ticks_msec()-started)/1000.0
	row.pass_number = battle.match_model.pass_number if is_instance_valid(battle) else -1
	inspect_game(index,battle,row)
	for fall in row.falls:
		if not fall.rest_shot: failures.append("Game %d fall without a resting capture" % index)
	games.append(row)
	FileAccess.open(folder+"/report.json",FileAccess.WRITE).store_string(JSON.stringify({"games":games,"failures":failures},"\t"))
	print("GAMES114 game=",index," mode=",mode," falls=",row.falls.size()," result=",row.result," wall=",row.wall_seconds)

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--folder="): folder = arg.trim_prefix("--folder=")
		if arg.begins_with("--first="): first = int(arg.trim_prefix("--first="))
		if arg.begins_with("--count="): count = int(arg.trim_prefix("--count="))
		if arg.begins_with("--gear="): gear_renown = int(arg.trim_prefix("--gear="))
	var state = root.get_node("GameState")
	if folder.is_empty() or DirAccess.dir_exists_absolute(folder) or not state.save_path.contains("qa_") or OS.get_environment("GALUMU_MEMORY_BOUND")!="1024" or DisplayServer.get_name()=="headless":
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(folder)
	state.save_path = folder+"/qa_profile.json"
	state.backup_path = folder+"/qa_backup.json"
	state.load_profile()
	state.profile.settings.sound = true
	if gear_renown>0:
		state.profile.renown = gear_renown
		state.profile.coins = 10000000
		var best = {}
		for item in state.items:
			var slot = str(item.get("slot",""))
			if slot.is_empty() or Catalogue.unlock_era(item)>Catalogue.era_for_renown(gear_renown) or gear_renown<Catalogue.required_renown(item): continue
			if not best.has(slot) or int(item.price)>int(best[slot].price): best[slot] = item
		for slot in best:
			var id = str(best[slot].id)
			if id not in state.profile.owned: state.purchase(id)
			state.equip(id)
		print("GAMES114 gear=",state.profile.equipped)
	AudioServer.set_bus_mute(0,true)
	root.size = Vector2i(1280,720)
	main = load("res://scenes/main.tscn").instantiate()
	main.smoke_mode = false
	root.add_child(main)
	current_scene = main
	main.set_process(false)
	for frame in range(30): await process_frame
	for index in range(first,first+count):
		await play(index)
		main._close_battle()
		for frame in range(20): await process_frame
	var report = {"passed":failures.is_empty(),"failures":failures,"games":games,
		"scope":"Real Main matches, random seeds, player driven by Battle.autoplay (aims at the head, always spurs) against the real level-free AI; arena/war alternate, renown 0 then 40. GPU isolated desktop, audio muted at Master. Not OS input or human play."}
	FileAccess.open(folder+"/report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("GAMES114_DONE failures=",failures)
	# Keep AudioServer and the tree alive for the game's asynchronous cleanup.
	# Previously this call was followed immediately by quit(), abandoning its
	# pending process_frame coroutine and reporting an ObjectDB exit leak.
	main.set_meta("qa_shutdown_started",true)
	if main.sounds:
		main.sounds.set_enabled(false)
		main.sounds.stop_all()
	main._close_battle()
	var closing_until=Time.get_ticks_msec()+150
	while Time.get_ticks_msec()<closing_until:await process_frame
	main.queue_free()
	await process_frame
	await process_frame
	quit(0 if failures.is_empty() else 1)
