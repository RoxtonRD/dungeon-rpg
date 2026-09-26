## Helpers shared by the test suites. Not a test suite itself (the runner
## only picks up files named *_test.gd).
extends RefCounted


## Every file under `dir` (recursively) whose name ends with `extension`,
## sorted so failure lists are stable between runs.
static func find_files(dir: String, extension: String) -> PackedStringArray:
	var out: PackedStringArray = []
	for file in DirAccess.get_files_at(dir):
		if file.ends_with(extension):
			out.append(dir.path_join(file))
	for sub in DirAccess.get_directories_at(dir):
		out.append_array(find_files(dir.path_join(sub), extension))
	out.sort()
	return out


## A readable failure message for a list of problems: a title line, then one
## problem per line.
static func problem_list(title: String, problems: PackedStringArray) -> String:
	return "%s (%d):\n  %s" % [title, problems.size(), "\n  ".join(problems)]
