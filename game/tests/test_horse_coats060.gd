extends SceneTree
## Pending real-engine QA. Uses isolated profile and the bounded launcher.
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	if OS.get_environment("GALUMU_MEMORY_BOUND")!="1024" or not root.get_node("GameState").save_path.contains("qa_"):
		quit(2)
		return
	var catalogue=load("res://scripts/core/catalogue.gd")
	var skin=load("res://scripts/visual/horse_skin.gd")
	var items=catalogue.load_items()
	var count=0
	for item in items:
		if item.slot!="horse": continue
		count+=1
		var stats=catalogue.stats(items,{"horse":item.id})
		assert(stats.horse_coat==catalogue.HORSE_COATS[item.id])
		assert(stats.speed==item.stats.speed and stats.stability==item.stats.stability)
		var near=skin.new()
		var far=skin.new("hind")
		near.set_coat(stats.horse_coat)
		far.set_coat(stats.horse_coat)
		# ART-063: coats are shared CanvasTextures from coat_texture(), not a const dict.
		assert(near.coat==far.coat and near.coat==skin.coat_texture(stats.horse_coat))
		assert(near.coat.get_width()>0 and near.coat.get_width()<=1536)
	assert(count==10)
	print("HORSE_COATS_060 mapping/shared texture/stat preservation PASS; visual motion not covered")
	quit()
