extends SceneTree
## Data-boundary purchase audit for every publicly offered item. The balance
## is deliberately set to exact thresholds; this is not earned progression.
const Catalogue=preload("res://scripts/core/catalogue.gd")
var failures=[]
var rows=[]
func _initialize()->void:call_deferred("run")
func check(ok:bool,why:String)->void:
	if not ok and why not in failures:failures.append(why);push_error(why)
func run()->void:
	var folder=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--folder="):folder=arg.trim_prefix("--folder=")
	var state=root.get_node("GameState")
	if folder.is_empty() or DirAccess.dir_exists_absolute(folder) or not state.save_path.contains("qa_") or OS.get_environment("GALUMU_MEMORY_BOUND").is_empty():quit(2);return
	DirAccess.make_dir_recursive_absolute(folder)
	state.save_path=folder+"/qa_profile.json";state.backup_path=folder+"/qa_backup.json"
	state.load_profile()
	state.profile=state.default_profile()
	check(state.save_profile(),"Initial boundary profile")
	var legacy=[];var starter=[]
	for item in state.items:
		if item.id in state.default_profile().owned:
			starter.append(item.id);continue
		if item.get("legacy",false):legacy.append(item.id);continue
		var id=str(item.id);var price=int(item.price);var renown=Catalogue.required_renown(item)
		check(price>0 and renown>=0,"Valid public transaction data "+id)
		var before_disk=FileAccess.get_sha256(state.save_path)
		state.profile=state.default_profile();state.profile.coins=maxi(0,price-1);state.profile.renown=renown
		var before=state.profile.duplicate(true)
		state.purchase(id)
		check(state.profile==before and FileAccess.get_sha256(state.save_path)==before_disk,"One coin short never debits or writes "+id)
		if renown>0:
			state.profile.coins=price;state.profile.renown=renown-1;before=state.profile.duplicate(true)
			state.purchase(id)
			check(state.profile==before and FileAccess.get_sha256(state.save_path)==before_disk,"One renown short remains locked "+id)
		state.profile.coins=price;state.profile.renown=renown
		check(state.purchase(id)=="已收入军械库" and state.profile.coins==0 and id in state.profile.owned,"Exact price/renown buys public item "+id)
		check(state.equip(id) and state.profile.equipped[item.slot]==id,"Purchased item equips in correct slot "+id)
		var paid=state.profile.duplicate(true)
		check(state.purchase(id)=="已经拥有" and state.profile==paid,"Owned item never debits twice "+id)
		state.profile=state.default_profile();state.load_profile()
		check(state.profile==paid and not state.profile_save_pending,"Purchase survives disk round trip "+id)
		rows.append({"id":id,"slot":item.slot,"region":item.region,"price":price,"required_renown":renown,"historical_era":item.era,"progression_era":Catalogue.unlock_era(item),"equipped_id":state.profile.equipped[item.slot]})
	# A player who already owns an old item must not lose access just because
	# later metadata hides that item from new buyers or lowers their renown.
	var old=state.default_profile();old.renown=0
	for item in state.items:
		if item.get("legacy",false) and item.id not in old.owned:old.owned.append(item.id)
	state.profile=state.sanitize(old)
	for id in old.owned:
		var item=Catalogue.find(state.items,id)
		if item.get("legacy",false):check(state.equip(id),"Owned legacy item remains usable "+id)
	check(state.profile.owned==old.owned,"Legacy collection survives equip transactions")
	FileAccess.open(folder+"/report.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"failures":failures,"public_items":rows,"starter_ids":starter,"hidden_unowned_legacy":legacy,"scope":"Exact coin/renown boundaries for all public purchase IDs via production APIs and QA disk round trips. Currency/renown are fixture values, not combat earnings. Old owned items retained; no GUI or human play claim."},"\t"))
	print("SHOP109 public=",rows.size()," failures=",failures);quit(0 if failures.is_empty() else 1)
