#!/bin/sh
# Imports the project and exports the browser build and its server, inside the
# toolchain image:
#
#   docker run --rm -v "<repo>:/src" -v stp-wasm-build:/build -v <work>:/work \
#     stp-wasm:toolchain sh wasm/build.sh
#
# Godot writes next to the project (.godot/, reimported .import files), so it
# works on a copy in a Docker volume: OneDrive and the Windows file share are
# slow with thousands of small files, and the repository stays clean. The first
# run imports every asset; later runs only what changed.
#
# Two packages come out for the browser, one per family of GPU texture formats.
# Each holds the whole game, so a device only downloads the textures it can use.
#
# DEBUG=1 (docker run -e DEBUG=1) exports to <work>/godot-debug with the debug
# template instead and skips the server. Release templates stay silent about GDScript
# runtime errors: a broken function just stops, so look for those in a debug build.
set -eu

SRC=${SRC:-/src}
PROJECT=/build/project
TEMPLATES=/root/.local/share/godot/export_templates/4.7.2.stable

if [ "${DEBUG:-0}" = 1 ]; then
  OUT=/work/godot-debug
  EXPORT=--export-debug
else
  OUT=/work/godot
  EXPORT=--export-release
fi
SERVER=/work/server

mkdir -p "$PROJECT" "$OUT" "$SERVER"
rsync -a --delete --modify-window=2 \
  --exclude=/.git --exclude=/.godot --exclude=/wasm --exclude=/docs \
  --exclude=/.gitlab-ci.yml --exclude=/smoke-evidence \
  "$SRC/" "$PROJECT/"

# Godot exits with an error here when a single asset fails; its log names the
# asset and the export below still reports what is missing.
godot --headless --path "$PROJECT" --import || echo "import finished with errors, see above"

godot --headless --path "$PROJECT" "$EXPORT" Web "$OUT/stp.html"
mv "$OUT/stp.pck" "$OUT/stp.desktop.pck"
godot --headless --path "$PROJECT" --export-pack "Web Mobile" "$OUT/stp.mobile.pck"
rm -f "$OUT/stp.html" "$OUT/stp.png"

if [ "${DEBUG:-0}" != 1 ]; then
  # The server is the official Linux runtime with its own package.
  godot --headless --path "$PROJECT" --export-pack "Web Server" "$SERVER/stp-server.pck"
  cp "$TEMPLATES/linux_release.x86_64" "$SERVER/stp-server.amd64"
  cp "$TEMPLATES/linux_release.arm64" "$SERVER/stp-server.arm64"
fi

ls -l "$OUT"
