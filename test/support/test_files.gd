## File helpers shared by the test suites. Not a test suite itself (the
## runner only picks up files named *_test.gd).
extends RefCounted


## Every file under `dir` (recursively) whose name ends with `extension`,
## sorted so failure lists are stable between runs.
static func find(dir: String, extension: String) -> PackedStringArray:
	var out: PackedStringArray = []
	for file in DirAccess.get_files_at(dir):
		if file.ends_with(extension):
			out.append(dir.path_join(file))
	for sub in DirAccess.get_directories_at(dir):
		out.append_array(find(dir.path_join(sub), extension))
	out.sort()
	return out
