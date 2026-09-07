#!/usr/bin/env bash
# SX25 — pobieranie obrazów netboot wg data/distros.list.
#
# Użycie:
#   ./scripts/fetch-distros.sh              # wszystkie wpisy z manifestu
#   ./scripts/fetch-distros.sh alpine64 debian64   # tylko wybrane id
#
# Pliki lądują w $SX25_HTTP_ROOT/distros/<id>/ (poza repozytorium).
set -euo pipefail
source "$(dirname "$0")/common.sh"

[ -f "$SX25_DISTRO_LIST" ] || die "Brak manifestu: $SX25_DISTRO_LIST"
mkdir -p "$SX25_HTTP_ROOT/distros"

WANT=("$@")   # opcjonalna lista id do pobrania

want_this() {
  [ "${#WANT[@]}" -eq 0 ] && return 0
  local id="$1" w
  for w in "${WANT[@]}"; do [ "$w" = "$id" ] && return 0; done
  return 1
}

download() {
  local url="$1" dest="$2"
  if [ -s "$dest" ]; then
    log "  = już jest: $(basename "$dest")"
    return 0
  fi
  log "  ↓ $url"
  if ! wget -q --show-progress -O "$dest" "$url"; then
    rm -f "$dest"
    warn "  nie udało się pobrać: $url"
    return 1
  fi
}

count=0
while IFS='|' read -r id arch kurl iurl xurl || [ -n "$id" ]; do
  # pomiń komentarze i puste linie
  case "$id" in ''|\#*) continue ;; esac
  id="$(echo "$id" | tr -d '[:space:]')"
  want_this "$id" || continue

  dir="$SX25_HTTP_ROOT/distros/$id"
  mkdir -p "$dir"
  log "[$id] ($arch)"

  if [ "$(echo "$iurl" | tr -d '[:space:]')" = "_ISO_" ]; then
    # Wpis typu ISO: kurl to adres obrazu ISO -> zapisz jako system.iso
    download "$(echo "$kurl" | xargs)" "$dir/system.iso" || true
  else
    download "$(echo "$kurl" | xargs)" "$dir/$(basename "$kurl")" || true
    download "$(echo "$iurl" | xargs)" "$dir/$(basename "$iurl")" || true
    xurl="$(echo "${xurl:-}" | xargs)"
    if [ -n "$xurl" ]; then
      download "$xurl" "$dir/$(basename "$xurl")" || true
    fi
  fi
  count=$((count+1))
done < "$SX25_DISTRO_LIST"

log "Przetworzono wpisów: $count. Obrazy w: $SX25_HTTP_ROOT/distros/"
