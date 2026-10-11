## Smoke test for the campaign bot (#61, #66): one campaign on a fixed seed must
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
		"| Dungeon | Level at boss | Fights | Rounds / fight | Est. minutes | Wipes | Stuck % |"
	)
	for dl in range(1, 5):
		assert_str(md).contains("| D%d |" % dl)
	assert_str(md).contains("| Dungeon | Campaigns in | Level at entry | Level at boss |")
	assert_str(md).contains("| Dungeon | Campaigns in | Wipes / campaign |")
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
		["campaign", "--runs"],
		["campaign", "--runs", "0"],
		["campaign", "--fights", "5"],
		["campaign", "--xp-mult"],
		["campaign", "--xp-mult", "0"],
		["campaign", "--xp-mult", "lots"]
	]:
		var opts := SimRunner.parse_campaign_args(PackedStringArray(args))
		assert_bool(opts.has("error")).override_failure_message(str(args)).is_true()


func _real_save_checksums() -> Dictionary:
	var out := {}
	for path in REAL_SAVE_FILES:
		out[path] = FileAccess.get_md5(path) if FileAccess.file_exists(path) else ""
	return out


func test_xp_mult_option_and_what_if_rows() -> void:
	var one := SimRunner.parse_campaign_args(
		PackedStringArray(["campaign", "--xp-mult", "2.5", "--runs", "1"])
	)
	assert_array(one["mults"]).is_equal([2.5])
	var all := SimRunner.parse_campaign_args(PackedStringArray(["campaign"]))
	assert_array(all["mults"]).is_equal([1.0, 2.0, 3.0, 4.0])

	var res := SimRunner.campaign_report(
		SimRunner.parse_campaign_args(PackedStringArray(["campaign", "--runs", "1", "--seed", "3"]))
	)
	var md: String = res["md"]
	assert_str(md).contains("## XP what-if")
	for m in ["x1.0", "x2.0", "x3.0", "x4.0"]:
		assert_str(md).contains("| %s |" % m)
	assert_array(res["guard"]["changed"]).is_empty()


func test_more_xp_means_higher_levels() -> void:
	var mults: Array[float] = [1.0, 4.0]
	var res := CampaignBot.run_isolated(1, 3, SimRunner.BUILDS[SimRunner.CAMPAIGN_BUILD], mults)
	assert_array(res["guard"]["changed"]).is_empty()
	var low: Array = res["batches"][0]["campaigns"][0]["dungeons"][0]["boss_levels"]
	var high: Array = res["batches"][1]["campaigns"][0]["dungeons"][0]["boss_levels"]
	assert_int(high.reduce(func(a, b): return a + b)).is_greater(
		low.reduce(func(a, b): return a + b)
	)
