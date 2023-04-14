#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="$(cd "${BASH_SOURCE[0]%/*}" && pwd)/certs"
rm -rf "$BASE_DIR"
