#!/bin/bash
# Writes a patched copy of Homebrew's wg-quick that stops its macOS route monitor from
# rewriting DNS on every network service after every route *lookup* (which pegs configd/airportd).
#   1. ignore RTM_GET / RTM_MISS: lookups, not route changes
#   2. skip `networksetup -setdnsservers` for services whose DNS is already correct
# usage: patch-wg-quick.sh SRC DEST
set -euo pipefail
src=$1 dest=$2
patched=$(perl -0pe '
  $n += s/\[\[ \$event == RTM_\* \]\] \|\| continue/[[ \$event == RTM_* && \$event != RTM_GET* && \$event != RTM_MISS* ]] || continue/;
  $n += s/(\tlocal service response\n\tfor service in "\$\{!SERVICE_DNS\[\@\]\}"; do\n)/$1\t\t[[ "\$(networksetup -getdnsservers "\$service" | tr "\\n" " ")" == "\${DNS[*]} " ]] \&\& continue\n/;
  END { exit($n == 2 ? 0 : 1) }
' "$src") || { echo "wg-quick changed upstream; patch no longer applies to $src" >&2; exit 1; }
printf '%s\n' "$patched" > "$dest"
bash -n "$dest"
