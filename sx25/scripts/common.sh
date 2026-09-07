#!/usr/bin/env bash
# SX25 — wspólne ustawienia, funkcje pomocnicze i SYSTEM LOGOWANIA.
# Source'owane przez pozostałe skrypty. Wartości nadpiszesz zmiennymi SX25_*.

set -euo pipefail

# Katalog projektu (rodzic katalogu scripts/).
SX25_PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Główny katalog roboczy serwera (poza repo — tu lądują obrazy i logi).
SX25_ROOT="${SX25_ROOT:-/srv/sx25}"
SX25_TFTP_ROOT="${SX25_TFTP_ROOT:-$SX25_ROOT/tftp}"
SX25_HTTP_ROOT="${SX25_HTTP_ROOT:-$SX25_ROOT/http}"

# Port serwera HTTP (kernel/initrd/menu/overlays).
SX25_HTTP_PORT="${SX25_HTTP_PORT:-8080}"

# IP serwera i podsieć dla proxyDHCP. "auto" => wykryj z domyślnej trasy.
SX25_SERVER_IP="${SX25_SERVER_IP:-auto}"
SX25_SUBNET="${SX25_SUBNET:-auto}"

# Manifest dystrybucji.
SX25_DISTRO_LIST="${SX25_DISTRO_LIST:-$SX25_PROJECT_DIR/data/distros.list}"

# ===========================================================================
#  SYSTEM LOGOWANIA — wszystko po polsku, do plików .txt
# ===========================================================================
# Cel: zapisać ABSOLUTNIE WSZYSTKO — każdą wykonaną komendę, jej wynik, to co
# zapisano, to co pominięto/niezrealizowane oraz crashe — wraz z auto-
# sugestywnym opisem, co się stało i co z tym zrobić.
#
# Znaczniki zdarzeń w logu:
#   [INFO]            informacja o postępie
#   [KOMENDA]         komenda, która ZA CHWILĘ zostanie wykonana
#   [WYKONANO]        komenda/krok zakończony sukcesem
#   [ZAPISANO]        zapis pliku/artefaktu na dysk
#   [NIEZREALIZOWANE] krok świadomie pominięty lub nieudany, ale nie krytyczny
#   [UWAGA]           ostrzeżenie
#   [BŁĄD]            błąd
#   [SUGESTIA]        auto-sugestia: co to znaczy i co zrobić dalej
#   [CRASH]           nieoczekiwane przerwanie skryptu (trap ERR)
#   [KONIEC]          podsumowanie zakończenia
#
# Dodatkowo (o ile SX25_TRACE!=0) do logu trafia pełny ślad wykonania (set -x)
# oraz cały strumień stdout/stderr (tee) — czyli naprawdę wszystko.

SX25_LOG_DIR="${SX25_LOG_DIR:-$SX25_ROOT/logs}"
SX25_LOG_FILE="${SX25_LOG_FILE:-}"
SX25_TRACE="${SX25_TRACE:-1}"

# Czy używać kolorów (tylko na prawdziwym terminalu, nie w pliku/pipe).
_sx25_color() { [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; }

sx25_now()  { date '+%Y-%m-%d %H:%M:%S'; }
sx25_time() { date '+%H:%M:%S'; }

# Zapis pojedynczego zdarzenia (idzie na stdout -> tee -> plik logu).
sx25_event() {
  local tag="$1"; shift
  printf '[%s] [%s] %s\n' "$(sx25_time)" "$tag" "$*"
}

# Wygodne aliasy zdarzeń.
sx25_info()  { sx25_event "INFO" "$*"; }
sx25_ok()    { sx25_event "WYKONANO" "$*"; }
sx25_saved() { sx25_event "ZAPISANO" "$*"; }
sx25_skip()  { sx25_event "NIEZREALIZOWANE" "$1"; [ -n "${2:-}" ] && sx25_event "SUGESTIA" "$2"; }
sx25_err()   { sx25_event "BŁĄD" "$1"; [ -n "${2:-}" ] && sx25_event "SUGESTIA" "$2"; }

# Zgodność wstecz: log/warn/die działają jak dawniej, ale trafiają do logu.
log()  { sx25_event "INFO"  "$*"; }
warn() { sx25_event "UWAGA" "$*"; }
die()  { sx25_event "BŁĄD"  "$*"; exit 1; }

# Mapowanie kodu wyjścia na auto-sugestię (co zwykle oznacza dany błąd).
sx25_hint_for() {
  case "$1" in
    1)   echo "Ogólny błąd — sprawdź powyższe komunikaty i uprawnienia." ;;
    2)   echo "Błędne użycie polecenia lub brak pliku — zweryfikuj argumenty i ścieżki." ;;
    126) echo "Brak uprawnień do wykonania — sprawdź atrybut +x i prawa dostępu." ;;
    127) echo "Nie znaleziono polecenia — czy pakiet jest zainstalowany? (uruchom setup.sh)" ;;
    130) echo "Przerwano ręcznie (Ctrl+C)." ;;
    4)   echo "Problem sieciowy/wget — sprawdź łącze, proxy i adresy w data/distros.list." ;;
    *)   echo "Nieoczekiwany kod $1 — zajrzyj do pełnego logu (ślad set -x) po szczegóły." ;;
  esac
}

# Trap: nieoczekiwane przerwanie (crash).
sx25_on_err() {
  local rc="$1" line="$2" cmd="$3"
  sx25_event "CRASH" "Przerwanie w linii $line (kod $rc). Komenda: ${cmd}"
  sx25_event "SUGESTIA" "$(sx25_hint_for "$rc")"
}

# Trap: zakończenie (zawsze) — podsumowanie i wskazanie pliku logu.
sx25_on_exit() {
  local rc="$1"
  if [ "$rc" -eq 0 ]; then
    sx25_event "KONIEC" "Zakończono sukcesem (kod 0)."
  else
    sx25_event "KONIEC" "Zakończono z kodem $rc (były problemy — patrz [BŁĄD]/[CRASH])."
  fi
  [ -n "$SX25_LOG_FILE" ] && sx25_event "KONIEC" "Pełny dziennik zapisano w: $SX25_LOG_FILE"
}

# Inicjalizacja logowania. Wywołaj RAZ na początku każdego skryptu:
#   sx25_log_init "nazwa-skryptu"
sx25_log_init() {
  local name="${1:-sx25}"
  # Katalog logów — z fallbackiem, gdy /srv niepisalny (np. brak roota).
  if ! mkdir -p "$SX25_LOG_DIR" 2>/dev/null; then
    SX25_LOG_DIR="$SX25_PROJECT_DIR/logs"
    mkdir -p "$SX25_LOG_DIR"
  fi
  SX25_LOG_FILE="$SX25_LOG_DIR/${name}_$(date +%Y%m%d-%H%M%S)_$$.txt"
  : > "$SX25_LOG_FILE"
  {
    echo "==================================================================="
    echo " SX25 — DZIENNIK: $name"
    echo " Start        : $(sx25_now)"
    echo " Host         : $(hostname 2>/dev/null || echo '?')"
    echo " Użytkownik   : $(id -un 2>/dev/null || echo '?') (uid=$(id -u 2>/dev/null || echo '?'))"
    echo " Katalog      : $(pwd)"
    echo " Polecenie    : $0 ${*:2}"
    echo " Pełny ślad   : $([ "$SX25_TRACE" != 0 ] && echo 'TAK (set -x)' || echo 'nie')"
    echo "==================================================================="
  } >> "$SX25_LOG_FILE"

  # Całą konsolę (stdout+stderr) kopiuj do pliku logu.
  exec > >(tee -a "$SX25_LOG_FILE") 2>&1

  # Pełny ślad wykonania (każda komenda) — tylko do pliku, by nie zaśmiecać konsoli.
  if [ "$SX25_TRACE" != "0" ]; then
    exec {SX25_XTRACE_FD}>>"$SX25_LOG_FILE"
    export BASH_XTRACEFD=$SX25_XTRACE_FD
    export PS4='+ [\t] ${BASH_SOURCE##*/}:${LINENO}: '
    set -x
  fi

  trap 'sx25_on_err $? $LINENO "$BASH_COMMAND"' ERR
  trap 'sx25_on_exit $?' EXIT

  sx25_info "Logowanie uruchomione. Dziennik: $SX25_LOG_FILE"
}

# Wykonaj komendę z pełnym logowaniem (opis + wynik + auto-sugestia).
# Użycie:
#   sx25_run "Opis kroku po polsku" [--hint "sugestia przy błędzie"] -- polecenie arg...
# Nie przerywa skryptu przy błędzie (zwraca kod) — decyduje wywołujący.
sx25_run() {
  local desc="$1"; shift
  local hint=""
  if [ "${1:-}" = "--hint" ]; then hint="$2"; shift 2; fi
  [ "${1:-}" = "--" ] && shift
  sx25_event "KOMENDA" "$desc → $*"
  local rc=0
  "$@" || rc=$?
  if [ "$rc" -eq 0 ]; then
    sx25_ok "$desc"
  else
    sx25_err "$desc (kod $rc)" "${hint:-$(sx25_hint_for "$rc")}"
  fi
  return "$rc"
}

# ===========================================================================
#  Sieć
# ===========================================================================
sx25_detect_ip() {
  local ip
  ip="$(ip -4 route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="src"){print $(i+1); exit}}')" || true
  [ -n "$ip" ] && { printf '%s' "$ip"; return 0; }
  return 1
}

sx25_detect_subnet() {
  local dev net
  dev="$(ip -4 route show default 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="dev"){print $(i+1); exit}}')" || true
  [ -z "$dev" ] && return 1
  net="$(ip -4 route show dev "$dev" scope link 2>/dev/null | awk 'NR==1{print $1}')" || true
  [ -n "$net" ] && { printf '%s' "$net"; return 0; }
  return 1
}

sx25_resolve_network() {
  if [ "$SX25_SERVER_IP" = "auto" ]; then
    SX25_SERVER_IP="$(sx25_detect_ip)" || die "Nie udało się wykryć IP — ustaw SX25_SERVER_IP=..."
    sx25_info "Wykryto IP serwera: $SX25_SERVER_IP"
  fi
  if [ "$SX25_SUBNET" = "auto" ]; then
    SX25_SUBNET="$(sx25_detect_subnet)" || die "Nie udało się wykryć podsieci — ustaw SX25_SUBNET=a.b.c.0/24"
    sx25_info "Wykryto podsieć: $SX25_SUBNET"
  fi
}
