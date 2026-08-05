"""Seed data and shared session-state helpers for the admin dashboard."""

from __future__ import annotations

import pandas as pd
import streamlit as st

DEFAULT_ROLES = [
    {"role": "Administrator", "opis": "Pełny dostęp do systemu i ustawień", "liczba_uprawnien": 24},
    {"role": "Redaktor", "opis": "Może tworzyć i edytować treści", "liczba_uprawnien": 12},
    {"role": "Analityk", "opis": "Dostęp tylko do odczytu metryk i raportów", "liczba_uprawnien": 6},
    {"role": "Gość", "opis": "Minimalny dostęp podglądowy", "liczba_uprawnien": 2},
]

DEFAULT_USERS = [
    {"id": 1, "imie_nazwisko": "Anna Kowalska", "email": "anna.kowalska@emaqai.com", "rola": "Administrator", "status": "Aktywny", "data_dolaczenia": "2024-02-11"},
    {"id": 2, "imie_nazwisko": "Piotr Nowak", "email": "piotr.nowak@emaqai.com", "rola": "Redaktor", "status": "Aktywny", "data_dolaczenia": "2024-05-03"},
    {"id": 3, "imie_nazwisko": "Maria Wiśniewska", "email": "maria.wisniewska@emaqai.com", "rola": "Analityk", "status": "Nieaktywny", "data_dolaczenia": "2023-11-22"},
    {"id": 4, "imie_nazwisko": "Tomasz Zieliński", "email": "tomasz.zielinski@emaqai.com", "rola": "Redaktor", "status": "Aktywny", "data_dolaczenia": "2024-07-18"},
    {"id": 5, "imie_nazwisko": "Katarzyna Lewandowska", "email": "katarzyna.lewandowska@emaqai.com", "rola": "Gość", "status": "Zaproszony", "data_dolaczenia": "2025-01-09"},
    {"id": 6, "imie_nazwisko": "Marek Dąbrowski", "email": "marek.dabrowski@emaqai.com", "rola": "Analityk", "status": "Aktywny", "data_dolaczenia": "2024-09-30"},
]


def init_state() -> None:
    """Populate st.session_state with mock tables on first run."""
    if "users_df" not in st.session_state:
        st.session_state.users_df = pd.DataFrame(DEFAULT_USERS)
    if "roles_df" not in st.session_state:
        st.session_state.roles_df = pd.DataFrame(DEFAULT_ROLES)


def next_user_id() -> int:
    df = st.session_state.users_df
    return int(df["id"].max()) + 1 if not df.empty else 1
