## Headless verification driver for slice (a). Run via F6 with
## combat_test.tscn as the current scene. Prints the full combat log,
## the result, and the XP/gold reward summary.
##
## The driver uses a fixed seed so re-runs are deterministic, and a
## very simple "pick first affordable skill, target first valid enemy"
## heuristic. The point is to exercise the state machine, not to play well.
extends Node

const ENEMY_PATHS: Array[String] = [
	"res://resources/enemies/goblin.tres",
	"res://resources/enemies/wolf.tres",
	"res://resources/enemies/bat.tres",
]


func _ready() -> void:
	seed(12345)
	print("=== Combat test ===")
	Party.start_new_game()
	var enemy_list: Array[EnemyData] = []
	for path in ENEMY_PATHS:
		enemy_list.append(load(path) as EnemyData)

	var state := CombatState.build(Party.heroes, enemy_list)
	state.log_appended.connect(func(line): print("  ", line))
	state.combat_ended.connect(_on_ended)

	state.start()
	# Pace one party turn per ~80ms so the editor's Output panel renders
	# progress live. Do NOT call quit() at the end — if we did, the running
	# scene would close before Godot flushed the final lines (and Output
	# would cut off mid-combat). User stops the scene manually when done.
	var safety := 100
	while not state.ended and safety > 0:
		safety -= 1
		await get_tree().create_timer(0.08).timeout
		if state.current_actor == null:
			print("  (current_actor became null — aborting)")
			break
		if state.current_actor.side == Battler.Side.ENEMY:
			state.step()
			continue
		var hero := state.current_actor.hero
		var skill := _pick_skill(hero)
		if skill == null:
			print("  (no affordable skill for %s — aborting)" % state.current_actor.display_name())
			break
		var target := _pick_target(state, skill)
		state.player_action(skill, target)

	print("=== Test finished (safety remaining: %d) — press Stop when done. ===" % safety)


func _pick_skill(hero: Hero) -> SkillData:
	for sk in hero.class_data.skills:
		if hero.level < sk.unlock_level:
			continue
		if hero.mp < sk.mp_cost:
			continue
		# Skip Reviver if nobody is dead — wastes MP otherwise.
		if sk.skill_type == SkillData.SkillType.REVIVE:
			var any_dead := false
			for h in Party.heroes:
				if not h.is_alive():
					any_dead = true
					break
			if not any_dead:
				continue
		return sk
	return null


func _pick_target(state: CombatState, skill: SkillData) -> Battler:
	if state.skill_is_auto_targeted(skill):
		return null
	var targets := state.valid_targets_for(state.current_actor, skill)
	return targets[0] if not targets.is_empty() else null


func _on_ended(r: CombatState.Result, rewards: Dictionary) -> void:
	var name_lookup := ["NONE", "VITÓRIA", "DERROTA", "FUGA"]
	print("Resultado: %s. Recompensas: %s" % [name_lookup[r], rewards])
	if r == CombatState.Result.VICTORY:
		print("Distribuindo XP:")
		for h in Party.heroes:
			if not h.is_alive():
				continue
			var unlocked := Party.award_xp(h, rewards["xp"])
			var unlock_names: Array[String] = []
			for sk in unlocked:
				unlock_names.append(sk.display_name)
			print("  %s: nivel %d, XP %d, skills desbloqueadas: %s" % [
				h.class_data.display_name, h.level, h.xp, unlock_names
			])
