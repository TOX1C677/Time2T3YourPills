# Time2T3 Your Pills (Flutter)

Клиент напоминаний о приёме лекарств с учётом требований к UI при паркинсонизме. Целевая платформа для диплома: **Android**.

## Структура репозитория

| Путь | Назначение |
|------|------------|
| `lib/` | Flutter-приложение (Provider + `AppServices`, go_router, GetStorage, синк с API через `ApiRemoteDataSource`). |
| `api/` | REST API (FastAPI, JWT, SQLite по умолчанию / Postgres в `db/`). |
| `db/` | Docker Compose для PostgreSQL, заметки по миграциям. |
| `.github/workflows/ci.yml` | CI: pytest для `api/`, `flutter analyze` + тесты. |
| `legacy_android/` | Прежний Java/Room проект — только справка, сборка из этой папки. |
| `DESIGN_GUIDELINES_PARKINSON.md` | Критерии доступности UI. |
| `UI_DESIGN_PLAN.md` | План дизайна и токены. |
| `FLUTTER_MIGRATION_PLAN.md` | Архитектура и этапы. |

## API (бэкенд)

```bash
cd api
python -m venv .venv
# Windows: .venv\Scripts\activate
pip install -r requirements.txt
uvicorn app.main:app --reload --port 8000
```

PostgreSQL для разработки: `cd db && docker compose up -d` (см. `db/README.md`).

Flutter по умолчанию ходит на `http://127.0.0.1:8000`. **Эмулятор Android** к хосту:  
`flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000`  
Прод или другой хост: `--dart-define=API_BASE_URL=https://…` (см. ниже).

После старта API: экран **«Вход»** → регистрация или логин. Подтверждение приёма на **Таймере** отправляет запись в **`POST /v1/patients/me/intake-events`**. История: вкладка **«История»** в нижнем меню (и у пациента, и у опекуна), плюс иконка на **таймере** у пациента и пункт меню в **профиле** (полноэкранный маршрут `/intake-history`). У опекуна нет вкладки «Таймер» — только таблетки, история и профиль (план §7.2). Фоновый скан пропусков и деплой: **`docs/DEPLOY.md`**.

### Развёрнутый сервер (актуальная проверка)

| Компонент | Состояние |
|-----------|-----------|
| **БД** | Контейнер `time2t3_postgres`, `healthy`; на хосте часто порт **5433** → 5432 внутри контейнера. |
| **API** | `uvicorn` на `0.0.0.0:8000`, в проде за nginx/Let’s Encrypt — публичный базовый URL **`https://api.anti-toxic.ru`**. Конфиг окружения на сервере (например `time2t3-api.env`): PostgreSQL на **`127.0.0.1:5433`**. |
| **Контракт** | Swagger: `https://api.anti-toxic.ru/docs`; реальные маршруты с префиксом **`/v1/...`** (auth и остальное). Проверка: `GET https://api.anti-toxic.ru/health` → `{"status":"ok"}`. |

Сборка/запуск Flutter против этого API:

```bash
flutter run --dart-define=API_BASE_URL=https://api.anti-toxic.ru
```

Проверка с телефона или ПК (не из песочницы CI):

```bash
curl -sS https://api.anti-toxic.ru/health
```

**После перезагрузки VPS** контейнер БД поднимется сам, если в реально используемом compose стоит **`restart: unless-stopped`** (в `db/docker-compose.yml` репозитория так и сделано — перенесите на сервер при деплое). Процесс **API (uvicorn)** после reboot сам не стартует, пока для него не настроен **systemd** (или другой supervisor) — иначе нужен ручной запуск. На разработку UI это не мешает, пока сервер не перезагружали.

## Запуск (Flutter)

```bash
flutter pub get
flutter run
```

Сборка APK:

```bash
flutter build apk --debug
```

### Про Gradle и «другой сборщик»

- Dart/Flutter-код компилирует **свой** toolchain (`flutter build …`).
- Для **APK/AAB** всё равно собирается нативная оболочка Android — это **всегда Gradle** (`android/` + wrapper из репозратория). Отдельного официального «другого сборщика» вместо Gradle для Android у Flutter нет.
- Старый Java-модуль живёт в **`legacy_android/`** — у него **свой** Gradle; в Android Studio Gradle-синк нужно вести от **`android/`** текущего Flutter-проекта (см. `.idea/gradle.xml`), иначе IDE путает корень и ломает импорты.

## Зафиксированные решения (из согласования)

- Скелет с моками для препаратов; **авторизация и профиль** — через REST в `api/` (см. `docs/DIPLOM_BACKEND_AUTH_PLAN.md`).
- Только русский UI.
- Напоминание: **интервал** или **график** (слоты времени).
- Офлайн: редактирование + **outbox**; при непустой очереди **pull не перезаписывает** локальные данные.
- Таймер в фоне: сохранение `endAt` + `flutter_local_notifications` с точным расписанием; отложить **+15 мин**; действия из шторки вызывают те же обработчики.
- DI: `MultiProvider` / `Provider`, контроллеры — `ChangeNotifier` с явным жизненным циклом (см. `lib/main.dart`).
