## Headless runner for the balance sim (dev tool — not used by the game).
##
## Runs as a scene so the autoloads (Party, GameState) exist, which the sim
## needs. Reads the user args, runs the Warrior talent-build report, prints it
## as Markdown and quits. Usage (see tools/sim.sh):
##     tools/sim.sh all --fights 200
##     tools/sim.sh tank executioner --seed 7 --level 10 --out docs/reports/x.md
##
## Arguments: build names (or "all"), then any of
##   --fights N   fights per cell (default 100)
##   --seed N     RNG seed, printed in the report (default 1)
##   --level N    every hero at level N instead of LEVEL_BY_DUNGEON
##   --out PATH   also write the report to PATH (relative to the project)
##
## SAFETY: this never calls GameState.save_game(). See balance_sim.gd.
extends Node

const PARTY: Array[String] = ["warrior", "cleric", "rogue", "mage"]
## Gear one tier behind the depth: encounter_report's "realistic" setting.
const GEAR_OFFSET := -1
## The Warrior's base skills, in class order: the usage table's columns.
const WARRIOR_SKILLS: Array[String] = ["slash", "cleave", "provoke", "execute"]

## Talent builds: {skill basename: {"fork": "a"|"b", "boost": bool}}, spent in
## this order (see BalanceSim.apply_build). Each uses exactly the 5 SP of
## level 10. Forks: Slash a Rending / b Momentum, Cleave a Wide Arc / b Heavy
## Arc, Provoke a Iron Wall / b Vengeance, Execute a Reaper / b Sunder.
const BUILDS := {
	"none": {},
	"tank":
	{
		"warrior_provoke": {"fork": "b", "boost": true},
		"warrior_slash": {"fork": "b", "boost": false},
		"warrior_cleave": {"fork": "a", "boost": false},
		"warrior_execute": {"fork": "a", "boost": false},
	},
	"executioner":
	{
		"warrior_execute": {"fork": "b", "boost": true},
		"warrior_slash": {"fork": "a", "boost": false},
		"warrior_cleave": {"fork": "b", "boost": false},
		"warrior_provoke": {"fork": "a", "boost": false},
	},
}


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var opts := parse_args(args)
	if opts.has("error"):
		printerr("sim_runner: %s" % opts["error"])
		get_tree().quit(2)
		return
	var md := report(opts)
	print(md)
	if str(opts["out"]) != "":
		var f := FileAccess.open(str(opts["out"]), FileAccess.WRITE)
		if f == null:
			printerr("sim_runner: can't write %s" % opts["out"])
			get_tree().quit(1)
			return
		f.store_string(md)
		f.close()
	get_tree().quit(0)


## Turns user args into {builds, fights, seed, level, out, args}, or
## {error: message} when they don't parse.
static func parse_args(args: PackedStringArray) -> Dictionary:
	var opts := {"builds": [], "fights": 100, "seed": 1, "level": 0, "out": "", "args": args}
	var i := 0
	while i < args.size():
		var a := args[i]
		if a in ["--fights", "--seed", "--level", "--out"]:
			if i + 1 >= args.size():
				return {"error": "%s needs a value" % a}
			var v := args[i + 1]
			if a == "--out":
				opts["out"] = v if v.contains("://") else "res://" + v
			elif not v.is_valid_int():
				return {"error": "%s needs a number, got %s" % [a, v]}
			else:
				opts[a.trim_prefix("--")] = int(v)
			i += 2
			continue
		if a == "all":
			opts["builds"].append_array(BUILDS.keys())
		elif BUILDS.has(a):
			opts["builds"].append(a)
		else:
			return {"error": "unknown build or option: %s (builds: %s)" % [a, BUILDS.keys()]}
		i += 1
	if (opts["builds"] as Array).is_empty():
		opts["builds"] = BUILDS.keys()
	if int(opts["fights"]) < 1:
		return {"error": "--fights must be at least 1"}
	if int(opts["level"]) < 0 or int(opts["level"]) > Party.LEVEL_CAP:
		return {"error": "--level must be 1..%d" % Party.LEVEL_CAP}
	return opts


## Runs every requested build and returns the Markdown report. Each build is
## reseeded with the same seed, so builds face the same RNG stream.
static func report(opts: Dictionary) -> String:
	var builds: Array = opts["builds"]
	var fights: int = opts["fights"]
	var levels: Array = BalanceSim.LEVEL_BY_DUNGEON
	if int(opts["level"]) > 0:
		levels = [opts["level"], opts["level"], opts["level"], opts["level"]]

	var results: Dictionary = {}  # build -> encounter_report output
	var usages: Dictionary = {}  # build -> {dungeon level: {class id: usage}}
	for b in builds:
		seed(int(opts["seed"]))
		var usage: Dictionary = {}
		results[b] = BalanceSim.encounter_report(
			PARTY, fights, levels, GEAR_OFFSET, BUILDS[b], usage
		)
		usages[b] = usage

	var lines: PackedStringArray = []
	lines.append("# Sim: Warrior talent builds")
	lines.append("")
	lines.append(
		"Generated output: `tools/sim.sh %s`. Don't edit by hand." % " ".join(opts["args"])
	)
	lines.append("")
	lines.append("- **Seed:** %d (each build reseeded)" % int(opts["seed"]))
	lines.append("- **Sample:** %d fights per cell, each from full HP" % fights)
	lines.append("- **Party:** %s" % ", ".join(PARTY))
	lines.append(
		(
			"- **Levels by dungeon 1-4:** %s (Warrior SP %s)"
			% [levels, levels.map(func(l): return Party.talent_sp_for_level(int(l)))]
		)
	)
	lines.append(
		"- **Gear:** best droppable item one tier behind the depth (offset %d)" % GEAR_OFFSET
	)
	lines.append("- **Policy:** balance_sim `_player_turn` (Warrior Provoke rule included)")
	lines.append("")
	lines.append_array(_talents_table(builds, levels))
	lines.append_array(_win_table(builds, results))
	lines.append_array(_usage_table(builds, usages, levels))
	return "\n".join(lines) + "\n"


## What each build actually bought at each dungeon's level.
static func _talents_table(builds: Array, levels: Array) -> PackedStringArray:
	var out: PackedStringArray = ["## Talents taken", ""]
	out.append("| Build | D1 (L%d) | D2 (L%d) | D3 (L%d) | D4 (L%d) |" % levels)
	out.append("|---|---|---|---|---|")
	for b in builds:
		var row := "| %s |" % b
		for dl in 4:
			var h: Hero = BalanceSim.make_party(["warrior"], int(levels[dl]), -1, BUILDS[b])[0]
			var picks: PackedStringArray = []
			for s in h.class_data.skills:
				var t := Party.get_talent(h, s)
				if t.is_empty():
					continue
				var variant := Party.get_effective_skill(h, s).id
				picks.append(variant + ("+" if t.get("boost", false) else ""))
			if h.sp_available > 0:
				picks.append("%d SP unspent" % h.sp_available)
			row += " %s |" % (", ".join(picks) if not picks.is_empty() else "-")
		out.append(row)
	out.append("")
	out.append("`+` = boosted.")
	out.append("")
	return out


## Win % and average rounds per cell, one column per build.
static func _win_table(builds: Array, results: Dictionary) -> PackedStringArray:
	var out: PackedStringArray = ["## Win % (average rounds)", ""]
	out.append("| Cell | %s |" % " | ".join(builds))
	out.append("|---|%s" % "---|".repeat(builds.size()))
	var first: Dictionary = results[builds[0]]
	for cell in first:
		var row := "| %s |" % cell
		for b in builds:
			var r: Dictionary = results[b][cell]
			row += " %d%% (%.1f) |" % [int(r["win%"]), float(r["rounds"])]
		out.append(row)
	out.append("")
	return out


## The Warrior's share of actions per skill, and distinct skills per fight
## (averaged over the fights he acted in), per dungeon and in total.
static func _usage_table(builds: Array, usages: Dictionary, levels: Array) -> PackedStringArray:
	var out: PackedStringArray = ["## Warrior skill usage (% of his actions)", ""]
	out.append(
		"| Build | Dungeon | %s | Actions | Distinct skills / fight |" % " | ".join(WARRIOR_SKILLS)
	)
	out.append("|---|---|%s---|---|" % "---|".repeat(WARRIOR_SKILLS.size()))
	for b in builds:
		var total := {"actions": {}, "fights": 0, "distinct": 0}
		for dl in range(1, 5):
			var u: Dictionary = usages[b].get(dl, {}).get("warrior", {})
			if u.is_empty():
				continue
			out.append(_usage_row(b, "D%d (L%d)" % [dl, int(levels[dl - 1])], u))
			for sid in u["actions"]:
				total["actions"][sid] = int(total["actions"].get(sid, 0)) + int(u["actions"][sid])
			total["fights"] += int(u["fights"])
			total["distinct"] += int(u["distinct"])
		out.append(_usage_row(b, "**all**", total))
	out.append("")
	out.append(
		"Slice target (combat-v3 §4): 3+ distinct skills per fight, no skill above 50% of actions."
	)
	out.append("")
	return out


static func _usage_row(build: String, label: String, u: Dictionary) -> String:
	var actions: Dictionary = u["actions"]
	var n := 0
	for sid in actions:
		n += int(actions[sid])
	var row := "| %s | %s |" % [build, label]
	for sid in WARRIOR_SKILLS:
		row += " %d%% |" % roundi(100.0 * float(actions.get(sid, 0)) / float(maxi(1, n)))
	var distinct := float(u["distinct"]) / float(maxi(1, int(u["fights"])))
	row += " %d | %.2f |" % [n, distinct]
	return row
