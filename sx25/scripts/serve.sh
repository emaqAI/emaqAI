#!/usr/bin/env bash
# SX25 — uruchomienie serwera: renderuje konfigi, startuje HTTP + dnsmasq.
# Uruchom jako root: sudo ./scripts/serve.sh
set -euo pipefail
source "$(dirname "$0")/common.sh"

[ "$(id -u)" -eq 0 ] || die "Uruchom przez sudo/root (dnsmasq nasłuchuje na portach 67/69)."
sx25_resolve_network

log "Serwer IP : $SX25_SERVER_IP"
log "Podsieć   : $SX25_SUBNET"
log "HTTP port : $SX25_HTTP_PORT"
log "TFTP root : $SX25_TFTP_ROOT"
log "HTTP root : $SX25_HTTP_ROOT"

command -v dnsmasq >/dev/null 2>&1 || die "Brak dnsmasq — uruchom najpierw scripts/setup.sh"
[ -f "$SX25_TFTP_ROOT/undionly.kpxe" ] || warn "Brak $SX25_TFTP_ROOT/undionly.kpxe — klienci BIOS się nie uruchomią (setup.sh)."

# Podstawianie znaczników @SX25_*@ w plikach szablonowych.
render() {
  sed -e "s#@SX25_SERVER_IP@#$SX25_SERVER_IP#g" \
      -e "s#@SX25_HTTP_PORT@#$SX25_HTTP_PORT#g" \
      -e "s#@SX25_SUBNET@#$SX25_SUBNET#g" \
      -e "s#@SX25_TFTP_ROOT@#$SX25_TFTP_ROOT#g" \
      "$1"
}

# 1) Menu iPXE -> katalog HTTP /boot
log "Renderuję menu iPXE do $SX25_HTTP_ROOT/boot ..."
mkdir -p "$SX25_HTTP_ROOT/boot"
for f in "$SX25_PROJECT_DIR"/config/ipxe/*.ipxe; do
  render "$f" > "$SX25_HTTP_ROOT/boot/$(basename "$f")"
done

# 2) Konfiguracja dnsmasq (runtime)
runtime_conf="$SX25_ROOT/dnsmasq.runtime.conf"
log "Generuję $runtime_conf ..."
render "$SX25_PROJECT_DIR/config/dnsmasq.conf" > "$runtime_conf"

# 3) Serwer HTTP w tle (kernel/initrd/menu/overlays)
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
  log "Zatrzymano."
}
trap cleanup EXIT INT TERM

log "Startuję HTTP na :$SX25_HTTP_PORT ..."
start_http
sleep 1

log "Startuję dnsmasq (proxyDHCP + TFTP). Ctrl+C kończy."
# --no-daemon: zostaje na pierwszym planie, logi widoczne w konsoli.
dnsmasq --conf-file="$runtime_conf" --no-daemon
