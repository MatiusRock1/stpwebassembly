# Toolchain of the SuperTux Party browser port: the official Godot editor, run
# headless, and the official web export templates, both checked against the
# SHA-512 sums Godot publishes with each release. docs/wasm/toolchain.md explains
# the versions. Only the templates this port can use stay in the image.
FROM debian:bookworm-slim

ARG GODOT_VERSION=4.7.2
ARG GODOT_SHA512=9aa00f7a605200940bce3027a567b782f49bd8e940dd06ae9e987bd65aee1b1467edd56ed84fcdcbdd44354bf613bdbb4e5d2913e925850368e150c59ed54c65
ARG TEMPLATES_SHA512=ca4d71c4d7b81dfc15d1a98baa07534aa95b03fdda78a0075b06672e1648d2e5f40980c9adc28d23e1b92e732ee7bf3461997aa804af74ec2fcd7a93ccb84079

RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl unzip rsync libfontconfig1 python3 \
 && rm -rf /var/lib/apt/lists/*

ENV GODOT_RELEASE=https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}-stable

RUN curl -fsSL -o /tmp/godot.zip "$GODOT_RELEASE/Godot_v${GODOT_VERSION}-stable_linux.x86_64.zip" \
 && echo "$GODOT_SHA512  /tmp/godot.zip" | sha512sum -c - \
 && unzip -q /tmp/godot.zip -d /tmp/godot \
 && mv "/tmp/godot/Godot_v${GODOT_VERSION}-stable_linux.x86_64" /usr/local/bin/godot \
 && rm -rf /tmp/godot /tmp/godot.zip

RUN curl -fsSL -o /tmp/templates.tpz "$GODOT_RELEASE/Godot_v${GODOT_VERSION}-stable_export_templates.tpz" \
 && echo "$TEMPLATES_SHA512  /tmp/templates.tpz" | sha512sum -c - \
 && mkdir -p "/root/.local/share/godot/export_templates/${GODOT_VERSION}.stable" \
 && unzip -q -j /tmp/templates.tpz \
      'templates/web_nothreads_release.zip' 'templates/web_nothreads_debug.zip' \
      'templates/linux_release.x86_64' 'templates/linux_release.arm64' 'templates/version.txt' \
      -d "/root/.local/share/godot/export_templates/${GODOT_VERSION}.stable" \
 && rm /tmp/templates.tpz

WORKDIR /src
