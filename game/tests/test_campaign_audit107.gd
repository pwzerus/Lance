extends SceneTree
## Export all real campaign definitions and compare the OLD benchmark's
## assumed purchases with first-clear income/unlocks. No profile writes,
## autoplay outcomes or inferred human win rates.
const Campaign=preload("res://scripts/core/campaign.gd")
const Catalogue=preload("res://scripts/core/catalogue.gd")
const Condition=preload("res://scripts/core/horse_condition.gd")
const Brain=preload("res://scripts/core/opponent_ai.gd")
var failures=[]
func _initialize()->void:call_deferred("run")
func reference_ids(n:int,line:String)->Dictionary:
	var q=clampi((n+2)/16,0,5)
	return {"armor":"eng_armor_%d"%q,"helmet":"eng_helmet_%d"%q,"shield":"eng_shield_%d"%(clampi(q/2,0,2)*2+(1 if line=="heavy" else 0)),"lance":"eng_lance_long_%d"%q,"horse":["horse_bay","horse_grey","horse_e1","horse_e2","horse_e4","horse_e4"][q],"crest":"crest_bend"}
func run()->void:
	var report_path=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):report_path=arg.trim_prefix("--report=")
	var state=root.get_node("GameState")
	if report_path.is_empty() or FileAccess.file_exists(report_path) or not "qa_" in state.save_path or OS.get_environment("GALUMU_MEMORY_BOUND").is_empty():quit(2);return
	var items=state.items
	var fresh=state.default_profile();var coins=int(fresh.coins);var renown=int(fresh.renown)
	var acquired:Dictionary={};var spent:Dictionary={}
	var legal_routes:Dictionary={}
	for line in ["light","heavy"]:acquired[line]=fresh.owned.duplicate();spent[line]=0
	for line in ["light","heavy","early_light","early_heavy"]:
		legal_routes[line]={"owned":fresh.owned.duplicate(),"equipped":fresh.equipped.duplicate(),"spent":0}
	var rows=[];var names={};var kits={};var profiles={}
	for n in range(1,81):
		var level=Campaign.level(items,n);var stats=Catalogue.stats(items,level.equipment)
		for slot in ["armor","helmet","shield","horse","lance"]:
			if not level.equipment.has(slot) or Catalogue.find(items,level.equipment[slot]).is_empty():failures.append("missing kit "+str([n,slot]))
		var price=0;var required_renown=0;var required_era=0
		for id in level.equipment.values():
			var item=Catalogue.find(items,id)
			price+=int(item.price);required_renown=maxi(required_renown,Catalogue.required_renown(item));required_era=maxi(required_era,Catalogue.unlock_era(item))
		var references={}
		var legal_kits={}
		for line in ["light","heavy"]:
			var ids=reference_ids(n,line);var blocked=[];var new_cost=0
			for id in ids.values():
				var item=Catalogue.find(items,id)
				if id not in acquired[line]:
					new_cost+=int(item.price);acquired[line].append(id)
				if Catalogue.required_renown(item)>renown or Catalogue.unlock_era(item)>Catalogue.era_for_renown(renown):blocked.append(id)
			spent[line]+=new_cost
			references[line]={"equipment":ids,"total_assumed_spending":spent[line],"remaining_after_assumed_purchases":coins-spent[line],"locked_items":blocked,"new_cost":new_cost}
			# Separate legal-budget diagnostic, not the game's recommended route:
			# leave the starter kit intact for 1-5, then buy only unlocked pieces
			# affordable from initial coins + preceding first-clear rewards.
			var route:Dictionary=legal_routes[line]
			var desired=ids.duplicate()
			var q=clampi((n+2)/16,0,5)
			if q==0:
				desired.armor=fresh.equipped.armor;desired.helmet=fresh.equipped.helmet
				if line=="light":desired.shield=fresh.equipped.shield
			if line=="heavy":
				desired.lance="eng_lance_stout_%d"%q
				desired.horse=["horse_cob","horse_chestnut","horse_e2","horse_e2","horse_steady","horse_steady"][q]
			var bought=[];var deferred=[]
			if n>=6:
				for slot in ["lance","armor","helmet","horse","shield"]:
					var id=str(desired[slot]);var item=Catalogue.find(items,id)
					if id in route.owned:route.equipped[slot]=id;continue
					if Catalogue.required_renown(item)>renown or Catalogue.unlock_era(item)>Catalogue.era_for_renown(renown) or int(item.price)>coins-int(route.spent):
						deferred.append(id);continue
					route.owned.append(id);route.spent+=int(item.price);route.equipped[slot]=id;bought.append(id)
			legal_kits[line]={"equipment":route.equipped.duplicate(),"stats":Catalogue.stats(items,route.equipped),"total_spent":route.spent,"coins_remaining":coins-int(route.spent),"bought":bought,"deferred":deferred}
		for line in ["early_light","early_heavy"]:
			# A second, explicit counterfactual: spend on the best unlocked tier
			# as it becomes affordable. This avoids equating a deliberately slow
			# benchmark upgrade schedule with the full game's difficulty curve.
			var q=0
			for candidate in range(6):
				var item=Catalogue.find(items,"eng_lance_long_%d"%candidate)
				if Catalogue.required_renown(item)<=renown and Catalogue.unlock_era(item)<=Catalogue.era_for_renown(renown):q=candidate
			var heavy=line=="early_heavy"
			var desired={"armor":"eng_armor_%d"%q,"helmet":"eng_helmet_%d"%q,"lance":"eng_lance_%s_%d"%["stout" if heavy else "long",q],"shield":"eng_shield_%d"%(clampi(q/2,0,2)*2+(1 if heavy else 0)),"horse":(["horse_cob","horse_chestnut","horse_e2","horse_e2","horse_steady","horse_steady"] if heavy else ["horse_bay","horse_grey","horse_e1","horse_e2","horse_e4","horse_e4"])[q]}
			var route:Dictionary=legal_routes[line];var bought=[];var deferred=[]
			if n>=6:
				for slot in ["lance","armor","helmet","horse","shield"]:
					var id=str(desired[slot]);var item=Catalogue.find(items,id)
					if id in route.owned:route.equipped[slot]=id;continue
					if Catalogue.required_renown(item)>renown or Catalogue.unlock_era(item)>Catalogue.era_for_renown(renown) or int(item.price)>coins-int(route.spent):deferred.append(id);continue
					route.owned.append(id);route.spent+=int(item.price);route.equipped[slot]=id;bought.append(id)
			legal_kits[line]={"equipment":route.equipped.duplicate(),"stats":Catalogue.stats(items,route.equipped),"total_spent":route.spent,"coins_remaining":coins-int(route.spent),"bought":bought,"deferred":deferred}
		var reaction=Brain.curve(Brain.REACTION,float(level.ai.awareness))+.35*float(level.ai.get("training",0))+Brain.vision_delay(stats)
		rows.append({"level":level,"enemy_stats":stats,"enemy_load_kg":Condition.load_kg(stats),"enemy_load_speed_factor":Condition.load_speed_factor(stats),"enemy_item_cost":price,"enemy_required_renown":required_renown,"enemy_required_era":required_era,"ai_observation_delay_seconds":reaction,"ai_think_seconds":Brain.curve(Brain.THINK,float(level.ai.awareness))+.25*float(level.ai.get("training",0)),"first_clear_income_before_level":coins,"first_clear_renown_before_level":renown,"legacy_reference":references,"budget_kits":legal_kits})
		var name_key=str(level.region)+" "+str(level.opponent)
		if not names.has(name_key):names[name_key]=[]
		names[name_key].append(n);kits[JSON.stringify(level.equipment)]=true;profiles[JSON.stringify(level.ai)]=true
		coins+=int(level.reward_coins);renown+=int(level.reward_renown)
	var duplicates={}
	for key in names:
		if names[key].size()>1:duplicates[key]=names[key]
	var report={"passed":failures.is_empty(),"failures":failures,"version":ProjectSettings.get_setting("application/config/version"),"rows":rows,"duplicate_names":duplicates,"unique_kits":kits.size(),"unique_ai_profiles":profiles.size(),"scope":"Actual campaign catalogue snapshot. Legacy reference affordability assumes buying each reference upgrade once and winning all previous levels, not actual purchase/progression or human play evidence."}
	DirAccess.make_dir_recursive_absolute(report_path.get_base_dir())
	FileAccess.open(report_path,FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("CAMPAIGN_AUDIT107 ",failures);quit(0 if failures.is_empty() else 1)
