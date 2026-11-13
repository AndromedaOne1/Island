#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
"$ROOT/Scripts/build-app.sh" "${1:-debug}"
/usr/bin/open -g "$ROOT/build/Island.app"
