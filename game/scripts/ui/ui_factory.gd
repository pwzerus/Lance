class_name UIFactory
extends RefCounted

const INK = Color("e9dfc5")
const MUTED = Color("a8ad9b")
const GOLD = Color("c5a568")
const DARK = Color("15221e")

static func theme() -> Theme:
	var result = Theme.new()
	if ResourceLoader.exists("res://assets/fonts/NotoSansSC.ttf"):
		var font = FontVariation.new()
		font.base_font = load("res://assets/fonts/NotoSansSC.ttf")
		var weight_tag = TextServerManager.get_primary_interface().name_to_tag("wght")
		font.variation_opentype = {weight_tag: 500.0}
		result.default_font = font
	else:
		var font = SystemFont.new()
		font.font_names = PackedStringArray(["Microsoft YaHei UI", "Microsoft YaHei", "Noto Sans CJK SC", "Arial"])
		result.default_font = font
	result.default_font_size = 18
	result.set_color("font_color", "Label", INK)
	result.set_color("font_color", "Button", INK)
	result.set_color("font_hover_color", "Button", Color("fff0c7"))
	result.set_color("font_disabled_color", "Button", Color("a8ad9b"))
	result.set_font_size("font_size", "Button", 19)
	result.set_constant("outline_size", "Label", 0)
	result.set_stylebox("normal", "Button", box(Color("25362e"), Color("6c7257"), 5))
	result.set_stylebox("hover", "Button", box(Color("3a4934"), GOLD, 5))
	result.set_stylebox("pressed", "Button", box(Color("18271f"), GOLD, 5))
	result.set_stylebox("disabled", "Button", box(Color("1c2822"), Color("404d40"), 5))
	result.set_stylebox("focus", "Button", box(Color(0,0,0,0), GOLD, 5))
	result.set_stylebox("panel", "PopupMenu", box(Color("1b2923"), GOLD, 5))
	result.set_color("font_color", "PopupMenu", INK)
	result.set_font_size("font_size", "PopupMenu", 18)
	return result

static func box(fill: Color = Color("15221e"), border: Color = Color("57604a"), radius: int = 4) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	return style

static func label(parent: Node, text: String, point: Vector2, font_size: int = 20, color: Color = INK, width: float = 0) -> Label:
	var node = Label.new()
	node.text = text
	node.position = point
	node.add_theme_font_size_override("font_size", font_size)
	node.add_theme_color_override("font_color", color)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if width > 0:
		# Wrapping must precede size assignment: the unwrapped text's minimum
		# width otherwise clamps size and remains after wrapping is enabled.
		node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		node.custom_minimum_size.x = width
		node.size.x = width
	parent.add_child(node)
	if width > 0:
		# Theme inheritance reshapes CJK text on enter_tree. Apply the fixed
		# paragraph width after that minimum-size notification has completed.
		node.set_deferred("size", Vector2(width, 0))
	return node

static func button(parent: Node, text: String, rect: Rect2, callback: Callable, primary: bool = false) -> Button:
	var node = Button.new()
	node.text = text
	node.position = rect.position
	node.size = rect.size
	node.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if primary:
		node.add_theme_stylebox_override("normal", box(Color("a4874e"), Color("e0c586")))
		node.add_theme_color_override("font_color", Color("18241d"))
		node.add_theme_color_override("font_hover_color", Color("fff0c7"))
	node.pressed.connect(callback)
	parent.add_child(node)
	if rect.size.y < 48:
		node.add_theme_font_size_override("font_size",mini(19,int(rect.size.y*.48)))
		for state in ["normal","hover","pressed","disabled","focus"]:
			var style = node.get_theme_stylebox(state).duplicate()
			style.content_margin_top = 4
			style.content_margin_bottom = 4
			node.add_theme_stylebox_override(state,style)
		node.set_deferred("size",rect.size)
	return node

static func panel(parent: Node, rect: Rect2, fill: Color = Color(.07,.12,.095,.95)) -> Panel:
	var node = Panel.new()
	node.position = rect.position
	node.size = rect.size
	node.add_theme_stylebox_override("panel", box(fill, Color("677052")))
	parent.add_child(node)
	return node

static func separator(parent: Node, point: Vector2, width: float) -> ColorRect:
	var node = ColorRect.new()
	node.color = Color("6d7453")
	node.position = point
	node.size = Vector2(width, 1)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)
	return node

static func check(parent: Node, text: String, value: bool, point: Vector2, callback: Callable) -> CheckButton:
	var node = CheckButton.new()
	node.text = text
	node.position = point
	node.size = Vector2(340,42)
	node.button_pressed = value
	node.toggled.connect(callback)
	parent.add_child(node)
	# The inherited button padding otherwise makes a 42px switch 54px high,
	# covering the explanatory caption and adjacent pause controls.
	for state in ["normal","hover","pressed","disabled","focus"]:
		var style = node.get_theme_stylebox(state).duplicate()
		style.content_margin_top = 4
		style.content_margin_bottom = 4
		node.add_theme_stylebox_override(state,style)
	node.set_deferred("size",Vector2(340,42))
	return node
