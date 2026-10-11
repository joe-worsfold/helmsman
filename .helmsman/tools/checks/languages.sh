#!/usr/bin/env bash
# Local full gate. CI does not call this. Each check is its own job via task.sh.
# Integration and the e2e smoke stay on those jobs. They are not part of this command.
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
if [[ $# -gt 0 ]]; then
  exec "$here/task.sh" "$@"
fi
exec "$here/task.sh" all
