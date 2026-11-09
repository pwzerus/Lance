extends SceneTree
## HORSE-065 compile gate: every script touched this round must load and
## compile headless before any render pass. Prints one line per script.
const PATHS = [
	"res://scripts/core/horse_condition.gd",
	"res://scripts/core/joust_match.gd",
	"res://scripts/visual/horse_gait.gd",
	"res://scripts/visual/rider_view.gd",
	"res://scripts/visual/shield_art.gd",
	"res://scripts/visual/character_face.gd",
	"res://scripts/battle.gd",
	"res://scripts/main.gd",
	"res://tests/test_armory065.gd",
	"res://tests/test_horse_stride065.gd",
	# EQUIP-066
	"res://scripts/core/catalogue.gd",
	"res://scripts/core/game_state.gd",
	"res://scripts/visual/heraldry.gd",
	"res://scripts/visual/horse_skin.gd",
	"res://tools/caparison_v066.gd",
	"res://tests/test_balance066.gd",
	"res://tests/test_equip066.gd",
	"res://tests/test_arm068.gd",
	"res://tests/test_hud067.gd",
]

func _initialize() -> void:
	var failed = 0
	for path in PATHS:
		var script = load(path)
		var ok = script != null and script.can_instantiate()
		if not ok: failed += 1
		print("PARSE065 %s %s" % ["OK  " if ok else "FAIL", path])
	print("PARSE065_RESULT failed=%d" % failed)
	quit(1 if failed else 0)
