extends RefCounted

const Api := preload("res://server/api/types.gd")
const ApiRoute := preload("res://server/api/route.gd")

const ApiResponse := Api.ApiResponse
const ApiError := Api.ApiError

const Router := preload("res://server/api/router.gd")

static var NOT_FOUND := ApiError.new("routing.notfound", "The requested api does not exist")
static var INTERNAL_ERROR := ApiError.new("internal", "There was an error processing your request. Please report this bug")

var routes: Dictionary

## internal helper function to add a route/router as gdscript does not support neither
## type unions nor function overloading [br]
## Use Router.route / Router.nested instead
func _add_route(path: String, route: Variant):
	var components := path.split(".")
	components.reverse()
	var cur: Dictionary = routes
	
	# add nested dictionaries if they don't exist
	while components.size() > 1:
		if cur.has(components[0]) and not cur[components[0]] is Dictionary:
			push_error("Api Route " + path + " already exists")
			return
		elif not cur.has(components[0]):
			cur[components[0]] = {}
		components.resize(components.size() - 1)
	
	# finally add the route at the bottom
	if cur.has(components[0]):
		push_error("Api Route " + path + " already exists")
		return
	cur[components[0]] = route

func nested(path: String, route: Router):
	_add_route(path, route)

func route(path: String, route: ApiRoute):
	_add_route(path, route)

func handle(components: PackedStringArray, data: Variant) -> ApiResponse:
	if components.is_empty():
		return ApiResponse.error(NOT_FOUND)
	
	while routes.has(components[components.size() - 1]):
		var route = routes[components[components.size() - 1]]
		components.resize(components.size() - 1)
		if route is ApiRoute:
			return route.handle(data)
		elif route is Router:
			return route.handle(components, data)
		elif route is Dictionary:
			# nested routes
			continue
		else:
			push_error("requested route is neither an ApiRoute nor a Router")
			return ApiResponse.error(INTERNAL_ERROR)
	return ApiResponse.error(NOT_FOUND)
