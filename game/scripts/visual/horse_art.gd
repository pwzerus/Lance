extends RefCounted
## Actual alpha-sprite regions and joint anchors, in atlas pixels.
## Source is AI-generated; layout is measured, not assumed to be a grid.
const ATLAS = preload("res://assets/art/pixel_v041/horse_atlas.png")
const PARTS = {
	"body":Rect2(60,100,575,338),
	"head":Rect2(634,24,512,433),
	"tail":Rect2(1180,108,283,381),
	"hoof":Rect2(1592,398,140,82),
	"fore_upper":Rect2(154,470,192,395),
	"fore_lower":Rect2(612,516,128,344),
	"hind_upper":Rect2(1010,474,238,387),
	"hind_lower":Rect2(1494,514,184,345)
}
const JOINTS = {
	"fore_upper":[Vector2(204,518),Vector2(284,832)],
	"fore_lower":[Vector2(663,555),Vector2(679,827)],
	"hind_upper":[Vector2(1102,532),Vector2(1158,827)],
	"hind_lower":[Vector2(1539,555),Vector2(1630,825)]
}
