#!/bin/sh
set -eu
# Internal cookie signing, not a third-party API key. No human credential needed.
if [ -z "${SEARXNG_SECRET:-}" ]; then
  SEARXNG_SECRET="$(head -c 32 /dev/urandom | od -An -tx1 | tr -d ' \n')"
  export SEARXNG_SECRET
fi
exec /usr/local/searxng/entrypoint.sh "$@"
