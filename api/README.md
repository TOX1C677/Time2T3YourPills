# TimeToTake API (FastAPI)

## Запуск

```bash
python -m venv .venv
# Windows: .venv\Scripts\activate
pip install -r requirements.txt
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

- **SQLite** (по умолчанию `DATABASE_URL`): при старте приложения вызывается `create_all` - таблицы создаются автоматически.
- **PostgreSQL**: таблицы создаются **только через Alembic** (`create_all` на старте не выполняется).

## Миграции Alembic

Из каталога `api/`:

```bash
# применить схему (DATABASE_URL должен указывать на целевую БД)
alembic upgrade head

# новая ревизия после изменения моделей (пример с пустой SQLite для автогенерации)
# del data\gen.db  # Windows
# export DATABASE_URL=sqlite:///./data/gen.db  # Linux/macOS
alembic revision --autogenerate -m "описание"
```

Файлы: `alembic.ini`, `alembic/env.py`, `alembic/versions/`.

## Переменные окружения

См. `app/config.py` и `docs/DEPLOY.md` в корне репозитория (JWT, worker, SMTP, rate limits).

## Тесты

```bash
pytest tests/ -v
```

В CI используется SQLite in-memory (`tests/conftest.py`); миграции Alembic там не вызываются.
