## The translation table is complete: every row has both languages, no key is
## defined twice, and every text key a .tres refers to exists.
extends GdUnitTestSuite

const TestUtil := preload("res://test/support/test_util.gd")
const CSV_PATH := "res://i18n/translations.csv"
const HEADER := ["keys", "pt_BR", "en"]
## .tres fields that hold a translation key rather than literal text.
const TEXT_KEY_FIELDS := ["display_name", "description"]


func test_header_is_keys_pt_br_en() -> void:
	var file := FileAccess.open(CSV_PATH, FileAccess.READ)
	assert_object(file).is_not_null()
	assert_array(Array(file.get_csv_line())).is_equal(HEADER)


func test_every_row_has_pt_br_and_en() -> void:
	var incomplete: PackedStringArray = []
	for row in _rows():
		var key: String = row.cells[0]
		if row.cells.size() != HEADER.size():
			incomplete.append(
				(
					"line %d %s: %d columns, expected %d"
					% [row.line, key, row.cells.size(), HEADER.size()]
				)
			)
			continue
		if row.cells[1].strip_edges().is_empty():
			incomplete.append("line %d %s: empty pt_BR" % [row.line, key])
		if row.cells[2].strip_edges().is_empty():
			incomplete.append("line %d %s: empty en" % [row.line, key])
	(
		assert_array(incomplete)
		. override_failure_message(TestUtil.problem_list("Incomplete CSV rows", incomplete))
		. is_empty()
	)


func test_no_duplicate_keys() -> void:
	var first_line := {}
	var duplicates: PackedStringArray = []
	for row in _rows():
		var key: String = row.cells[0]
		if key.is_empty():
			duplicates.append("line %d: empty key" % row.line)
		elif first_line.has(key):
			duplicates.append(
				"line %d %s: already defined on line %d" % [row.line, key, first_line[key]]
			)
		else:
			first_line[key] = row.line
	(
		assert_array(duplicates)
		. override_failure_message(TestUtil.problem_list("Duplicate or empty keys", duplicates))
		. is_empty()
	)


func test_tres_text_keys_exist() -> void:
	var keys := {}
	for row in _rows():
		keys[row.cells[0]] = true

	# Read the .tres as text rather than loading it, so this test still
	# reports missing keys when a resource is broken (resources_load_test
	# reports that), and it sees sub-resources (e.g. the skin catalog) too.
	var field := RegEx.create_from_string('^(%s) = "(.*)"$' % "|".join(TEXT_KEY_FIELDS))
	var missing: PackedStringArray = []
	var checked := 0
	for path in TestUtil.find_files("res://resources", ".tres"):
		var lines := FileAccess.get_file_as_string(path).split("\n")
		for i in lines.size():
			var m := field.search(lines[i].strip_edges())
			if m == null or m.get_string(2).is_empty():
				continue
			checked += 1
			if not keys.has(m.get_string(2)):
				missing.append("%s:%d %s = %s" % [path, i + 1, m.get_string(1), m.get_string(2)])
	assert_int(checked).is_greater(0)
	(
		assert_array(missing)
		. override_failure_message(TestUtil.problem_list("Text keys missing from the CSV", missing))
		. is_empty()
	)


## Data rows of the CSV (header skipped, blank lines skipped), each as
## { line: int (1-based), cells: PackedStringArray }.
func _rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var file := FileAccess.open(CSV_PATH, FileAccess.READ)
	if file == null:
		return rows
	file.get_csv_line()  # header
	var next_line := 2
	while not file.eof_reached():
		var line := next_line
		var cells := file.get_csv_line()
		# A quoted cell can span several lines of the file.
		next_line += 1
		for cell in cells:
			next_line += cell.count("\n")
		if cells.size() == 1 and cells[0].strip_edges().is_empty():
			continue
		rows.append({"line": line, "cells": cells})
	return rows
