extends Node

const ApiServer := preload("res://server/api/connection.gd")

func _ready() -> void:
	# Load config from file
	load_config()
	
	# Set up the websocket server
	var api := ApiServer.new()
	get_tree().root.add_child.call_deferred(api)
	
	# Set up the network
	var peer := create_peer()
	multiplayer.multiplayer_peer = peer
	var server_multiplayer := MultiplayerAPI.create_default_interface()
	server_multiplayer.multiplayer_peer = peer

	# Start the actual server code
	load_server.call_deferred(server_multiplayer)

## Browsers cannot use ENet: with the "websocket" transport this server is for the
## browser build. The game connection then needs its own port, because the version
## API already holds the TCP port that sits next to ENet's UDP port on the desktop.
func create_peer() -> MultiplayerPeer:
	var port: int = ProjectSettings.get("server/port")
	var bind_ip: String = ProjectSettings.get("server/bind_ip")
	if ProjectSettings.get("server/transport") == "websocket":
		var websocket := WebSocketMultiplayerPeer.new()
		var err := websocket.create_server(port + WebPlatform.GAME_PORT_OFFSET, bind_ip)
		if err != OK:
			push_error("Cannot listen on port {0}: {1}".format([port + WebPlatform.GAME_PORT_OFFSET, error_string(err)]))
		return websocket
	var enet := ENetMultiplayerPeer.new()
	enet.set_bind_ip(bind_ip)
	enet.create_server(port, ProjectSettings.get("server/max_players"))
	return enet

func load_server(server_multiplayer: MultiplayerAPI):
	var game := preload("res://server/game.tscn").instantiate()
	get_tree().set_multiplayer(server_multiplayer)
	get_tree().root.add_child(game)
	get_tree().set_multiplayer(server_multiplayer, game.get_node("Game").get_path())
	game.get_node("Game").init_server()
	queue_free()

func create_config():
	var file := ConfigFile.new()
	
	file.set_value("network", "bind_ip", ProjectSettings.get("server/bind_ip"))
	file.set_value("network", "port", ProjectSettings.get("server/port"))
	file.set_value("network", "transport", ProjectSettings.get("server/transport"))

	file.set_value("limits", "max_players", ProjectSettings.get("server/max_players"))
	file.set_value("limits", "max_lobbies", ProjectSettings.get("server/max_lobbies"))
	
	file.save("server_settings.ini")

func load_config():
	if not FileAccess.file_exists("server_settings.ini"):
		create_config()
		return
	
	var file := ConfigFile.new()
	file.load("server_settings.ini")
	
	var bind_ip: String = file.get_value("network", "bind_ip", ProjectSettings.get("server/bind_ip"))
	var port: int = file.get_value("network", "port", ProjectSettings.get("server/port"))
	var transport: String = file.get_value("network", "transport", ProjectSettings.get("server/transport"))

	var max_players: int = file.get_value("limits", "max_players", ProjectSettings.get("server/max_players"))
	var max_lobbies: int = file.get_value("limits", "max_lobbies", ProjectSettings.get("server/max_lobbies"))
	
	ProjectSettings.set("server/bind_ip", bind_ip)
	ProjectSettings.set("server/port", port)
	ProjectSettings.set("server/transport", transport)
	ProjectSettings.set("server/max_players", max_players)
	ProjectSettings.set("server/max_lobbies", max_lobbies)
