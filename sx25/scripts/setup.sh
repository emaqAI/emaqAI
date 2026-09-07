#!/usr/bin/env bash
# SX25 — instalacja zależności i przygotowanie katalogów TFTP/HTTP.
# Uruchom jako root: sudo ./scripts/setup.sh
# Wszystkie kroki są logowane do pliku .txt (patrz koniec działania).
set -euo pipefail
source "$(dirname "$0")/common.sh"
sx25_log_init "setup" "$@"

[ "$(id -u)" -eq 0 ] || die "Uruchom przez sudo/root (instalacja pakietów i katalogi w $SX25_ROOT)."

# --- Zależności ---------------------------------------------------------------
install_pkgs() {
  if command -v apt-get >/dev/null 2>&1; then
    sx25_info "Wykryto menedżer pakietów: apt"
    sx25_run "Aktualizacja indeksów apt" -- apt-get update -qq || true
    sx25_run "Instalacja: dnsmasq wget curl ca-certificates (apt)" \
      --hint "Sprawdź łącze i źródła apt (/etc/apt/sources.list)." \
      -- apt-get install -y dnsmasq wget curl ca-certificates
  elif command -v apk >/dev/null 2>&1; then
    sx25_info "Wykryto menedżer pakietów: apk"
    sx25_run "Instalacja: dnsmasq wget curl ca-certificates (apk)" \
      -- apk add --no-cache dnsmasq wget curl ca-certificates
  elif command -v dnf >/dev/null 2>&1; then
    sx25_info "Wykryto menedżer pakietów: dnf"
    sx25_run "Instalacja: dnsmasq wget curl ca-certificates (dnf)" \
      -- dnf install -y dnsmasq wget curl ca-certificates
  else
    sx25_skip "Instalacja zależności — nieznany menedżer pakietów" \
      "Zainstaluj ręcznie: dnsmasq wget curl."
  fi
}

# dnsmasq systemowy zająłby port 67 — używamy własnej instancji.
disable_system_dnsmasq() {
  if command -v systemctl >/dev/null 2>&1; then
    if systemctl disable --now dnsmasq 2>/dev/null; then
      sx25_ok "Wyłączono systemową usługę dnsmasq (unikamy konfliktu portu 67)"
    else
      sx25_skip "Wyłączanie systemowego dnsmasq" \
        "Usługa mogła nie istnieć — to normalne, jeśli dnsmasq nie był uruchomiony jako serwis."
    fi
  fi
}

# --- Katalogi -----------------------------------------------------------------
make_dirs() {
  sx25_info "Tworzę katalogi robocze w $SX25_ROOT ..."
  mkdir -p "$SX25_TFTP_ROOT" \
           "$SX25_HTTP_ROOT/boot" \
           "$SX25_HTTP_ROOT/distros" \
           "$SX25_HTTP_ROOT/overlays" \
           "$SX25_LOG_DIR"
  sx25_saved "Katalogi: tftp/, http/{boot,distros,overlays}/, logs/ w $SX25_ROOT"
}

# --- Binaria iPXE (etap 1, przez TFTP) ---------------------------------------
fetch_ipxe() {
  local base="https://boot.ipxe.org"
  sx25_info "Pobieram binaria iPXE do $SX25_TFTP_ROOT ..."
  sx25_run "Pobranie undionly.kpxe (BIOS)" \
    --hint "Bez tego klienci BIOS/legacy się nie uruchomią. Sprawdź łącze do boot.ipxe.org." \
    -- wget -q -O "$SX25_TFTP_ROOT/undionly.kpxe" "$base/undionly.kpxe" \
    && sx25_saved "$SX25_TFTP_ROOT/undionly.kpxe" || true
  sx25_run "Pobranie ipxe.efi (UEFI x86_64)" \
    --hint "Bez tego klienci UEFI 64-bit się nie uruchomią." \
    -- wget -q -O "$SX25_TFTP_ROOT/ipxe.efi" "$base/ipxe.efi" \
    && sx25_saved "$SX25_TFTP_ROOT/ipxe.efi" || true
  if wget -q -O "$SX25_TFTP_ROOT/ipxe32.efi" "$base/ipxe32.efi"; then
    sx25_saved "$SX25_TFTP_ROOT/ipxe32.efi"
  else
    rm -f "$SX25_TFTP_ROOT/ipxe32.efi"
    sx25_skip "Pobranie ipxe32.efi (UEFI 32-bit)" \
      "Brak gotowego pliku na serwerze. Zbuduj własny: scripts/build-ipxe.sh"
  fi
}

install_pkgs
disable_system_dnsmasq
make_dirs
fetch_ipxe

sx25_ok "Setup zakończony. Dalej:"
sx25_info "  1) ./scripts/build-overlay.sh        # nakładki Alpine (SSH, DOSBox, box64)"
sx25_info "  2) ./scripts/fetch-distros.sh        # obrazy dystrybucji"
sx25_info "  3) sudo ./scripts/serve.sh           # uruchom serwer"
