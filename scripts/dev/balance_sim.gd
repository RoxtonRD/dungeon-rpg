## Headless balance simulator (dev tool — not used by the game).
##
## Runs combats through the real CombatState with a scripted "competent player"
## policy, so tuning changes can be measured instead of guessed at. Drive it
## from the Godot MCP with e.g.
##     return BalanceSim.encounter_report(["warrior","cleric","rogue","mage"], 200)
##
## SAFETY: the sim builds throwaway Hero objects and never touches Party.heroes
## or GameState. In particular it does NOT award XP — Party.award_xp levels the
## hero, which grants level-gated skins via GameState.unlock_skin(), which SAVES
## THE GAME. Levels are therefore set directly, and level-up effects (the full
## HP/MP restore) are modelled explicitly by `restore_on_level` in gauntlet().
class_name BalanceSim
extends RefCounted

## Safety valve so a stalemate can never hang the editor.
const MAX_ROUNDS := 60
## Hero level assumed at each dungeon level (index = dungeon_level - 1).
## Tuned for split XP: a 4-hero party earns a quarter share each, so levelling
## is roughly a quarter as fast as the old pay-full-to-everyone behaviour.
const LEVEL_BY_DUNGEON := [2, 3, 4, 5]


# ── Party / enemy construction ────────────────────────────────────────────────

## Builds a party at `level`, geared to `gear_tier` (ItemData.Tier, -1 = naked).
## Gearing matters: a real party at dungeon 4 is carrying rare/epic loot, so
## simulating naked heroes badly understates party power at depth.
static func make_party(class_ids: Array, level: int, gear_tier: int = -1) -> Array[Hero]:
	var out: Array[Hero] = []
	for cid in class_ids:
		var cd := load("res://resources/classes/%s.tres" % cid) as ClassData
		var h := Hero.create(cd)
		h.level = level
		if gear_tier >= 0:
			_equip_best(h, gear_tier)
		h.hp = h.max_hp()   # after level+gear, so maxima are correct
		h.mp = h.max_mp()
		out.append(h)
	return out


## Cache of resolved loadouts, keyed "<class_id>:<tier>" — resolving from the
## item pool per hero per trial is far too slow to run thousands of fights.
static var _gear_cache: Dictionary = {}


## Equips the highest-value item this class may use in each slot, at or below
## `max_tier`, drawn from the same droppable pool the game uses.
static func _equip_best(h: Hero, max_tier: int) -> void:
	var key := "%s:%d" % [h.class_data.id, max_tier]
	if not _gear_cache.has(key):
		var slots := {"weapon": ItemData.Slot.WEAPON, "armor": ItemData.Slot.ARMOR,
			"trinket": ItemData.Slot.TRINKET}
		var loadout: Dictionary = {}
		for slot_name in slots:
			var want: ItemData.Slot = slots[slot_name]
			var best: ItemData = null
			for id in Loot.DROPPABLE:
				var it := load("res://resources/items/%s.tres" % id) as ItemData
				if it == null or it.slot != want or int(it.tier) > max_tier:
					continue
				if it.class_restriction.size() > 0 and not it.class_restriction.has(h.class_data.id):
					continue
				if best == null or it.value > best.value:
					best = it
			if best != null:
				loadout[slot_name] = best
		_gear_cache[key] = loadout
	for slot_name in (_gear_cache[key] as Dictionary):
		h.equipment[slot_name] = _gear_cache[key][slot_name]


static func heal_party(heroes: Array[Hero]) -> void:
	for h in heroes:
		h.hp = h.max_hp()
		h.mp = h.max_mp()


# ── One fight ─────────────────────────────────────────────────────────────────

## Fights `enemy_list` with `heroes` (HP/MP carry in and out). Accumulates
## damage dealt per class id into `dmg_by_class`. Returns {result, rounds}.
static func fight(heroes: Array[Hero], enemy_list: Array[EnemyData], dmg_by_class: Dictionary) -> Dictionary:
	var st := CombatState.build(heroes, enemy_list)
	st.start()
	var guard := 0
	while not st.ended and guard < MAX_ROUNDS * 8:
		guard += 1
		var actor: Battler = st.current_actor
		if actor == null or st.round_number > MAX_ROUNDS:
			break
		if actor.side == Battler.Side.ENEMY:
			st.step()
		else:
			_player_turn(st, actor, dmg_by_class)
	return {"result": int(st.result), "rounds": st.round_number}


## Scripted player policy: heal a badly hurt ally when possible, otherwise use
## the highest expected-damage affordable skill, focusing the weakest enemy.
static func _player_turn(st: CombatState, actor: Battler, dmg_by_class: Dictionary) -> void:
	var hero: Hero = actor.hero
	var usable: Array[SkillData] = []
	for s in hero.class_data.skills:
		if hero.level >= s.unlock_level and hero.mp >= s.mp_cost:
			usable.append(s)
	if usable.is_empty():
		st.player_flee()
		return

	# Someone below half HP? Prefer a heal.
	var wounded: Battler = null
	for b in st.party:
		if not b.is_alive():
			continue
		if float(b.get_hp()) / float(maxi(1, b.max_hp)) < 0.5:
			if wounded == null or b.get_hp() < wounded.get_hp():
				wounded = b

	var pick: SkillData = null
	if wounded != null:
		for s in usable:
			if s.skill_type == SkillData.SkillType.HEAL:
				pick = s
				break
	if pick == null:
		var best := -1.0
		for s in usable:
			var score := _damage_score(s, st)
			if score > best:
				best = score
				pick = s
	if pick == null:
		pick = usable[0]

	var target: Battler = null
	if not st.skill_is_auto_targeted(pick):
		var opts := st.valid_targets_for(actor, pick)
		if opts.is_empty():
			pick = usable[0]
			opts = st.valid_targets_for(actor, pick)
			if opts.is_empty():
				st.player_flee()
				return
		target = opts[0]
		for o in opts:
			# Heals go to the most hurt ally; damage focuses the weakest enemy.
			if o.get_hp() < target.get_hp():
				target = o

	var before := _enemy_hp_total(st)
	st.player_action(pick, target)
	var dealt := before - _enemy_hp_total(st)
	if dealt > 0:
		var key: String = hero.class_data.id
		dmg_by_class[key] = int(dmg_by_class.get(key, 0)) + dealt


## Rough expected-damage heuristic used to choose a skill.
static func _damage_score(s: SkillData, st: CombatState) -> float:
	match s.skill_type:
		SkillData.SkillType.HEAL, SkillData.SkillType.BUFF, \
		SkillData.SkillType.DEBUFF, SkillData.SkillType.REVIVE:
			return 0.0
	var targets := 1
	if s.target == SkillData.TargetType.ALL:
		targets = _alive_count(st.enemies)
	var hits := float(s.hits) if s.skill_type == SkillData.SkillType.MULTI else 1.0
	return s.power * float(targets) * hits


static func _enemy_hp_total(st: CombatState) -> int:
	var t := 0
	for e in st.enemies:
		t += e.get_hp()
	return t


static func _alive_count(list: Array) -> int:
	var n := 0
	for b in list:
		if b.is_alive():
			n += 1
	return n


static func _party_hp_pct(heroes: Array[Hero]) -> float:
	var cur := 0.0
	var mx := 0.0
	for h in heroes:
		cur += float(h.hp)
		mx += float(h.max_hp())
	return 0.0 if mx <= 0.0 else cur / mx


# ── Reports ───────────────────────────────────────────────────────────────────

## Per-fight difficulty at every (dungeon_level, floor), each fight starting
## from full HP/MP — isolates "how hard is one encounter".
## `gear_offset` shifts how well-equipped the party is assumed to be:
##  0 = best-in-slot for the depth (optimistic), -1 = one tier behind
##  (realistic), -2 = two behind / naked early (pessimistic).
static func encounter_report(class_ids: Array, trials: int = 100, levels: Array = [],
		gear_offset: int = -1) -> Dictionary:
	var by_dungeon: Array = levels if levels.size() == 4 else LEVEL_BY_DUNGEON
	var out: Dictionary = {}
	for dl in range(1, 5):
		var level: int = int(by_dungeon[dl - 1])
		var gear: int = clampi(dl - 1 + gear_offset, -1, 3)
		var run := DungeonRun.generate(dl)
		for fl in range(0, 4):
			var wins := 0
			var rounds := 0
			var hp_left := 0.0
			var dmg: Dictionary = {}
			for i in trials:
				var heroes := make_party(class_ids, level, gear)
				var res := fight(heroes, run.roll_encounter(fl), dmg)
				if int(res["result"]) == int(CombatState.Result.VICTORY):
					wins += 1
				rounds += int(res["rounds"])
				hp_left += _party_hp_pct(heroes)
			out["D%d_F%d" % [dl, fl + 1]] = {
				"win%": roundi(100.0 * float(wins) / float(trials)),
				"rounds": snappedf(float(rounds) / float(trials), 0.1),
				"hp_left%": roundi(100.0 * hp_left / float(trials)),
			}
		# Boss of this dungeon level.
		var bwins := 0
		var brounds := 0
		var bhp := 0.0
		var bdmg: Dictionary = {}
		for i in trials:
			var heroes := make_party(class_ids, level, gear)
			var res := fight(heroes, run.roll_boss(), bdmg)
			if int(res["result"]) == int(CombatState.Result.VICTORY):
				bwins += 1
			brounds += int(res["rounds"])
			bhp += _party_hp_pct(heroes)
		out["D%d_BOSS" % dl] = {
			"win%": roundi(100.0 * float(bwins) / float(trials)),
			"rounds": snappedf(float(brounds) / float(trials), 0.1),
			"hp_left%": roundi(100.0 * bhp / float(trials)),
		}
	return out


## Attrition: consecutive fights on one party with no healing between them.
## `restore_on_level` models the current level-up full-restore by topping the
## party up every `fights_per_level` fights — set false to see the difference.
static func gauntlet(class_ids: Array, dungeon_level: int, trials: int = 100,
		restore_on_level: bool = true, fights_per_level: int = 3) -> Dictionary:
	var level: int = LEVEL_BY_DUNGEON[clampi(dungeon_level, 1, 4) - 1]
	var run := DungeonRun.generate(dungeon_level)
	var survived_total := 0
	var wiped := 0
	for i in trials:
		var heroes := make_party(class_ids, level)
		var dmg: Dictionary = {}
		var cleared := 0
		for f in 12:   # cap: 12 fights is a very long run
			var res := fight(heroes, run.roll_encounter(mini(f / 3, 3)), dmg)
			if int(res["result"]) != int(CombatState.Result.VICTORY):
				break
			cleared += 1
			if restore_on_level and cleared % fights_per_level == 0:
				heal_party(heroes)
		if cleared >= 12:
			pass
		else:
			wiped += 1
		survived_total += cleared
	return {
		"avg_fights_cleared": snappedf(float(survived_total) / float(trials), 0.1),
		"wiped_before_12%": roundi(100.0 * float(wiped) / float(trials)),
		"restore_on_level": restore_on_level,
	}


## Damage share per class over many fights — who is carrying?
static func class_damage(class_ids: Array, dungeon_level: int = 2, trials: int = 100) -> Dictionary:
	var level: int = LEVEL_BY_DUNGEON[clampi(dungeon_level, 1, 4) - 1]
	var run := DungeonRun.generate(dungeon_level)
	var dmg: Dictionary = {}
	for i in trials:
		var heroes := make_party(class_ids, level)
		fight(heroes, run.roll_encounter(1), dmg)
	var total := 0
	for k in dmg:
		total += int(dmg[k])
	var out: Dictionary = {}
	for k in dmg:
		out[k] = "%d%%" % roundi(100.0 * float(dmg[k]) / float(maxi(1, total)))
	return out
