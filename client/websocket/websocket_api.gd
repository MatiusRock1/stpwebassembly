extends RefCounted

const WebSocketClient := preload("res://client/websocket/WebSocketClient.gd")
# Through a TLS proxy the handshake alone can take more than two seconds
const TIMEOUT_SECONDS: float = 6.0

var websocket: WebSocketClient

var pending: Array[ApiRequest] = []
var connected := false
var pending_packets: Array[String] = []

class ApiError:
	var type: String
	var message: String
	var detail: Dictionary
	
	func _init(type: String, message: String, detail := {}):
		self.type = type
		self.message = message
		self.detail = detail

class ApiResponse:
	var content
	var error: ApiError
	
	func _init(content):
		self.content = content
	
	static func from_error(response: Dictionary) -> ApiResponse:
		var err: Dictionary = response.get("error", {})
		var result := ApiResponse.new(null)
		var type: String = err.get("type", "unknown")
		var message: String = err.get("message", "<No message provided>")
		var detail: Dictionary = err.get("detail", {})
		result.error = ApiError.new(type, message, detail)
		return result

class ApiRequest:
	var timer: SceneTreeTimer
	
	signal response(data)

func _init(websocket: WebSocketClient):
	self.websocket = websocket
	websocket.connection_closed.connect(_abort_pending)
	websocket.connected_to_server.connect(func ():
		connected = true
		# Send all buffered packets
		for msg in pending_packets:
			websocket.send(msg))
	websocket.message_received.connect(func (msg: String):
		# Dequeue a request
		var request: ApiRequest = pending.pop_front()
		# Abort the timer
		request.timer = null
		request.response.emit(msg))

func _abort_pending():
	for request in pending:
		request.response.emit(null)
	pending = []

func _do_request(path: String, data := {}) -> ApiResponse:
	var request := ApiRequest.new()
	request.timer = websocket.get_tree().create_timer(TIMEOUT_SECONDS)
	request.timer.timeout.connect(func():
		request.response.emit(null))
	pending.append(request)
	
	var req_data := JSON.stringify({"path": path, "data": data})
	if connected:
		self.websocket.send(req_data)
	else:
		pending_packets.append(req_data)
	
	var response = await request.response
	if response == null:
		return null
	
	var parsed = JSON.parse_string(response)
	if not parsed is Dictionary:
		push_error("Server sent an invalid response")
		return null
	
	var json_response: Dictionary = parsed
	if json_response.has("error"):
		return ApiResponse.from_error(json_response)
	return ApiResponse.new(json_response)

func get_version() -> ApiResponse:
	var response := await _do_request("connectinfo.version")
	if response and response.content:
		response.content = Global.SemVer.deserialize(response.content)
	
	return response
