extends "test_ui082.gd"
## Normal beginner progression: no injected coins, renown, owned kit or results.
## Battle autoplay replaces a person; actual wins/losses fund viewport purchases.
const Catalogue087=preload("res://scripts/core/catalogue.gd")
var rounds=[]
var purchases=[]

func wall_wait(seconds:float)->void:
	var end=Time.get_ticks_msec()+int(seconds*1000)
	while Time.get_ticks_msec()<end:await process_frame

func click_action(prefix:String,parent:Node=null)->bool:
	for action in buttons(main if parent==null else parent):
		if not action.text.begins_with(prefix) or action.disabled or not action.is_visible_in_tree():continue
		var e=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_LEFT;e.pressed=true;e.position=action.get_global_rect().get_center()
		root.push_input(e,true);e=e.duplicate();e.pressed=false;root.push_input(e,true)
		return true
	return false

func start_competition()->void:
	main.show_match_setup();await process_frame
	check(click_action("进入竞技场"),"Mode selection lacks arena action")
	await process_frame
	if is_instance_valid(main.brief_overlay):
		check(click_action("明白了，出战"),"First match cannot acknowledge controls")
		await process_frame
	check(is_instance_valid(main.battle),"Arena setup did not create a battle")
	if not is_instance_valid(main.battle):return
	main.battle.autoplay=true
	main.battle.match_model.rng.seed=87300+rounds.size()*97
	main.battle.ai_rng.seed=87530+rounds.size()*97
	if root.focus_exited.is_connected(main.battle._on_focus_lost):root.focus_exited.disconnect(main.battle._on_focus_lost)
	var actual=main.battle.match_model.fighters[0].stats
	var expected=state.player_stats()
	for key in ["armor","helmet","power","speed","reach","shield_capacity","horse_coat"]:
		check(actual[key]==expected[key],"New match did not apply purchased equipment: "+key)

func shop_after_result()->void:
	check(click_action("返回营地"),"Result cannot return to camp")
	await process_frame
	var slot_order=["lance","helmet","armor","shield","caparison","horse","crest"]
	var chosen={}
	# Try the next unvisited slot; always require real unlocked affordable stock.
	for offset in range(slot_order.size()):
		var slot=slot_order[(rounds.size()-1+offset)%slot_order.size()]
		for item in state.items:
			if item.slot!=slot or bool(item.get("legacy",false)) or item.id in state.profile.owned or int(item.price)>int(state.profile.coins) or Catalogue087.required_renown(item)>int(state.profile.renown):continue
			if chosen.is_empty() or int(item.price)<int(chosen.price):chosen=item
		if not chosen.is_empty():break
	if chosen.is_empty():return
	main.selected_slot=chosen.slot;main.selected_item={};main.selected_region=0;main.selected_quality=0;main.selected_era=-1
	main.show_armory();await wall_wait(.25)
	var card:Button=main.armory_cards.get(chosen.id)
	check(card!=null,"Affordable unlocked item is absent from its unfiltered slot")
	if card==null:return
	main.armory_scroll.ensure_control_visible(card);await process_frame
	var e=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_LEFT;e.pressed=true;e.position=card.get_global_rect().get_center()
	root.push_input(e,true);e=e.duplicate();e.pressed=false;root.push_input(e,true)
	await wall_wait(.15)
	check(main.selected_item.get("id")==chosen.id,"Visible item click selected a different item")
	var before_coins=int(state.profile.coins)
	check(click_action("购买 ·",main.info_panel),"Unlocked affordable purchase has no enabled action")
	await wall_wait(.25)
	check(chosen.id in state.profile.owned and int(state.profile.coins)==before_coins-int(chosen.price),"Purchase did not charge exactly its real price")
	check(click_action("装备",main.info_panel),"Purchased item cannot be equipped")
	await wall_wait(.25)
	check(state.profile.equipped.get(chosen.slot)==chosen.id,"Equipment action did not select purchased item")
	check(not state.profile_save_pending,"Normal purchase/equip failed to persist")
	purchases.append({"after_match":rounds.size(),"item":chosen.id,"price":chosen.price,"coins_before":before_coins,"coins_after":state.profile.coins,"renown":state.profile.renown,"required_renown":Catalogue087.required_renown(chosen)})
	if purchases.size() in [1,3,6]:await capture("shop_after_%02d"%rounds.size())
	main.show_home()

func run()->void:
	var seconds=480.0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--folder="):folder=arg.trim_prefix("--folder=")
		if arg.begins_with("--seconds="):seconds=clampf(float(arg.trim_prefix("--seconds=")),300,480)
	state=root.get_node("GameState")
	if folder.is_empty() or DirAccess.dir_exists_absolute(folder) or not state.save_path.contains("qa_") or OS.get_environment("GALUMU_MEMORY_BOUND")!="1024" or DisplayServer.get_name()=="headless":quit(2);return
	DirAccess.make_dir_recursive_absolute(folder)
	state.save_path=folder+"/qa_profile.json";state.backup_path=folder+"/qa_backup.json";state.load_profile()
	state.profile.settings.difficulty=0
	AudioServer.set_bus_mute(0,true)
	root.size=Vector2i(960,540)
	main=load("res://scenes/main.tscn").instantiate();root.add_child(main);current_scene=main
	await wall_wait(2)
	var started=Time.get_ticks_msec()
	await start_competition()
	while Time.get_ticks_msec()-started<int(seconds*1000) and failures.is_empty():
		await process_frame
		if not main.result_visible:continue
		check(state.profile.matches==rounds.size()+1,"Result did not award exactly once")
		rounds.append({"result":main.pending_result.duplicate(true),"coins":state.profile.coins,"renown":state.profile.renown,"equipped":state.profile.equipped.duplicate(true),"contacts":main.battle.exchange_log.size()})
		await wall_wait(.6)
		await shop_after_result()
		FileAccess.open(folder+"/progress.json",FileAccess.WRITE).store_string(JSON.stringify({"matches":rounds.size(),"purchases":purchases,"failures":failures}))
		if failures.is_empty():await start_competition()
	check(rounds.size()>=6,"Beginner journey did not complete six normal matches")
	check(purchases.size()>=3,"Earned rewards did not support three actual equipment changes")
	check(Catalogue087.era_for_renown(int(state.profile.renown))>=1,"Normal completed results failed to open the next era")
	main._close_battle();main.show_home();await capture("final_camp")
	check(state.save_profile(),"Final earned progression did not persist")
	var saved=state._read_save(state.save_path)
	check(int(saved.get("coins",-1))==int(state.profile.coins) and saved.get("equipped",{})==state.profile.equipped,"Disk progression differs after shopping")
	FileAccess.open(folder+"/report.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"failures":failures,"rounds":rounds,"purchases":purchases,"wall_seconds":(Time.get_ticks_msec()-started)/1000.0,"version":ProjectSettings.get_setting("application/config/version"),"executable":OS.get_executable_path(),"final_profile":state.profile,"scope":"Fresh normal profile, real Main results/rewards, normal AI and production autoplay; real viewport first-run, purchase, equip and next-match controls. No injected funds, renown, gear or hit/results. Not human learning, enjoyment, win-rate or FPS evidence."},"\t"))
	print("JOURNEY087 matches=",rounds.size()," purchases=",purchases.size()," failures=",failures)
	main.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
