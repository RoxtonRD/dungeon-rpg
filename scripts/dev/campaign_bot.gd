## Campaign bot (dev tool — not used by the game).
##
## Autoplays whole campaigns (dungeons 1-4) with real XP and attrition, to
## measure the level curve, run length and difficulty instead of assuming them
## (BalanceSim.LEVEL_BY_DUNGEON). Run it with `tools/sim.sh campaign` (see
## sim_runner.gd); the report is built by `report()`.
##
## Policy per campaign (brief #61):
##   - a fresh level-1 party with the starter items enters dungeon 1;
##   - each floor: visit every reachable room in BFS order, then the stairs;
##     the boss last on floor 4;
##   - fights use BalanceSim's policy with the party's current HP/MP (attrition
##     carries over); rest rooms rest, treasure is taken but its loot ignored,
##     events and shrines are left alone;
##   - in the city between dungeons: full heal, the Warrior spends new SP by a
##     build order, and gear is reset to BalanceSim's "one tier behind" model;
##   - a campaign ends at a TPK or after the dungeon 4 boss.
##
## SAFETY: unlike the rest of the sim this DOES award XP, and it drives the
## real DungeonRun helpers, which act on the Party and GameState autoloads.
## Awarding XP can unlock a skin, and unlocking a skin SAVES THE GAME. So
## `run_isolated()` points GameState.save_dir at a scratch folder, swaps the
## bot's heroes into Party.heroes, snapshots everything else it can touch, and
## restores it all afterwards; it also checksums the real save files before
## and after. Always go through run_isolated().
class_name CampaignBot
extends RefCounted

const PARTY: Array[String] = ["warrior", "cleric", "rogue", "mage"]
## Scratch save folder for a bot run. Deleted afterwards.
const SCRATCH_DIR := "user://bot_runs/campaign"
const SCRATCH_ROOT := "user://bot_runs"
## Gear one tier behind the depth, as the talent-build report (#56) assumes.
const GEAR_OFFSET := -1
## A fled or stalled fight leaves the room's content in place and the bot
## re-engages it; after this many tries it walks on and leaves the room.
const MAX_REENGAGE := 10
## Time estimate: seconds per party action and per enemy action (brief #61).
const SECONDS_PER_PARTY_ACTION := 5.0
const SECONDS_PER_ENEMY_ACTION := 1.5
## Run-length target for one dungeon, in minutes (D-013).
const TARGET_MINUTES := [15, 20]

# ── Isolation ─────────────────────────────────────────────────────────────────


## Plays `runs` campaigns from seed `seed_value` and returns
## {"campaigns": [...], "guard": {...}} (see _play_campaign and _save_guard).
## Every campaign's heroes spend SP by `build` (see BalanceSim.apply_build).
##
## GDScript has no try/finally. A script error aborts only the function it
## happens in, so the risky work lives in _run_all() and the restore below it
## runs whatever happens in there: that call boundary is the "finally".
static func run_isolated(runs: int, seed_value: int, build: Dictionary) -> Dictionary:
	var real_paths: Array[String] = [
		GameState.save_path, GameState.backup_path, GameState.tmp_path, GameState.corrupt_path
	]
	var md5_before := _checksums(real_paths)
	var snapshot := {
		"save_dir": GameState.save_dir,
		"owned_skins": GameState.owned_skins.duplicate(),
		"gold": GameState.gold,
		"inventory": GameState.inventory.duplicate(),
		"turn_counter": GameState.turn_counter,
		"current_run": GameState.current_run,
		"heroes": Party.heroes,
	}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SCRATCH_DIR))
	GameState.save_dir = SCRATCH_DIR

	var campaigns = _run_all(runs, seed_value, build)

	# The "finally" path: put back everything the bot could have touched.
	GameState.save_dir = snapshot["save_dir"]
	GameState.owned_skins.assign(snapshot["owned_skins"])
	GameState.gold = snapshot["gold"]
	GameState.inventory.assign(snapshot["inventory"])
	GameState.turn_counter = snapshot["turn_counter"]
	GameState.current_run = snapshot["current_run"]
	Party.heroes = snapshot["heroes"]
	_delete_scratch()

	var md5_after := _checksums(real_paths)
	var changed: Array[String] = []
	for path in real_paths:
		if md5_before[path] != md5_after[path]:
			changed.append(path)
	return {
		"campaigns": campaigns if campaigns is Array else [],
		"guard": {"checked": real_paths, "changed": changed, "md5": md5_before},
	}


## MD5 of each file ("" when it doesn't exist).
static func _checksums(paths: Array[String]) -> Dictionary:
	var out := {}
	for path in paths:
		out[path] = FileAccess.get_md5(path) if FileAccess.file_exists(path) else ""
	return out


static func _delete_scratch() -> void:
	for file in DirAccess.get_files_at(SCRATCH_DIR):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SCRATCH_DIR.path_join(file)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SCRATCH_DIR))
	if DirAccess.get_files_at(SCRATCH_ROOT).is_empty():
		if DirAccess.get_directories_at(SCRATCH_ROOT).is_empty():
			DirAccess.remove_absolute(ProjectSettings.globalize_path(SCRATCH_ROOT))


static func _run_all(runs: int, seed_value: int, build: Dictionary) -> Array:
	seed(seed_value)
	var out: Array = []
	for i in runs:
		out.append(_play_campaign(build))
	return out


# ── One campaign ──────────────────────────────────────────────────────────────


## Plays dungeons 1-4 with one party. Returns
## {"dungeons": [per-dungeon stats, see _play_dungeon], "talents": String}
## where `talents` is the Warrior's loadout when the campaign ended.
static func _play_campaign(build: Dictionary) -> Dictionary:
	var heroes := BalanceSim.make_party(PARTY, 1)
	Party.heroes = heroes
	GameState.gold = GameState.STARTING_GOLD
	GameState.inventory.assign(GameState.STARTER_ITEMS)
	GameState.turn_counter = 0
	GameState.current_run = null
	var dungeons: Array = []
	for dl in range(1, 5):
		_city(heroes, dl, build)
		var d := _play_dungeon(heroes, dl)
		dungeons.append(d)
		if str(d["tpk"]) != "":
			break
	return {"dungeons": dungeons, "talents": _talent_label(heroes[0])}


## The city before dungeon `dl`: the Warrior spends his SP, gear is set for the
## depth, then a full heal (after the gear, so the maxima are right).
static func _city(heroes: Array[Hero], dl: int, build: Dictionary) -> void:
	for h in heroes:
		if h.class_data.uses_talents:
			BalanceSim.apply_build(h, build)
		var tier := clampi(dl - 1 + GEAR_OFFSET, -1, 3)
		h.equipment = {"weapon": null, "armor": null, "trinket": null}
		if tier >= 0:
			BalanceSim._equip_best(h, tier)
	BalanceSim.heal_party(heroes)


## Plays one dungeon. Returns its stats:
## {dl, entry_levels, boss_levels ([] if the boss wasn't reached), sp,
##  fights, rounds (one entry per fight, 1-based), party_actions,
##  enemy_actions, rests, moves, unresolved, boss_hp (-1 if not reached),
##  tpk ("" | "F1".."F4" | "boss")}.
static func _play_dungeon(heroes: Array[Hero], dl: int) -> Dictionary:
	var d := {
		"dl": dl,
		"entry_levels": _levels(heroes),
		"boss_levels": [],
		"sp": 0,
		"fights": 0,
		"rounds": [],
		"party_actions": 0,
		"enemy_actions": 0,
		"rests": 0,
		"moves": 0,
		"unresolved": 0,
		"boss_hp": -1.0,
		"tpk": "",
	}
	var run := DungeonRun.generate(dl)
	for fl in DungeonRun.NUM_FLOORS:
		var rooms: Dictionary = run.rooms_on_floor()
		var visited: Dictionary = {Vector2i.ZERO: true}
		for pos in _bfs_order(rooms):
			if (rooms[pos] as DungeonRoom).kind == DungeonRoom.RoomType.BOSS:
				continue  # the boss comes last
			_walk_to(run, pos, visited, d)
			if not _resolve_room(run, heroes, d, "F%d" % (fl + 1)):
				return _finish(d, heroes)
		if not run.is_boss_floor():
			_walk_to(run, _find_room(rooms, DungeonRoom.RoomType.STAIRS), visited, d)
			run.descend()
			continue
		_walk_to(run, _find_room(rooms, DungeonRoom.RoomType.BOSS), visited, d)
		d["boss_levels"] = _levels(heroes)
		d["boss_hp"] = BalanceSim._party_hp_pct(heroes)
		_resolve_room(run, heroes, d, "boss")
	return _finish(d, heroes)


static func _finish(d: Dictionary, heroes: Array[Hero]) -> Dictionary:
	d["sp"] = Party.talent_sp_for_level(heroes[0].level)
	return d


## Triggers the room the party stands in, as dungeon_map.gd's _trigger_room
## would, with the bot's choices. Returns false on a TPK (recorded in `d`).
static func _resolve_room(
	run: DungeonRun, heroes: Array[Hero], d: Dictionary, where: String
) -> bool:
	var room := run.current_room()
	if not room.has_content():
		return true
	match room.kind:
		DungeonRoom.RoomType.COMBAT, DungeonRoom.RoomType.BOSS:
			var is_boss := room.kind == DungeonRoom.RoomType.BOSS
			for attempt in MAX_REENGAGE:
				var enemies: Array[EnemyData] = (
					run.roll_boss() if is_boss else run.roll_encounter(run.current_floor)
				)
				var res := BalanceSim.fight(heroes, enemies, {})
				d["fights"] += 1
				(d["rounds"] as Array).append(int(res["rounds"]) + 1)
				d["party_actions"] += int(res["party_actions"])
				d["enemy_actions"] += int(res["enemy_actions"])
				match int(res["result"]):
					CombatState.Result.VICTORY:
						_award_xp(heroes, int(res["xp"]))
						room.cleared = true
						return true
					CombatState.Result.DEFEAT:
						d["tpk"] = where
						return false
			# Fled (or stalled) every time: the room keeps its content.
			d["unresolved"] += 1
		DungeonRoom.RoomType.REST:
			run.resolve_rest()
			d["rests"] += 1
			room.cleared = true
		DungeonRoom.RoomType.TREASURE:
			run.resolve_treasure()  # gold and items land in the isolated GameState
			room.cleared = true
		DungeonRoom.RoomType.EVENT:
			# Every event's second option is the leave / move-on one.
			var event := run.roll_event()
			(event["options"][1]["effect"] as Callable).call()
			room.cleared = true
		DungeonRoom.RoomType.SHRINE:
			room.cleared = true  # left alone: a shrine grants a skin
	return true


## Splits a victory's XP across the party the way the game does. The rule
## lives only in UI code, so it is mirrored here (tech debt): source is
## scripts/combat/combat_screen.gd, _show_end_panel(), lines 721-737. Each hero
## gets total / party size (integer division); a downed hero gets half of that
## and stays downed.
static func _award_xp(heroes: Array[Hero], xp_total: int) -> void:
	var xp_share := xp_total / maxi(1, heroes.size())
	for h in heroes:
		var was_down := not h.is_alive()
		var xp_award := xp_share
		if was_down:
			xp_award /= 2
		Party.award_xp(h, xp_award)
		if was_down:
			h.hp = 0


# ── Map walking ───────────────────────────────────────────────────────────────


## Every room on the floor in BFS order from the start room (neighbours in
## DungeonRoom.DIRS order), start room excluded.
static func _bfs_order(rooms: Dictionary) -> Array[Vector2i]:
	var order: Array[Vector2i] = []
	var seen := {Vector2i.ZERO: true}
	var queue: Array[Vector2i] = [Vector2i.ZERO]
	while not queue.is_empty():
		var pos: Vector2i = queue.pop_front()
		for next in _neighbours(rooms, pos):
			if not seen.has(next):
				seen[next] = true
				order.append(next)
				queue.append(next)
	return order


static func _neighbours(rooms: Dictionary, pos: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var room: DungeonRoom = rooms[pos]
	for dir in DungeonRoom.DIRS:
		var npos: Vector2i = pos + dir["vec"]
		if (room.connections & dir["bit"]) != 0 and rooms.has(npos):
			out.append(npos)
	return out


## Walks to `target` one room at a time through rooms already visited (in BFS
## order a room's parent is always visited first, so a path exists). Each step
## is a real move_to, so statuses tick as they do in the game. Rooms passed
## through are not re-triggered.
static func _walk_to(run: DungeonRun, target: Vector2i, visited: Dictionary, d: Dictionary) -> void:
	var rooms: Dictionary = run.rooms_on_floor()
	var came_from := {run.player_pos: run.player_pos}
	var queue: Array[Vector2i] = [run.player_pos]
	while not queue.is_empty() and not came_from.has(target):
		var pos: Vector2i = queue.pop_front()
		for next in _neighbours(rooms, pos):
			if came_from.has(next) or (next != target and not visited.has(next)):
				continue
			came_from[next] = pos
			queue.append(next)
	var path: Array[Vector2i] = []
	var step := target
	while step != run.player_pos:
		path.push_front(step)
		step = came_from[step]
	for pos in path:
		run.move_to(pos)
		d["moves"] += 1
	visited[target] = true


static func _find_room(rooms: Dictionary, kind: DungeonRoom.RoomType) -> Vector2i:
	for pos in rooms:
		if (rooms[pos] as DungeonRoom).kind == kind:
			return pos
	return Vector2i.ZERO


static func _levels(heroes: Array[Hero]) -> Array:
	return heroes.map(func(h): return h.level)


## The Warrior's talents as "variant(+), ...", "+" = boosted; "-" for none.
static func _talent_label(h: Hero) -> String:
	var picks: PackedStringArray = []
	for s in h.class_data.skills:
		var t := Party.get_talent(h, s)
		if not t.is_empty():
			picks.append(
				Party.get_effective_skill(h, s).id + ("+" if t.get("boost", false) else "")
			)
	return ", ".join(picks) if not picks.is_empty() else "-"


# ── Report ────────────────────────────────────────────────────────────────────


## The Markdown report for `campaigns` (run_isolated's output). `command` is
## the command line that produced it, printed in the header.
static func report(
	campaigns: Array, seed_value: int, build_name: String, command: String
) -> String:
	var n := campaigns.size()
	var lines: PackedStringArray = []
	lines.append("# Sim: campaign bot")
	lines.append("")
	lines.append("Generated output: `%s`. Don't edit by hand." % command)
	lines.append("")
	lines.append("- **Seed:** %d (one seed for the whole batch)" % seed_value)
	lines.append("- **Sample:** %d campaigns, each dungeons 1-4 with one party" % n)
	lines.append("- **Party:** %s, level 1, starter items" % ", ".join(PARTY))
	lines.append(
		(
			"- **XP:** real, split as the game does (share = total / 4, half for downed "
			+ "heroes; mirrored from `combat_screen.gd`)"
		)
	)
	lines.append("- **Warrior SP:** spent in the city by the `%s` build order (#56)" % build_name)
	lines.append(
		(
			"- **Gear:** best droppable item one tier behind the depth, reset in the "
			+ "city (D1 none, D2 common, D3 uncommon, D4 rare)"
		)
	)
	lines.append(
		(
			"- **Policy:** every reachable room in BFS order, stairs last, boss last; "
			+ "fights by balance_sim `_player_turn` with HP/MP carried over; rest rooms "
			+ "rest; events and shrines left; full heal in the city"
		)
	)
	lines.append(
		(
			"- **Rounds** count from 1 here (a fight won in its first round is 1). "
			+ "The talent-build report (#56) counts from 0: add 1 to compare."
		)
	)
	lines.append("")
	lines.append_array(_headline_table(campaigns))
	lines.append_array(_level_table(campaigns))
	lines.append_array(_length_table(campaigns))
	lines.append_array(_tpk_table(campaigns))
	lines.append_array(_talent_table(campaigns))
	lines.append_array(_limits())
	return "\n".join(lines) + "\n"


## Every dungeon record for dungeon `dl` across `campaigns`.
static func _records(campaigns: Array, dl: int) -> Array:
	var out: Array = []
	for c in campaigns:
		for d in c["dungeons"]:
			if int(d["dl"]) == dl:
				out.append(d)
	return out


## Records that went the whole dungeon (boss beaten): the fair sample for
## "how long is a dungeon".
static func _cleared(records: Array) -> Array:
	return records.filter(func(d): return str(d["tpk"]) == "")


static func _minutes(d: Dictionary) -> float:
	var secs := (
		float(d["party_actions"]) * SECONDS_PER_PARTY_ACTION
		+ float(d["enemy_actions"]) * SECONDS_PER_ENEMY_ACTION
	)
	return secs / 60.0


static func _headline_table(campaigns: Array) -> PackedStringArray:
	var out: PackedStringArray = ["## Headline", ""]
	out.append("| Dungeon | Level at boss | Fights | Rounds / fight | Est. minutes | TPK % |")
	out.append("|---|---|---|---|---|---|")
	for dl in range(1, 5):
		var recs := _records(campaigns, dl)
		if recs.is_empty():
			out.append("| D%d | not reached | | | | |" % dl)
			continue
		var done := _cleared(recs)
		var rounds := _all_rounds(recs)
		(
			out
			. append(
				(
					"| D%d | %s | %s | %s | %s | %d%% |"
					% [
						dl,
						_level_cell(recs, "boss_levels"),
						_avg_cell(done, "fights"),
						(
							"%.1f (p10 %d, p90 %d)"
							% [_mean(rounds), _pct(rounds, 0.1), _pct(rounds, 0.9)]
						),
						_minutes_cell(done),
						roundi(100.0 * float(recs.size() - done.size()) / float(recs.size())),
					]
				)
			)
		)
	out.append("")
	out.append(
		(
			(
				"Level: mean hero level (lowest-highest single hero). Fights and minutes: "
				+ "mean over the campaigns that beat that dungeon. TPK %%: of the campaigns "
				+ "that entered it. Target: %d-%d minutes per dungeon (D-013)."
			)
			% TARGET_MINUTES
		)
	)
	out.append("")
	return out


static func _level_table(campaigns: Array) -> PackedStringArray:
	var out: PackedStringArray = ["## Level curve", ""]
	out.append("| Dungeon | Campaigns in | Level at entry | Level at boss | Warrior SP earned |")
	out.append("|---|---|---|---|---|")
	for dl in range(1, 5):
		var recs := _records(campaigns, dl)
		if recs.is_empty():
			continue
		var sp: Array = recs.map(func(d): return int(d["sp"]))
		(
			out
			. append(
				(
					"| D%d | %d | %s | %s | %.1f (%d-%d) |"
					% [
						dl,
						recs.size(),
						_level_cell(recs, "entry_levels"),
						_level_cell(recs, "boss_levels"),
						_mean(sp),
						sp.min(),
						sp.max(),
					]
				)
			)
		)
	out.append("")
	out.append(
		(
			"Warrior SP earned: total by the end of that dungeon (talent SP comes at "
			+ "even levels), mean (min-max); it is spent in the city before the next one."
		)
	)
	out.append("")
	return out


static func _length_table(campaigns: Array) -> PackedStringArray:
	var out: PackedStringArray = ["## Run length and attrition", ""]
	out.append(
		(
			"| Dungeon | Fights | Party actions | Enemy actions | Est. minutes | "
			+ "Room moves | Rests | HP % entering boss |"
		)
	)
	out.append("|---|---|---|---|---|---|---|---|")
	for dl in range(1, 5):
		var done := _cleared(_records(campaigns, dl))
		if done.is_empty():
			continue
		var at_boss := _records(campaigns, dl).filter(func(d): return float(d["boss_hp"]) >= 0.0)
		var hp: Array = at_boss.map(func(d): return 100.0 * float(d["boss_hp"]))
		(
			out
			. append(
				(
					"| D%d | %s | %s | %s | %s | %s | %s | %d%% |"
					% [
						dl,
						_avg_cell(done, "fights"),
						_avg_cell(done, "party_actions"),
						_avg_cell(done, "enemy_actions"),
						_minutes_cell(done),
						_avg_cell(done, "moves"),
						_avg_cell(done, "rests"),
						roundi(_mean(hp)),
					]
				)
			)
		)
	out.append("")
	out.append(
		(
			(
				"Mean (min-max) over the campaigns that beat that dungeon. Est. minutes = "
				+ "%.0f s per party action + %.1f s per enemy action, combat only: walking, "
				+ "menus, the city and reading events are not counted, so real play is longer. "
				+ "HP %% entering the boss: party HP / party max HP (downed heroes count 0), "
				+ "over every campaign that reached the boss."
			)
			% [SECONDS_PER_PARTY_ACTION, SECONDS_PER_ENEMY_ACTION]
		)
	)
	out.append("")
	return out


static func _tpk_table(campaigns: Array) -> PackedStringArray:
	var out: PackedStringArray = ["## TPKs", ""]
	out.append("| Dungeon | Campaigns in | TPK % | F1 | F2 | F3 | F4 | Boss |")
	out.append("|---|---|---|---|---|---|---|---|")
	var total := 0
	var unresolved := 0
	for dl in range(1, 5):
		var recs := _records(campaigns, dl)
		if recs.is_empty():
			continue
		var where := {"F1": 0, "F2": 0, "F3": 0, "F4": 0, "boss": 0}
		for d in recs:
			unresolved += int(d["unresolved"])
			if str(d["tpk"]) != "":
				where[str(d["tpk"])] += 1
				total += 1
		(
			out
			. append(
				(
					"| D%d | %d | %d%% | %d | %d | %d | %d | %d |"
					% [
						dl,
						recs.size(),
						roundi(100.0 * float(_total_in(where)) / float(recs.size())),
						where["F1"],
						where["F2"],
						where["F3"],
						where["F4"],
						where["boss"],
					]
				)
			)
		)
	out.append("")
	(
		out
		. append(
			(
				(
					"A TPK ends the campaign. Campaigns finished: %d of %d (%d%% TPK overall). "
					+ "Rooms left after %d fled or stalled fights in a row: %d."
				)
				% [
					campaigns.size() - total,
					campaigns.size(),
					roundi(100.0 * float(total) / float(maxi(1, campaigns.size()))),
					MAX_REENGAGE,
					unresolved,
				]
			)
		)
	)
	out.append("")
	return out


static func _total_in(where: Dictionary) -> int:
	var n := 0
	for k in where:
		n += int(where[k])
	return n


## The Warrior's talents at the end of the campaigns that finished, most
## common first.
static func _talent_table(campaigns: Array) -> PackedStringArray:
	var counts := {}
	for c in campaigns:
		var ds: Array = c["dungeons"]
		if ds.size() == 4 and str(ds[3]["tpk"]) == "":
			counts[c["talents"]] = int(counts.get(c["talents"], 0)) + 1
	var out: PackedStringArray = ["## Warrior talents after dungeon 4", ""]
	if counts.is_empty():
		out.append("No campaign finished.")
		out.append("")
		return out
	var keys: Array = counts.keys()
	keys.sort_custom(
		func(a, b): return counts[a] > counts[b] or (counts[a] == counts[b] and str(a) < str(b))
	)
	out.append("| Talents | Campaigns |")
	out.append("|---|---|")
	for k in keys:
		out.append("| %s | %d |" % [k, counts[k]])
	out.append("")
	out.append("`+` = boosted. Bought in the city, so the dungeon 4 boss is fought without")
	out.append("the SP earned inside dungeon 4.")
	out.append("")
	return out


static func _limits() -> PackedStringArray:
	return PackedStringArray(
		[
			"## Limitations",
			"",
			"- Loot and the market are out: gear is the model above, treasure and drops",
			"  are ignored, and no potions are bought.",
			"- The fight policy never uses consumables, so the starter items go unused.",
			"- Only the Warrior spends SP. The Cleric, Rogue and Mage bank theirs, so",
			"  their skills stay at tier 1 and party power is understated at depth.",
			"- Events and shrines are always left, so their risks and rewards are out.",
			"- Rest rooms are used when first reached, whatever the party's HP.",
			"- The bot stops at the first TPK; the game would revive the party in the",
			"  city (25% HP, -20% gold) and let it retry.",
			"",
		]
	)


# ── Stats helpers ─────────────────────────────────────────────────────────────


static func _all_rounds(records: Array) -> Array:
	var out: Array = []
	for d in records:
		out.append_array(d["rounds"])
	return out


static func _mean(values: Array) -> float:
	if values.is_empty():
		return 0.0
	var t := 0.0
	for v in values:
		t += float(v)
	return t / float(values.size())


## Nearest-rank percentile `p` (0..1) of `values`.
static func _pct(values: Array, p: float) -> int:
	if values.is_empty():
		return 0
	var sorted := values.duplicate()
	sorted.sort()
	var idx := clampi(ceili(p * float(sorted.size())) - 1, 0, sorted.size() - 1)
	return int(sorted[idx])


## "mean (min-max)" of a per-record count.
static func _avg_cell(records: Array, key: String) -> String:
	if records.is_empty():
		return "-"
	var v: Array = records.map(func(d): return int(d[key]))
	return "%.1f (%d-%d)" % [_mean(v), v.min(), v.max()]


static func _minutes_cell(records: Array) -> String:
	if records.is_empty():
		return "-"
	var v: Array = records.map(func(d): return _minutes(d))
	return "%.1f (%.1f-%.1f)" % [_mean(v), v.min(), v.max()]


## "mean (lowest-highest)" over every hero's level in `key`.
static func _level_cell(records: Array, key: String) -> String:
	var all: Array = []
	for d in records:
		all.append_array(d[key])
	if all.is_empty():
		return "-"
	return "%.1f (%d-%d)" % [_mean(all), all.min(), all.max()]
