# Online server of the browser build: the official Godot Linux runtime, headless,
# with the game package. wasm/build.sh writes both into <work>/server.
#
#   docker buildx build --build-context work=<work> -t stp-server wasm/server
#
# It listens on two WebSocket ports: 7634 answers the menu's version check and
# 7635 carries the game. Put a TLS proxy in front on a public site, because pages
# served over HTTPS can only open wss:// (docs/wasm/port.md, "Online play").
FROM debian:bookworm-slim

ARG TARGETARCH

RUN apt-get update \
 && apt-get install -y --no-install-recommends libfontconfig1 \
 && rm -rf /var/lib/apt/lists/* \
 && useradd --system --uid 10001 --home-dir /server --create-home stp

COPY --from=work --chmod=755 server/stp-server.${TARGETARCH} /server/stp-server
COPY --from=work server/stp-server.pck /server/stp-server.pck
COPY --chmod=755 entrypoint.sh /server/entrypoint.sh

USER stp
WORKDIR /server
EXPOSE 7634 7635
ENTRYPOINT ["/server/entrypoint.sh"]
