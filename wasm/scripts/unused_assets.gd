# Lists files under res://assets that nothing in the game can reach, so the browser
# package can leave them out. Upstream exports every resource and the art packs in
# assets/ hold far more than the game uses. Run from wasm/scripts/update_exclusions.py.
#
# A file counts as used when a script names it, when it is a dependency of any scene
# or resource outside assets/, or of a used file. Scripts that build paths at runtime
# from a directory are covered by DYNAMIC_DIRECTORIES.
extends SceneTree

const DYNAMIC_DIRECTORIES := [
	"res://assets/textures/controls/",
	"res://assets/sounds/",
	"res://assets/fonts/",
	"res://assets/defaults/",
]
const RESOURCE_EXTENSIONS := ["tscn", "scn", "tres", "res", "material", "gdshader", "gd"]
const IMPORTED_EXTENSIONS := ["png", "jpg", "jpeg", "svg", "webp", "ogg", "wav", "mp3", "glb", "gltf", "obj", "dae", "escn", "otf", "ttf"]

var _used := {}


func _init():
	var files: Array[String] = []
	_list_files("res://", files)

	var roots: Array[String] = []
	var script_text := ""
	for file in files:
		var extension := file.get_extension().to_lower()
		if file.begins_with("res://assets/"):
			continue
		if extension in RESOURCE_EXTENSIONS or extension in IMPORTED_EXTENSIONS:
			roots.append(file)
	for file in files:
		if file.get_extension() in ["gd", "json", "tres", "tscn", "cfg", "godot", "material"]:
			script_text += FileAccess.get_file_as_string(file) + "\n"
	script_text += FileAccess.get_file_as_string("res://project.godot")

	for file in files:
		if file.begins_with("res://assets/") and file in script_text:
			roots.append(file)
		for directory in DYNAMIC_DIRECTORIES:
			if file.begins_with(directory):
				roots.append(file)

	for root_file in roots:
		_visit(root_file)

	for file in files:
		var extension := file.get_extension().to_lower()
		if not file.begins_with("res://assets/") or file in _used:
			continue
		if extension in RESOURCE_EXTENSIONS or extension in IMPORTED_EXTENSIONS:
			print("UNUSED ", file)
	print("DONE")
	quit()


func _visit(path: String):
	if path in _used:
		return
	_used[path] = true
	if not ResourceLoader.exists(path):
		return
	for dependency in ResourceLoader.get_dependencies(path):
		# Format: "uid://...::type::res://path" or a plain path
		var target: String = dependency.get_slice("::", 2) if "::" in dependency else dependency
		if target.begins_with("uid://"):
			target = ResourceUID.get_id_path(ResourceUID.text_to_id(target))
		_visit(target)


func _list_files(directory: String, files: Array[String]):
	var dir := DirAccess.open(directory)
	if not dir:
		return
	dir.include_hidden = false
	dir.list_dir_begin()
	while true:
		var entry := dir.get_next()
		if entry == "":
			break
		if entry.begins_with("."):
			continue
		var path := directory.path_join(entry)
		if dir.current_is_dir():
			_list_files(path, files)
		else:
			files.append(path)
	dir.list_dir_end()
