# Деплой API и фоновые задачи

## Переменные окружения

Обязательно задайте в продакшене:

- `DATABASE_URL` — строка подключения PostgreSQL (или SQLite для разработки).
- `JWT_SECRET` — длинная случайная строка.
- `WORKER_API_KEY` — секрет для вызова сканера пропусков (произвольная строка).

Опционально:

- `MISSED_INTAKE_GRACE_MINUTES` — через сколько минут после планового времени считать приём пропущенным (по умолчанию 45).
- `CAREGIVER_LINK_ATTEMPTS_PER_HOUR` — лимит попыток привязки пациента на одного опекуна в час (по умолчанию 30).

## Сканер пропусков (`POST /v1/system/missed-intake-scan`)

Создаёт записи в таблице `missed_intake_alerts` для **интервальных** лекарств: если после последнего подтверждённого приёма прошёл интервал плюс «grace», а нового подтверждения нет — фиксируется пропуск. Режим «по расписанию» (`slot_times`) в v1 не обрабатывается.

Заголовок запроса:

```http
X-Worker-Key: <значение WORKER_API_KEY>
```

Пример через `curl` раз в 15 минут (systemd timer):

```ini
# /etc/systemd/system/time2t3-missed-scan.service
[Unit]
Description=Time2T3 missed intake scan

[Service]
Type=oneshot
ExecStart=/usr/bin/curl -fsS -X POST -H "X-Worker-Key: %i" https://your-api.example.com/v1/system/missed-intake-scan
```

Подставьте URL и ключ; `%i` в unit не используется — лучше `EnvironmentFile=/etc/time2t3.env` с `CURL_URL` и вызовом из скрипта.

Опекун видит накопленные записи в приложении: **Профиль → Пропуски приёмов** (`GET /v1/caregiver/alerts`).

## Запуск API (обзор)

```bash
cd api
python -m venv .venv
.venv\Scripts\activate   # Windows
pip install -r requirements.txt
uvicorn app.main:app --host 0.0.0.0 --port 8000
```

Миграции: при старте вызывается `create_all` для SQLite/простых случаев; для продакшена PostgreSQL рекомендуется Alembic (при появлении в проекте).
