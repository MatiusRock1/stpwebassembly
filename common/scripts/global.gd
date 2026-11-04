## Manages global state with the possiblity to create/destroy clients/servers
extends Node

## A version specification according to https://semver.org/
class SemVer:
	var major: int
	var minor: int
	var patch: int
	
	var beta: int
	
	func _init(major: int, minor: int, patch: int, beta := -1):
		self.major = major
		self.minor = minor
		self.patch = patch
		self.beta = beta
	
	func serialize() -> Dictionary:
		return {
			"major": major,
			"minor": minor,
			"patch": patch,
			"beta": beta
		}
	
	static func deserialize(data: Dictionary) -> SemVer:
		return SemVer.new(data.major, data.minor, data.patch, data.beta)
	
	## Formats the SemVer as a readable string
	func format() -> String:
		if beta != -1:
			return "{0}.{1}.{2}-beta{3}".format([major, minor, patch, beta])
		return "{0}.{1}.{2}".format([major, minor, patch])
	
	## Check if this SemVer can work with the given version [br]
	## In other words, checks whether the major version matches and the minor
	## version is at least as high
	## Furthermore, beta versions need not be compatible with other betas of the
	## same major.minor version so we have to check that as well
	func is_compatible(other: SemVer):
		return other.major == major and \
			(other.minor < minor or (other.minor == minor and other.beta == beta))
	

## Version of the game to check for compability with the remote party
var VERSION := SemVer.new(1, 0, 0, 2)

## Create a server running on this machine. [br]
## If [param public] is false, the local server will listen only on localhost,
## otherwise the server will be accessable from any computer in the network. [br]
## Can be used for singleplayer (public = false) or LAN multiplayer (public = true)
func create_local_server(public: bool = false) -> Node:
	var game_server: Node = load("res://server/game.tscn").instantiate()
	var server: MultiplayerPeer
	var local_client: MultiplayerPeer
	var port := 0
	if OS.has_feature("web"):
		# A browser cannot listen on a socket: client and server share this process
		var pair := LoopbackPeer.create_pair()
		server = pair[0]
		local_client = pair[1]
	else:
		var enet := ENetMultiplayerPeer.new()
		if not public:
			enet.set_bind_ip("127.0.0.1")
		if enet.create_server(0) != OK:
			return null
		port = enet.host.get_local_port()
		server = enet

	get_tree().root.add_child(game_server)
	var server_multiplayer := MultiplayerAPI.create_default_interface()
	server_multiplayer.multiplayer_peer = server
	get_tree().set_multiplayer(server_multiplayer, game_server.get_node("Game").get_path())
	game_server.get_node("Game").init_server()
	
	var client := _start_client(local_client) if local_client else connect_remote_server("127.0.0.1", port)
	# Clean up on error
	if not client:
		game_server.queue_free()
	return client

## Destroy a server created with [method create_local_server].
func destroy_local_server():
	get_node("/root/Client").queue_free()
	get_node("/root/Server").queue_free()

## Connect to the server running on host [param ip] and port [param port].
func connect_remote_server(ip: String, port: int) -> Node:
	var client: MultiplayerPeer
	if OS.has_feature("web"):
		# ENet needs UDP, which browsers do not have. See wasm/server
		var websocket := WebSocketMultiplayerPeer.new()
		websocket.handshake_timeout = 10.0
		if websocket.create_client(WebPlatform.game_url(ip, port)) != OK:
			return null
		client = websocket
	else:
		var enet := ENetMultiplayerPeer.new()
		if enet.create_client(ip, port) != OK:
			return null
		client = enet
	return _start_client(client)

func _start_client(client: MultiplayerPeer) -> Node:
	var game_client = load("res://client/game.tscn").instantiate()
	var client_multiplayer := MultiplayerAPI.create_default_interface()
	client_multiplayer.multiplayer_peer = client
	
	# Ugly hack:
	# The lobby menu for singleplayer games is in the main menu, which is not in the
	# /root/Client/Game/ subtree...
	# So we need the client multiplayer menu to work there as well
	get_tree().set_multiplayer(client_multiplayer)
	get_tree().root.add_child(game_client)
	get_tree().set_multiplayer(client_multiplayer, game_client.get_node("Game").get_path())
	game_client.get_node("Game").init_client()
	
	return game_client.get_node("Game")

## Returns the current local server (if any).
func get_current_server() -> Node:
	var client := get_node_or_null("/root/Client")
	if not client or client.is_queued_for_deletion():
		return null
	return client.get_node_or_null("Game")

## Destroy a remote connection created with [method connect_remote_server]
func destroy_remote_connection():
	get_node("/root/Client").queue_free()

## Destroy any currently active networking created with either
## [method create_local_server] or [method connect_remote_server]
func shutdown_connection():
	if has_node("/root/Server"):
		destroy_local_server()
	elif has_node("/root/Client"):
		destroy_remote_connection()

## Checks whether there is a local server running
func is_local_multiplayer() -> bool:
	return has_node("/root/Client") and has_node("/root/Server")

## Show a global error message that survives scene changes. [br]
## Helpful if there is a fatal error and the only sensible thing to do is
## raise an error and return to the main menu. Use only as a last resort
func show_error(error: String):
	var dialog := AcceptDialog.new()
	dialog.theme = preload("res://assets/defaults/default_theme.tres")
	dialog.title = "ERROR"
	dialog.dialog_text = error
	add_child(dialog)
	dialog.confirmed.connect(dialog.queue_free)
	dialog.popup_centered()

## Path where [member storage] is saved
const USER_STORAGE_FILE = "user://data.cfg"

## Loader for savegames
var savegame_loader := SaveGameLoader.new()

signal language_changed

var _interactive_loaders := {}
# Browser build only: paths that wait for their turn, see _start_waiting_loads()
var _waiting_loads: Array[String] = []

## If enabled, pauses the game if the window loses focus.
var pause_window_unfocus := true

## If enabled, mutes game if the window loses focus.
var mute_window_unfocus := true
var _was_muted := false

## ConfigFile to store custom data between sessions. If you change a value,
## call [method save_storage] to write the data to disk.
var storage: ConfigFile = ConfigFile.new()

func _ready() -> void:
	randomize()
	var err := storage.load(USER_STORAGE_FILE)
	if err != OK:
		push_error("Error while loading saved data: " + error_string(err))

func _notification(what: int) -> void:
	match what:
		MainLoop.NOTIFICATION_APPLICATION_FOCUS_IN:
			if mute_window_unfocus:
				if not _was_muted:
					AudioServer.set_bus_mute(0, false)
				else:
					_was_muted = false
		MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT:
			if mute_window_unfocus:
				if not AudioServer.is_bus_mute(0):
					AudioServer.set_bus_mute(0, true)
				else:
					_was_muted = true

func _input(event: InputEvent):
	if event.is_action_pressed("screenshot"):
		var time = Time.get_datetime_dict_from_system()
		await RenderingServer.frame_post_draw
		var image := get_viewport().get_texture().get_image()
		var filename := "%04dY-%02dM-%02dD %02dh-%02dm-%02ds.png" % [time.year, time.month, time.day, time.hour, time.minute, time.second]
		if OS.has_feature("web"):
			# There is no folder to open in a browser: hand the file to the player
			JavaScriptBridge.download_buffer(image.save_png_to_buffer(), filename, "image/png")
			return
		DirAccess.make_dir_absolute("user://screenshots")
		image.save_png("user://screenshots/" + filename)

func _process(_delta: float) -> void:
	for path in _interactive_loaders.keys():
		if path in _waiting_loads:
			continue
		var status := ResourceLoader.load_threaded_get_status(path)
		if status != ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			if status == ResourceLoader.THREAD_LOAD_LOADED:
				var resource := ResourceLoader.load_threaded_get(path)
				for callback in _interactive_loaders[path]:
					callback.call(resource)
			else:
				push_error("Failed to load resource: {0} (error {1})".format([
					path,
					status
				]))
			_interactive_loaders.erase(path)

## Returns what percentage of load requests have already completed
func get_loader_progress() -> float:
	var cumulative := 0.0
	for path in _interactive_loaders.keys():
		if path in _waiting_loads:
			continue
		var result := []
		ResourceLoader.load_threaded_get_status(path, result)
		cumulative += result[0]
	# Prevent division by zero when everything is loaded
	if _interactive_loaders.size() > 0:
		return cumulative / _interactive_loaders.size()
	return 1.0

func _load_interactive(path: String, method: Callable):
	# Resourceloader cannot load the same resource multiple times simultaneously
	# Check if we're already loading the path, so we can add another callback
	if path in _interactive_loaders:
		_interactive_loaders[path].append(method)
		return
	if OS.has_feature("web"):
		_interactive_loaders[path] = [method]
		_waiting_loads.append(path)
		if _waiting_loads.size() == 1:
			_start_waiting_loads()
		return
	var loader := ResourceLoader.load_threaded_request(path)
	if loader == OK:
		_interactive_loaders[path] = [method]
	else:
		push_error("Failed to obtain loader for `{0}`".format([path]))

## The browser build has no worker threads, so a threaded request loads on the
## spot and blocks the page. Requests wait here for the frame that shows the
## loading screen, and start one per frame so the progress bar can move. [br]
## Waiting only for frame_post_draw is not enough: the browser presents a frame
## when control returns to it, so the next frame has to begin first.
func _start_waiting_loads():
	while not _waiting_loads.is_empty():
		await RenderingServer.frame_post_draw
		await get_tree().process_frame
		var path: String = _waiting_loads.pop_front()
		if ResourceLoader.load_threaded_request(path) != OK:
			push_error("Failed to obtain loader for `{0}`".format([path]))
			_interactive_loaders.erase(path)

## Save persisted data from [member storage]
func save_storage():
	storage.save(USER_STORAGE_FILE)
