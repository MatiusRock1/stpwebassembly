## In-process [MultiplayerPeer] pair for the browser build. [br]
## The game always runs a server next to its client, even with one player, and
## on the desktop they talk through ENet on localhost. A browser has no UDP
## sockets, so here the two peers hand their packets straight to each other. [br]
## Packets are delivered on the receiver's next poll, like a real connection, so
## [code]connected_to_server[/code] fires after the caller starts waiting for it.
class_name LoopbackPeer
extends MultiplayerPeerExtension

const SERVER_ID := 1
## Large enough for any RPC; nothing crosses a real network.
const MAX_PACKET_SIZE := 1 << 24

class Packet:
	var from: int
	var channel: int
	var mode: int
	var data: PackedByteArray

	func _init(from_id: int, transfer_channel: int, transfer_mode: int, content: PackedByteArray):
		from = from_id
		channel = transfer_channel
		mode = transfer_mode
		data = content

# Weak, so that the two ends can be freed: each MultiplayerAPI owns its own end.
var _remote: WeakRef
var _remote_id := 0
var _unique_id := 0
var _status := CONNECTION_DISCONNECTED
var _announced := false

var _inbox: Array[Packet] = []

var _target := 0
var _transfer_channel := 0
var _transfer_mode := TRANSFER_MODE_RELIABLE
var _refuse_connections := false

## Creates a connected pair: the first element is the server (always peer 1),
## the second is the client.
static func create_pair() -> Array[LoopbackPeer]:
	var server := LoopbackPeer.new()
	var client := LoopbackPeer.new()
	server._unique_id = SERVER_ID
	client._unique_id = client.generate_unique_id()
	server._remote = weakref(client)
	client._remote = weakref(server)
	server._remote_id = client._unique_id
	client._remote_id = server._unique_id
	server._status = CONNECTION_CONNECTED
	client._status = CONNECTION_CONNECTING
	return [server, client]

func _is_server() -> bool:
	return _unique_id == SERVER_ID

func _get_unique_id() -> int:
	return _unique_id

func _get_connection_status() -> ConnectionStatus:
	return _status

func _poll() -> void:
	if _status == CONNECTION_DISCONNECTED:
		return
	if _remote.get_ref() == null:
		_disconnect()
	elif not _announced:
		_announced = true
		_status = CONNECTION_CONNECTED
		peer_connected.emit(_remote_id)

func _close() -> void:
	_disconnect()

func _disconnect_peer(_peer: int, _force: bool) -> void:
	_disconnect()

func _disconnect() -> void:
	if _status == CONNECTION_DISCONNECTED:
		return
	var remote: LoopbackPeer = _remote.get_ref()
	_status = CONNECTION_DISCONNECTED
	_inbox.clear()
	if _announced:
		peer_disconnected.emit(_remote_id)
	if remote:
		remote._disconnect()

func _get_available_packet_count() -> int:
	return _inbox.size()

func _get_max_packet_size() -> int:
	return MAX_PACKET_SIZE

func _get_packet_script() -> PackedByteArray:
	return _inbox.pop_front().data

func _put_packet_script(buffer: PackedByteArray) -> Error:
	var remote: LoopbackPeer = _remote.get_ref() if _status == CONNECTION_CONNECTED else null
	if not remote:
		return ERR_UNCONFIGURED
	# 0 is everyone and a negative target excludes that peer. The only other peer
	# in this network is the remote one.
	if _target == 0 or _target == _remote_id or (_target < 0 and _target != -_remote_id):
		remote._inbox.append(Packet.new(_unique_id, _transfer_channel, _transfer_mode, buffer))
	return OK

func _get_packet_channel() -> int:
	return _inbox[0].channel

func _get_packet_mode() -> TransferMode:
	return _inbox[0].mode

func _get_packet_peer() -> int:
	return _inbox[0].from

func _set_target_peer(peer: int) -> void:
	_target = peer

func _get_transfer_channel() -> int:
	return _transfer_channel

func _set_transfer_channel(channel: int) -> void:
	_transfer_channel = channel

func _get_transfer_mode() -> TransferMode:
	return _transfer_mode

func _set_transfer_mode(mode: TransferMode) -> void:
	_transfer_mode = mode

func _is_server_relay_supported() -> bool:
	return false

func _set_refuse_new_connections(enable: bool) -> void:
	_refuse_connections = enable

func _is_refusing_new_connections() -> bool:
	return _refuse_connections
