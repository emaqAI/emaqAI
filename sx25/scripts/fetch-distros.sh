#!/usr/bin/env bash
# SX25 — pobieranie obrazów netboot wg data/distros.list.
# Użycie:
#   ./scripts/fetch-distros.sh              # wszystkie wpisy
#   ./scripts/fetch-distros.sh alpine64 debian64   # tylko wybrane id
# Każde pobranie (udane, pominięte, nieudane) jest logowane do pliku .txt.
set -euo pipefail
source "$(dirname "$0")/common.sh"
sx25_log_init "fetch-distros" "$@"

[ -f "$SX25_DISTRO_LIST" ] || die "Brak manifestu: $SX25_DISTRO_LIST"
mkdir -p "$SX25_HTTP_ROOT/distros"

WANT=("$@")

want_this() {
  [ "${#WANT[@]}" -eq 0 ] && return 0
  local id="$1" w
  for w in "${WANT[@]}"; do [ "$w" = "$id" ] && return 0; done
  return 1
}

download() {
  local url="$1" dest="$2"
  if [ -s "$dest" ]; then
    sx25_skip "Pobranie $(basename "$dest")" "Plik już istnieje — pomijam (usuń go, by pobrać ponownie)."
    return 0
  fi
  sx25_event "KOMENDA" "wget → $url"
  if wget -q --show-progress -O "$dest" "$url"; then
    sx25_saved "$dest ($(du -h "$dest" 2>/dev/null | cut -f1))"
    return 0
  else
    rm -f "$dest"
    sx25_err "Pobranie $url" \
      "Adres mógł się zdezaktualizować lub brak łącza. Zaktualizuj data/distros.list i sprawdź sieć."
    return 1
  fi
}

count=0 ok=0 fail=0
while IFS='|' read -r id arch kurl iurl xurl || [ -n "$id" ]; do
  case "$id" in ''|\#*) continue ;; esac
  id="$(echo "$id" | tr -d '[:space:]')"
  want_this "$id" || continue

  dir="$SX25_HTTP_ROOT/distros/$id"
  mkdir -p "$dir"
  sx25_info "[$id] ($arch)"
  count=$((count+1))
  step_ok=1

  if [ "$(echo "$iurl" | tr -d '[:space:]')" = "_ISO_" ]; then
    download "$(echo "$kurl" | xargs)" "$dir/system.iso" || step_ok=0
  else
    download "$(echo "$kurl" | xargs)" "$dir/$(basename "$kurl")" || step_ok=0
    download "$(echo "$iurl" | xargs)" "$dir/$(basename "$iurl")" || step_ok=0
    xurl="$(echo "${xurl:-}" | xargs)"
    if [ -n "$xurl" ]; then
      download "$xurl" "$dir/$(basename "$xurl")" || step_ok=0
    fi
  fi

  if [ "$step_ok" -eq 1 ]; then ok=$((ok+1)); sx25_ok "[$id] komplet plików gotowy";
  else fail=$((fail+1)); sx25_skip "[$id] niekompletny" "Część plików się nie pobrała — patrz [BŁĄD] powyżej."; fi
done < "$SX25_DISTRO_LIST"

sx25_info "Podsumowanie: przetworzono $count, kompletnych $ok, z problemami $fail."
sx25_info "Obrazy w: $SX25_HTTP_ROOT/distros/"
[ "$fail" -eq 0 ] || sx25_event "SUGESTIA" "Dla wpisów z problemami sprawdź adresy w data/distros.list (bywają dezaktualizowane) lub użyj pozycji netboot.xyz w menu."
