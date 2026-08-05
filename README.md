- 👋 Hi, I’m @emaqAI
- 👀 I’m interested in ...
- 🌱 I’m currently learning ...
- 💞️ I’m looking to collaborate on ...
- 📫 How to reach me ...
- 😄 Pronouns: ...
- ⚡ Fun fact: ...

<!---
emaqAI/emaqAI is a ✨ special ✨ repository because its `README.md` (this file) appears on your GitHub profile.
You can click the Preview link to take a look at your changes.
--->

## Admin Dashboard

Panel admina zbudowany w Streamlit do zarządzania użytkownikami i rolami (obecnie na danych mockowanych).

### Uruchomienie lokalne

```bash
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
streamlit run app.py
```

### Struktura

- `app.py` — strona główna z przeglądem (statystyki, wykresy)
- `pages/1_Uzytkownicy.py` — lista, dodawanie, edycja i usuwanie użytkowników
- `pages/2_Role.py` — lista, dodawanie, edycja i usuwanie ról
- `utils/mock_data.py` — dane startowe i inicjalizacja stanu sesji
