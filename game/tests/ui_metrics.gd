extends SceneTree
const UI = preload("res://scripts/ui/ui_factory.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var page = Control.new()
	page.theme = UI.theme()
	root.add_child(page)
	var panel = UI.panel(page,Rect2(50,50,430,250))
	var label = UI.label(panel,"12 世纪至 13 世纪早期，英、法、德、意骑手装备并不截然不同。本作先保留结构共性，再扩充地区与个人装饰。",Vector2(20,60),17,UI.INK,389)
	await process_frame
	await process_frame
	print("UI_METRICS size=",label.size," minimum=",label.get_minimum_size()," custom=",label.custom_minimum_size," lines=",label.get_line_count()," wrap=",label.autowrap_mode," font=",label.get_theme_font("font").get_string_size("骑手装备",HORIZONTAL_ALIGNMENT_LEFT,-1,17))
	print("FONT_AXES ", label.get_theme_font("font").base_font.get_supported_variation_list(), " SELECTED ", label.get_theme_font("font").variation_opentype)
	if label.size.x > 390 or label.get_line_count() < 3:
		push_error("Chinese paragraph escaped its fixed-width card")
		quit(1)
		return
	quit()
