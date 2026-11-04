#!/bin/sh
# Writes the settings server/server.gd reads, from the container's environment.
#
#   STP_MAX_LOBBIES   games running at once: each one simulates a whole match (4)
#   STP_MAX_PLAYERS   connections accepted, in a lobby or not (32)
set -eu

cat > server_settings.ini <<EOF
[network]

bind_ip="*"
port=7634
transport="websocket"

[limits]

max_players=${STP_MAX_PLAYERS:-32}
max_lobbies=${STP_MAX_LOBBIES:-4}
EOF

exec ./stp-server --headless
