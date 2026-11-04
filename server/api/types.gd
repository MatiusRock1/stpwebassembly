extends RefCounted

class ApiError:
	var type: String
	var message: String
	var detail: Dictionary
	
	func _init(type: String, message: String, detail := {}):
		self.type = type
		self.message = message
		self.detail = detail
	
	func to_json():
		return JSON.stringify({
			"error": {
				"type": type,
				"message": message,
				"detail": detail
			}
		})

class ApiResponse:
	var content: Variant
	var err: ApiError = null
	
	func _init(content: Variant):
		self.content = content
	
	static func error(error: ApiError) -> ApiResponse:
		var response := ApiResponse.new(null)
		response.err = error
		return response
