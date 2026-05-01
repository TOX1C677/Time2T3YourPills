# База данных (PostgreSQL)

Локальная разработка и прод на Ubuntu: **PostgreSQL 16**.

## Docker Compose

Из корня `db/`:

```bash
cd db
docker compose up -d
```

Параметры по умолчанию (см. `docker-compose.yml`):

- пользователь: `time2t3`
- пароль: `time2t3`
- БД: `time2t3`
- порт на хосте: **`5432:5432`** (локально). На VPS часто публикуют **`5433:5432`**, чтобы не конфликтовать с системным PostgreSQL - тогда в `DATABASE_URL` для API указывают `127.0.0.1:5433`.
- у сервиса задано **`restart: unless-stopped`**, чтобы контейнер поднимался после перезагрузки хоста.

Строка подключения для API:

```bash
export DATABASE_URL=postgresql+psycopg2://time2t3:time2t3@127.0.0.1:5432/time2t3
cd ../api
alembic upgrade head   # после появления миграций
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

## Миграции

Исходная схема дублируется в SQLAlchemy-моделях `api/app/models.py`. Для продакшена рекомендуется **Alembic** в каталоге `api/alembic` (см. `api/README.md`). SQL-дампы вручную можно складывать в `db/migrations/` для документации.

## Примечание

Для **pytest** в CI и быстрых тестов API по умолчанию используется **SQLite in-memory** (см. `api/tests/conftest.py`), без поднятия контейнера.
