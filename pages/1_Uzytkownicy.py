"""Zarządzanie użytkownikami — lista, filtrowanie, dodawanie, edycja, usuwanie."""

import pandas as pd
import streamlit as st

from utils.mock_data import init_state, next_user_id

st.set_page_config(page_title="Użytkownicy — emaqAI Admin", page_icon="👤", layout="wide")
init_state()

st.title("👤 Użytkownicy")

users_df = st.session_state.users_df
roles_df = st.session_state.roles_df
role_names = roles_df["role"].tolist()

with st.sidebar:
    st.header("Filtry")
    role_filter = st.multiselect("Rola", options=role_names, default=role_names)
    status_filter = st.multiselect(
        "Status",
        options=sorted(users_df["status"].unique()),
        default=sorted(users_df["status"].unique()),
    )
    search = st.text_input("Szukaj (imię, nazwisko, e-mail)")

filtered = users_df[
    users_df["rola"].isin(role_filter) & users_df["status"].isin(status_filter)
]
if search:
    mask = filtered["imie_nazwisko"].str.contains(search, case=False) | filtered[
        "email"
    ].str.contains(search, case=False)
    filtered = filtered[mask]

st.caption(f"Wyniki: {len(filtered)} z {len(users_df)}")
st.dataframe(filtered, use_container_width=True, hide_index=True)

st.divider()

add_tab, edit_tab, delete_tab = st.tabs(["➕ Dodaj", "✏️ Edytuj", "🗑️ Usuń"])

with add_tab:
    with st.form("add_user_form", clear_on_submit=True):
        col1, col2 = st.columns(2)
        imie_nazwisko = col1.text_input("Imię i nazwisko")
        email = col2.text_input("E-mail")
        col3, col4 = st.columns(2)
        rola = col3.selectbox("Rola", options=role_names)
        status = col4.selectbox("Status", options=["Aktywny", "Nieaktywny", "Zaproszony"])
        data_dolaczenia = st.date_input("Data dołączenia", value=pd.Timestamp.today())
        submitted = st.form_submit_button("Dodaj użytkownika")

        if submitted:
            if not imie_nazwisko or not email:
                st.error("Podaj imię i nazwisko oraz e-mail.")
            else:
                new_row = {
                    "id": next_user_id(),
                    "imie_nazwisko": imie_nazwisko,
                    "email": email,
                    "rola": rola,
                    "status": status,
                    "data_dolaczenia": str(data_dolaczenia),
                }
                st.session_state.users_df = pd.concat(
                    [st.session_state.users_df, pd.DataFrame([new_row])], ignore_index=True
                )
                st.success(f"Dodano użytkownika {imie_nazwisko}.")
                st.rerun()

with edit_tab:
    if users_df.empty:
        st.info("Brak użytkowników do edycji.")
    else:
        options = {
            f"{row.imie_nazwisko} ({row.email})": row.id for row in users_df.itertuples()
        }
        selected_label = st.selectbox("Wybierz użytkownika", options=list(options.keys()))
        selected_id = options[selected_label]
        current = users_df[users_df["id"] == selected_id].iloc[0]

        with st.form("edit_user_form"):
            col1, col2 = st.columns(2)
            imie_nazwisko = col1.text_input("Imię i nazwisko", value=current["imie_nazwisko"])
            email = col2.text_input("E-mail", value=current["email"])
            col3, col4 = st.columns(2)
            rola = col3.selectbox(
                "Rola", options=role_names, index=role_names.index(current["rola"]) if current["rola"] in role_names else 0
            )
            status_options = ["Aktywny", "Nieaktywny", "Zaproszony"]
            status = col4.selectbox(
                "Status", options=status_options, index=status_options.index(current["status"])
            )
            save = st.form_submit_button("Zapisz zmiany")

            if save:
                idx = st.session_state.users_df.index[
                    st.session_state.users_df["id"] == selected_id
                ][0]
                st.session_state.users_df.loc[idx, ["imie_nazwisko", "email", "rola", "status"]] = [
                    imie_nazwisko,
                    email,
                    rola,
                    status,
                ]
                st.success("Zapisano zmiany.")
                st.rerun()

with delete_tab:
    if users_df.empty:
        st.info("Brak użytkowników do usunięcia.")
    else:
        options = {
            f"{row.imie_nazwisko} ({row.email})": row.id for row in users_df.itertuples()
        }
        selected_label = st.selectbox(
            "Wybierz użytkownika do usunięcia", options=list(options.keys()), key="delete_select"
        )
        selected_id = options[selected_label]
        if st.button("Usuń użytkownika", type="primary"):
            st.session_state.users_df = st.session_state.users_df[
                st.session_state.users_df["id"] != selected_id
            ].reset_index(drop=True)
            st.success("Użytkownik usunięty.")
            st.rerun()
