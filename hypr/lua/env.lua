-- Время в 24 часах, язык при этом остаётся английским.
--
-- Формат часов приложения берут из LC_TIME, а не из своих настроек: en_US
-- означает «12 часов и AM/PM», и Telegram, календари и всё остальное
-- показывали 12:02 AM вместо 00:02. Отдельная переменная, а не смена LANG:
-- меняем ровно формат времени, не трогая язык интерфейса.
hl.env("LC_TIME", "en_GB.UTF-8")

-- Курсор: Bibata Modern Classic — чёрный, без обводки и теней, ровно под
-- тёмную оболочку. Имя темы нужно и в переменных (их читают Xwayland и
-- программы на GTK/Qt), и в самом Hyprland — он рисует курсор сам.
hl.env("XCURSOR_THEME", "Bibata-Modern-Classic")
hl.env("HYPRCURSOR_THEME", "Bibata-Modern-Classic")
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")
hl.env("GDK_SCALE", "1")
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")
