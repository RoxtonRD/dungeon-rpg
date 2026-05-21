## Headless verification for slice (a). Run via the Godot bridge (or F6 with
## dungeon_test.tscn). Generates a dungeon, prints the map, and exercises
## encounter / boss / event / treasure rolling against GameState + Party.
extends Node


func _ready() -> void:
	seed(777)
	print("=== Dungeon test ===")
	Party.start_new_game()
	GameState.start_new_game()
	print("Ouro inicial: %d | inventário: %s" % [GameState.gold, GameState.inventory])

	var run := DungeonRun.generate(1, 3)
	GameState.current_run = run
	_print_map(run)

	print("\n-- Encontros --")
	print("Andar 0: %s" % _names(run.roll_encounter(0)))
	print("Andar 1: %s" % _names(run.roll_encounter(1)))
	print("Chefe:   %s" % _names(run.roll_boss()))

	print("\n-- Evento --")
	var ev := run.roll_event()
	print("%s — %s" % [ev["title"], ev["desc"]])
	for opt in ev["options"]:
		print("  [%s] disponível=%s" % [opt["text"], opt["available"]])
	# Resolve the first available option to prove effects fire.
	for opt in ev["options"]:
		if opt["available"]:
			var effect: Callable = opt["effect"]
			print("  -> %s" % effect.call())
			break

	print("\n-- Tesouro --")
	var treasure := run.resolve_treasure()
	print("Recompensa: +%d ouro, itens %s" % [treasure["gold"], treasure["items"]])
	print("Ouro agora: %d | inventário: %s" % [GameState.gold, GameState.inventory])

	print("\n-- Navegação --")
	print("Alcançáveis a partir do início: %d nó(s)" % run.reachable_nodes().size())
	run.advance_to(run.floors[0][0])
	print("Após andar 0, alcançáveis: %d | completo=%s" % [run.reachable_nodes().size(), run.is_complete()])

	print("=== Done — press Stop when ready. ===")


func _print_map(run: DungeonRun) -> void:
	print("Dungeon nível %d, %d andares:" % [run.level, run.floors.size()])
	for f in run.floors.size():
		var kinds: Array[String] = []
		for node in run.floors[f]:
			kinds.append(node.type_name())
		print("  Andar %d: %s" % [f, kinds])


func _names(enemies: Array) -> String:
	var s := ""
	for e in enemies:
		if not s.is_empty():
			s += ", "
		s += e.display_name
	return s
