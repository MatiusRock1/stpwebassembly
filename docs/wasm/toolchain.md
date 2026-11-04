# Toolchain

## Versions

| Component | Version | Source |
| --- | --- | --- |
| SuperTux Party | `4812d74606bb008af215a7a1eae280c78f23ce60` (`dev`, 2025-01-24) | `BASE_COMMIT.txt` |
| Godot editor, Linux x86_64 | 4.7.2-stable | GitHub release, SHA-512 in `wasm/Dockerfile` |
| Godot export templates | 4.7.2-stable, kept: `web_nothreads_release`, `web_nothreads_debug`, `linux_release.x86_64`, `linux_release.arm64` | Same |
| Base image | `debian:bookworm-slim` | Docker Hub |
| Emscripten | 4.0.20, inside the official template, not installed here | Reported by the engine at startup |

Upstream targets Godot 4.2. The port moved to 4.7.2 because Godot 4.3 and later offer a web export without threads, and because later versions bring a better Compatibility renderer. The project opened and exported without code changes caused by the version; the fixes in `port.md` are upstream bugs or browser adaptations.

## Why these choices

- **Official templates, no engine fork.** Nothing has needed an engine change. Godot is MIT licensed, so distributing its official template carries no source obligation beyond its notice. If a change becomes necessary, build a template from source with the matching Emscripten and set `custom_template/*` in the presets.
- **No threads.** No `SharedArrayBuffer`, so no dependency on COOP/COEP and a real chance on Safari and iPhone, which the threaded SuperTuxKart port does not have. Costs: resource loads block the page (`Global._start_waiting_loads` shows the loading screen first), and streamed music is mixed on the main thread.
- **Work on a copy in a Docker volume.** Godot writes `.godot/` next to the project and handles thousands of small files, which is slow through OneDrive and the Windows file share. `wasm/build.sh` copies the tree to the `stp-wasm-build` volume with rsync.

## Metadata in the repository

After an import, `wasm/sync_metadata.sh` copies `.import` and `.uid` files from the volume to the repository. Godot's documentation asks to keep them under version control, and without them rsync would overwrite the generated ones and every build would import again. Run it after any change that adds assets or scripts.

```text
docker run --rm -v "<repo>:/src" -v stp-wasm-build:/build stp-wasm:toolchain sh wasm/sync_metadata.sh
```

## Tuning scripts

Both write into the repository and are safe to run again:

```text
python wasm/scripts/tune_imports.py
```

```text
docker run --rm -v "<repo>:/src" -v stp-wasm-build:/build stp-wasm:toolchain sh -c \
  'cp /src/wasm/scripts/unused_assets.gd /tmp/ && godot --headless --path /build/project --script /tmp/unused_assets.gd 2>&1 | grep -E "^(UNUSED|DONE)"' > unused.txt
python wasm/scripts/update_exclusions.py unused.txt
```

`port.md` explains what each one does and why.

## Sizes

Measured on the build of 2026-11-04.

| File | Size |
| --- | --- |
| `stp.wasm` | 38 MiB |
| `stp.desktop.<hash>.pck` | 123 MiB |
| `stp.mobile.<hash>.pck` | 123 MiB |
| Online server image, amd64 | 285 MB |

The first export, with both texture formats in one package and nothing tuned, was 421 MB.

## Not verified

- Android and iPhone browsers. The owner tests Android himself; iPhone and Safari have not been tried.
- The mobile package rendering correctly: it depends on `WEBGL_compressed_texture_etc`, which the development machine's GPU lacks under Direct3D 11. There, `?pack=mobile` draws black textures with `compressedTexImage2D: invalid format`. That does not happen with the automatic choice, which picks the desktop package when S3TC is present.
- Firefox.
- An arm64 server image. The arm64 runtime is copied into the build context, but only amd64 has been run.
