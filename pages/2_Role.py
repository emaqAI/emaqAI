"""Zarządzanie rolami — lista, dodawanie, edycja, usuwanie."""

import pandas as pd
import streamlit as st

from utils.mock_data import init_state

st.set_page_config(page_title="Role — emaqAI Admin", page_icon="🔑", layout="wide")
init_state()

st.title("🔑 Role")

roles_df = st.session_state.roles_df
users_df = st.session_state.users_df

roles_with_counts = roles_df.copy()
roles_with_counts["liczba_uzytkownikow"] = roles_with_counts["role"].map(
    users_df["rola"].value_counts()
).fillna(0).astype(int)

st.dataframe(roles_with_counts, use_container_width=True, hide_index=True)

st.divider()

add_tab, edit_tab, delete_tab = st.tabs(["➕ Dodaj", "✏️ Edytuj", "🗑️ Usuń"])

with add_tab:
    with st.form("add_role_form", clear_on_submit=True):
        role = st.text_input("Nazwa roli")
        opis = st.text_area("Opis")
        liczba_uprawnien = st.number_input("Liczba uprawnień", min_value=0, step=1, value=0)
        submitted = st.form_submit_button("Dodaj rolę")

        if submitted:
            if not role:
                st.error("Podaj nazwę roli.")
            elif role in roles_df["role"].values:
                st.error("Rola o tej nazwie już istnieje.")
            else:
                new_row = {"role": role, "opis": opis, "liczba_uprawnien": int(liczba_uprawnien)}
                st.session_state.roles_df = pd.concat(
                    [st.session_state.roles_df, pd.DataFrame([new_row])], ignore_index=True
                )
                st.success(f"Dodano rolę {role}.")
                st.rerun()

with edit_tab:
    if roles_df.empty:
        st.info("Brak ról do edycji.")
    else:
        selected_role = st.selectbox("Wybierz rolę", options=roles_df["role"].tolist())
        current = roles_df[roles_df["role"] == selected_role].iloc[0]

        with st.form("edit_role_form"):
            opis = st.text_area("Opis", value=current["opis"])
            liczba_uprawnien = st.number_input(
                "Liczba uprawnień", min_value=0, step=1, value=int(current["liczba_uprawnien"])
            )
            save = st.form_submit_button("Zapisz zmiany")

            if save:
                idx = st.session_state.roles_df.index[
                    st.session_state.roles_df["role"] == selected_role
                ][0]
                st.session_state.roles_df.loc[idx, ["opis", "liczba_uprawnien"]] = [
                    opis,
                    int(liczba_uprawnien),
                ]
                st.success("Zapisano zmiany.")
                st.rerun()

with delete_tab:
    if roles_df.empty:
        st.info("Brak ról do usunięcia.")
    else:
        selected_role = st.selectbox(
            "Wybierz rolę do usunięcia", options=roles_df["role"].tolist(), key="delete_role_select"
        )
        in_use = int((users_df["rola"] == selected_role).sum())
        if in_use:
            st.warning(f"Ta rola jest przypisana do {in_use} użytkownik(ów). Usunięcie nie zmieni ich wpisów.")
        if st.button("Usuń rolę", type="primary"):
            st.session_state.roles_df = st.session_state.roles_df[
                st.session_state.roles_df["role"] != selected_role
            ].reset_index(drop=True)
            st.success("Rola usunięta.")
            st.rerun()
