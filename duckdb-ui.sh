#!/bin/sh
# Launch the DuckDB web UI in a way that's reachable from the Docker host.
#
# DuckDB's UI binds to IPv6 loopback only ([::1]:4213) inside the container,
# which Docker port-publishing cannot reach. We bridge it: socat listens on
# all IPv4 interfaces (0.0.0.0:4213) and forwards to the UI on [::1]:4213.
# `tail -f /dev/null` keeps DuckDB's stdin open so the process — and the UI
# server — stays alive even without an attached TTY.
set -e

DB="${1:-/data/warehouse.duckdb}"

socat TCP4-LISTEN:4213,fork,reuseaddr "TCP6:[::1]:4213" &

echo "DuckDB UI starting — open http://localhost:4213 in your browser."
echo "Database file: ${DB}    (Ctrl-C to stop)"

{ printf "CALL start_ui();\n"; tail -f /dev/null; } | duckdb "${DB}"
