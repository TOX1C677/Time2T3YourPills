# Деплой API и фоновые задачи

## Переменные окружения

Обязательно задайте в продакшене:

- `DATABASE_URL` — строка подключения PostgreSQL (или SQLite для разработки).
- `JWT_SECRET` — длинная случайная строка.
- `WORKER_API_KEY` — секрет для вызова сканера пропусков (произвольная строка).

Опционально:

- `MISSED_INTAKE_GRACE_MINUTES` — через сколько минут после планового времени считать приём пропущенным (по умолчанию 45).
- `CAREGIVER_LINK_ATTEMPTS_PER_HOUR` — лимит попыток привязки пациента на одного опекуна в час (по умолчанию 30).
- `PATIENT_INVITE_CODE_READS_PER_HOUR` — лимит запросов `GET .../invite-code` на одного пациента в час (по умолчанию 60).

### Почта опекуну при пропуске (SMTP)

Если задан **`SMTP_HOST`**, после сканера для каждого **нового** алерта отправляется одно письмо всем привязанным опекунам; в ответе сканера смотрите поле **`emails_sent`**.

| Переменная | Пример |
|------------|--------|
| `SMTP_HOST` | `smtp.yandex.ru` |
| `SMTP_PORT` | `587` (STARTTLS) или `465` (SSL) |
| `SMTP_USER` / `SMTP_PASSWORD` | логин почтового ящика |
| `SMTP_FROM_EMAIL` | адрес «От» (обязателен при отправке) |
| `SMTP_USE_TLS` | `true` для порта 587 (по умолчанию) |

Без `SMTP_HOST` уведомления только **in-app** (`GET /v1/caregiver/alerts`). На Windows в venv рекомендуется `tzdata` (уже в `requirements.txt`) для IANA-таймзон в сканере расписания.

## Сканер пропусков (`POST /v1/system/missed-intake-scan`)

Создаёт записи в `missed_intake_alerts`:

- **interval** — после последнего `confirmed` и `interval_minutes` + grace нет следующего подтверждения;
- **schedule** — слоты из `slot_times` (`"HH:MM"`) в таймзоне профиля пациента; проверяются сегодня и вчера (чтобы не пропустить окно около полуночи по UTC).

После записи алертов при настроенном SMTP уходит рассылка опекунам.

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
