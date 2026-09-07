# SX25 — nakładki Alpine (apkovl)

Nakładka (apkovl) to spakowany `.tar.gz` z fragmentem systemu plików, który
Alpine wczytuje przy rozruchu netboot (parametr jądra `apkovl=URL`). SX25
używa jej, by w locie doinstalować i skonfigurować narzędzia (DOSBox, box64)
w ulotnym środowisku Alpine.

## Zawartość `files/`

```
files/
├── etc/local.d/sx25-tools.start   # przy starcie: apk add dosbox, box64
├── etc/motd                       # komunikat powitalny
└── root/.profile                  # autostart wg sx25_autostart=dosbox|box64
```

## Budowa nakładki

```bash
./scripts/build-overlay.sh
```

Skrypt składa `files/` w poprawny apkovl (włącza usługę `local`, dodaje pakiety
do `/etc/apk/world`) i zapisuje wynik do
`$SX25_HTTP_ROOT/overlays/toolbox.apkovl.tar.gz`, skąd serwuje go `serve.sh`.

## Uwagi

- Środowisko jest **ulotne** — po restarcie klienta zmiany znikają.
- `box64` ma sens głównie na hostach **ARM/RISC-V** (uruchamia binaria x86_64).
  Na kliencie x86 instalacja jest best-effort i zwykle zbędna — pozycja
  istnieje zgodnie z wymaganiem projektu.
- Instalacja pakietów wymaga działającej sieci i dostępu do repozytoriów Alpine.
