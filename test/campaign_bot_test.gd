## Smoke test for the campaign bot (#61): one campaign on a fixed seed must
## produce the per-dungeon tables, leave the real save untouched, and put the
## live GameState / Party state back.
##
## The bot awards real XP, which can unlock a skin, and unlocking a skin saves
## the game. CampaignBot.run_isolated() points the save at a scratch folder;
## this suite checks that nothing leaks out of it.
extends GdUnitTestSuite

const SimRunner := preload("res://scripts/dev/sim_runner.gd")
## The real save files, by their default paths. Checked, never written.
const REAL_SAVE_FILES: Array[String] = [
	"user://save.json",
	"user://save.bak.json",
	"user://save.tmp.json",
	"user://save.corrupt.json",
]


func test_one_campaign_produces_tables() -> void:
	var before := _real_save_checksums()
	var heroes_before := Party.heroes
	var skins_before := GameState.owned_skins.duplicate()
	var save_dir_before := GameState.save_dir
	var opts := SimRunner.parse_campaign_args(
		PackedStringArray(["campaign", "--runs", "1", "--seed", "3"])
	)
	assert_bool(opts.has("error")).override_failure_message(str(opts.get("error"))).is_false()

	var res := SimRunner.campaign_report(opts)
	var md: String = res["md"]

	assert_str(md).contains("**Seed:** 3")
	assert_str(md).contains(
		"| Dungeon | Level at boss | Fights | Rounds / fight | Est. minutes | TPK % |"
	)
	for dl in range(1, 5):
		assert_str(md).contains("| D%d |" % dl)
	assert_str(md).contains("| Dungeon | Campaigns in | Level at entry | Level at boss |")
	assert_str(md).contains("| Dungeon | Campaigns in | TPK % | F1 | F2 | F3 | F4 | Boss |")
	assert_array(res["guard"]["changed"]).is_empty()
	assert_dict(_real_save_checksums()).is_equal(before)
	# The live state is back, and the scratch save folder is gone.
	assert_bool(Party.heroes == heroes_before).is_true()
	assert_array(GameState.owned_skins).is_equal(skins_before)
	assert_str(GameState.save_dir).is_equal(save_dir_before)
	assert_bool(DirAccess.dir_exists_absolute(CampaignBot.SCRATCH_DIR)).is_false()


func test_same_seed_same_report() -> void:
	var opts := SimRunner.parse_campaign_args(PackedStringArray(["campaign", "--runs", "1"]))
	assert_str(SimRunner.campaign_report(opts)["md"]).is_equal(
		SimRunner.campaign_report(opts)["md"]
	)


func test_bad_campaign_args_are_rejected() -> void:
	for args in [
		["campaign", "--runs"], ["campaign", "--runs", "0"], ["campaign", "--fights", "5"]
	]:
		var opts := SimRunner.parse_campaign_args(PackedStringArray(args))
		assert_bool(opts.has("error")).override_failure_message(str(args)).is_true()


func _real_save_checksums() -> Dictionary:
	var out := {}
	for path in REAL_SAVE_FILES:
		out[path] = FileAccess.get_md5(path) if FileAccess.file_exists(path) else ""
	return out
