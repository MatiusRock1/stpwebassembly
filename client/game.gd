extends Node

signal create_lobby_callback(name)
signal join_lobby_callback(success)
signal public_lobbies(list)
signal version(prot, name)

var current_lobby

func init_client():
	multiplayer.server_disconnected.connect(self._on_connection_lost)

func _on_connection_lost():
	current_lobby = null
	Global.show_error(tr("MENU_ERROR_CONNECTION_LOST"))
	var scene := get_tree().current_scene
	if not scene or scene.scene_file_path != "res://client/menus/main_menu.tscn":
		get_tree().change_scene_to_file("res://client/menus/main_menu.tscn")
	Global.shutdown_connection()

func _process(delta: float):
	# Run the client main loop
	# Note: We cannot use self.propagate_call here because we need to check
	# whether the node to be called is currently disabled from processing
	Utility.propagate_process_call(self, "_client_process", [delta])

# Some boilerplate rpc function definitions
# This is necessary, because since Godot4 these methods must be declared
# on the sending side as well
@rpc("any_peer")
func server_create_lobby(): pass
@rpc("any_peer")
func server_join_lobby(_lobby_name: String): pass
@rpc("any_peer")
func get_public_lobbies(): pass

func create_lobby() -> Node:
	server_create_lobby.rpc_id(1)
	var lobby_name = await self.create_lobby_callback
	if lobby_name.is_empty():
		return null
	var lobby = preload("res://client/lobby.tscn").instantiate()
	lobby.name = lobby_name
	add_child(lobby)
	current_lobby = lobby
	return lobby

func join_lobby(lobby_name: String) -> Node:
	var lobby = preload("res://client/lobby.tscn").instantiate()
	lobby.name = lobby_name
	add_child(lobby)
	server_join_lobby.rpc_id(1, lobby_name)
	if not await self.join_lobby_callback:
		lobby.free()
		return null
	current_lobby = lobby
	return lobby

func update_lobbies():
	get_public_lobbies.rpc_id(1)

@rpc func public_lobbies_callback(list: Array):
	public_lobbies.emit(list)

@rpc func lobby_creation_failed():
	Global.show_error(tr("MENU_ERROR_SERVER_BUSY"))
	create_lobby_callback.emit("")

@rpc func lobby_created(lobby_name: String):
	create_lobby_callback.emit(lobby_name)

@rpc func lobby_join_failed():
	join_lobby_callback.emit(false)

@rpc func lobby_joined():
	join_lobby_callback.emit(true)
