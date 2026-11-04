## What the browser build needs to know about its page. [br]
## On other platforms these functions return the values of the original game.
class_name WebPlatform

## The game server listens on the API port + 1 when it is addressed by host name
const GAME_PORT_OFFSET := 1

static var _is_touch = null

# Objects of the page. JavaScriptBridge.eval is not an option here: the site's
# Content-Security-Policy blocks eval, and the call would just return nothing.
static func _page(interface: String) -> JavaScriptObject:
	return JavaScriptBridge.get_interface(interface)

## Whether the player is on a phone or tablet, as far as the page can tell
static func is_touch_device() -> bool:
	if _is_touch == null:
		_is_touch = OS.has_feature("web") and bool(_page("window").matchMedia("(pointer: coarse)").matches)
	return _is_touch

## Graphics quality of a player who has not chosen one (index of the options menu)
static func default_quality() -> int:
	const MEDIUM := 1
	const LOW := 2
	return LOW if is_touch_device() else MEDIUM

## Servers offered before the player has saved a list: the one this site names in
## <meta name="stp-server">, if any. An empty list otherwise, as in the original
## game: this build never contacts a server the player or the site did not choose.
static func default_servers() -> Array:
	if not OS.has_feature("web"):
		return []
	var meta = _page("document").querySelector('meta[name="stp-server"]')
	if not meta or String(meta.content).is_empty():
		return []
	return [{"display_name": "Source Quest", "host": String(meta.content), "port": 0}]

## The address of a server entry of the menu without a trailing slash, if it is
## a URL or a path on this site. Empty if it is a plain host name.
static func _server_base(host: String) -> String:
	if host.begins_with("/"):
		var origin := String(_page("location").origin).replace("http", "ws")
		return (origin + host).trim_suffix("/")
	if host.begins_with("ws://") or host.begins_with("wss://"):
		return host.trim_suffix("/")
	if host.begins_with("http://") or host.begins_with("https://"):
		return host.replace("http", "ws").trim_suffix("/")
	return ""

static func _plain_url(host: String, port: int) -> String:
	# A page served over HTTPS may only open secure WebSockets
	var scheme := "wss://" if _page("location").protocol == "https:" else "ws://"
	# Assume ":" means IPv6 (otherwise it is invalid anyway)
	return scheme + ("[%s]:%d" % [host, port] if ":" in host else "%s:%d" % [host, port])

static var _test_minigames = null

## Test hook: --stp-minigames=hurdle,memory plays these minigames in order, one each
## round. The player only passes engine options on a local server (?args=).
static func apply_test_minigame(lobby: Lobby, state: Lobby.MinigameState) -> void:
	if _test_minigames == null:
		_test_minigames = []
		for argument in OS.get_cmdline_args():
			if argument.begins_with("--stp-minigames="):
				_test_minigames = Array(argument.get_slice("=", 1).split(","))
				lobby.overrides.max_turns = _test_minigames.size()
	if _test_minigames.is_empty():
		return
	var minigame: String = _test_minigames.pop_front()
	var config := PluginSystem.minigame_loader.get_config_by_path("res://plugins/minigames/%s/minigame.json" % minigame)
	state.minigame_config = config
	var everyone := [1, 2, 3, 4]
	match config.type[0]:
		"FFA":
			state.minigame_type = Lobby.MINIGAME_TYPES.FREE_FOR_ALL
			state.minigame_teams = [everyone, []]
		"2v2":
			state.minigame_type = Lobby.MINIGAME_TYPES.TWO_VS_TWO
			state.minigame_teams = [[1, 2], [3, 4]]
		"1v3":
			state.minigame_type = Lobby.MINIGAME_TYPES.ONE_VS_THREE
			state.minigame_teams = [[2, 3, 4], [1]]
		"NolokSolo":
			state.minigame_type = Lobby.MINIGAME_TYPES.NOLOK_SOLO
			state.minigame_teams = [[1], []]
		"NolokCoop":
			state.minigame_type = Lobby.MINIGAME_TYPES.NOLOK_COOP
			state.minigame_teams = [everyone, []]
		"GnuSolo":
			state.minigame_type = Lobby.MINIGAME_TYPES.GNU_SOLO
			state.minigame_teams = [[1], []]
			lobby.minigame_reward = Lobby.MinigameReward.new()
			lobby.minigame_reward.gnu_solo_item_reward = load(PluginSystem.item_loader.get_buyable_items()[0]).new()
		"GnuCoop":
			state.minigame_type = Lobby.MINIGAME_TYPES.GNU_COOP
			state.minigame_teams = [everyone, []]
	print("[stp-test] minigame ", minigame)

## Where the server's version API listens
static func api_url(host: String, port: int) -> String:
	var base := _server_base(host)
	return base + "/api" if base else _plain_url(host, port)

## Where the server's game connection listens
static func game_url(host: String, port: int) -> String:
	var base := _server_base(host)
	return base + "/game" if base else _plain_url(host, port + GAME_PORT_OFFSET)
