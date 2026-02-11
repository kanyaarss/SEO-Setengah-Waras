#!/bin/sh
set -eu

APP_BIN="/app/bin/elixir_nawala_dk168"

if [ "${SKIP_MIGRATIONS:-false}" != "true" ]; then
  echo "Running database migrations..."
  "$APP_BIN" eval "ElixirNawalaDK168.Release.migrate()"
fi

echo "Starting application..."
exec "$APP_BIN" "${1:-start}"
