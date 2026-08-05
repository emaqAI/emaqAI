# emaqAI — System kontroli dostępu (RBAC)

Backend REST API do zarządzania użytkownikami, rolami i uprawnieniami (Role-Based Access Control).

Stos: Node.js, TypeScript, Express, Prisma (SQLite domyślnie, łatwo przełączyć na PostgreSQL/MySQL), JWT, bcrypt.

## Model danych

- **User** — konto z adresem email i hasłem (hash bcrypt).
- **Role** — nazwana rola (np. `admin`, `user`).
- **Permission** — nazwane uprawnienie (np. `users:manage`).
- Relacje wiele-do-wielu: użytkownik ↔ role, rola ↔ uprawnienia.

## Uruchomienie lokalne

```bash
npm install
cp .env.example .env
npx prisma migrate dev --name init
npm run seed        # tworzy role user/admin, uprawnienia i konto admina
npm run dev          # serwer na http://localhost:3000
```

Domyślne konto admina (nadpisywalne przez `SEED_ADMIN_EMAIL` / `SEED_ADMIN_PASSWORD`):
`admin@emaqai.local` / `ChangeMe123!`

## Endpointy API

### Autentykacja (`/auth`)

| Metoda | Ścieżka | Opis | Autoryzacja |
|---|---|---|---|
| POST | `/auth/register` | Rejestracja (rola `user` domyślnie) | brak |
| POST | `/auth/login` | Logowanie, zwraca JWT | brak |
| GET | `/auth/me` | Dane zalogowanego użytkownika, role, uprawnienia | Bearer token |

### Użytkownicy (`/users`)

| Metoda | Ścieżka | Opis | Wymagane uprawnienie |
|---|---|---|---|
| GET | `/users` | Lista użytkowników | `users:read` |
| GET | `/users/:id` | Szczegóły użytkownika (role, uprawnienia) | `users:read` |
| PATCH | `/users/:id/active` | Aktywacja/dezaktywacja konta | `users:manage` |
| POST | `/users/:id/roles` | Przypisanie roli (`{ roleId }`) | `users:manage` |
| DELETE | `/users/:id/roles/:roleId` | Usunięcie roli | `users:manage` |

### Role (`/roles`)

| Metoda | Ścieżka | Opis | Wymagane uprawnienie |
|---|---|---|---|
| GET | `/roles` | Lista ról z uprawnieniami | `roles:read` |
| POST | `/roles` | Utworzenie roli (`{ name, description? }`) | `roles:manage` |
| DELETE | `/roles/:id` | Usunięcie roli | `roles:manage` |
| POST | `/roles/:id/permissions` | Przypisanie uprawnienia (`{ permissionId }`) | `roles:manage` |
| DELETE | `/roles/:id/permissions/:permissionId` | Usunięcie uprawnienia z roli | `roles:manage` |

### Uprawnienia (`/permissions`)

| Metoda | Ścieżka | Opis | Wymagane uprawnienie |
|---|---|---|---|
| GET | `/permissions` | Lista uprawnień | `permissions:read` |
| POST | `/permissions` | Utworzenie uprawnienia | `permissions:manage` |
| DELETE | `/permissions/:id` | Usunięcie uprawnienia | `permissions:manage` |

Wszystkie chronione endpointy wymagają nagłówka `Authorization: Bearer <token>` uzyskanego z `/auth/login`.

## Testy

```bash
npm test
```

---

- 👋 Hi, I'm @emaqAI
- 👀 I'm interested in ...
- 🌱 I'm currently learning ...
- 💞️ I'm looking to collaborate on ...
- 📫 How to reach me ...
- 😄 Pronouns: ...
- ⚡ Fun fact: ...

<!---
emaqAI/emaqAI is a ✨ special ✨ repository because its `README.md` (this file) appears on your GitHub profile.
You can click the Preview link to take a look at your changes.
--->
