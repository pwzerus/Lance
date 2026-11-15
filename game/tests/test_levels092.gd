extends SceneTree
## LEVEL-092 check (isolated desktop, QA profile, memory bound):
##  1. Campaign data: 80 levels, valid kits, AI ranges, rewards, variety.
##  2. Progress and rewards on a scratch copy of the QA profile: unlock order,
##     first clear vs replay vs loss, save sanitising. The QA profile is
##     restored and re-saved afterwards.
##  3. Real main scene: level list screenshots, an autopiloted level match
##     against the level's own opponent, the result screen and its reward.
## Engine-injected autoplay, not OS input or a human playtest.
const Campaign = preload("res://scripts/core/campaign.gd")
const Catalogue = preload("res://scripts/core/catalogue.gd")
var folder = ""
var failures: Array = []
var report: Dictionary = {}

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--levels-report="): folder = arg.trim_prefix("--levels-report=")
	var state = root.get_node("GameState")
	if OS.get_environment("GALUMU_MEMORY_BOUND")!="1024" or not state.save_path.contains("qa_") or folder.is_empty() or DisplayServer.get_name()=="headless" or DirAccess.dir_exists_absolute(folder):
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(folder)
	# 1. Data.
	var items = state.items
	var levels = Campaign.levels(items)
	check(levels.size()==80,"expected 80 levels, got %d" % levels.size())
	var kinds = {}
	var war = 0
	var bosses = 0
	var total_coins = 0
	var previous_skill = -1.0
	var chapter_skill: Array = []
	for level in levels:
		kinds[level.archetype] = int(kinds.get(level.archetype,0))+1
		if level.mode=="war": war += 1
		if level.boss: bosses += 1
		total_coins += int(level.reward_coins)
		for slot in ["armor","helmet","shield","lance","horse"]:
			check(level.equipment.has(slot) and not Catalogue.find(items,str(level.equipment[slot])).is_empty(),"level %d missing %s" % [level.number,slot])
		check(float(level.ai.skill)>=0.0 and float(level.ai.skill)<=2.0 and float(level.ai.awareness)>=0.0 and float(level.ai.awareness)<=2.0,"level %d AI out of range" % level.number)
		if int(level.position)==1:
			chapter_skill.append(float(level.ai.skill))
	for i in range(1,chapter_skill.size()):
		check(chapter_skill[i]>=chapter_skill[i-1],"chapter %d opens easier than chapter %d" % [i+1,i])
	check(kinds.size()>=6,"only %d archetypes used" % kinds.size())
	check(bosses==8,"expected 8 champion levels")
	check(float(levels[0].ai.skill)<.3 and float(levels[79].ai.skill)>1.8,"difficulty curve does not span beginner to veteran")
	report["archetypes"] = kinds
	report["war_levels"] = war
	report["first_clear_coins_total"] = total_coins
	report["sample"] = [levels[0],levels[9],levels[40],levels[79]]
	# 2. Progress on a scratch profile.
	var original: Dictionary = state.profile.duplicate(true)
	state.profile.campaign_cleared = []
	state.profile.coins = 1000
	state.profile.renown = 0
	check(state.campaign_frontier()==1 and state.campaign_unlocked(1) and not state.campaign_unlocked(2),"fresh campaign unlock order")
	var first = state.award_level("t1",1,1)
	check(int(first.coins)==Campaign.reward_coins(1,false) and first.first_clear and int(state.profile.coins)==1000+int(first.coins),"first clear pays the full purse")
	check(state.campaign_unlocked(2) and not state.campaign_unlocked(3),"clearing 1 opens 2 only")
	var again = state.award_level("t2",1,1)
	check(int(again.coins)==Campaign.replay_coins(1,false) and not again.first_clear and int(again.renown)==0,"replay pays a quarter, no renown")
	var coins_before = int(state.profile.coins)
	var lost = state.award_level("t3",2,-1)
	check(int(lost.coins)==0 and int(state.profile.coins)==coins_before and not state.campaign_unlocked(3),"loss pays nothing and opens nothing")
	check(state.award_level("t3",2,1).is_empty(),"same session cannot be paid twice")
	var dirty = original.duplicate(true)
	dirty["campaign_cleared"] = [0,81,"x",3.0,3,2,-4,INF]
	check(state.sanitize(dirty).campaign_cleared==[2,3],"sanitise keeps only valid unique level numbers")
	var old_save = original.duplicate(true)
	old_save.erase("campaign_cleared")
	check(state.sanitize(old_save).campaign_cleared==[],"older saves load with an empty campaign")
	# 3. Real UI.
	state.profile.campaign_cleared = []
	for n in range(1,26): state.profile.campaign_cleared.append(n)
	state.profile.settings.combat_brief_v044 = true
	root.size = Vector2i(1440,810)
	root.content_scale_size = Vector2i(1440,810)
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	for _i in range(4): await process_frame
	await _shot("home.png")
	main.show_levels(0)
	for _i in range(3): await process_frame
	await _shot("levels_ch1.png")
	main.show_levels(2)
	for _i in range(3): await process_frame
	await _shot("levels_ch3.png")
	main.show_levels(3)
	for _i in range(3): await process_frame
	await _shot("levels_ch4_locked.png")
	var target = 26
	var coins_start = int(state.profile.coins)
	main._start_level(target)
	check(main.battle!=null and int(main.battle.level.get("number",0))==target,"battle did not receive level %d" % target)
	if main.battle:
		main.battle.autoplay = true
		var enemy: Dictionary = main.battle.match_model.fighters[1].stats
		var expected = Catalogue.stats(items,Campaign.level(items,target).equipment)
		check(is_equal_approx(float(enemy.get("armor",0)),float(expected.get("armor",-1))) and str(enemy.get("armor_art",""))==str(expected.get("armor_art","")),"enemy kit differs from the level kit")
		check(not main.battle.ai_controller.profile.is_empty(),"AI profile not applied")
	var shot_charge = false
	for frame in range(60*120):
		await process_frame
		if not shot_charge and main.battle and main.battle.match_model.phase=="charge" and float(main.battle.match_model.fighters[0].x)>-600:
			await _shot("level26_charge.png")
			shot_charge = true
		if main.result_visible:
			break
	check(main.result_visible,"level match never finished")
	for _i in range(3): await process_frame
	await _shot("level26_result.png")
	var won = int(main.pending_result.get("winner",-1))==0
	report["level26"] = {"won":won,"reward":main.reward,"coins_delta":int(state.profile.coins)-coins_start}
	if won:
		check(26 in state.profile.campaign_cleared and int(main.reward.coins)==Campaign.reward_coins(26,false),"won level 26 but no first-clear reward")
	else:
		check(26 not in state.profile.campaign_cleared and int(main.reward.get("coins",0))==0,"lost level 26 but was paid")
	main.queue_free()
	await process_frame
	state.profile = original
	state.save_profile()
	report["failures"] = failures
	report["passed"] = failures.is_empty()
	var file = FileAccess.open(folder+"/levels.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	file.close()
	print("LEVELS092 "+JSON.stringify({"passed":failures.is_empty(),"failures":failures,"archetypes":kinds,"war":war,"coins":total_coins,"level26":report.level26}))
	quit(0 if failures.is_empty() else 1)

func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder+"/"+name)
