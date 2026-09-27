## Smoke test for the headless sim runner (#56): one tiny report (1 build,
## 5 fights per cell) must produce its tables, so CI catches the runner or
## the sim breaking. Also checks the sim never touches the real save.
##
## The sim builds throwaway heroes and never awards XP (a level can unlock a
## skin, and unlocking a skin saves the game: see scripts/dev/balance_sim.gd).
extends GdUnitTestSuite

const SimRunner := preload("res://scripts/dev/sim_runner.gd")
## The real save files, by their default paths. Checked, never written.
const REAL_SAVE_FILES: Array[String] = [
	"user://save.json",
	"user://save.bak.json",
	"user://save.tmp.json",
	"user://save.corrupt.json",
]


func test_tiny_report_produces_tables() -> void:
	var before := _real_save_checksums()
	var opts := SimRunner.parse_args(PackedStringArray(["tank", "--fights", "5", "--seed", "3"]))
	assert_bool(opts.has("error")).override_failure_message(str(opts.get("error"))).is_false()

	var md := SimRunner.report(opts)

	assert_str(md).contains("**Seed:** 3")
	assert_str(md).contains("| Cell | tank |")
	for cell in ["D1_F1", "D3_F4", "D4_BOSS"]:
		assert_str(md).contains("| %s | " % cell)
	assert_str(md).contains("| slash | cleave | provoke | execute |")
	assert_str(md).contains("| tank | **all** |")
	assert_dict(_real_save_checksums()).is_equal(before)


func test_same_seed_same_report() -> void:
	var opts := SimRunner.parse_args(PackedStringArray(["none", "--fights", "2"]))
	assert_str(SimRunner.report(opts)).is_equal(SimRunner.report(opts))


func test_bad_args_are_rejected() -> void:
	assert_bool(SimRunner.parse_args(PackedStringArray(["nope"])).has("error")).is_true()
	assert_bool(SimRunner.parse_args(PackedStringArray(["--fights"])).has("error")).is_true()
	assert_bool(SimRunner.parse_args(PackedStringArray(["--level", "11"])).has("error")).is_true()


func _real_save_checksums() -> Dictionary:
	var out := {}
	for path in REAL_SAVE_FILES:
		out[path] = FileAccess.get_md5(path) if FileAccess.file_exists(path) else ""
	return out
