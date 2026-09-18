# Tetris PSX

Pełna gra Tetris dla Sony PlayStation 1 (PSX), budowana przy użyciu
[PSn00bSDK](https://github.com/Lameguy64/PSn00bSDK). Wynikiem budowy jest
bootowalny obraz płyty (`tetris.bin` + `tetris.cue`), który można odpalić na
prawdziwej konsoli (na płycie CD-R z modchipem/swap trickiem) albo w
emulatorze (DuckStation, pcsx-redux, Mednafen...).

## Funkcje gry

- Planszal 10x20 pól, 7 klocków (I, O, T, S, Z, J, L) z systemem obrotów SRS.
- Sterowanie padem: ruch lewo/prawo, obrót CW/CCW, soft drop, hard drop, hold.
- Podgląd następnego klocka i funkcja "hold" (przechowaj klocek).
- System poziomów (poziom rośnie co 10 wyczyszczonych linii, przyspiesza
  spadanie klocków).
- Punktacja zgodna z klasycznym Tetris (single/double/triple/tetris, soft/hard
  drop bonus).
- Menu główne (Start, High Score, sterowanie), ekran pauzy, ekran Game Over.
- Zapis najlepszego wyniku w pamięci karty pamięci PSX (memory card, slot 1).
- Prosty dźwięk (SPU) - efekty ruchu, obrotu, czyszczenia linii, game over.

## Struktura projektu

```
games/tetris-psx/
├── CMakeLists.txt          # konfiguracja budowy (PSn00bSDK toolchain)
├── src/                    # kod źródłowy gry (C)
│   ├── main.c
│   ├── game.c / game.h     # logika gry, plansza, grawitacja, punktacja
│   ├── tetromino.c / .h    # definicje klocków i rotacji (SRS)
│   ├── render.c / .h       # rysowanie (GPU, prymitywy 2D)
│   ├── input.c / .h        # obsługa pada
│   ├── audio.c / .h        # SPU, efekty dźwiękowe
│   ├── save.c / .h         # zapis/odczyt karty pamięci
│   └── state.h             # maszyna stanów: menu / gra / pauza / game over
├── iso/
│   ├── iso.xml             # deskryptor mkpsxiso (struktura płyty)
│   └── system.cnf          # plik startowy PSX (wskazuje na SLUS/EXE)
├── toolchain/
│   └── setup.sh            # instalacja PSn00bSDK + mkpsxiso
└── build.sh                # jednopoleceniowa budowa ISO
```

## Wymagany toolchain

Gra wymaga cross-kompilatora `mipsel-none-elf-gcc` oraz bibliotek
PSn00bSDK, a do mastera obrazu płyty narzędzia `mkpsxiso`. W tym środowisku
kontenerowym te narzędzia **nie są preinstalowane** (nie ma dostępu do
`apt`/sieci potrzebnej do zbudowania cross-GCC), więc obraz ISO należy
zbudować lokalnie lub w CI z dostępem do internetu.

### Instalacja (Linux/macOS/WSL)

```bash
cd games/tetris-psx/toolchain
./setup.sh          # klonuje i buduje PSn00bSDK + mkpsxiso do ~/.psn00bsdk
```

### Budowa gry i ISO

```bash
cd games/tetris-psx
export PSN00BSDK_LIBS=~/.psn00bsdk/lib/libpsn00b
./build.sh
```

Wynik: `build/tetris.bin`, `build/tetris.cue` — obraz gotowy do wypalenia na
CD-R (np. `cdrdao write tetris.cue`) lub uruchomienia w emulatorze:

```bash
duckstation-nogui build/tetris.cue
```

## Sterowanie

| Przycisk       | Akcja                     |
|----------------|---------------------------|
| ←/→            | Przesuń klocek             |
| ↓              | Soft drop                  |
| ↑              | Hard drop                  |
| ✕ (Cross)      | Obrót w prawo (CW)         |
| ◯ (Circle)     | Obrót w lewo (CCW)         |
| △ (Triangle)   | Hold (przechowaj klocek)   |
| START          | Pauza / zatwierdź w menu   |
| SELECT         | Reset gry (z menu pauzy)   |

## Status projektu

Kod gry jest kompletny i gotowy do budowy przy użyciu PSn00bSDK. Ponieważ
środowisko, w którym powstał ten kod, nie ma zainstalowanego cross-toolchainu
MIPS ani `mkpsxiso`, finalny plik `.iso`/`.bin+.cue` nie został tu wygenerowany
binarnie — należy uruchomić `toolchain/setup.sh` i `build.sh` lokalnie lub w
pipeline CI z dostępem do sieci, aby otrzymać gotowy obraz płyty.
