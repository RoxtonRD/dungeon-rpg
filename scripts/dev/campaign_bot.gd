## Campaign bot (dev tool — not used by the game).
##
## Autoplays whole campaigns (dungeons 1-4) with real XP and attrition, to
## measure the level curve, run length and difficulty instead of assuming them
## (BalanceSim.LEVEL_BY_DUNGEON). Run it with `tools/sim.sh campaign` (see
## sim_runner.gd); the report is built by `report()`.
##
## Policy per campaign (briefs #61 and #66):
##   - a fresh level-1 party with the starter items enters dungeon 1;
##   - each floor: visit every reachable room in BFS order, then the stairs;
##     the boss last on floor 4;
##   - fights use BalanceSim's policy with the party's current HP/MP (attrition
##     carries over), plus potions (see _potion_choice); treasure is taken but
##     its loot ignored, events and shrines are left alone;
##   - rest rooms are remembered and used only when party HP is under
##     REST_BELOW (the bot walks back to the nearest unused one);
##   - in the city before each dungeon: full heal, the Warrior spends new SP by
##     a build order, the others upgrade their skills in class order, gear is
##     reset to BalanceSim's "one tier behind" model, and the bot shops for
##     potions;
##   - a wipe applies the game's TPK rule and retries the same dungeon; the
##     third wipe in one dungeon ends the campaign as "stuck";
##   - `xp_mult` scales the XP awarded (what-if only, the game is untouched).
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
## Drink a heal potion when a hero is under this share of max HP and no
## healer can afford a heal skill.
const POTION_HP_BELOW := 0.35
## A mana caster under this share of max MP drinks a mana potion.
const POTION_MP_BELOW := 0.20
const MANA_CASTERS: Array[String] = ["mage", "cleric", "alchemist"]
## Use a remembered rest room only when party HP is under this share.
const REST_BELOW := 0.6
## City shopping: share of the gold spent on heal potions, then on mana potions.
const HEAL_BUDGET := 0.5
const MANA_BUDGET := 0.25
## Potions in the order they are bought (cheapest first).
const HEAL_SHOP: Array[String] = ["potion_heal", "elixir_full"]
const MANA_SHOP: Array[String] = ["potion_mana"]
## The third wipe in one dungeon ends the campaign as "stuck".
const MAX_WIPES := 3
## XP multipliers the report compares (what-if, bot only).
const XP_MULTS: Array[float] = [1.0, 2.0, 3.0, 4.0]
## The party level the what-if is looking for at the dungeon 4 boss.
const TARGET_LEVEL_MIN := 9.0
const TARGET_LEVEL_MAX := 10.0

## XP multiplier for the batch being played (set by _run_all; what-if only).
static var xp_mult := 1.0

# ── Isolation ─────────────────────────────────────────────────────────────────


## Plays `runs` campaigns per XP multiplier in `mults`, each batch from seed
## `seed_value`, and returns {"batches": [{"mult": float, "campaigns": [...]}],
## "guard": {...}} (see _play_campaign). The Warrior of every campaign spends
## SP by `build` (see BalanceSim.apply_build).
##
## GDScript has no try/finally. A script error aborts only the function it
## happens in, so the risky work lives in _run_all() and the restore below it
## runs whatever happens in there: that call boundary is the "finally".
static func run_isolated(
	runs: int, seed_value: int, build: Dictionary, mults: Array[float] = [1.0]
) -> Dictionary:
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

	var batches = _run_all(runs, seed_value, build, mults)
	xp_mult = 1.0

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
		"batches": batches if batches is Array else [],
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


static func _run_all(runs: int, seed_value: int, build: Dictionary, mults: Array[float]) -> Array:
	var out: Array = []
	for m in mults:
		xp_mult = m
		seed(seed_value)  # every multiplier faces the same RNG stream
		var campaigns: Array = []
		for i in runs:
			campaigns.append(_play_campaign(build))
		out.append({"mult": m, "campaigns": campaigns})
	return out


# ── One campaign ──────────────────────────────────────────────────────────────


## Plays dungeons 1-4 with one party. Returns
## {"dungeons": [per-dungeon record, see _dungeon_record], "talents": String}
## where `talents` is the Warrior's loadout when the campaign ended. A wipe
## applies the game's TPK rule and retries the same dungeon (a new layout)
## until MAX_WIPES, then the campaign stops.
static func _play_campaign(build: Dictionary) -> Dictionary:
	var heroes := BalanceSim.make_party(PARTY, 1)
	Party.heroes = heroes
	GameState.gold = GameState.STARTING_GOLD
	GameState.inventory.assign(GameState.STARTER_ITEMS)
	GameState.turn_counter = 0
	GameState.current_run = null
	GameState.restock_market()
	var dungeons: Array = []
	for dl in range(1, 5):
		var attempts: Array = []
		var stuck := false
		while true:
			var bought := _city(heroes, dl, build)
			var a := _play_dungeon(heroes, dl)
			a["potions_bought"] = bought
			attempts.append(a)
			if str(a["tpk"]) == "":
				GameState.restock_market()  # a finished run restocks, as in the game
				break
			GameState.apply_tpk_penalty()
			if _wipes(attempts) >= MAX_WIPES:
				stuck = true
				break
		dungeons.append(_dungeon_record(attempts, stuck))
		if stuck:
			break
	return {"dungeons": dungeons, "talents": _talent_label(heroes[0])}


static func _wipes(attempts: Array) -> int:
	return attempts.filter(func(a): return str(a["tpk"]) != "").size()


## One dungeon's record from its attempts (the last one beat it, or made the
## campaign stuck). It is the last attempt's stats, except: entry levels are
## the first attempt's, boss levels / HP come from the latest attempt that
## reached the boss, and rounds, potions and the *_all action counts cover
## every attempt. It adds {wipes, stuck, wipe_at: ["F2", ...], potions_used,
## potions_bought, party_actions_all, enemy_actions_all}.
static func _dungeon_record(attempts: Array, stuck: bool) -> Dictionary:
	var rec: Dictionary = (attempts[-1] as Dictionary).duplicate()
	rec["entry_levels"] = attempts[0]["entry_levels"]
	rec["rounds"] = []
	rec["wipes"] = _wipes(attempts)
	rec["stuck"] = stuck
	rec["wipe_at"] = []
	rec["potions_used"] = 0
	rec["potions_bought"] = 0
	rec["party_actions_all"] = 0
	rec["enemy_actions_all"] = 0
	for a in attempts:
		(rec["rounds"] as Array).append_array(a["rounds"])
		if str(a["tpk"]) != "":
			(rec["wipe_at"] as Array).append(str(a["tpk"]))
		rec["potions_used"] += int(a["potions_used"])
		rec["potions_bought"] += int(a["potions_bought"])
		rec["party_actions_all"] += int(a["party_actions"])
		rec["enemy_actions_all"] += int(a["enemy_actions"])
		if not (a["boss_levels"] as Array).is_empty():
			rec["boss_levels"] = a["boss_levels"]
			rec["boss_hp"] = a["boss_hp"]
	return rec


## The city before dungeon `dl`: spend SP, set gear for the depth, full heal
## (after the gear, so the maxima are right), then shop. Returns the number of
## potions bought.
static func _city(heroes: Array[Hero], dl: int, build: Dictionary) -> int:
	for h in heroes:
		if h.class_data.uses_talents:
			BalanceSim.apply_build(h, build)
		else:
			_spend_tiers(h)
		var tier := clampi(dl - 1 + GEAR_OFFSET, -1, 3)
		h.equipment = {"weapon": null, "armor": null, "trinket": null}
		if tier >= 0:
			BalanceSim._equip_best(h, tier)
	BalanceSim.heal_party(heroes)
	var gold := GameState.gold
	var n := _buy(HEAL_SHOP, roundi(gold * HEAL_BUDGET))
	return n + _buy(MANA_SHOP, roundi(gold * MANA_BUDGET))


## Upgrades a tier-class hero's skills in the class's skill order, one skill
## at a time until it is maxed or the SP is gone.
static func _spend_tiers(h: Hero) -> void:
	for s in h.class_data.skills:
		while Party.upgrade_skill(h, s):
			pass


## Buys potions from the market shelf in `ids` order while the price fits the
## `budget` and the gold. Returns how many were bought.
static func _buy(ids: Array[String], budget: int) -> int:
	var bought := 0
	for id in ids:
		var price := (load("res://resources/items/%s.tres" % id) as ItemData).value
		for entry in GameState.potion_stock:
			if str(entry["id"]) != id:
				continue
			while int(entry["qty"]) > 0 and price <= budget and price <= GameState.gold:
				entry["qty"] = int(entry["qty"]) - 1
				GameState.gold -= price
				budget -= price
				GameState.add_item(id)
				bought += 1
	return bought


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
		"potions_used": 0,
		"boss_hp": -1.0,
		"tpk": "",
	}
	var run := DungeonRun.generate(dl)
	for fl in DungeonRun.NUM_FLOORS:
		var rooms: Dictionary = run.rooms_on_floor()
		var visited: Dictionary = {Vector2i.ZERO: true}
		var rest_rooms: Array[Vector2i] = []  # remembered, not yet used
		for pos in _bfs_order(rooms):
			var room: DungeonRoom = rooms[pos]
			if room.kind == DungeonRoom.RoomType.BOSS:
				continue  # the boss comes last
			_walk_to(run, pos, visited, d)
			if room.kind == DungeonRoom.RoomType.REST:
				if BalanceSim._party_hp_pct(heroes) < REST_BELOW:
					_rest(run, room, d)
				else:
					rest_rooms.append(pos)  # save it for when the party needs it
			elif not _resolve_room(run, heroes, d, "F%d" % (fl + 1)):
				return _finish(d, heroes)
			_rest_if_needed(run, heroes, rest_rooms, visited, d)
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
		DungeonRoom.RoomType.COMBAT, DungeonRoom.RoomType.ELITE, DungeonRoom.RoomType.BOSS:
			var is_boss := room.kind == DungeonRoom.RoomType.BOSS
			var is_elite := room.kind == DungeonRoom.RoomType.ELITE
			for attempt in MAX_REENGAGE:
				# No elite policy yet (E4): an elite room is fought like any
				# other, from the elite groups, without the reward bonus.
				var enemies: Array[EnemyData] = (
					run.roll_boss() if is_boss else run.roll_encounter(run.current_floor, is_elite)
				)
				var res := _fight(heroes, enemies)
				d["fights"] += 1
				(d["rounds"] as Array).append(int(res["rounds"]) + 1)
				d["party_actions"] += int(res["party_actions"])
				d["enemy_actions"] += int(res["enemy_actions"])
				d["potions_used"] += int(res["potions"])
				match int(res["result"]):
					CombatState.Result.VICTORY:
						_award_xp(int(res["xp"]))
						room.cleared = true
						return true
					CombatState.Result.DEFEAT:
						d["tpk"] = where
						return false
			# Fled (or stalled) every time: the room keeps its content.
			d["unresolved"] += 1
		DungeonRoom.RoomType.REST:
			_rest(run, room, d)  # play_dungeon decides when; this is the fallback
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


## Rests the party in `room` (full HP/MP, statuses cleared).
static func _rest(run: DungeonRun, room: DungeonRoom, d: Dictionary) -> void:
	run.resolve_rest()
	d["rests"] += 1
	room.cleared = true


## While the party is under REST_BELOW and a remembered rest room is unused,
## walks back to the nearest one (through rooms already visited) and rests.
static func _rest_if_needed(
	run: DungeonRun,
	heroes: Array[Hero],
	rest_rooms: Array[Vector2i],
	visited: Dictionary,
	d: Dictionary
) -> void:
	if rest_rooms.is_empty() or BalanceSim._party_hp_pct(heroes) >= REST_BELOW:
		return
	var rooms: Dictionary = run.rooms_on_floor()
	var nearest := rest_rooms[0]
	for pos in rest_rooms:
		if _path_to(run, pos, visited).size() < _path_to(run, nearest, visited).size():
			nearest = pos
	_walk_to(run, nearest, visited, d)
	_rest(run, rooms[nearest], d)
	rest_rooms.erase(nearest)


## Awards a victory's XP through the game's own split rule
## (Party.distribute_combat_xp). `xp_total` is scaled by `xp_mult` first
## (what-if only).
static func _award_xp(xp_total: int) -> void:
	Party.distribute_combat_xp(roundi(float(xp_total) * xp_mult))


# ── Fights and potions ────────────────────────────────────────────────────────


## BalanceSim.fight's loop with the bot's potion rules in front of the shared
## `_player_turn` (which stays untouched, so the #56 report is reproducible).
## Returns {result, rounds, xp, party_actions, enemy_actions, potions}.
static func _fight(heroes: Array[Hero], enemy_list: Array[EnemyData]) -> Dictionary:
	var st := CombatState.build(heroes, enemy_list)
	st.start()
	var party_actions := 0
	var enemy_actions := 0
	var potions := 0
	var guard := 0
	while not st.ended and guard < BalanceSim.MAX_ROUNDS * 8:
		guard += 1
		var actor: Battler = st.current_actor
		if actor == null or st.round_number > BalanceSim.MAX_ROUNDS:
			break
		if actor.side == Battler.Side.ENEMY:
			st.step()
			enemy_actions += 1
			continue
		party_actions += 1
		var choice := _potion_choice(st, actor)
		if choice.is_empty():
			BalanceSim._player_turn(st, actor, {})
		else:
			st.player_item(str(choice["id"]), choice["target"])
			potions += 1
	return {
		"result": int(st.result),
		"rounds": st.round_number,
		"xp": int(st.rewards.get("xp", 0)),
		"party_actions": party_actions,
		"enemy_actions": enemy_actions,
		"potions": potions,
	}


## The potion the acting hero drinks this turn as {id, target}, or {}.
##   1. A hero is under POTION_HP_BELOW HP and no living healer can afford a
##      heal skill: the best heal potion on hand, on the most hurt hero.
##   2. Else a mana caster is under POTION_MP_BELOW MP: a mana potion, on self.
static func _potion_choice(st: CombatState, actor: Battler) -> Dictionary:
	var hurt: Battler = null
	for b in st.party:
		if not b.is_alive():
			continue
		if float(b.get_hp()) / float(maxi(1, b.max_hp)) < POTION_HP_BELOW:
			if hurt == null or b.get_hp() < hurt.get_hp():
				hurt = b
	if hurt != null and not _can_heal(st):
		var id := _best_heal_potion()
		if id != "":
			return {"id": id, "target": hurt}
	var hero := actor.hero
	if MANA_CASTERS.has(hero.class_data.id) and hero.max_mp() > 0:
		if float(hero.mp) / float(hero.max_mp()) < POTION_MP_BELOW:
			if GameState.inventory.has("potion_mana"):
				return {"id": "potion_mana", "target": actor}
	return {}


## True when a living party member can use a heal skill right now.
static func _can_heal(st: CombatState) -> bool:
	for b in st.party:
		if not b.is_alive():
			continue
		for s in b.hero.class_data.skills:
			if s.skill_type == SkillData.SkillType.HEAL and st.can_use(b, s):
				return true
	return false


## The id of the inventory's strongest heal potion (most HP restored), or "".
static func _best_heal_potion() -> String:
	var best := ""
	var best_heal := 0
	for id in GameState.inventory:
		var item := load("res://resources/items/%s.tres" % id) as ItemData
		if item != null and item.use_revive_party <= 0.0 and item.use_heal > best_heal:
			best = id
			best_heal = item.use_heal
	return best


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
	for pos in _path_to(run, target, visited):
		run.move_to(pos)
		d["moves"] += 1
	visited[target] = true


## The rooms to step through from the player to `target`, shortest first
## (`target` itself last; empty when already there). Only rooms in `visited`
## are crossed.
static func _path_to(run: DungeonRun, target: Vector2i, visited: Dictionary) -> Array[Vector2i]:
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
	return path


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


## The Markdown report for `batches` (run_isolated's output): the full tables
## for the first batch, then the XP what-if table over all of them. `command`
## is the command line that produced it, printed in the header.
static func report(batches: Array, seed_value: int, build_name: String, command: String) -> String:
	var campaigns: Array = batches[0]["campaigns"]
	var main_mult: float = batches[0]["mult"]
	var n := campaigns.size()
	var lines: PackedStringArray = []
	lines.append("# Sim: campaign bot")
	lines.append("")
	lines.append("Generated output: `%s`. Don't edit by hand." % command)
	lines.append("")
	lines.append("- **Seed:** %d (every XP multiplier is reseeded with it)" % seed_value)
	lines.append(
		"- **Sample:** %d campaigns per XP multiplier, each dungeons 1-4 with one party" % n
	)
	lines.append("- **Party:** %s, level 1, starter items" % ", ".join(PARTY))
	(
		lines
		. append(
			(
				(
					"- **XP:** real, split by `Party.distribute_combat_xp` (share = total / 4, half for downed "
					+ "heroes). The tables below are for "
					+ "**x%s XP**; the what-if section compares the multipliers (bot only, the "
					+ "game is untouched)"
				)
				% _mult_label(main_mult)
			)
		)
	)
	lines.append(
		(
			(
				"- **Skill points:** spent in the city. The Warrior by the `%s` build order "
				+ "(#56); the others upgrade their skills in class order, one skill at a time"
			)
			% build_name
		)
	)
	lines.append(
		(
			"- **Gear:** best droppable item one tier behind the depth, reset in the "
			+ "city (D1 none, D2 common, D3 uncommon, D4 rare)"
		)
	)
	lines.append(
		(
			"- **Policy:** every reachable room in BFS order, stairs last, boss last; "
			+ "fights by balance_sim `_player_turn` with HP/MP carried over; events and "
			+ "shrines left; full heal in the city"
		)
	)
	lines.append(
		(
			(
				"- **Potions:** a hero under %d%% HP drinks the best heal potion when no living "
				+ "healer can afford a heal skill; a Mage, Cleric or Alchemist under %d%% MP "
				+ "drinks a mana potion. Bought in the city with up to %d%% of the gold on heal "
				+ "potions, then %d%% on mana potions, from the market's limited stock"
			)
			% [
				roundi(POTION_HP_BELOW * 100.0),
				roundi(POTION_MP_BELOW * 100.0),
				roundi(HEAL_BUDGET * 100.0),
				roundi(MANA_BUDGET * 100.0)
			]
		)
	)
	lines.append(
		(
			(
				"- **Rest rooms:** remembered, and used only when party HP is under %d%% "
				+ "(the bot walks back to the nearest unused one; the moves are counted)"
			)
			% roundi(REST_BELOW * 100.0)
		)
	)
	lines.append(
		(
			(
				"- **Wipes:** the game's TPK rule (revive at 25%% HP, -20%% gold, market "
				+ "restocked), then the same dungeon again on a new layout. Wipe number %d in "
				+ "one dungeon ends the campaign as **stuck**"
			)
			% MAX_WIPES
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
	lines.append_array(_wipe_table(campaigns))
	lines.append_array(_talent_table(campaigns))
	lines.append_array(_what_if(batches))
	lines.append_array(_limits())
	return "\n".join(lines) + "\n"


static func _mult_label(m: float) -> String:
	return "%.1f" % m


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


## Combat minutes of the dungeon's clearing run, or of every attempt (wiped
## ones included) with `all_attempts`.
static func _minutes(d: Dictionary, all_attempts := false) -> float:
	var party := float(d["party_actions_all" if all_attempts else "party_actions"])
	var enemy := float(d["enemy_actions_all" if all_attempts else "enemy_actions"])
	return (party * SECONDS_PER_PARTY_ACTION + enemy * SECONDS_PER_ENEMY_ACTION) / 60.0


## Mean wipes per record.
static func _mean_wipes(records: Array) -> float:
	return _mean(records.map(func(d): return int(d["wipes"])))


## Percent of records that ended stuck.
static func _stuck_pct(records: Array) -> int:
	if records.is_empty():
		return 0
	return roundi(100.0 * float(records.filter(func(d): return d["stuck"]).size()) / records.size())


static func _headline_table(campaigns: Array) -> PackedStringArray:
	var out: PackedStringArray = ["## Headline", ""]
	out.append(
		"| Dungeon | Level at boss | Fights | Rounds / fight | Est. minutes | Wipes | Stuck % |"
	)
	out.append("|---|---|---|---|---|---|---|")
	for dl in range(1, 5):
		var recs := _records(campaigns, dl)
		if recs.is_empty():
			out.append("| D%d | not reached | | | | | |" % dl)
			continue
		var done := _cleared(recs)
		var rounds := _all_rounds(recs)
		var rounds_cell := (
			"%.1f (p10 %d, p90 %d)" % [_mean(rounds), _pct(rounds, 0.1), _pct(rounds, 0.9)]
		)
		var row := [
			dl,
			_level_cell(recs, "boss_levels"),
			_avg_cell(done, "fights"),
			rounds_cell,
			_minutes_cell(done),
			_mean_wipes(recs),
			_stuck_pct(recs),
		]
		out.append("| D%d | %s | %s | %s | %s | %.2f | %d%% |" % row)
	out.append("")
	out.append(
		(
			(
				"Level: mean hero level (lowest-highest single hero) at the boss, from the "
				+ "latest attempt that reached it. Fights and minutes: mean over the campaigns "
				+ "that beat that dungeon (the clearing run only). Wipes: mean per campaign "
				+ "that entered it. Stuck: %% of those that wiped out of the dungeon for "
				+ "good. Rounds / fight covers every fight, wiped runs included. Target: "
				+ "%d-%d minutes per dungeon (D-013)."
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
		var row := [
			dl,
			recs.size(),
			_level_cell(recs, "entry_levels"),
			_level_cell(recs, "boss_levels"),
			_mean(sp),
			sp.min(),
			sp.max(),
		]
		out.append("| D%d | %d | %s | %s | %.1f (%d-%d) |" % row)
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
			+ "Est. min incl. wiped runs | Room moves | Rests | Potions used | "
			+ "Potions bought | HP % entering boss |"
		)
	)
	out.append("|---|---|---|---|---|---|---|---|---|---|---|")
	for dl in range(1, 5):
		var done := _cleared(_records(campaigns, dl))
		if done.is_empty():
			continue
		var at_boss := _records(campaigns, dl).filter(func(d): return float(d["boss_hp"]) >= 0.0)
		var hp: Array = at_boss.map(func(d): return 100.0 * float(d["boss_hp"]))
		var all_min: Array = done.map(func(d): return _minutes(d, true))
		var row := [
			dl,
			_avg_cell(done, "fights"),
			_avg_cell(done, "party_actions"),
			_avg_cell(done, "enemy_actions"),
			_minutes_cell(done),
			_mean(all_min),
			_avg_cell(done, "moves"),
			_avg_cell(done, "rests"),
			_avg_cell(done, "potions_used"),
			_avg_cell(done, "potions_bought"),
			roundi(_mean(hp)),
		]
		out.append("| D%d | %s | %s | %s | %s | %.1f | %s | %s | %s | %s | %d%% |" % row)
	out.append("")
	out.append(
		(
			(
				"Mean (min-max) over the campaigns that beat that dungeon. Actions, moves, "
				+ "rests and potions used are the clearing run's; potions bought are for "
				+ "that run's city visit. Est. minutes = %.0f s per party action + %.1f s "
				+ "per enemy action, combat only: walking, menus, the city and reading events "
				+ 'are not counted, so real play is longer. "Incl. wiped runs" adds the '
				+ "combat time of the wiped attempts. HP %% entering the boss: party HP / "
				+ "party max HP (downed heroes count 0), over every campaign that reached "
				+ "the boss."
			)
			% [SECONDS_PER_PARTY_ACTION, SECONDS_PER_ENEMY_ACTION]
		)
	)
	out.append("")
	return out


static func _wipe_table(campaigns: Array) -> PackedStringArray:
	var out: PackedStringArray = ["## Wipes", ""]
	(
		out
		. append(
			"| Dungeon | Campaigns in | Wipes / campaign | 0 wipes | 1 | 2 | 3 (stuck) | At F1 | F2 | F3 | F4 | Boss |"
		)
	)
	out.append("|---|---|---|---|---|---|---|---|---|---|---|---|")
	var stuck := 0
	var unresolved := 0
	for dl in range(1, 5):
		var recs := _records(campaigns, dl)
		if recs.is_empty():
			continue
		var by_count := [0, 0, 0, 0]
		var where := {"F1": 0, "F2": 0, "F3": 0, "F4": 0, "boss": 0}
		for d in recs:
			unresolved += int(d["unresolved"])
			by_count[mini(int(d["wipes"]), 3)] += 1
			if d["stuck"]:
				stuck += 1
			for w in d["wipe_at"]:
				where[str(w)] += 1
		var row := [dl, recs.size(), _mean_wipes(recs)]
		row.append_array(by_count)
		for k in ["F1", "F2", "F3", "F4", "boss"]:
			row.append(where[k])
		out.append("| D%d | %d | %.2f | %d | %d | %d | %d | %d | %d | %d | %d | %d |" % row)
	out.append("")
	out.append(
		(
			(
				'Wipes counted over every attempt at that dungeon; the "At" columns say where '
				+ "the party died. Campaigns finished (dungeon 4 beaten): %d of %d; stuck: %d. "
				+ "Rooms left after %d fled or stalled fights in a row: %d."
			)
			% [
				campaigns.filter(func(c): return _finished(c)).size(),
				campaigns.size(),
				stuck,
				MAX_REENGAGE,
				unresolved,
			]
		)
	)
	out.append("")
	return out


## True when the campaign beat the dungeon 4 boss.
static func _finished(campaign: Dictionary) -> bool:
	var ds: Array = campaign["dungeons"]
	return ds.size() == 4 and str(ds[3]["tpk"]) == ""


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


## The XP what-if: the same campaigns with the XP awarded multiplied (bot only),
## one row per multiplier in `batches`.
static func _what_if(batches: Array) -> PackedStringArray:
	var out: PackedStringArray = ["## XP what-if", ""]
	out.append(
		(
			(
				"`--xp-mult` multiplies the XP awarded after each victory, in the bot only: "
				+ "the game's numbers are untouched. Each row replays %d campaigns from the same "
				+ "seed with the same policy, so the rows differ only by XP."
			)
			% (batches[0]["campaigns"] as Array).size()
		)
	)
	out.append("")
	out.append_array(_target_line(batches))
	out.append("")
	_what_if_table(out, "Level at each boss", batches, _cell_boss_level)
	_what_if_table(out, "Warrior SP earned by the end of each dungeon", batches, _cell_sp)
	_what_if_table(out, "Wipes per campaign that entered the dungeon", batches, _cell_wipes)
	_what_if_table(out, "Stuck (campaign ended in that dungeon)", batches, _cell_stuck)
	_what_if_table(out, "Est. minutes per dungeon (clearing run)", batches, _cell_minutes)
	_what_if_table(out, "Rounds per fight", batches, _cell_rounds)
	var fin := PackedStringArray(
		["### Campaigns finished", "", "| XP x | Beat dungeon 4 |", "|---|---|"]
	)
	for b in batches:
		var n: int = (b["campaigns"] as Array).size()
		var done: int = (b["campaigns"] as Array).filter(func(c): return _finished(c)).size()
		fin.append("| x%s | %d of %d |" % [_mult_label(b["mult"]), done, n])
	fin.append("")
	out.append_array(fin)
	return out


## Which multiplier lands the party at TARGET_LEVEL_MIN-TARGET_LEVEL_MAX at the
## dungeon 4 boss: the first inside the band, else the closest to it.
static func _target_line(batches: Array) -> PackedStringArray:
	var best := -1
	var best_gap := INF
	var best_mean := 0.0
	var best_n := 0
	for i in batches.size():
		var recs := _records(batches[i]["campaigns"], 4)
		var levels: Array = []
		for d in recs:
			levels.append_array(d["boss_levels"])
		if levels.is_empty():
			continue
		var m := _mean(levels)
		var gap := maxf(0.0, maxf(TARGET_LEVEL_MIN - m, m - TARGET_LEVEL_MAX))
		if gap < best_gap:
			best = i
			best_gap = gap
			best_mean = m
			best_n = recs.filter(func(d): return not (d["boss_levels"] as Array).is_empty()).size()
	if best < 0:
		return PackedStringArray(["**No multiplier reached the dungeon 4 boss.**"])
	var label := _mult_label(batches[best]["mult"])
	if best_gap == 0.0:
		return PackedStringArray(
			[
				(
					(
						"**Level %d-%d at the dungeon 4 boss: x%s XP** (mean hero level %.1f, over %d "
						+ "campaigns that reached it)."
					)
					% [int(TARGET_LEVEL_MIN), int(TARGET_LEVEL_MAX), label, best_mean, best_n]
				)
			]
		)
	return PackedStringArray(
		[
			(
				(
					"**No multiplier lands in level %d-%d at the dungeon 4 boss; the closest is "
					+ "x%s XP** (mean hero level %.1f, over %d campaigns that reached it)."
				)
				% [int(TARGET_LEVEL_MIN), int(TARGET_LEVEL_MAX), label, best_mean, best_n]
			)
		]
	)


## One what-if table: a row per multiplier, a column per dungeon, each cell
## built by `cell(records) -> String` from that dungeon's records.
static func _what_if_table(
	out: PackedStringArray, title: String, batches: Array, cell: Callable
) -> void:
	out.append("### " + title)
	out.append("")
	out.append("| XP x | D1 | D2 | D3 | D4 |")
	out.append("|---|---|---|---|---|")
	for b in batches:
		var cells: PackedStringArray = []
		for dl in range(1, 5):
			var recs := _records(b["campaigns"], dl)
			cells.append(str(cell.call(recs)) if not recs.is_empty() else "-")
		out.append("| x%s | %s |" % [_mult_label(b["mult"]), " | ".join(cells)])
	out.append("")


static func _cell_boss_level(recs: Array) -> String:
	var levels: Array = []
	for d in recs:
		levels.append_array(d["boss_levels"])
	return "%.1f" % _mean(levels) if not levels.is_empty() else "-"


static func _cell_sp(recs: Array) -> String:
	return "%.1f" % _mean(recs.map(func(d): return int(d["sp"])))


static func _cell_wipes(recs: Array) -> String:
	return "%.2f" % _mean_wipes(recs)


static func _cell_stuck(recs: Array) -> String:
	return "%d%%" % _stuck_pct(recs)


static func _cell_minutes(recs: Array) -> String:
	var done := _cleared(recs)
	if done.is_empty():
		return "-"
	return "%.1f" % _mean(done.map(func(d): return _minutes(d)))


static func _cell_rounds(recs: Array) -> String:
	var rounds := _all_rounds(recs)
	return "%.1f" % _mean(rounds) if not rounds.is_empty() else "-"


static func _limits() -> PackedStringArray:
	return PackedStringArray(
		[
			"## Limitations",
			"",
			"- Loot is out: gear is the model above, and treasure gold and items are taken",
			"  but never equipped or sold. Only the market's potions are bought.",
			"- Potions: only heal and mana potions are used. Revive items and shrines are",
			"  left unused, and no potion is bought for dungeons the party never reaches.",
			"- The market shelf is the game's own limited random stock, restocked when a",
			"  run ends, so the potion supply varies by campaign.",
			"- Skill points are spent only in the city, so the SP earned inside a",
			"  dungeon waits for the next visit.",
			"- Events and shrines are always left, so their risks and rewards are out.",
			"- A wipe retries on a fresh layout, as the game starts a new run after a TPK.",
			"- Levels at the dungeon 4 boss only count campaigns that got there, so a",
			"  multiplier that sticks fewer campaigns earlier is not directly comparable.",
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
