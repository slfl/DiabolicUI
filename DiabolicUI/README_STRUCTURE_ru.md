# DiabolicUI — карта проекта

Аддон интерфейса для World of Warcraft 3.3.5a (WotLK, build 12340).
Этот файл — навигационная карта: где что лежит и за что отвечает.

## Порядок загрузки (из DiabolicUI.toc)

Файлы грузятся строго в этом порядке — важно, т.к. более поздние
зависят от более ранних:

1. `locale/locale.xml`   — переводы (нужны всем)
2. `engine/engine.xml`   — ядро (движок, менеджер модулей, API)
3. `handlers/handlers.xml`— переиспользуемые "обработчики"
4. `data/data.xml`       — статические данные (цвета, ауры, предметы)
5. `media/media.xml`     — регистрация шрифтов/текстур
6. `config/config.xml`   — настройки каждого модуля
7. `modules/modules.xml` — сами модули интерфейса

Правило: если делаешь новый модуль, который зависит от хендлера или
конфига — он должен грузиться ПОСЛЕ них (т.е. внутри modules.xml).

## Дерево каталогов

```
DiabolicUI/
├── DiabolicUI.toc        Манифест: метаданные + порядок загрузки файлов
├── Bindings.xml          Действия для назначения на клавиши (в меню биндов)
│
├── engine/               ЯДРО. Не трогать без крайней необходимости.
│   ├── engine.lua          Движок: события, таймеры, модули, хендлеры,
│   │                       комбат-очередь, масштаб UI, IsBuild и т.д.
│   └── engine.xml
│
├── handlers/             ПЕРЕИСПОЛЬЗУЕМЫЕ КИРПИЧИ (общие для модулей).
│   │                     Регистрируются как Engine:NewHandler(...),
│   │                     достаются через self:GetHandler("Имя").
│   ├── blizzard.lua        "BlizzardUI"    — прячет/скинит стандартный UI
│   ├── commands.lua        "ChatCommand"   — слэш-команды (/diabolic ...)
│   ├── fade.lua            "Fade"          — плавное появление/скрытие
│   ├── flash.lua           "Flash"         — вспышки/мигание элементов
│   ├── orb.lua             "Orb"           — шары (здоровье/мана)
│   ├── popups.lua          "PopUpMessage"  — всплывающие окна-запросы
│   ├── slider.lua          "Slider"        — ползунки
│   ├── statusbar.lua       "StatusBar"     — кастомные полоски-статусбары
│   ├── tooltip.lua         "Tooltip"       — кастомные подсказки
│   ├── unitframe.lua       "UnitFrame"     — база для рамок юнитов
│   └── handlers.xml
│
├── config/               СТАТИЧЕСКИЕ НАСТРОЙКИ (размеры, позиции, цвета,
│   │                     пути к текстурам). Здесь крутить внешний вид.
│   ├── actionbars.lua      Панели действий
│   ├── auras.lua           Ауры/баффы
│   ├── blizzard.lua        Скин стандартного UI, игровое меню
│   ├── chat.lua            Чат
│   ├── fonts.lua           Шрифты
│   ├── nameplates.lua      Плашки над головами
│   ├── objectives.lua      Трекер целей/квестов
│   ├── tooltips.lua        Подсказки
│   ├── ui.lua              Общие параметры UI
│   ├── unitframes.lua      Рамки юнитов
│   ├── warnings.lua        Экранные предупреждения
│   └── config.xml
│
├── data/                 ЧИСТЫЕ ДАННЫЕ (без логики).
│   ├── colors.lua          Таблицы цветов (классы, реакции, power и т.д.)
│   ├── auras.lua           Списки ID аур
│   ├── items.lua           Данные предметов
│   └── data.xml
│
├── locale/               ПЕРЕВОДЫ.
│   ├── locale_handler.lua  Механизм локализации + fallback на enUS
│   ├── locale-enUS.lua     Английский (базовый/fallback)
│   ├── locale-ruRU.lua     Русский
│   └── locale.xml
│
├── media/                ГРАФИКА И ШРИФТЫ.
│   ├── fonts/              .ttf шрифты (+ fonts.xml)
│   ├── statusbars/         текстуры полосок (4 шт., используемые)
│   ├── textures/           текстуры по назначению:
│   │   ├── actionbars/       панели, кнопки, XP, артворки (45)
│   │   ├── unitframes/       шары, рамки цели, портреты (35)
│   │   ├── ui/               общие кнопки, монеты, лого (9)
│   │   ├── tooltips/         элементы подсказок (8)
│   │   ├── auras/            ауры/шейд (2)
│   │   └── objectives/       кнопки трекера (2)
│   └── media.xml
│
└── modules/              МОДУЛИ ИНТЕРФЕЙСА (фичи). Регистрируются как
    │                     Engine:NewModule(...), тут вся видимая логика.
    │
    ├── actionbars/         ПАНЕЛИ ДЕЙСТВИЙ.
    │   ├── actionbars.lua    Главный модуль ("ActionBars")
    │   ├── bars/             Отдельные бары:
    │   │     bar_1_primary, bar_2_bottomleft, bar_3_bottomright,
    │   │     bar_4_right, bar_5_left, bar_pet, bar_stance,
    │   │     bar_vehicle, bar_xp_rep
    │   ├── controllers/      Контроллеры видимости/раскладки:
    │   │     controller_main, _side, _pet, _stance, _menu,
    │   │     _chat, _custom
    │   ├── menus/            Микроменю и меню чата (main, chat)
    │   └── templates/        Шаблоны кнопок/баров:
    │         bar_template, button_template, flyoutbar_template,
    │         menubutton_template
    │
    ├── blizzard/           РАБОТА СО СТАНДАРТНЫМ UI (прятать/скинить):
    │     "PlayerPowerBarAlt", "BuffFrame", "DurabilityFrame",
    │     "Fonts", "GameMenu", "GhostFrame", "LevelUpDisplay",
    │     "MirrorTimers", "PopUps", "Tooltips", "TotemBar",
    │     "ObjectivesTracker", "VehicleSeatIndicator"
    │
    ├── nameplates/         Плашки над головами ("NamePlates")
    │
    ├── objectives/         ЦЕЛИ/КВЕСТЫ/МИР:
    │     "CaptureBars", "QuestTimer", "Warnings",
    │     "WorldState", "ZoneText"
    │
    └── unitframes/         РАМКИ ЮНИТОВ.
        ├── unitframes.lua    Главный модуль
        ├── units/            Конкретные юниты:
        │     player, target, tot (target-of-target), focus,
        │     pet, party, raid
        └── elements/         Элементы рамок (переиспользуемые):
              aura, cast, classification, combatfeedback,
              combopoints, happiness, health, name, portraits,
              power, runes, threat
```

## Как всё связано (поток)

```
engine  ──создаёт──►  Engine (главный объект)
   │
   ├─ handlers регистрируют себя:  Engine:NewHandler("StatusBar")
   ├─ modules  регистрируют себя:  Engine:NewModule("ActionBars")
   │
   └─ модуль в работе:
        self:GetHandler("StatusBar")   -- взять кирпич
        self:GetStaticConfig("ActionBars") -- взять настройки из config/
        self:GetConfig(...)            -- сохранённые настройки игрока
        Engine:GetLocale()             -- строки перевода
```

## Где что менять (шпаргалка)

| Хочу изменить...              | Иду в...                          |
|------------------------------|-----------------------------------|
| Размер/позицию/цвет элемента | `config/<модуль>.lua`             |
| Поведение фичи               | `modules/<группа>/<файл>.lua`     |
| Текст/перевод                | `locale/locale-ruRU.lua`          |
| Цвета классов/реакций        | `data/colors.lua`                 |
| Картинку/текстуру            | `media/textures/` + путь в config |
| Слэш-команду                 | `handlers/commands.lua`           |
| Скрыть кусок стандартного UI | `modules/blizzard/<файл>.lua`     |

## Важные предостережения

- `engine/` — фундамент. Ломается engine → ломается всё. Правки тут
  только осознанно.
- Пути к текстурам прописаны в `config/*.lua` как полные строки
  (`path .. [[textures\...tga]]`). При перемещении файла текстуры
  нужно синхронно править путь — иначе она просто не отобразится.
- Файлы в кодировке UTF-8 с BOM (нормально для WoW). Config-инструменты
  сторонних сборок иногда это не любят — сам клиент переваривает.
- Порядок в TOC и внутри .xml имеет значение: зависимость должна
  грузиться раньше зависящего.
