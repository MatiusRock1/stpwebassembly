# SuperTux Party WebAssembly

[SuperTux Party](https://supertux.party/), a free party game built with the Godot Engine, running in the browser: on a computer or in a phone's browser. This repository holds the game's sources and the web adaptations together, on top of the upstream commit recorded in `BASE_COMMIT.txt`.

This is an unofficial port. It is not affiliated with or endorsed by the SuperTux Party project, the Godot Engine project, or the owners of the mascots in the game. It never contacts the project's servers: online play only reaches a server the player or the hosting site chooses.

The original README is [README.upstream.md](README.upstream.md).

## Repository layout

| Path | Contents |
| --- | --- |
| `project.godot`, `client/`, `common/`, `server/`, `plugins/`, `assets/`, `translations/` | The game, with the changes described in [docs/wasm/port.md](docs/wasm/port.md) |
| `common/scripts/web/` | Code only the browser build uses: in-process multiplayer peer, page integration, on-screen gamepad |
| `wasm/` | Docker toolchain, build and package scripts, browser player, online server |
| `docs/wasm/` | [What changed and why](docs/wasm/port.md), [validated versions and commands](docs/wasm/toolchain.md), [licenses of what ships](docs/wasm/licenses.md) |
| `licenses/` | Upstream's license and asset inventories |

Godot itself is not in this repository: the build uses the official 4.7.2 editor and export templates, unmodified and checked by SHA-512 (`wasm/Dockerfile`).

## Build and run

Requirements: Docker and Python 3. Run these from this repository's root. `<work>` is a directory outside OneDrive, for example `C:/stp-web-work`. In Git Bash on Windows, put `MSYS_NO_PATHCONV=1` before `docker run` and use `$(pwd -W)` as the repository path.

```text
docker build -t stp-wasm:toolchain wasm
docker run --rm -v "<repo>:/src" -v stp-wasm-build:/build -v <work>:/work stp-wasm:toolchain sh wasm/build.sh
python wasm/package.py <work>
python wasm/scripts/serve.py <work>/web
```

Then open <http://localhost:8093/index.html>. The first build imports every asset and takes a few minutes; later ones only what changed.

`python wasm/scripts/smoke.py` starts the game in Chrome and checks for working frames. It needs Playwright for Python.

Release templates stay silent about GDScript runtime errors: a broken function just stops. To see them, build with `docker run -e DEBUG=1 ...`, package with `python wasm/package.py <work> --debug` and serve `<work>/web-debug`.

On a local server only, the page takes `?args=` (engine options), `?engine=`, `?data=`, `?pack=desktop|mobile` and `?server=`. `?args=--stp-minigames=hurdle,memory` plays those minigames in order, one per round.

## Deployment

Copy `<work>/web/` to a web server. It needs no special headers, because this build uses no threads. Without HTTPS the page cannot keep the game in Cache Storage and downloads it on every visit.

The two `.pck` files can live elsewhere, such as a CDN that allows the site with CORS: name their directory in `<meta name="stp-data" content="...">` in `index.html`.

## Online play

Browsers cannot use the game's ENet protocol, so the online server in `wasm/server/` speaks WebSocket. It only serves this browser build, not the desktop game.

```text
docker buildx build --build-context work=<work> -t stp-server wasm/server
docker run -p 7634:7634 -p 7635:7635 -e STP_MAX_LOBBIES=4 -e STP_MAX_PLAYERS=32 stp-server
```

A page served over HTTPS needs `wss://`, so put a TLS proxy in front and name its path in `<meta name="stp-server" content="/stp-online">`. The proxy forwards `/stp-online/api` to port 7634 and `/stp-online/game` to port 7635, with the WebSocket upgrade headers and a long read timeout. [docs/wasm/port.md](docs/wasm/port.md#online-play) has the configuration used for testing.

## License and credits

SuperTux Party was created by [its contributors](https://gitlab.com/SuperTuxParty/SuperTuxParty); the in-game credits list them. Its code and these adaptations are under the [GNU GPL v3.0 or later](licenses/LICENSE). Art, music, fonts and shaders have their own licenses, listed per file in `licenses/`. [Godot Engine](https://godotengine.org/) is under the MIT license.
