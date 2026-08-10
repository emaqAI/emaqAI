# CLAUDE.md

## Preferencje użytkownika

- Użytkownik używa najinteligentniejszego modelu AI.
- Preferowany model: Claude Opus 5 (`claude-opus-5`) — wybrany 2026-08-10.

## Zasady pracy

- Wszystkie zmiany muszą być odwracalne (reversible). Preferuj podejście, które łatwo cofnąć: osobne commity z jasnymi opisami, praca na gałęzi (nie na `main`), unikanie destrukcyjnych operacji (nadpisywanie, usuwanie, `--force`, wymuszona historia) bez wyraźnej zgody. Nieodwracalne kroki wymagają potwierdzenia użytkownika przed wykonaniem.

## Projekt: exchange-board

Tablica kursów walut — pojedyncza, samodzielna strona HTML.

- **Plik:** `exchange-board/currency-board.html` (bez zależności, bez build — cały CSS/JS inline).
- **Funkcja:** wpisujesz kwotę i wybierasz walutę bazową, a płytki przeliczają się automatycznie. Kliknięcie płytki ustawia ją jako nową walutę bazową.
- **Dane:** kursy zaszyte w stałej `RATES` (wartość 1 USD w danej walucie); waluty: USD, EUR, GBP, JPY, PLN, CHF, CAD, AUD, CNY, INR. Nazwy w `NAMES`, znacznik czasu w `LAST_UPDATED`. Kursy podmieniane w całości przy odświeżeniu.
- **UI:** interfejs po polsku, formatowanie liczb `pl-PL`, motyw jasny/ciemny (auto + `data-theme`), respektuje `prefers-reduced-motion`.
- **Charakter:** dane wyłącznie orientacyjne, nie do celów handlowych ani rozliczeniowych.
