# SX25 — Multi-Boot PXE Server

Serwer PXE do rozruchu sieciowego (netboot) lekkich dystrybucji Linuksa dla
architektur **x86-64** i **x86-32 (i386)**, wraz ze środowiskami **DOSBox**
oraz **box64**.

Jedna maszyna (serwer SX25) udostępnia w sieci LAN menu startowe iPXE. Klienty
z włączonym rozruchem sieciowym (PXE/UEFI) pobierają menu i uruchamiają wybraną
dystrybucję bez nośnika fizycznego.

```
   ┌────────────┐   DHCP/proxyDHCP + TFTP    ┌──────────────────────┐
   │  Klient    │◀──────────────────────────▶│   Serwer SX25        │
   │  (PXE/UEFI)│   HTTP (kernel/initrd/iso) │  dnsmasq + iPXE + HTTP│
   └────────────┘◀──────────────────────────▶└──────────────────────┘
```

## Co potrafi

- **Menu iPXE** z podziałem na: lekkie Linuksy 64-bit, lekkie Linuksy 32-bit,
  narzędzia (DOSBox, box64), narzędzia systemowe.
- **Netboot lekkich dystrybucji** — pobieranych bezpośrednio z oficjalnych
  serwerów lub serwowanych lokalnie przez HTTP (patrz [docs/DISTROS.md](docs/DISTROS.md)).
- **proxyDHCP** — działa obok istniejącego routera/DHCP, nie trzeba go zastępować.
- **BIOS i UEFI** — osobne pliki startowe dla obu trybów.
- **SSH** — logowanie kluczem do uruchomionych maszyn: Alpine (wszystkie
  pozycje) przez nakładkę, Debian przez instalator (network-console).
- **Autostart DOSBox** — pozycja „DOSBox" w menu Narzędzia startuje emulator
  automatycznie (autologin + launcher z fallbackiem X/framebuffer).
- **Pełne logowanie po polsku** — każdy krok (wykonany, zapisany,
  niezrealizowany, crash) trafia do plików `.txt` z auto-sugestiami; po stronie
  serwera i klienta. Szczegóły: [docs/LOGI.md](docs/LOGI.md).

## Wymagania

- Linux na serwerze (testowane pod Debian/Ubuntu i Alpine).
- `dnsmasq`, `wget`/`curl`, `git`, dostęp do sieci LAN.
- Uprawnienia roota (dnsmasq nasłuchuje na portach 67/69).
- ~2–10 GB miejsca na obrazy netboot (zależnie od liczby dystrybucji).

## Szybki start

```bash
cd sx25

# 1. Zainstaluj zależności i przygotuj katalogi TFTP/HTTP
sudo ./scripts/setup.sh

# 2. Zbuduj nakładki Alpine (SSH, DOSBox, box64)
./scripts/build-overlay.sh

# 3. Pobierz obrazy netboot wybranych dystrybucji
./scripts/fetch-distros.sh            # wszystkie z data/distros.list
./scripts/fetch-distros.sh alpine64 debian64   # tylko wybrane

# 4. Uruchom serwer (dnsmasq proxyDHCP/TFTP + HTTP)
sudo ./scripts/serve.sh
```

Każdy skrypt zapisuje pełny dziennik `.txt` (domyślnie w `/srv/sx25/logs/`);
ścieżkę pliku wypisuje na końcu działania.

Następnie ustaw w kliencie rozruch z sieci (Network Boot / PXE) i wybierz
pozycję z menu SX25.

> ⚠️ **Uwaga sieciowa.** proxyDHCP współdziała z istniejącym DHCP w LAN.
> Uruchamiaj SX25 w sieci, którą kontrolujesz — nieautoryzowany serwer
> rozruchu sieciowego w cudzej sieci jest niepożądany i często zabroniony.

## Struktura

```
sx25/
├── README.md
├── config/
│   ├── dnsmasq.conf         # proxyDHCP + TFTP + wskazanie iPXE
│   └── ipxe/
│       ├── menu.ipxe        # menu główne
│       ├── linux64.ipxe     # dystrybucje x86-64
│       ├── linux32.ipxe     # dystrybucje i386
│       └── tools.ipxe       # DOSBox, box64, narzędzia
├── data/
│   └── distros.list         # manifest: co i skąd pobrać
├── overlays/                # nakładki Alpine (apkovl): SSH, DOSBox, box64
│   ├── files/               # zawartość nakładki (etc/, root/, usr/local/...)
│   └── README.md
├── scripts/
│   ├── common.sh            # wspólne ustawienia + system logowania (PL, .txt)
│   ├── setup.sh             # instalacja zależności + katalogi
│   ├── build-overlay.sh     # buduje sx25-base + toolbox (SSH/DOSBox/box64)
│   ├── fetch-distros.sh     # pobieranie obrazów netboot
│   ├── build-ipxe.sh        # (opcjonalnie) budowa własnych binariów iPXE
│   └── serve.sh             # start dnsmasq + HTTP
└── docs/
    ├── ARCHITECTURE.md      # jak to działa (DHCP→TFTP→iPXE→HTTP)
    ├── DISTROS.md           # katalog dystrybucji + DOSBox/box64 + SSH
    └── LOGI.md              # system logowania (co, gdzie, format)
```

## Status

🚧 W budowie. Szkielet z działającymi konfiguracjami iPXE/dnsmasq i skryptami
pobierania. Zobrazy netboot nie są trzymane w repozytorium — pobiera je
`fetch-distros.sh`.

## Dokumentacja

- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) — architektura i przepływ rozruchu.
- [docs/DISTROS.md](docs/DISTROS.md) — lista dystrybucji, DOSBox i box64.
