# Time2T3 Your Pills (Flutter)

Клиент напоминаний о приёме лекарств с учётом требований к UI при паркинсонизме. Целевая платформа для диплома: **Android**.

## Структура репозитория

| Путь | Назначение |
|------|------------|
| `lib/` | Flutter-приложение (Provider + `AppServices`, go_router, GetStorage, мок-синк). |
| `legacy_android/` | Прежний Java/Room проект — только справка, сборка из этой папки. |
| `DESIGN_GUIDELINES_PARKINSON.md` | Критерии доступности UI. |
| `UI_DESIGN_PLAN.md` | План дизайна и токены. |
| `FLUTTER_MIGRATION_PLAN.md` | Архитектура и этапы. |

## Запуск

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

- Сначала скелет с моками, затем свой API (Swagger) + PostgreSQL на сервере; на защите — рабочий клиент с дизайном и бэкендом.
- Только русский UI; без регистрации (MVP).
- Напоминание: **интервал** или **график** (слоты времени).
- Офлайн: редактирование + **outbox**; при непустой очереди **pull не перезаписывает** локальные данные.
- Таймер в фоне: сохранение `endAt` + `flutter_local_notifications` с точным расписанием; отложить **+15 мин**; действия из шторки вызывают те же обработчики.
- DI: `MultiProvider` / `Provider`, контроллеры — `ChangeNotifier` с явным жизненным циклом (см. `lib/main.dart`).
