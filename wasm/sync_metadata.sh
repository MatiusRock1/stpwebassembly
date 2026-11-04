#!/bin/sh
# Copies the files Godot generates next to the sources back to the repository,
# after wasm/build.sh has imported the project. Godot's documentation asks to keep
# them in version control: .import holds the import settings and .uid the stable
# IDs that scenes refer to. Without them every build imports the project again.
#
#   docker run --rm -v "<repo>:/src" -v stp-wasm-build:/build stp-wasm:toolchain sh wasm/sync_metadata.sh
set -eu

rsync -a --modify-window=2 --exclude=/.godot \
  --include='*/' --include='*.import' --include='*.uid' --exclude='*' \
  /build/project/ /src/
