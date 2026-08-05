"""emaqAI Admin Dashboard — punkt wejścia i strona przeglądu."""

import pandas as pd
import streamlit as st

from utils.mock_data import init_state

st.set_page_config(page_title="emaqAI Admin", page_icon="📊", layout="wide")

init_state()

st.title("📊 emaqAI — Panel Admina")
st.caption("Dane na tej stronie są mockowane i tymczasowe (przechowywane w sesji).")

users_df = st.session_state.users_df
roles_df = st.session_state.roles_df

col1, col2, col3, col4 = st.columns(4)
col1.metric("Użytkownicy", len(users_df))
col2.metric("Aktywni", int((users_df["status"] == "Aktywny").sum()))
col3.metric("Role", len(roles_df))
col4.metric("Zaproszeni", int((users_df["status"] == "Zaproszony").sum()))

st.divider()

left, right = st.columns(2)

with left:
    st.subheader("Użytkownicy wg roli")
    st.bar_chart(users_df["rola"].value_counts())

with right:
    st.subheader("Użytkownicy wg statusu")
    st.bar_chart(users_df["status"].value_counts())

st.divider()
st.subheader("Ostatnio dołączeni")
recent = users_df.sort_values("data_dolaczenia", ascending=False).head(5)
st.dataframe(recent, use_container_width=True, hide_index=True)

st.info("Użyj menu po lewej, aby zarządzać użytkownikami i rolami.")
