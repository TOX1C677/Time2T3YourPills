# Time2T3 API

REST API (`/v1`) для приложения «Время принять таблетки»: регистрация, вход JWT, профиль пациента, код привязки опекуна, привязка пациента.

## Локальный запуск

```bash
cd api
python -m venv .venv
.venv\Scripts\activate   # Windows
# source .venv/bin/activate  # Linux/macOS
pip install -r requirements.txt
```

По умолчанию используется **SQLite** (`./data/time2t3_api.db`). Для PostgreSQL см. `../db/README.md`.

```bash
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

Документация OpenAPI: http://127.0.0.1:8000/docs

Развёрнутый инстанс (пример): **`https://api.anti-toxic.ru/docs`**, health — **`GET /health`**, бизнес-маршруты под **`/v1/...`**.

### Лекарства (пациент)

- `GET /v1/patients/me/medications` — список (без soft-deleted).
- `PUT /v1/patients/me/medications/{medication_id}` — upsert (тело: `name`, `dosage`, `reminder_mode` = `interval` | `schedule`, `interval_minutes`, `slot_times`).
- `DELETE /v1/patients/me/medications/{medication_id}` — soft delete.

### Лекарства (опекун, только привязанные пациенты)

- `GET /v1/caregiver/patients/{patient_user_id}/medications`
- `PUT /v1/caregiver/patients/{patient_user_id}/medications/{medication_id}`
- `DELETE /v1/caregiver/patients/{patient_user_id}/medications/{medication_id}`

### История приёмов (intake events)

- `POST /v1/patients/me/intake-events` — тело: `medication_id` (опц.), `scheduled_at`, `recorded_at`, `status` (`confirmed` \| `missed` \| `snoozed`), `medication_name_snapshot`, `dosage_snapshot`, `source`, опц. `snooze_until`.
- `GET /v1/patients/me/intake-events?from=&to=` — фильтр по `recorded_at` (ISO), без query — вся история.
- `GET /v1/caregiver/patients/{patient_user_id}/intake-events?from=&to=` — история выбранного пациента для опекуна.

## Переменные окружения

| Переменная | Описание | По умолчанию |
|------------|----------|--------------|
| `DATABASE_URL` | SQLAlchemy URL | `sqlite:///./data/time2t3_api.db` |
| `JWT_SECRET` | Секрет подписи JWT | `dev-change-me` (обязательно сменить в проде) |
| `JWT_ACCESS_MINUTES` | TTL access | `30` |
| `JWT_REFRESH_DAYS` | TTL refresh | `7` |

## Миграции (PostgreSQL)

```bash
export DATABASE_URL=postgresql+psycopg2://time2t3:time2t3@127.0.0.1:5432/time2t3
alembic upgrade head
```

## Тесты

```bash
cd api
pytest tests/ -v
```
