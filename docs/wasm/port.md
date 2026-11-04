# SuperTux Party in the browser

What the port changes in the game, and why. Versions and commands are in [toolchain.md](toolchain.md).

## How the game fits a browser

SuperTux Party is pure GDScript on Godot, with no native extensions, so the engine's official web template runs it. Godot's Compatibility renderer provides WebGL 2, and the project uses none of the features that renderer lacks. The port only had to change what a browser cannot do, and what the game assumed about windows and keys.

| Problem | Solution |
| --- | --- |
| The game runs a local ENet server even with one player, and browsers have no UDP | `LoopbackPeer`: client and server pass packets directly inside the process |
| Online play uses ENet | `WebSocketMultiplayerPeer` on the client and on our own server |
| Plugins are separate `.pck` files beside the executable | Everything goes in the main package, and the loader skips the plugin directory |
| Threaded loading blocks a build without threads | Requests wait for the frame that shows the loading screen, one per frame |
| Downloads were too large | Two packages by GPU, lighter imports, unused assets excluded |
| Long sounds decode entirely on first play under Godot's web sample mode | Music plays as a stream |
| Phones have no keyboard | On-screen gamepad |

## Multiplayer

### Local games: `common/scripts/web/loopback_peer.gd`

`Global.create_local_server()` used to open ENet on localhost. In the browser it creates a `LoopbackPeer` pair, a `MultiplayerPeerExtension` written in GDScript. Packets are delivered on the receiver's next poll, like a real connection, so `connected_to_server` fires after the caller starts waiting for it. Each end holds the other through a `WeakRef`, so replacing the `MultiplayerAPI` frees both.

The rest of the game cannot tell the difference: it keeps its server tree and client tree in one process, as on the desktop.

### Online play

`Global.connect_remote_server()` uses WebSocket in the browser. `server/server.gd` gained the `server/transport` setting: `enet` by default, and `websocket` for the `Server` feature that the `Web Server` preset sets.

The version API already listens on TCP at `server/port`, next to ENet's UDP port on the desktop. Over WebSocket the game needs its own TCP port, so it uses `server/port + 1`.

`WebPlatform` turns a menu entry into URLs:

| Server entry | Version API | Game connection |
| --- | --- | --- |
| Plain host and port | `ws(s)://host:port` | `ws(s)://host:port+1` |
| A path such as `/stp-online`, or a URL | `<base>/api` | `<base>/game` |

No server is preset. The list starts empty unless the page names one in `<meta name="stp-server">`.

`WebPlatform` reads the page through `JavaScriptBridge.get_interface`, never `eval`: the site's `Content-Security-Policy` allows `wasm-unsafe-eval` but not `eval`, and an enforced policy would make such a call return nothing.

The test configuration, the shape a public site would use:

```nginx
map $http_upgrade $connection_upgrade { default upgrade; '' close; }
location /stp-online/api  { proxy_pass http://stp-server:7634/; proxy_http_version 1.1; proxy_set_header Upgrade $http_upgrade; proxy_set_header Connection $connection_upgrade; proxy_read_timeout 1h; }
location /stp-online/game { proxy_pass http://stp-server:7635/; proxy_http_version 1.1; proxy_set_header Upgrade $http_upgrade; proxy_set_header Connection $connection_upgrade; proxy_read_timeout 1h; }
```

### Limits on a public server

Every lobby simulates a whole game on the server, and anyone can connect.

- `server/max_lobbies` limits the games running at once, and a client can only be in one when creating a lobby. `STP_MAX_LOBBIES` sets it, 4 by default in the image.
- `server/max_players` limits connections, which WebSocket does not do by itself. `STP_MAX_PLAYERS`, 32 by default.
- Player names are cut to 32 characters, because other players see them.
- `run/max_fps.Server=60`: without a display to wait for, the server spun a whole core.

Not covered: a client flooding RPCs. A public deployment should limit connections per address in the proxy.

Upstream's "kick players for inactivity" stays on for online lobbies, with a 30 second default. Two browsers left idle on a dialog are removed, by design. The owner can turn it off in the lobby.

## Package size

- **One package per GPU family.** The presets `Web` (S3TC, BPTC) and `Web Mobile` (ETC2, ASTC) each export the whole game. The player asks the GPU, not the user agent: `WEBGL_compressed_texture_s3tc` selects the desktop package. Asking for both formats in one package doubled the textures.
- **`wasm/scripts/tune_imports.py`** edits import settings:
  - GPU-compressed textures: at most 1024 pixels per side. Some were 4096, such as `tux_texture.png` on a cake.
  - Lossless textures over 256 KiB, mostly screenshots: lossy WebP with the same limit.
  - WAV files over 1 MiB, 71 MB of music: QOA, about a fifth of the size, keeping the path the scenes use.
- **`wasm/scripts/unused_assets.gd` and `update_exclusions.py`** list what nothing reaches and exclude it from the web presets: 124 files, 132 MB of sources, mostly a nature art pack. They stay in the repository. A file counts as used if a script names it, if it is a dependency of anything outside `assets/`, or if it is in a directory scripts build paths from.

The player keeps the large files in Cache Storage under their content hash, so a return visit starts without the network: 13 s on the first visit and 3 s on the next, measured locally.

## Audio

Godot's web sample mode, the default, plays effects without depending on the main thread: they keep playing during a load. It also decodes the whole stream into memory at the first `play()`, which for a long track means a stall and tens of megabytes. `tune_imports.py` therefore sets `playback_type = 1` (stream) on players of long sounds in 13 scenes. `driver/output_latency.web=100` gives streamed music room for slow frames.

## Graphics and page integration

- `window/stretch/mode.web="canvas_items"` with `aspect="expand"`: the 1280x720 layout scales to any canvas. Upstream has no stretch mode, so its UI stays small on a large screen and overflows on a phone.
- The player sizes the canvas (`canvasResizePolicy: 0` and a `ResizeObserver`) and caps the pixel ratio at 2 on touch screens.
- `omni_shadow_mode = 0` removed from `kernel_compiling`: the renderer only has cubemap shadows for omni lights and reported the other mode on every frame.
- A 60 FPS cap drops frames on a 60 Hz display, because frames do not arrive exactly on target. On the web the frame cap defaults to uncapped: the browser already paces frames.
- Quality defaults to Low on touch screens, and the shadow atlas stops at 4096 instead of 16384.
- Unavailable options hide on the web: Quit, Screenshots, VSync. The screenshot key downloads the file.

## Phones

`common/scripts/web/touch_controls.gd` draws a gamepad during the game when the page reports a coarse pointer. Each button sends the event mapped to player 1's action, so the lobby converts it to the right player like any key, and remapped controls keep working. Action buttons show the letter the game's hints use. The bottom one also confirms, as a gamepad's A button does in the default mapping. Menus work through touches as mouse clicks.

The page fills the window on touch screens and asks to turn the phone in portrait. An iPhone has no fullscreen for pages, so the surface is fixed to the window as well.

`left_mouse_pressed` was bound to device 0, while touch-emulated mouse events come from device -1, so taps on dialogs and board arrows would not have matched. It now listens to all devices.

## Things players could not figure out

Reported while testing. The original game waits for keys without saying so.

- **`ControlHelper.hint()`** builds on-screen hints with the player's actual key, and separate wording on touch screens. They appear on the turn banner, item selection, speech dialogs, junction arrows, space selection, shop and duel selection. Clicking or touching the board also rolls.
- **Start with no character** did nothing, because the server ignores the request. It now opens the character menu, and the empty button says "Choose character". A name typed without pressing Enter is kept. Other languages fall back to English for these new texts.
- **The turn banner** said "It's your turn!" on the bots' turns too. It now names the player.
- **The dice** is not in the original: there it is just an icon, and the number appears at once. The selected item now turns, and a roll shows a spinning dice with shuffling numbers for 0.8 s, for which the server waits before moving the player.
- The join code is hidden in local games, where nobody can use it.
- Spanish joined the language menu, "Gira" became "Turnos", and "Es tu turno!" got its opening mark.

## Upstream bugs fixed

These affect the desktop game too.

| File | Problem | Fix |
| --- | --- | --- |
| `client/menus/main_menu.tscn` | Commit `cde322f9` saved offsets as if the parent had no size, so the logo covered the buttons | The values from before that commit |
| `common/scripts/loader/item_loader.gd` | An exported game finds `item.gd.remap` and `item.gdc`, so every item appeared twice in the shop | Only look for `item.gd` |
| `common/scenes/speech_dialog/speech_dialog.gd` | A dialog opened by the client only accepts the current player's key. When a bot bought the cake a keyboard player was stuck, and online everyone but the current player was kicked after 30 s | The first local player can close it |
| `itemselection.gd` | Arrows moved focus to empty slots or the background, and confirming then did nothing | Those no longer take focus. Same background fix in `duelselection.gd` |
| `client/menus/main_menu.gd` | Godot 3 calls (`network_peer`) broke loading a saved game and failed connections | Godot 4 equivalents |
| `client/game.gd` | `scene.filename` no longer exists. `lobby_creation_failed` emitted null, which crashed the caller | `scene_file_path`, and an error message for the player |
| `common/scripts/global.gd` | After a lost connection the menu reopened the dead server's list, because `queue_free` runs at the end of the frame | `get_current_server()` ignores a client being freed, and a message explains what happened |
| `client/menus/options_menu.gd` | `set_msaa` and `set_use_fxaa` no longer exist | `msaa_3d` and `screen_space_aa` |
| `server/lobby.gd` | `leave()` assigned an untyped array to `player_info`, which fails. Bots stayed in the lobby after a game, and a player who left mid-lobby stayed as a ghost | Typed array |

## Moving from Godot 4.2 to 4.7

Upstream's `.import` files have no `gltf/naming_version`, so Godot 4.7 read them as version 0, older than the game. Version 0 reserves the file's name, so the root node `stage` of `stage.glb` became `stage2`, and the victory screen lost its camera animation and lights: the paths `Scene/stage/Camera` no longer resolved. Godot 4.2 behaves as version 1, which `tune_imports.py` now sets on every glTF model.

## A bug the port introduced

`client/rewardscreens/common.gd` sized its 3D view with `get_viewport().size`, the window in pixels. Harmless upstream, where nothing scales. With the stretched canvas the container draws that size through the scale again, so at 1920x1080 the view was 1.5 times larger than the screen, and characters were cut off. It now uses the visible rectangle. The 3D of those screens therefore renders at the scaled size, slightly softer on a large monitor.

The same screens place a column of texts under each character: reward, total and what to press. It fit on a 1080p window without scaling, but the scaled canvas is always about 720 high and the last row fell off the screen. The rows are now shorter (`cookie_text.tscn`) and `position_beneath()` keeps the column on screen.

## What has been tested

On 2026-11-04, Chrome on Windows with an AMD integrated GPU, 60 FPS throughout.

- Menu, lobby, a full round with bots, reward screen, in English and Spanish. Results of the rest of the minigames: see the end of this section.
- Online between two Chrome instances through nginx: version check, public lobby and join code, both reaching the board in sync. A full online match has not been played.
- Cache Storage: the second visit starts in about 3 s.
- Packages hold only their texture formats: counted in the files.

Automated match through the minigames with a debug build (`--stp-minigames`), pressing keys at random:

| Minigame | Result |
| --- | --- |
| `kernel_compiling` | Played by hand as well |
| `hurdle`, `harvest_food` | Ran to the reward screen, no script errors |

Godot logs "Node not found" and "Invalid packet received" a few times when a client sends an RPC for a scene the server has just left. Upstream's protocol has this race and it is harmless.

Not tested: audio by ear, gamepads, saved games beyond the code fix, phones (see [toolchain.md](toolchain.md)).
