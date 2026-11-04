extends RefCounted

const Api := preload("res://server/api/types.gd")

const ApiResponse := Api.ApiResponse
const ApiError := Api.ApiError

func handle(_data: Dictionary) -> ApiResponse:
	push_error("Route not implemented!")
	const TYPE := "routing.error"
	const MSG := "The requested route is not implemented yet. Please report this bug"
	return ApiResponse.error(ApiError.new(TYPE, MSG))
