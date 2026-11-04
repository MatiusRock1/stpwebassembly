extends Node

## Imports
const WebSocketServer := preload("res://server/websocket/WebSocketServer.gd")
const Api := preload("res://server/api/types.gd")
const ApiRoute := preload("res://server/api/route.gd")

const Router := preload("res://server/api/router.gd")

const ApiError = Api.ApiError
const ApiResponse = Api.ApiResponse

## API endpoints
const ConnectInfo := preload("res://server/api/connectinfo/controller.gd")

## Top-Level error messages
static var INVALID_FORMAT := ApiError.new("format.invalid", "The request has not been a valid JSON message")
static var MISSING_PATH := ApiError.new("format.invalid", "The request is missing a path entry")
static var INVALID_PATH := ApiError.new("format.invalid", "The requested path is not a string")
static var INVALID_DATA := ApiError.new("format.invalid", "The request data is not an object")
static var RATELIMIT := ApiError.new("limit.toomany", "Too many requests. Please try again later")

## Throttling info
const MAX_REQUESTS_PER_TIMESTAMP := 10
const TIMESTAMP_DURATION_SECONDS := 120 # 2 minutes

var websocket: WebSocketServer
var router := Router.new()

var peer_ip := {}
var request_log := {}

class ApiRequestLog:
	var timestamp: float
	var endpoint: String

func _init():
	setup_routes()
	setup_websocket()

func setup_routes():
	router.nested("connectinfo", ConnectInfo.new())

func setup_websocket():
	var node := Node.new()
	node.set_script(WebSocketServer)
	websocket = node
	add_child(node)
	
	websocket.client_connected.connect(_on_websocket_connect)
	websocket.client_disconnected.connect(_on_websocket_disconnect)
	websocket.message_received.connect(_on_websocket_message)
	
	websocket.listen(ProjectSettings.get("server/port"))

func _on_websocket_connect(peer: int):
	var websocket_peer: WebSocketPeer = websocket.peers[peer]
	var ip := websocket_peer.get_connected_host()
	# Record the peer's ip address as it cannot be accessed when client disconnects
	peer_ip[peer] = ip
	var timestamps: Array[ApiRequestLog] = []
	request_log[ip] = timestamps

func _on_websocket_disconnect(peer: int):
	request_log.erase(peer_ip[peer])
	peer_ip.erase(peer)

func _on_websocket_message(peer: int, message: String):
	var response := _handle(peer, message)
	if response.err != null:
		websocket.send(peer, response.err.to_json())
	else:
		websocket.send(peer, JSON.stringify(response.content))

func _handle(peer: int, message: String) -> ApiResponse:
	var ip: String = peer_ip[peer]
	
	# rate limiting
	var timestamps: Array[ApiRequestLog] = request_log[ip]
	# remove outdated logged requests
	# Unfortunately this is O(n^2), we should keep the maximum number
	# of api calls low for performance reasons
	var first_timestamp := Time.get_ticks_msec() - TIMESTAMP_DURATION_SECONDS * 1000
	while not timestamps.is_empty() and timestamps[0].timestamp < first_timestamp:
		timestamps.pop_front()
	if timestamps.size() > MAX_REQUESTS_PER_TIMESTAMP:
		return ApiResponse.error(RATELIMIT)
	
	var data = JSON.parse_string(message)
	
	if not data is Dictionary:
		return ApiResponse.error(INVALID_FORMAT)
	
	var request: Dictionary = data
	if not request.has("path"):
		return ApiResponse.error(MISSING_PATH)
	if not request["path"] is String:
		return ApiResponse.error(INVALID_PATH)
	
	# log request
	var log_entry := ApiRequestLog.new()
	log_entry.timestamp = Time.get_ticks_msec()
	log_entry.endpoint = request["path"]
	timestamps.append(log_entry)
	
	var api_data := {}
	if request.has("data"):
		if request["data"] is Dictionary:
			api_data = request["data"]
		else:
			return ApiResponse.error(INVALID_DATA)
	
	var path_components: PackedStringArray = request["path"].split(".")
	# for performance reasons, invert the path order and pop back insted of pop_front
	# Processing becomes O(n) instead of O(n^2) because of this
	path_components.reverse()
	return router.handle(path_components, api_data)
