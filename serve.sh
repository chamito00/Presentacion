#!/usr/bin/env bash
# Levanta un servidor local para ver la presentación en http://localhost:8000
set -e
PORT="${1:-8000}"
echo "Sirviendo presentación en http://localhost:${PORT}"
python3 -m http.server "${PORT}"
