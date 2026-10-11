## Encounters E3 (D-038): dungeon pressure. Rest rooms restore part of the
## party, the Fountain is a small heal, every floor has a fight quota, elite
## rooms stay off the only route to the stairs, and walking back through
## explored rooms ticks nothing.
##
## The rest and Fountain tests swap a test party into the Party autoload and
## put the real one (and GameState.turn_counter) back afterwards.
extends GdUnitTestSuite

const WARRIOR := "res://resources/classes/warrior.tres"
const MAGE := "res://resources/classes/mage.tres"
const CLERIC := "res://resources/classes/cleric.tres"
## Floors generated per floor index for the quota checks.
const GENERATED_FLOORS := 200

var _saved_heroes: Array[Hero] = []
var _saved_turn_counter: int = 0


func before_test() -> void:
	_saved_heroes = Party.heroes.duplicate()
	_saved_turn_counter = GameState.turn_counter


func after_test() -> void:
	Party.heroes.assign(_saved_heroes)
	GameState.turn_counter = _saved_turn_counter


# ── Builders ──────────────────────────────────────────────────────────────────


func _hero(class_path: String) -> Hero:
	return Hero.create(load(class_path))


func _status(kind: CombatStatus.Kind, duration: int = 3) -> CombatStatus:
	var st := CombatStatus.new()
	st.kind = kind
	st.source_name = "test"
	st.duration = duration
	return st


## One status of every kind a hero can carry between fights.
func _give_every_status(h: Hero) -> void:
	for kind in [
		CombatStatus.Kind.BUFF,
		CombatStatus.Kind.DEBUFF,
		CombatStatus.Kind.DOT,
		CombatStatus.Kind.BARRIER,
		CombatStatus.Kind.REGEN,
	]:
		var st := _status(kind)
		if kind == CombatStatus.Kind.DOT:
			st.dot_damage = 2
		if kind == CombatStatus.Kind.REGEN:
			st.heal_per_turn = 2
		h.statuses.append(st)


func _kinds(h: Hero) -> Array:
	var out: Array = []
	for st in h.statuses:
		out.append((st as CombatStatus).kind)
	out.sort()
	return out


func _use_party(heroes: Array) -> void:
	Party.heroes.assign(heroes)


# ── Rest rooms ────────────────────────────────────────────────────────────────


func test_rest_restores_half_hp_and_a_quarter_mp() -> void:
	var mage := _hero(MAGE)
	mage.hp = 1
	mage.mp = 0
	_use_party([mage])
	DungeonRun.new().resolve_rest()
	assert_int(mage.hp).is_equal(1 + roundi(mage.max_hp() * 0.5))
	assert_int(mage.mp).is_equal(roundi(mage.max_mp() * 0.25))
	assert_int(mage.hp).is_less(mage.max_hp())
	assert_int(mage.mp).is_less(mage.max_mp())


func test_rest_caps_at_max() -> void:
	var cleric := _hero(CLERIC)
	cleric.hp = cleric.max_hp() - 1
	cleric.mp = cleric.max_mp() - 1
	_use_party([cleric])
	DungeonRun.new().resolve_rest()
	assert_int(cleric.hp).is_equal(cleric.max_hp())
	assert_int(cleric.mp).is_equal(cleric.max_mp())


func test_rest_revives_downed_heroes_at_a_quarter_hp_and_mp() -> void:
	var warrior := _hero(WARRIOR)
	var mage := _hero(MAGE)
	warrior.hp = 0
	mage.hp = 0
	mage.mp = 0
	_use_party([warrior, mage])
	DungeonRun.new().resolve_rest()
	assert_int(warrior.hp).is_equal(roundi(warrior.max_hp() * 0.25))
	assert_int(mage.hp).is_equal(roundi(mage.max_hp() * 0.25))
	assert_int(mage.mp).is_equal(roundi(mage.max_mp() * 0.25))
	assert_int(mage.mp).is_greater(0)
	assert_bool(warrior.is_alive()).is_true()


func test_rest_clears_debuffs_and_dots_but_keeps_buffs() -> void:
	var warrior := _hero(WARRIOR)
	var mage := _hero(MAGE)
	_give_every_status(warrior)
	_give_every_status(mage)
	_use_party([warrior, mage])
	DungeonRun.new().resolve_rest()
	var kept := [CombatStatus.Kind.BUFF, CombatStatus.Kind.BARRIER, CombatStatus.Kind.REGEN]
	kept.sort()
	assert_array(_kinds(warrior)).is_equal(kept)
	assert_array(_kinds(mage)).is_equal(kept)


# ── The Fountain ──────────────────────────────────────────────────────────────


func test_fountain_heals_30_percent_hp_and_clears_only_dots() -> void:
	var mage := _hero(MAGE)
	mage.hp = 1
	mage.mp = 0
	_give_every_status(mage)
	var downed := _hero(WARRIOR)
	downed.hp = 0
	var healthy := _hero(CLERIC)
	healthy.hp = healthy.max_hp() - 1
	_use_party([mage, downed, healthy])

	var run := DungeonRun.new()
	var fountain := run._event_fountain()
	assert_str(fountain["id"]).is_equal("fountain")
	(fountain["options"][0]["effect"] as Callable).call()

	assert_int(mage.hp).is_equal(1 + roundi(mage.max_hp() * 0.3))
	assert_int(mage.mp).is_equal(0)  # no MP
	assert_int(downed.hp).is_equal(0)  # no revive
	assert_int(healthy.hp).is_equal(healthy.max_hp())  # capped
	var kept := [
		CombatStatus.Kind.BUFF,
		CombatStatus.Kind.DEBUFF,
		CombatStatus.Kind.BARRIER,
		CombatStatus.Kind.REGEN,
	]
	kept.sort()
	assert_array(_kinds(mage)).is_equal(kept)


# ── Fight quota ───────────────────────────────────────────────────────────────


func _count(rooms: Dictionary, kind: DungeonRoom.RoomType) -> int:
	var n := 0
	for room in rooms.values():
		if room.kind == kind:
			n += 1
	return n


func test_every_floor_meets_its_fight_quota() -> void:
	for floor_index in DungeonRun.NUM_FLOORS:
		var min_fights: int = DungeonRun.MIN_COMBAT_ROOMS[floor_index]
		var max_fights: int = min_fights + DungeonRun.MAX_EXTRA_COMBAT_ROOMS
		for i in GENERATED_FLOORS:
			var rooms := DungeonRun._generate_floor(floor_index)
			var fights := _count(rooms, DungeonRoom.RoomType.COMBAT)
			(
				assert_int(fights)
				. override_failure_message(
					(
						"floor %d: %d fights, quota %d-%d"
						% [floor_index + 1, fights, min_fights, max_fights]
					)
				)
				. is_between(min_fights, max_fights)
			)
			# The start room stays a safe landing; the goal is still there.
			assert_int((rooms[Vector2i.ZERO] as DungeonRoom).kind).is_equal(
				DungeonRoom.RoomType.EMPTY
			)
			var goal := (
				DungeonRoom.RoomType.BOSS
				if floor_index == DungeonRun.NUM_FLOORS - 1
				else DungeonRoom.RoomType.STAIRS
			)
			assert_int(_count(rooms, goal)).is_equal(1)


## The quota turns rooms into fights EMPTY first, then EVENT, then TREASURE,
## and REST only when none of those is left: if it converted a room of one kind,
## no room of an earlier kind may be left unconverted.
func test_quota_converts_rest_rooms_last() -> void:
	var order: Array = DungeonRun.QUOTA_CONVERT_ORDER
	for floor_index in DungeonRun.NUM_FLOORS:
		for i in GENERATED_FLOORS:
			var rooms := DungeonRun._rolled_floor(floor_index)
			var before := {}
			for room in rooms.values():
				before[room.pos] = room.kind
			DungeonRun._apply_fight_quota(rooms, floor_index)
			# Index in `order` of the latest kind converted, and of the earliest
			# kind left as it was. The start room is never converted.
			var latest_converted := -1
			var earliest_left := order.size()
			for room in rooms.values():
				var idx := order.find(before[room.pos])
				if idx == -1 or room.pos == Vector2i.ZERO:
					continue
				if room.kind == DungeonRoom.RoomType.COMBAT:
					latest_converted = maxi(latest_converted, idx)
				elif room.kind == before[room.pos]:
					earliest_left = mini(earliest_left, idx)
			var message := (
				"floor %d: converted kind #%d of %s while kind #%d was left"
				% [floor_index + 1, latest_converted, order, earliest_left]
			)
			assert_int(latest_converted).override_failure_message(message).is_less_equal(
				earliest_left
			)


func test_generated_elites_are_never_on_the_only_route() -> void:
	var elites := 0
	for floor_index in range(DungeonRun.ELITE_FIRST_FLOOR, DungeonRun.NUM_FLOORS):
		for i in GENERATED_FLOORS:
			var rooms := DungeonRun._generate_floor(floor_index)
			var required := DungeonRun._required_rooms(rooms)
			for room in rooms.values():
				if room.kind == DungeonRoom.RoomType.ELITE:
					elites += 1
					assert_bool(required.has(room.pos)).is_false()
	assert_int(elites).is_greater(0)


## Links two adjacent rooms with a passage.
func _link(rooms: Dictionary, a: Vector2i, b: Vector2i) -> void:
	for dir in DungeonRoom.DIRS:
		if a + dir["vec"] == b:
			(rooms[a] as DungeonRoom).connections |= dir["bit"]
			(rooms[b] as DungeonRoom).connections |= dir["opposite"]


func _room(rooms: Dictionary, pos: Vector2i, kind: DungeonRoom.RoomType) -> void:
	var room := DungeonRoom.new()
	room.pos = pos
	room.kind = kind
	rooms[pos] = room


func test_elite_is_skipped_when_every_room_is_on_the_route() -> void:
	# start - A - B - stairs: every room is on the only route.
	var rooms := {}
	_room(rooms, Vector2i(0, 0), DungeonRoom.RoomType.EMPTY)
	_room(rooms, Vector2i(1, 0), DungeonRoom.RoomType.COMBAT)
	_room(rooms, Vector2i(2, 0), DungeonRoom.RoomType.TREASURE)
	_room(rooms, Vector2i(3, 0), DungeonRoom.RoomType.STAIRS)
	_link(rooms, Vector2i(0, 0), Vector2i(1, 0))
	_link(rooms, Vector2i(1, 0), Vector2i(2, 0))
	_link(rooms, Vector2i(2, 0), Vector2i(3, 0))
	for i in 60:
		DungeonRun._maybe_place_elite(rooms, 2)
		assert_int(_count(rooms, DungeonRoom.RoomType.ELITE)).is_equal(0)


func test_quota_takes_back_the_elite_room_on_a_tiny_floor() -> void:
	# Floor 2 needs 3 fights but has only 3 rooms to give, one of them elite.
	var rooms := {}
	_room(rooms, Vector2i(0, 0), DungeonRoom.RoomType.EMPTY)
	_room(rooms, Vector2i(1, 0), DungeonRoom.RoomType.TREASURE)
	_room(rooms, Vector2i(2, 0), DungeonRoom.RoomType.STAIRS)
	_room(rooms, Vector2i(1, 1), DungeonRoom.RoomType.REST)
	_room(rooms, Vector2i(1, -1), DungeonRoom.RoomType.ELITE)
	DungeonRun._apply_fight_quota(rooms, 1)
	assert_int(_count(rooms, DungeonRoom.RoomType.COMBAT)).is_equal(3)
	assert_int(_count(rooms, DungeonRoom.RoomType.ELITE)).is_equal(0)
	assert_int(_count(rooms, DungeonRoom.RoomType.STAIRS)).is_equal(1)


func test_quota_trims_extra_fights() -> void:
	var rooms := {}
	_room(rooms, Vector2i(0, 0), DungeonRoom.RoomType.EMPTY)
	for x in range(1, 9):
		_room(rooms, Vector2i(x, 0), DungeonRoom.RoomType.COMBAT)
	_room(rooms, Vector2i(9, 0), DungeonRoom.RoomType.STAIRS)
	DungeonRun._apply_fight_quota(rooms, 0)
	assert_int(_count(rooms, DungeonRoom.RoomType.COMBAT)).is_equal(
		DungeonRun.MIN_COMBAT_ROOMS[0] + DungeonRun.MAX_EXTRA_COMBAT_ROOMS
	)
	assert_int((rooms[Vector2i(0, 0)] as DungeonRoom).kind).is_equal(DungeonRoom.RoomType.EMPTY)
	assert_int(_count(rooms, DungeonRoom.RoomType.STAIRS)).is_equal(1)


# ── Walk-back ─────────────────────────────────────────────────────────────────


func test_statuses_tick_only_on_first_visits() -> void:
	var mage := _hero(MAGE)
	mage.hp = 1
	var regen := _status(CombatStatus.Kind.REGEN, 10)
	regen.heal_per_turn = 2
	mage.statuses.append(regen)
	_use_party([mage])
	GameState.turn_counter = 0

	var run := DungeonRun.generate(1)
	var next: Vector2i = Vector2i.ZERO
	for dir in DungeonRoom.DIRS:
		if run.can_move_to(Vector2i.ZERO + dir["vec"]):
			next = dir["vec"]
			break
	assert_bool(next == Vector2i.ZERO).is_false()  # the start always has a passage

	# First visit: the turn advances and regen heals.
	run.move_to(next)
	assert_int(GameState.turn_counter).is_equal(1)
	assert_int(mage.hp).is_equal(3)
	assert_int(regen.duration).is_equal(9)

	# Back and forth through explored rooms: nothing ticks.
	for i in 5:
		assert_array(run.move_to(Vector2i.ZERO)).is_empty()
		assert_array(run.move_to(next)).is_empty()
	assert_int(GameState.turn_counter).is_equal(1)
	assert_int(mage.hp).is_equal(3)
	assert_int(regen.duration).is_equal(9)
