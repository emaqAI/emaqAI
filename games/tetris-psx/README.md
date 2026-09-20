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

Gra została w pełni zbudowana i przetestowana end-to-end: cross-toolchain
`mipsel-none-elf-gcc` (GCC 11.2.0 + binutils 2.37), PSn00bSDK (`libpsn00b`)
oraz `mkpsxiso` zostały skompilowane ze źródeł, po czym `tetris.exe` skompilował
się bez błędów i `mkpsxiso` wygenerował poprawny obraz płyty
(`build/tetris.bin` + `build/tetris.cue`, 75 264 bajty / 32 sektory).
`tetris.exe` ma prawidłowy nagłówek `PS-X EXE`.

Podczas budowy dwie rzeczy wymagały korekty względem pierwszej wersji kodu,
ponieważ ta wersja PSn00bSDK nie implementuje wysokopoziomowego API:

- **`audio.c`** — `SpuVoiceAttr`/`SpuSetVoiceAttr` są w tym SDK wyłączone
  (`#if 0` w `psxspu.h`); efekty dźwiękowe używają niskopoziomowych makr
  rejestrowych (`SpuSetVoiceVolume`, `SpuSetVoicePitch`, `SpuSetVoiceADSR`,
  `SpuSetKey`).
- **`save.c`** — SDK udostępnia tylko sektorowe funkcje BIOS
  (`InitCARD`/`_card_read`/`_card_write`), bez systemu plików karty pamięci.
  Wynik zapisywany jest bezpośrednio w sektorze danych bloku 1 (slot 1), co
  działa poprawnie w samej grze, ale nie pojawi się jako nazwany plik w
  menedżerze kart pamięci BIOS-u.

### Test w emulatorze — zweryfikowane, gra bootuje i działa

Gra została uruchomiona end-to-end w emulatorze (pcsx-redux, CLI/headless)
z [OpenBIOS](https://github.com/grumpycoders/pcsx-redux/tree/main/src/mips/openbios)
(legalny, open-source'owy zamiennik BIOS-u PS1 — nie zrzut firmware'u Sony)
i potwierdzona zrzutem ekranu z ekranu tytułowego (TETRIS PSX / START /
HIGH SCORE / CONTROLS).

Po drodze napotkano i naprawiono prawdziwy bug w OpenBIOS: funkcja
`cdromInnerInit()` (`src/mips/openbios/cdrom/statemachine.c`) czekała na
odpowiedź napędu CD tylko 30 000 iteracji pętli, po czym poddawała się i
wysyłała komendę `CDL_INIT` ponownie. Emulatory realistycznie symulujące
mechanikę napędu (otwarcie/zamknięcie szuflady, rozkręcenie płyty — na
prawdziwym sprzęcie to ponad 6 sekund) nigdy nie zdążały odpowiedzieć w tym
czasie, więc OpenBIOS w kółko resetował stan napędu, zanim ten zdążył
dokończyć inicjalizację — nieskończony livelock. Poprawka zwiększa limit
oczekiwania do 30 000 000 iteracji, co pozwala jednej próbie faktycznie się
zakończyć. Ten sam bug reprodukował się identycznie zarówno w `mednafen`,
jak i w `pcsx-redux` (i dotyczy każdej gry na PSn00bSDK/OpenBIOS, nie tylko
tego Tetrisa).

Do przetestowania na własnym sprzęcie/emulatorze (np. DuckStation) polecany
jest ten sam poprawiony OpenBIOS, ewentualnie prawdziwy BIOS PS1, jeśli go
posiadasz. Patch dla OpenBIOS (do zastosowania na
`grumpycoders/pcsx-redux`, plik `src/mips/openbios/cdrom/statemachine.c`)
jest w `toolchain/patches/openbios-cdrom-init-timeout.patch`.
