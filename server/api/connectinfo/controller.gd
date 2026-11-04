extends "res://server/api/router.gd"

class VersionRoute extends ApiRoute:
	func handle(_data: Dictionary) -> ApiResponse:
		return ApiResponse.new(Global.VERSION.serialize())

func _init():
	route("version", VersionRoute.new())
