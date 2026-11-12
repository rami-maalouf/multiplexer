#!/bin/zsh
# builds the site and publishes it to vercel as a static site: project "mux", served at
# https://mux.orbitlabs.studio. needs bun and the vercel cli, signed in to the account that
# owns orbitlabs.studio. the domain is already attached to the project.
set -euo pipefail
cd "$(dirname "$0")"
bun install --frozen-lockfile
bun run build
vercel deploy dist --prod --yes --project mux
