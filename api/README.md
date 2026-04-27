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
