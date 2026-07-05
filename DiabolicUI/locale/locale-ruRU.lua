local _, Engine = ...

local L = Engine:NewLocale("ruRU")
if not L then return end

---------------------------------------------------------------------
-- System Messages
---------------------------------------------------------------------

-- Core Engine
L["Bad argument #%d to '%s': %s expected, got %s"] = true
L["The Engine has no method named '%s'!"] = true
L["The handler '%s' has no method named '%s'!"] = true
L["The handler element '%s' has no method named '%s'!"] = true
L["The module '%s' has no method named '%s'!"] = true
L["The module widget '%s' has no method named '%s'!"] = true
L["The Engine has no method named '%s'!"] = true
L["The handler '%s' has no method named '%s'!"] = true
L["The module '%s' has no method named '%s'!"] = true
L["The event '%' isn't currently registered to any object."] = true
L["The event '%' isn't currently registered to the object '%s'."] = true
L["Attempting to unregister the general occurence of the event '%s' in the object '%s', when no such thing has been registered. Did you forget to add function or method name to UnregisterEvent?"] = true
L["The method named '%s' isn't registered for the event '%s' in the object '%s'."] = true
L["The function call assigned to the event '%s' in the object '%s' doesn't exist."] = true
L["The message '%' isn't currently registered to any object."] = true
L["The message '%' isn't currently registered to the object '%s'."] = true
L["Attempting to unregister the general occurence of the message '%s' in the object '%s', when no such thing has been registered. Did you forget to add function or method name to UnregisterMessage?"] = true
L["The method named '%s' isn't registered for the message '%s' in the object '%s'."] = true
L["The function call assigned to the message '%s' in the object '%s' doesn't exist."] = true
L["The config '%s' already exists!"] = true
L["The config '%s' doesn't exist!"] = true
L["The config '%s' doesn't have a profile named '%s'!"] = true
L["The static config '%s' doesn't exist!"] = true
L["The static config '%s' already exists!"] = true
L["Bad argument #%d to '%s': No handler named '%s' exist!"] = true
L["Bad argument #%d to '%s': No module named '%s' exist!"] = true
L["The element '%s' is already registered to the '%s' handler!"] = true
L["The widget '%s' is already registered to the '%s' module!"] = true
L["A handler named '%s' is already registered!"] = true
L["Bad argument #%d to '%s': The name '%s' is reserved for a handler!"] = true
L["Bad argument #%d to '%s': A module named '%s' already exists!"] = true
L["Bad argument #%d to '%s': The load priority '%s' is invalid! Valid priorities are: %s"] = true
L["Attention!"] = "Внимание!"
L["The UI scale is wrong, so the graphics might appear fuzzy or pixelated. If you choose to ignore it, you won't be asked about this issue again.|n|nFix this issue now?"] = true
L["UI scaling is activated and needs to be disabled, otherwise you'll might get fuzzy borders or pixelated graphics. If you choose to ignore it and handle the UI scaling yourself, you won't be asked about this issue again.|n|nFix this issue now?"] = true
L["UI scaling was turned off but needs to be enabled, otherwise you'll might get fuzzy borders or pixelated graphics. If you choose to ignore it and handle the UI scaling yourself, you won't be asked about this issue again.|n|nFix this issue now?"] = true
L["The UI scale is wrong, so the graphics might appear fuzzy or pixelated. If you choose to ignore it and handle the UI scaling yourself, you won't be asked about this issue again.|n|nFix this issue now?"] = true
L["Your resolution is too low for this UI, but the UI scale can still be adjusted to make it fit. If you choose to ignore it and handle the UI scaling yourself, you won't be asked about this issue again.|n|nFix this issue now?"] = true
L["Accept"] = "Подтвердить"
L["Cancel"] = "Отмена"
L["Ignore"] = "Игнорировать"
L["You can re-enable the auto scaling by typing |cff448800/diabolic autoscale|r in the chat at any time."] = true
L["Auto scaling of the UI has been enabled."] = "Включено автоматическое масштабирование пользовательского интерфейса."
L["Auto scaling of the UI has been disabled."] = "Выключено автоматическое масштабирование пользовательского интерфейса."
L["Reload Needed"] = "Нужна перезагрузка"
L["The user interface has to be reloaded for the changes to be applied.|n|nDo you wish to do this now?"] = true
L["The Engine can't be tampered with!"] = true

-- Blizzard Handler
L["Bad argument #%d to '%s'. No object named '%s' exists."] = "Неверный аргумент #%d для '%s'. Объекта с именем '%s' не существует»."


---------------------------------------------------------------------
-- User Interface
---------------------------------------------------------------------

-- actionbar module
-- button tooltips
L["Main Menu"] = "Главное меню"
L["<Left-click> to toggle menu."] = "<ЛКМ> открыть главное меню."
L["Action Bars"] = "Панель действий"
L["<Left-click> to toggle action bar menu."] = "<ЛКМ> для переключений панели действий."
L["Bags"] = "Сумки"
L["<Left-click> to toggle bags."] = "<ЛКМ> открыть все сумки."
L["<Right-click> to toggle bag bar."] = "<ПКМ> открыть выбор сумок."
L["Chat"] = "Чат"
L["<Left-click> or <Enter> to chat."] = "<ЛКМ> или <Энтер> чтоб написать в чат."
L["Friends & Guild"] = "Друзья, гильдия, каналы, рейд."
L["<Left-click> to toggle social frames."] = "<ЛКМ> для открытия фрейма."

-- actionbar menu
L["Action Bars"] = "Панель действий"
L["Side Bars"] = "Боковая панель"
L["Hold |cff00b200<Alt+Ctrl+Shift>|r and drag to remove spells, macros and items from the action buttons."] = "Зажми |cff00b200<Alt+Ctrl+Shift>|r для перемещения спеллов на панели комманд."
L["No Bars"] = "Без панели"
L["One"] = "Одна"
L["Two"] = "Две"
L["Three"] = "Три"

-- xp bar
L["Current XP: "] = "Опыт: "
L["Rested Bonus: "] = "Отдых: "
L["Faction: "] = "Фракция: "
L["Standing: "] = "Отношение: "
L["Reputation: "] = "Репутация: "
L["Rested"] = "Отдых"
L["%s of normal experience\ngained from monsters."] = "%s обычного опыта,\nполученного от монстров."
L["Resting"] = "Отдых"
L["You must rest for %s additional\nhours to become fully rested."] = "Вы должны отдыхать в течение %s дополнительных\nчасов, чтобы полностью отдохнуть."
L["You must rest for %s additional\nminutes to become fully rested."] = "Вы должны отдохнуть еще %s\nминут, чтобы полностью отдохнуть."
L["Normal"] = "Нормальный"
L["You should rest at an Inn."] = "Вы должны отдохнуть в таверне."

-- stance bar
L["Stances"] = "Формы"
L["<Left-click> to toggle stance bar."] = "<Left-click> выбрать форму."

-- added to the interface options menu in WotLK
L["Cast action keybinds on key down"] = "Назначить привязку клавиш действия при нажатии клавиши"

-- chat module
L["Chat Setup"] = "Настройки чата"
L["Would you like to automatically have the main chat window sized and positioned to match Diablo III, or would you like to manually handle this yourself?|n|nIf you choose to manually position things yourself, you won't be asked about this issue again."] = "Хотели бы вы, чтобы размер и положение главного окна чата автоматически соответствовали Diablo III, или вы хотите сделать это вручную?|n|nЕсли вы решите расположить элементы вручную, вас больше не будут спрашивать об этой проблеме."
L["Auto"] = "Авто"
L["Manual"] = "Вручную"
L["You can re-enable the auto positioning by typing |cff448800/diabolic autoposition|r in the chat at any time."] = "Вы можете снова включить автоматическое позиционирование, набрав |cff448800/diabolic autoposition|r в чате в любое время."
L["Auto positioning of chat windows has been enabled."] = "Включено автоматическое позиционирование окон чата."
L["Auto positioning of chat windows has been disabled."] = "Выключено автоматическое позиционирование окон чата."

-- Options panel
L["Additional interface options."] = "Дополнительные настройки интерфейса."
L["Show FPS and latency"] = "Показывать FPS и задержку"
L["Toggles the performance readout (frames per second and latency) on the micro menu."] = "Включает/выключает показ производительности (кадры в секунду и задержку) на микроменю."
L["Class colored health orb"] = "Классовый цвет орба здоровья"
L["Colors the player health orb using your class color instead of the default red."] = "Окрашивает орб здоровья игрока в цвет класса вместо стандартного красного."
L["Also color the pet health orb"] = "Также красить орб питомца"
L["Also colors the pet health orb using your class color."] = "Также окрашивает орб здоровья питомца в цвет вашего класса."
L["Show player coordinates"] = "Показывать координаты персонажа"
L["Shows your map coordinates in the lower-left corner."] = "Показывает координаты на карте в левом нижнем углу."
L["Show menu buttons"] = "Показывать кнопки меню"
L["Shows the menu, bags, chat and friends buttons. Turn off for a cleaner interface."] = "Показывает кнопки меню, сумок, чата и друзей. Отключите для чистого интерфейса."
L["Custom minimap"] = "Diablo мини-карта"
L["Shows the custom square minimap. Turn off to use another minimap addon. Requires a relog to take effect."] = "Показывает свою квадратную мини-карту. Отключите для другого аддона мини-карты. Требует перезахода."
L["The minimap change will take effect after your next relog."] = "Изменение мини-карты вступит в силу после перезахода."
L["24-hour clock"] = "24-часовой формат"
L["Use a 24-hour clock (15:55) instead of 12-hour (3:55 PM)."] = "24-часовой формат (15:55) вместо 12-часового (3:55 PM)."
L["Use slash in date"] = "Слеш в дате"
L["Separate the date with a slash (05/07) instead of a dot (05.07)."] = "Разделять дату слешем (05/07) вместо точки (05.07)."
L["Show addon buttons"] = "Показывать кнопки аддонов"
L["Show the collapsible addon-button holder under the minimap."] = "Показывать сворачиваемую панель кнопок аддонов под мини-картой."
L["Show vignette"] = "Показывать виньетку"
L["Show a dark vignette overlay on the minimap."] = "Показывать тёмную виньетку поверх мини-карты."
L["Vignette strength"] = "Сила виньетки"
L["Adjust the vignette opacity."] = "Регулировка прозрачности виньетки."
L["Minimap opacity"] = "Прозрачность мини-карты"
L["Adjust the overall minimap opacity."] = "Регулировка общей прозрачности мини-карты."
L["Date format"] = "Формат даты"
L["Day only"] = "Только день"
L["Day and month"] = "День и месяц"
L["Day, month and year"] = "День, месяц и год"
L["Date separator"] = "Разделитель даты"
L["Dot (.)"] = "Точка (.)"
L["Colon (:)"] = "Двоеточие (:)"
L["Slash (/)"] = "Слеш (/)"
L["Command bar"] = "Панель команд"
L["Minimap"] = "Мини-карта"
L["About"] = "Об аддоне"
L["A Diablo-style UI modification."] = "UI модификация в стиле Diablo."
L["Version"] = "Версия"
L["Author"] = "Автор"
L["Category"] = "Категория"
L["Interface"] = "Интерфейс"
L["License"] = "Лицензия"
L["Free / open"] = "Свободная"
L["Email"] = "Почта"
L["Client"] = "Клиент"
L["Chat"] = "Чат"
L["Show message timestamp"] = "Показывать время сообщения"
L["Shows the time before each chat message."] = "Показывает время перед каждым сообщением в чате."
L["Timestamp format"] = "Формат времени"
L["Wrap time in brackets"] = "Время в скобках"
L["Wraps the timestamp in square brackets, e.g. [15:55]."] = "Оборачивает время в квадратные скобки, например [15:55]."
L["Timestamp changes apply to new messages."] = "Изменения времени применяются к новым сообщениям."
L["Show chat buttons"] = "Показывать кнопки чата"
L["Shows the up / down / bottom scroll buttons on the chat window."] = "Показывает кнопки прокрутки вверх / вниз / вниз до конца на окне чата."
L["Background darkness"] = "Затемнение фона"
L["Adjust the darkness of the chat background."] = "Регулировка затемнения фона чата."
L["Copy chat"] = "Копировать чат"
L["Enhanced chat"] = "Обновлённый чат"
L["Applies the dark Diablo chat styling, buttons and copy window. Requires a relog to take effect."] = "Применяет тёмное оформление чата в стиле Diablo, кнопки и окно копирования. Требует перезахода."
L["The chat change will take effect after your next relog."] = "Изменение чата вступит в силу после перезахода."
L["Hide friends button"] = "Скрыть кнопку общения"
L["Hides the friends (Social) button above the chat. The one by the input line stays."] = "Скрывает кнопку общения над чатом. Кнопка возле поля ввода остаётся."
L["Original"] = "Оригинал"
L["Time"] = "Время"
L["Server time"] = "Серверное время"
L["Local time"] = "Местное время"
L["Today"] = "Сегодня"
L["Use local time"] = "Местное время"
L["Show your computer's local time instead of the server time."] = "Показывать местное время компьютера вместо серверного."
L["Show artwork"] = "Отображать ArtWork"
L["Shows the decorative angel and demon artwork on the sides of the command bar."] = "Показывает декоративные изображения ангела и демона по бокам панели команд."
L["Show resources"] = "Отображать ресурсы"
L["Always"] = "Всегда"
L["In combat only"] = "Только в бою"
L["Never"] = "Никогда"
