#!/usr/bin/env bash
# runs the matrix playbook (setup.yml) against our inventory, from the playbook's
# folder so that its ansible.cfg applies. pass the usual ansible-playbook flags:
#   ./server/playbook.sh --tags=self-check
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
cd "$here/vendor/matrix-docker-ansible-deploy"
exec ansible-playbook -i "$here/inventory/hosts" setup.yml "$@"
