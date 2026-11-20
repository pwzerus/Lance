extends SceneTree
## Exercise real transactions, unlock checks and disk persistence. Outcomes
## here are supplied to the reward API, not won through combat. Rendered
## earned progression is a separate fixture and must remain labelled so.
const Catalogue=preload("res://scripts/core/catalogue.gd")
const Campaign=preload("res://scripts/core/campaign.gd")
const Condition=preload("res://scripts/core/horse_condition.gd")
var state:Node
var folder=""
var failures=[]
var routes=[]
var checks=[]
var reward_cases=[]
func _initialize()->void:call_deferred("run")
func check(ok:bool,why:String)->void:
	checks.append({"name":why,"passed":ok})
	if not ok and why not in failures:failures.append(why);push_error(why)
func fresh(name_value:String)->void:
	var path=folder+"/"+name_value
	DirAccess.make_dir_recursive_absolute(path)
	state.save_path=path+"/qa_profile.json";state.backup_path=path+"/qa_backup.json"
	state.profile=state.default_profile();state.session_awarded.clear()
	state.recovery_required=false;state.profile_save_pending=false;state.save_error="";state.profile_save_error=""
	check(state.save_profile(),name_value+" initial save")
func restored(why:String)->void:
	var before=state.profile.duplicate(true)
	state.profile=state.default_profile();state.load_profile()
	check(state.profile==before,why+" disk round trip")
func purchase(id:String,why:String)->bool:
	var item=Catalogue.find(state.items,id)
	var before=state.profile.duplicate(true)
	var message=state.purchase(id)
	var bought=id in state.profile.owned and id not in before.owned
	if bought:
		check(state.profile.coins==int(before.coins)-int(item.price),why+" exact debit "+id)
		check(not state.profile_save_pending,why+" saved purchase "+id)
		check(state.purchase(id)=="已经拥有" and state.profile.coins==int(before.coins)-int(item.price),why+" duplicate purchase no debit "+id)
	else:
		check(state.profile==before,why+" rejected purchase unchanged "+id+" "+message)
	return bought
func run()->void:
	var audit_path=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--folder="):folder=arg.trim_prefix("--folder=")
		if arg.begins_with("--audit="):audit_path=arg.trim_prefix("--audit=")
	state=root.get_node("GameState")
	if folder.is_empty() or DirAccess.dir_exists_absolute(folder) or not state.save_path.contains("qa_") or OS.get_environment("GALUMU_MEMORY_BOUND").is_empty() or audit_path.is_empty():quit(2);return
	DirAccess.make_dir_recursive_absolute(folder)
	var audit=JSON.parse_string(FileAccess.get_file_as_string(audit_path))
	if not audit is Dictionary or audit.rows.size()!=80:quit(2);return
	for route in ["light","heavy","early_light","early_heavy"]:
		fresh(route)
		var rows=[];var total_spent=0;var earned=0;var gained_renown=0
		for n in range(1,81):
			var tag=route+" level "+str(n)
			check(state.campaign_unlocked(n),tag+" naturally unlocked by reward records")
			if n<80:check(not state.campaign_unlocked(n+1),tag+" next still locked")
			var expected=audit.rows[n-1].budget_kits[route]
			var bought=[]
			for slot in ["lance","armor","helmet","horse","shield"]:
				var id=str(expected.equipment[slot]);var item=Catalogue.find(state.items,id)
				if id not in state.profile.owned:
					check(not item.get("legacy",false),tag+" new purchase offered in armory")
					if purchase(id,tag):total_spent+=int(item.price);bought.append(id)
				check(state.equip(id),tag+" equip "+id)
			check(state.profile.coins==520+earned-total_spent,tag+" purse ledger")
			check(state.profile.coins==int(expected.coins_remaining) and total_spent==int(expected.total_spent),tag+" prior shadow budget matches real purchases")
			check(state.profile.renown==gained_renown,tag+" renown ledger")
			if n in [1,5,10,24,43,80]:
				var before=state.profile.duplicate(true)
				var lost=state.award_level(tag+" loss",n,-1)
				check(lost.coins==0 and lost.renown==0 and state.profile.coins==before.coins and state.profile.owned==before.owned and state.profile.equipped==before.equipped and state.profile.campaign_cleared==before.campaign_cleared,tag+" loss preserves equipment and progression")
				restored(tag+" lost match")
			var before_coins=int(state.profile.coins)
			var reward=state.award_level(tag,n,1)
			var purse=120+12*(n-1)+(300 if n%10==0 else 0)
			var renown=3 if n%10==0 else 1
			earned+=purse;gained_renown+=renown
			check(reward.coins==purse and reward.renown==renown and reward.first_clear and state.profile.coins==before_coins+purse,tag+" first-clear reward")
			var paid=state.profile.duplicate(true)
			check(state.award_level(tag,n,1).is_empty() and state.profile==paid,tag+" duplicate callback no reward")
			restored(tag)
			if n%10==0:
				check(state.save_slot(2),tag+" manual snapshot")
				check(state.load_slot(2) and state.profile==paid,tag+" manual snapshot retains progress")
			var stats=state.player_stats()
			rows.append({"level":n,"bought":bought,"equipped":state.profile.equipped.duplicate(),"coins_before":before_coins,"coins_after":state.profile.coins,"renown":state.profile.renown,"owned_count":state.profile.owned.size(),"load_kg":Condition.load_kg(stats),"load_speed_factor":Condition.load_speed_factor(stats),"horse_speed":stats.get("speed",0),"horse_stability":stats.get("stability",0),"reward":reward})
		check(state.profile.campaign_cleared.size()==80 and earned==49920 and gained_renown==96,route+" whole first-clear ledger")
		var before=state.profile.duplicate(true)
		for n in [1,10,43,80]:
			var replay=state.award_level(route+" replay "+str(n),n,1)
			check(replay.coins==int((120+12*(n-1)+(300 if n%10==0 else 0))/4) and replay.renown==0 and not replay.first_clear,route+" replay purse "+str(n))
		check(state.profile.renown==before.renown and state.profile.campaign_cleared==before.campaign_cleared,route+" replay cannot farm unlock renown")
		routes.append({"route":route,"first_clear_coins":earned,"first_clear_renown":gained_renown,"spent":total_spent,"rows":rows})
	# Reuse legally earned last-route funds, not synthetic ownership, to
	# compare the two established reward systems with all cloth styles.
	for id in ["caparison_none","caparison_linen","caparison_wool","caparison_velvet"]:
		if id not in state.profile.owned:check(purchase(id,"cloth"),"cloth is affordable from completed route")
		check(state.equip(id),"equip reward cloth "+id)
		var bonus=int(Catalogue.find(state.items,id).get("stats",{}).get("caparison_renown",0))
		for mode in ["arena","war"]:
			for outcome in [-1,0,1]:
				var reward=state.award_match("cloth "+str([id,mode,outcome]),outcome,mode)
				var expected_coins=(55 if outcome<0 else (110 if outcome==0 else 180))+(30 if mode=="war" else 0)
				check(reward.coins==expected_coins and reward.renown==(3+bonus if outcome>0 else 1),"free-play cloth reward "+str([id,mode,outcome]))
				reward_cases.append({"cloth":id,"mode":mode,"outcome":outcome,"reward":reward})
		var replay=state.award_level("cloth campaign "+id,1,1)
		check(replay.coins==30 and replay.renown==0,"cloth does not alter campaign replay "+id)
		restored("cloth "+id)
	fresh("poor_purchase")
	var cosmetic=[]
	for item in state.items:
		if item.slot in ["crest","caparison"] and item.id not in state.profile.owned and Catalogue.unlock_era(item)==0 and Catalogue.required_renown(item)==0:cosmetic.append(item)
	cosmetic.sort_custom(func(a,b):return int(a.price)>int(b.price))
	var purchases=[]
	for item in cosmetic:
		if int(item.price)<=int(state.profile.coins) and purchase(item.id,"cosmetic detour"):purchases.append(item.id)
	var remaining=int(state.profile.coins)
	check(not purchase("de_helmet_5","future tier") and not state.equip("de_helmet_5"),"future item cannot be bought or equipped")
	check(not purchase("missing_109","unknown item"),"unknown item not purchasable")
	var target=Catalogue.find(state.items,"eng_lance_long_0")
	var recovery_matches=0
	while int(state.profile.coins)<int(target.price) and recovery_matches<12:
		state.award_match("recovery loss "+str(recovery_matches),-1,"arena");recovery_matches+=1
	check(purchase(target.id,"recovered purchase") and state.equip(target.id),"cosmetic spending is recoverable without a win")
	check("lance_ash" in state.profile.owned and state.equip("lance_ash"),"free starter remains usable")
	restored("poor purchase recovery")
	var horses=[];var max_speed=0.0;var max_stability=0.0
	for item in state.items:
		if item.slot=="horse":
			var stats=Catalogue.stats(state.items,{"horse":item.id})
			horses.append({"id":item.id,"price":item.price,"speed":stats.speed,"stability":stats.stability})
			max_speed=maxf(max_speed,float(stats.speed));max_stability=maxf(max_stability,float(stats.stability))
	check(horses.size()==10,"ten shared horse tradeoffs")
	for h in horses:check(not (h.speed>=max_speed and h.stability>=max_stability),"no fastest and steadiest horse "+h.id)
	var report={"passed":failures.is_empty(),"failures":failures,"checks":checks,"routes":routes,"reward_cases":reward_cases,"poor_purchase":{"cosmetics":purchases,"remaining":remaining,"recovery_losses":recovery_matches,"final_profile":state.profile},"horses":horses,"scope":"Real GameState purchase/equip/reward/save/load APIs and isolated disk files, including 320 first-clear ledger cases. Combat outcomes are supplied, not earned; no rendered UI, human win rate or continuous campaign claim."}
	FileAccess.open(folder+"/report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("ECON109 routes=",routes.size()," failures=",failures);quit(0 if failures.is_empty() else 1)
