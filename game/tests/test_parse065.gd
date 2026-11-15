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
	# ART-090
	"res://scripts/visual/lance_art.gd",
	"res://scripts/visual/equipment_art.gd",
	"res://scripts/visual/head_fit.gd",
	"res://scripts/visual/helmet_view.gd",
	"res://scripts/core/opponent_ai.gd",
	"res://tools/battle_sprites_v090.gd",
	"res://tests/test_art090.gd",
	"res://tests/test_anim091.gd",
	"res://scripts/core/campaign.gd",
	"res://tests/test_ai_bench092.gd",
	"res://tests/opponent_ai_legacy091.gd",
	"res://tests/test_levels092.gd",
	"res://tests/test_legs093.gd",
	"res://tests/test_unhorse093.gd",
	"res://scripts/visual/heraldry.gd",
	"res://tests/test_unsteady094.gd",
	"res://tests/test_level_diag094.gd",
	"res://tests/test_ai_steady095.gd",
	"res://tests/test_impact097.gd",
	"res://scripts/visual/exchange_director.gd",
	"res://scripts/visual/fallen_rider.gd",
	"res://scripts/visual/impact_fx.gd",
	"res://tools/caparison_v066.gd",
	"res://scripts/ui/combat_report.gd",
	"res://scripts/battle.gd",
	"res://scripts/visual/rider_view.gd",
	"res://scripts/visual/horse_gait.gd",
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
