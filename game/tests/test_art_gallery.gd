extends SceneTree

const Rider = preload("res://scripts/visual/rider_view.gd")
const Model = preload("res://scripts/core/joust_match.gd")
const Catalogue = preload("res://scripts/core/catalogue.gd")
const UI = preload("res://scripts/ui/ui_factory.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var page = Control.new()
	page.theme = UI.theme()
	root.add_child(page)
	var bg = ColorRect.new()
	bg.color = Color("101e19")
	bg.size = Vector2(1440,810)
	page.add_child(bg)
	UI.label(page,"装备分件 · 游戏内双向组合验收",Vector2(20,16),28,UI.GOLD)
	UI.label(page,"胸甲 / 头盔独立造型；四肢和马具仍为通用游戏组件。",Vector2(20,56),16,UI.MUTED)
	var items = Catalogue.load_items()
	for row in range(2):
		for era in range(5):
			var panel = UI.panel(page,Rect2(14+era*286,86+row*350,276,334))
			panel.clip_contents = true
			UI.label(panel,Catalogue.ERAS[era],Vector2(14,12),22,UI.GOLD)
			UI.label(panel,Catalogue.ERA_NAMES[era]+(" · 右向" if row==0 else " · 左向"),Vector2(14,48),15,UI.MUTED)
			var stats = Catalogue.opponent_stats(items,era)
			stats.heraldry = ["bend","chevron","cross","diamond","bend"][era]
			var model = Model.new("arena",stats)
			var fighter = model.fighters[0]
			fighter.x = 0
			fighter.direction = 1 if row==0 else -1
			fighter.lean = .25 if row==0 else -.25
			var rider = Rider.new()
			rider.fighter = fighter
			rider.position = Vector2(130,305)
			rider.scale = Vector2.ONE*.64
			panel.add_child(rider)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var result = root.get_texture().get_image().save_png("E:/GALUMU/docs/development/screenshots/v03/04_equipment_gallery.png")
	print("ART_GALLERY_CAPTURE ",result)
	page.queue_free()
	await process_frame
	quit(result)
