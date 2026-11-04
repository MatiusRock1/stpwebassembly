extends Node3D

@onready var lobby := Lobby.get_lobby(self)

var finished := false

func end_game():
	setup_game_end()
	lobby.broadcast(_client_game_failed)
	await get_tree().create_timer(3).timeout
	lobby.minigame_gnu_loose()

func setup_game_end():
	finished = true
	for node in Utility.get_nodes_in_group(self, &"ghost"):
		node.finished = true
	lobby.broadcast(game_ended)
	$Player1.process_mode = Node.PROCESS_MODE_DISABLED
	$Player2.process_mode = Node.PROCESS_MODE_DISABLED
	$Player3.process_mode = Node.PROCESS_MODE_DISABLED
	$Player4.process_mode = Node.PROCESS_MODE_DISABLED

@rpc
func _client_game_failed():
	$LoseSound.play()
	for node in Utility.get_nodes_in_group(self, &"ghost"):
		node.win()

func _server_process(_delta):
	if $Control/Duration.time_left == 0:
		setup_game_end()
		await get_tree().create_timer(3).timeout
		lobby.minigame_gnu_win()

func _client_process(_delta):
	$Control/Timer.text = "%.1f" % snapped($Control/Duration.time_left, 0.1)

@rpc func game_ended():
	$Control/Timer.hide()
	$Control/Message.show()
	$Player1.process_mode = Node.PROCESS_MODE_DISABLED
	$Player2.process_mode = Node.PROCESS_MODE_DISABLED
	$Player3.process_mode = Node.PROCESS_MODE_DISABLED
	$Player4.process_mode = Node.PROCESS_MODE_DISABLED

@rpc func spawn_ghost(pos: Vector3, ghostname: String):
	var ghost = preload("res://plugins/minigames/haunted_dreams/ghost.tscn").instantiate()
	ghost.position = pos
	ghost.name = ghostname
	add_child(ghost)

var num_ghost_spawned := 0
func _on_Timer_timeout():
	if not multiplayer.is_server() or finished:
		return
	if $Control/Duration.time_left > 5:
		var dir := randf() * 2 * PI
		var pos := Vector3(cos(dir) * 10, 1, sin(dir) * 10)

		num_ghost_spawned += 1
		var ghostname := "Ghost" + str(num_ghost_spawned)

		lobby.broadcast(spawn_ghost.bind(pos, ghostname))
		spawn_ghost(pos, ghostname)
