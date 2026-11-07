#!/bin/zsh
# builds the site and publishes it to vercel as a static site: project "mux", served at
# https://mux.orbitlabs.studio. needs the vercel cli, signed in to the account that owns
# orbitlabs.studio. the first run creates the project; adding the domain is a one-time step
# (`vercel domains add mux.orbitlabs.studio mux`).
set -euo pipefail
cd "$(dirname "$0")"
bun exact.mjs web-build --out dist
vercel deploy dist --prod --yes --project mux
