#!/usr/bin/env bash
# SX25 — uruchomienie serwera: renderuje konfigi, startuje HTTP + dnsmasq.
# Uruchom jako root: sudo ./scripts/serve.sh
# Cały przebieg (w tym logi PXE z dnsmasq) trafia do pliku .txt.
set -euo pipefail
source "$(dirname "$0")/common.sh"
sx25_log_init "serve" "$@"

[ "$(id -u)" -eq 0 ] || die "Uruchom przez sudo/root (dnsmasq nasłuchuje na portach 67/69)."
sx25_resolve_network

sx25_info "Serwer IP : $SX25_SERVER_IP"
sx25_info "Podsieć   : $SX25_SUBNET"
sx25_info "HTTP port : $SX25_HTTP_PORT"
sx25_info "TFTP root : $SX25_TFTP_ROOT"
sx25_info "HTTP root : $SX25_HTTP_ROOT"

command -v dnsmasq >/dev/null 2>&1 || die "Brak dnsmasq — uruchom najpierw scripts/setup.sh"
[ -f "$SX25_TFTP_ROOT/undionly.kpxe" ] || sx25_skip "Kontrola undionly.kpxe" \
  "Brak $SX25_TFTP_ROOT/undionly.kpxe — klienci BIOS się nie uruchomią. Uruchom setup.sh."

# Podstawianie znaczników @SX25_*@ w plikach szablonowych.
render() {
  sed -e "s#@SX25_SERVER_IP@#$SX25_SERVER_IP#g" \
      -e "s#@SX25_HTTP_PORT@#$SX25_HTTP_PORT#g" \
      -e "s#@SX25_SUBNET@#$SX25_SUBNET#g" \
      -e "s#@SX25_TFTP_ROOT@#$SX25_TFTP_ROOT#g" \
      "$1"
}

# 1) Menu iPXE -> katalog HTTP /boot
sx25_info "Renderuję menu iPXE do $SX25_HTTP_ROOT/boot ..."
mkdir -p "$SX25_HTTP_ROOT/boot"
for f in "$SX25_PROJECT_DIR"/config/ipxe/*.ipxe; do
  render "$f" > "$SX25_HTTP_ROOT/boot/$(basename "$f")"
  sx25_saved "menu: boot/$(basename "$f")"
done

# 2) authorized_keys dla instalatora Debiana (SSH przez network-console)
akeys_src="$SX25_PROJECT_DIR/overlays/files/root/.ssh/authorized_keys"
if [ -f "$akeys_src" ]; then
  mkdir -p "$SX25_HTTP_ROOT/overlays"
  cp -f "$akeys_src" "$SX25_HTTP_ROOT/overlays/authorized_keys"
  sx25_saved "overlays/authorized_keys (dla SSH do instalatora Debiana)"
else
  sx25_skip "Kopiowanie authorized_keys" "Brak $akeys_src — SSH do Debiana nie zadziała bez kluczy."
fi

# 3) Kontrola nakładek Alpine (SSH/DOSBox/box64)
for ovl in sx25-base.apkovl.tar.gz toolbox.apkovl.tar.gz; do
  if [ -f "$SX25_HTTP_ROOT/overlays/$ovl" ]; then
    sx25_ok "Nakładka obecna: overlays/$ovl"
  else
    sx25_skip "Nakładka overlays/$ovl" "Zbuduj nakładki: ./scripts/build-overlay.sh (inaczej brak SSH/DOSBox w Alpine)."
  fi
done

# 4) Konfiguracja dnsmasq (runtime)
runtime_conf="$SX25_ROOT/dnsmasq.runtime.conf"
render "$SX25_PROJECT_DIR/config/dnsmasq.conf" > "$runtime_conf"
sx25_saved "konfiguracja dnsmasq: $runtime_conf"

# 5) Serwer HTTP w tle
start_http() {
  ( cd "$SX25_HTTP_ROOT" && \
    if command -v python3 >/dev/null 2>&1; then
      exec python3 -m http.server "$SX25_HTTP_PORT" --bind 0.0.0.0
    elif command -v busybox >/dev/null 2>&1; then
      exec busybox httpd -f -p "0.0.0.0:$SX25_HTTP_PORT" -h "$SX25_HTTP_ROOT"
    else
      die "Brak python3 i busybox — nie mam czym serwować HTTP."
    fi ) &
  HTTP_PID=$!
}

HTTP_PID=""
cleanup() {
  [ -n "$HTTP_PID" ] && kill "$HTTP_PID" 2>/dev/null || true
  sx25_info "Zatrzymano serwer HTTP."
}
trap cleanup EXIT INT TERM

sx25_info "Startuję HTTP na :$SX25_HTTP_PORT ..."
start_http
sleep 1
sx25_ok "HTTP działa (PID $HTTP_PID), serwuje $SX25_HTTP_ROOT"

sx25_info "Startuję dnsmasq (proxyDHCP + TFTP). Ctrl+C kończy. Logi PXE poniżej i w dzienniku."
# --no-daemon: pierwszy plan; cały ruch DHCP/TFTP widoczny i logowany.
dnsmasq --conf-file="$runtime_conf" --no-daemon
