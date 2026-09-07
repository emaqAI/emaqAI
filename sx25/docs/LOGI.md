# SX25 — system logowania

Cel: zapisać **absolutnie wszystko** po polsku — każdą wykonaną komendę, to co
zapisano, kroki niezrealizowane oraz crashe — wraz z **auto-sugestiami**, co
dane zdarzenie oznacza i co z nim zrobić. Logi są zwykłymi plikami `.txt`.

## Gdzie trafiają logi

| Strona   | Katalog                 | Nazwa pliku                         |
|----------|-------------------------|-------------------------------------|
| Serwer   | `/srv/sx25/logs/`       | `<skrypt>_RRRRMMDD-GGMMSS_PID.txt`  |
| Klient   | `/var/log/sx25/`        | `toolbox_...txt`, `dosbox_...txt`   |

- Serwer: jeśli katalog `/srv` jest niepisalny (brak roota), logi lądują w
  `sx25/logs/` w repo (ten katalog jest w `.gitignore`).
- Klient (netboot): środowisko jest ulotne — logi żyją w RAM do restartu.
  Dlatego SX25 **zbiera je zdalnie** (patrz niżej); można też skopiować ręcznie
  przez SSH (`scp root@<IP>:/var/log/sx25/* .`).

## Zdalne zbieranie logów klientów

Aby dzienniki nie ginęły po restarcie ulotnego klienta, są **wysyłane na
serwer SX25**:

1. Serwer HTTP (`scripts/sx25-httpd.py`, uruchamiany przez `serve.sh`) przyjmuje
   pliki metodą `PUT`/`POST` na `/upload/<nazwa>` i zapisuje je do
   `/srv/sx25/logs/clients/` (nazwa jest sanityzowana — bez wyjścia poza katalog).
2. Klient dostaje adres w parametrze jądra `sx25_log_url=http://IP:PORT/upload`
   (ustawiany w menu iPXE dla obrazów Alpine).
3. Skrypt `sx25-uplog` na kliencie wysyła `/var/log/sx25/*.txt` (przez `curl -T`
   lub `wget --method=PUT`). Uruchamiany jest na koniec startu oraz przy wyjściu
   z DOSBox. Nazwa pliku na serwerze zawiera host i IP klienta.

Best-effort: brak `sx25_log_url`, sieci lub `curl`/`wget-PUT` = wysyłka jest po
prostu pomijana (odnotowana w logu), a lokalne logi i tak pozostają.

Wymaga `python3` na serwerze (busybox httpd nie obsługuje uploadu — wtedy
`serve.sh` odnotuje to jako `[NIEZREALIZOWANE]`).

## Znaczniki zdarzeń

| Znacznik            | Znaczenie                                                    |
|---------------------|-------------------------------------------------------------|
| `[INFO]`            | informacja o postępie                                       |
| `[KOMENDA]`         | komenda, która za chwilę zostanie wykonana                  |
| `[WYKONANO]`        | krok zakończony sukcesem                                    |
| `[ZAPISANO]`        | zapis pliku/artefaktu na dysk                               |
| `[NIEZREALIZOWANE]` | krok pominięty lub nieudany, ale niekrytyczny               |
| `[UWAGA]`           | ostrzeżenie                                                 |
| `[BŁĄD]`            | błąd                                                        |
| `[SUGESTIA]`        | auto-sugestia: co to znaczy i co zrobić                     |
| `[CRASH]`           | nieoczekiwane przerwanie skryptu (z numerem linii i kodem)  |
| `[KONIEC]`          | podsumowanie + ścieżka pełnego dziennika                    |

## Co dokładnie jest zapisywane

Na serwerze każdy skrypt (`setup.sh`, `build-overlay.sh`, `fetch-distros.sh`,
`serve.sh`, `build-ipxe.sh`):

1. **Nagłówek** — data, host, użytkownik, katalog, polecenie.
2. **Zdarzenia po polsku** — czytelne wpisy z powyższymi znacznikami.
3. **Pełny strumień** — całe `stdout`/`stderr` (przez `tee`), w tym logi PXE z
   dnsmasq w `serve.sh`.
4. **Pełny ślad wykonania** — `set -x`: każda komenda powłoki z numerem linii
   (można wyłączyć: `SX25_TRACE=0`).
5. **Crash** — pułapka `ERR` zapisuje linię, kod i komendę, a `EXIT` dopisuje
   podsumowanie i ścieżkę logu.

Po stronie klienta (Alpine netboot) skrypty startowe logują analogicznie
(instalacja SSH/DOSBox/box64, autologin, start usług) do `/var/log/sx25/`.

## Sterowanie

| Zmienna         | Domyślnie          | Efekt                                  |
|-----------------|--------------------|----------------------------------------|
| `SX25_LOG_DIR`  | `$SX25_ROOT/logs`  | katalog logów serwera                  |
| `SX25_TRACE`    | `1`                | `0` wyłącza pełny ślad `set -x`         |
| `NO_COLOR`      | —                  | wyłącza kolory na terminalu            |

## Przykład (fragment)

```
[13:41:36] [INFO] Logowanie uruchomione. Dziennik: /srv/sx25/logs/serve_20260907-134136_1682.txt
[13:41:36] [KOMENDA] Pobranie ipxe.efi (UEFI x86_64) → wget -q -O ... 
[13:41:37] [ZAPISANO] /srv/sx25/tftp/ipxe.efi
[13:41:37] [NIEZREALIZOWANE] Pobranie ipxe32.efi (UEFI 32-bit)
[13:41:37] [SUGESTIA] Brak gotowego pliku na serwerze. Zbuduj własny: scripts/build-ipxe.sh
[13:41:37] [KONIEC] Pełny dziennik zapisano w: /srv/sx25/logs/serve_...txt
```
