# Полный технический слепок: Time2T3YourPills (Android)

**Дата снимка:** 24.04.2026  
**Цель документа:** единая база для миграции на Flutter и доработки функционала.

---

## 1. Назначение продукта

Нативное Android-приложение для напоминаний о приёме лекарств: обратный отсчёт (интервал в минутах), повторы цикла, уведомление по окончании, подтверждение приёма; учёт препаратов в локальной БД; карточка пациента (имя, отчество/second name, заметки); экран «О приложении».

---

## 2. Стек и метаданные сборки

| Параметр | Значение |
|----------|----------|
| Язык | Java 8 |
| Модуль | один `:app` |
| `applicationId` / namespace | `com.example.time2t3yourpills` |
| `compileSdk` | 34 |
| `minSdk` | 24 |
| `versionCode` / `versionName` | 1 / 1.0 |
| Android Gradle Plugin | 8.13.2 (корневой `build.gradle`) |
| `buildToolsVersion` | 33.0.2 |

**Репозитории:** Google + Maven Central (`settings.gradle`, `FAIL_ON_PROJECT_REPOS`).

---

## 3. Зависимости (`app/build.gradle`)

| Библиотека | Версия | Фактическое использование в коде |
|------------|--------|-----------------------------------|
| `androidx.appcompat:appcompat` | 1.6.1 | да |
| `com.google.android.material:material` | 1.10.0 | BottomNavigationView |
| `androidx.room:room-runtime` + compiler | 2.5.2 | да |
| `androidx.constraintlayout:constraintlayout` | 2.1.4 | только импорт TAG в `MedicationFragment` / `MedicationViewModel` (ошибочный импорт) |
| `androidx.lifecycle:lifecycle-viewmodel` | 2.4.1 | да |
| `androidx.lifecycle:lifecycle-livedata` | 2.6.2 | да |
| `com.google.firebase:firebase-firestore` | 24.8.1 | **нет** — в исходниках не используется |
| `io.reactivex.rxjava3:rxjava` / `rxandroid` | 3.1.0 / 3.0.0 | **нет** |
| JUnit / AndroidX Test / Espresso | тесты | шаблонные тесты |

**Замечания по Gradle:** в конце `app/build.gradle` дублируется `apply plugin: 'com.android.application'` при уже объявленном `plugins { id 'com.android.application' }`.

**Отсутствует в явных зависимостях:** `androidx.localbroadcastmanager:localbroadcastmanager` — при этом в коде активно используется `LocalBroadcastManager` (нужна либо явная зависимость, либо замена на другой канал связи).

---

## 4. Манифест и разрешения

**Файл:** `app/src/main/AndroidManifest.xml`

- Разрешение: `POST_NOTIFICATIONS`.
- `MainActivity` — launcher, `exported=true`.
- `TimerService` — фоновый сервис таймера.
- BroadcastReceivers: `ConfirmReceiver`, `SnoozeReceiver` (без `intent-filter` в манифесте — вызываются через `PendingIntent` / явный `Intent` где применимо).
- Тема: `Theme.Time2T3YourPills`, backup/data extraction rules.

---

## 5. Архитектура UI и навигация

**Паттерн:** классический **Single-Activity** + **4 Fragment** + **Bottom Navigation**.

```
MainActivity
├── FrameLayout (fragment_container)
└── BottomNavigationView → replaceFragment(...)
```

| Вкладка (menu id) | Fragment | Назначение |
|-------------------|----------|------------|
| `nav_timer` | `TimerFragment` | Старт таймера, отображение секунд, Confirm |
| `nav_medication` | `MedicationFragment` | Форма + список (RecyclerView) препаратов |
| `nav_patient` | `PatientFragment` | Профиль пользователя Room |
| `nav_about` | `AboutFragment` | Название, версия, контакт (строки) |

Стартовый экран при первом запуске: `TimerFragment`.

**Навигация:** `FragmentTransaction.replace` без back stack — при переключении вкладок состояние фрагментов не сохраняется стандартным способом.

---

## 6. Слой представления (детально по экранам)

### 6.1 MainActivity

- Связывается с `TimerService` (`bindService` + `startService` в `onResume`; `unbind` в `onPause`).
- Создаёт `SharedViewModel` уровня Activity.
- Регистрирует `BroadcastReceiver` на `TimerService.ACTION_TIMER_UPDATE` через `LocalBroadcastManager`, прокидывает значение в `sharedViewModel.setTimerValue(...)`.
- Нижнее меню переключает фрагменты.

### 6.2 TimerFragment

- Отдельно биндится к `TimerService` (дублирование логики с Activity).
- Слушает `LocalBroadcastManager` в `onResume`/`onPause`: обновляет текст «Осталось времени: N сек.», скрывает/показывает кнопку Start по флагу `is_running`.
- Кнопки: Start → `timerService.startTimerFromService()`; Confirm → `timerService.onConfirmationReceived()`.

### 6.3 MedicationFragment

- `MedicationViewModel` (scope фрагмента) + `SharedViewModel` (scope Activity).
- `RecyclerView` + `MedicationAdapter` (ListAdapter + DiffUtil).
- Поля: название, доза, таймер (минуты), число повторов; кнопка «Add Medication».
- При добавлении: валидация непустых полей → `insertOrUpdate` → обновление `SharedViewModel` и `startService` с action `SET_TIMER_VALUE`.
- Наблюдение за `getAllMedications()`: **всегда подставляет в форму последний элемент списка** и подписывается на `getCurrentMedication` по его id — логика «текущего» препарата привязана к последней записи, а не к выбору из списка.

### 6.4 PatientFragment

- Поля: имя, «middle name», заметки; Save.
- `UserViewModel.getUser()` — один пользователь из БД.
- `loadUser(userId)` из `arguments` реализован, но **нигде не передаётся `setArguments`** при навигации — ветка фактически мёртвая.
- Сохранение: `insertOrUpdateUser` с callback (логирование успеха/ошибки); Toast для пользователя по сохранению **не показывается** (в отличие от пустых полей в других местах).

### 6.5 AboutFragment

- Статические строки: `app_name`, `app_version` с плейсхолдером `1.0`, `contact_info` с плейсхолдером email.
- `SharedViewModel` получается, но **не используется**.

---

## 7. ViewModel-слой

| Класс | Базовый класс | Scope | Роль |
|-------|---------------|-------|------|
| `SharedViewModel` | `AndroidViewModel` | Activity | `MutableLiveData<Long>` таймер; `MutableLiveData<Integer>` repeat — repeat почти не заполняется извне; регистрация receiver на LBM в конструкторе |
| `MedicationViewModel` | `AndroidViewModel` | Fragment | Обёртка над `MedicationRepository`; `getCurrentMedication(id)` кэширует один `LiveData` на первый вызов (потенциальная ошибка при смене id) |
| `UserViewModel` | `AndroidViewModel` | Fragment | `getUser()`, `getNotes()` через `Transformations.switchMap`, `getUserById`, `insertOrUpdateUser` |

**Паттерн:** упрощённый **MVVM** (ViewModel + LiveData), без единого Application-класса и без Hilt/Koin.

---

## 8. Репозитории и данные

### 8.1 MedicationRepository

- Источник: Room (`MedicationDao`).
- Асинхронность: **устаревший `AsyncTask`** для insert/update.
- Методы: `getAllMedications`, `getMedicationById` (LiveData), `getMedicationByIdSync`, `insert`, `update`, `insertOrUpdate` (не используется из ViewModel напрямую — ViewModel дублирует логику insert/update).

### 8.2 UserRepository

- `UserDao`, `NoteDao`, `Executor` single-thread.
- `getUser`, `getUserById`, `getNotes`, `insertOrUpdateUser` (сравнение с `getUserSync` — один глобальный «текущий» пользователь).
- `insertOrUpdateNote` — в UI не вызывается; заметки пользователя в форме **не редактируются** — в `User` есть поле `notes` как один текст, а сущность `Note` — отдельная таблица.

---

## 9. База данных Room

**Файл:** `database/AppDatabase.java`

- Имя файла БД: `app_database`.
- Версия схемы: **8**.
- `fallbackToDestructiveMigration()` — при смене версии данные стираются.
- `exportSchema = false`.

**Сущности:**

1. **Medication** (`medication_table`)  
   - `@PrimaryKey` `String id` — по умолчанию `UUID.randomUUID()` в поле объекта.  
   - `name`, `dosage`, `timer` (long, **минуты** в бизнес-логике сервиса умножаются на 60×1000), `repetitions` (int).

2. **User** (`user_table`)  
   - `@PrimaryKey(autoGenerate = true) int id`  
   - `name`, `middleName`, `notes`.

3. **Note** (`note_table`)  
   - FK на `User`, CASCADE, индекс `userId`.  
   - Поля: `noteText`, `userId`.  
   - В приложении нет экрана для CRUD заметок; связь подготовлена под будущее.

**DAO кратко:**

- `MedicationDao`: полный CRUD-набор запросов + `deleteAll`.
- `UserDao`: insert, sync/async get, update, delete; **default-методы** `insertOrUpdate` и `deleteUserAsync` с `Executor`/`AsyncTask` внутри интерфейса DAO (нетипичная смесь ответственности).
- `NoteDao`: insert, update, запросы по user / id.

---

## 10. Фоновая логика: TimerService

**Тип:** bound + started (`START_STICKY`).

**Ключевые константы:**  
`ACTION_TIMER_UPDATE`, `EXTRA_TIMER_VALUE`, `ACTION_CONFIRM`, `ACTION_SNOOZE`.

**Реализация таймера:** `android.os.CountDownTimer` с шагом 1 с.

**Загрузка настроек:**

- В `onCreate`: `AsyncTask` → `getMedicationByIdSync("YOUR_MEDICATION_ID")` — **заглушка**, не реальный id.
- `onStartCommand`: `updateTimerSettings("YOUR_MEDICATION_ID")` — снова заглушка.
- Поддержка `SET_TIMER_VALUE` из Intent — выставляет `duration` в мс.
- `ACTION_CONFIRM`: сброс уведомления, перезапуск цикла через `startTimerFromService()`.
- **`ACTION_SNOOZE` в коде сервиса не обрабатывается** (есть только в `SnoozeReceiver`, который шлёт action в сервис).

**По окончании тика:** локальный broadcast + `NotificationHelper.buildNotification` + `notify(1)`.

**Повторы:** при `repeatCount > 0` после финиша декремент и рекурсивный перезапуск таймера.

**Мусор/заготовки в коде:** неиспользуемые импорты `Observer`, `ViewModelProvider`, поле `medicationViewModel` в сервисе.

---

## 11. Уведомления

**Класс:** `NotificationHelper`

- Канал O+: `medication_reminder_channel`.
- Действие «Confirm» → `PendingIntent` → `ConfirmReceiver` → `startService` с `ACTION_CONFIRM`.
- **Ресурсы:** `R.drawable.ic_confirm`, `R.drawable.ic_notification` — в каталоге `res/drawable` **отсутствуют** (см. раздел 13).

---

## 12. Адаптер списка препаратов

**MedicationAdapter** (`ListAdapter` + `MedicationDiffCallback`):

- `onBindViewHolder` **полностью закомментирован** — элементы списка визуально пустые.
- `MedicationDiffCallback.areItemsTheSame`: сравнение `oldItem.getId() == newItem.getId()` для **String** — логическая ошибка (нужно `Objects.equals`); DiffUtil может работать некорректно.

**MedicationViewHolder:** ожидает id `medication_name`, `dosage`, `timer`, `repeat_count` в **item layout** — в `medication_list_item.xml` эти TextView **закомментированы**, контейнер по сути пустой.

---

## 13. Ресурсы (ресурсный долг)

**Меню:** `bottom_nav_menu.xml` ссылается на `@drawable/ic_timer`, `ic_medication`, `ic_patient`, `ic_about` — **файлов нет** в репозитории (в `drawable` только launcher и `kreis.xml`).

**Уведомления:** см. выше — нет `ic_confirm`, `ic_notification`.

Итог: проект в текущем виде с высокой вероятностью **не соберётся** или потребует недостающих vector/png и исправления ссылок.

---

## 14. Локализация и UX-копирайт

- Смесь **русского** (текст таймера) и **английского** (кнопки, hints, Toast «Please fill out all fields»).
- `strings.xml`: минимальный набор; часть текстов захардкожена в layout/Java.

---

## 15. Тестирование

- `ExampleUnitTest` / `ExampleInstrumentedTest` — шаблоны, **не покрывают** бизнес-логику.

---

## 16. Карта пакета `com.example.time2t3yourpills`

```
MainActivity
TimerFragment, MedicationFragment, PatientFragment, AboutFragment
SharedViewModel, MedicationViewModel, UserViewModel
TimerService
NotificationHelper
ConfirmReceiver, SnoozeReceiver
MedicationViewHolder
adapters/MedicationAdapter
repository/MedicationRepository, UserRepository
database/AppDatabase
dao/MedicationDao, UserDao, NoteDao
models/Medication, User, Note
```

---

## 17. Потоки данных (сжатая схема)

```
MedicationFragment → MedicationViewModel → MedicationRepository → Room
                              ↓
                    SharedViewModel (timer ms, repeat)
                              ↓
              startService(SET_TIMER_VALUE) → TimerService

TimerService (CountDownTimer) → LocalBroadcastManager
       → MainActivity / TimerFragment / SharedViewModel (частично дублирование)

Timer end → NotificationManager + (optional) repeat loop
Confirm (notification) → ConfirmReceiver → TimerService.ACTION_CONFIRM
```

```
PatientFragment → UserViewModel → UserRepository → Room (User; Note API не используется в UI)
```

---

## 18. Ключевые риски и технический долг (для миграции)

1. Заглушка `YOUR_MEDICATION_ID` — нет связи «выбранный препарат ↔ таймер».
2. Дублирование bind к сервису в Activity и TimerFragment.
3. `SharedViewModel` держит BroadcastReceiver + дублирование с MainActivity.
4. Firebase / RxJava — мёртвый вес зависимостей.
5. `MedicationViewModel.getCurrentMedication` — кэш LiveData на один id.
6. Список препаратов не отображает данные; DiffUtil с `==` для String id.
7. Отсутствующие drawable и возможно LBM dependency.
8. `SnoozeReceiver` / `ACTION_SNOOZE` — незавершённая цепочка.
9. Заметки `Note` vs поле `notes` у User — непрояснённая доменная модель.
10. Нет foreground service / типа для долгой фоновой работы на новых версиях Android (политика ОС).

---

## 19. Итоговая характеристика «что есть продуктово»

| Функция | Статус |
|---------|--------|
| Список препаратов в БД | частично (данные есть, UI списка пустой) |
| Форма добавления препарата | да |
| Таймер обратного отсчёта | да (ручной старт; настройки из сервиса частично заглушены) |
| Повтор циклов | задумано в сервисе |
| Уведомление + подтверждение | задумано; ресурсы могут ломать сборку |
| Профиль пациента | да (один user) |
| Отдельные заметки Note | только слой данных |
| О приложении | да |

---

*Конец слепка. План миграции на Flutter — в отдельном файле `FLUTTER_MIGRATION_PLAN.md`.*
