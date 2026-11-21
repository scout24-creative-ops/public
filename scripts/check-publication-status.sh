#!/usr/bin/env bash
set -euo pipefail
[[ $# -eq 1 ]] || { printf 'Usage: %s <source-file>\n' "$0" >&2; exit 64; }
script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
exec python3 "$script_dir/source_records.py" file "$1"
