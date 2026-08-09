function fish_prompt --description 'Однострочная строка в стиле пилюли'
    # Что осталось от предыдущей команды — ловим до любых вызовов
    set -l last_status $status

    # Акцент приезжает из conf.d/theme_colors.fish, который пишет switch_theme.sh
    set -l accent normal
    if set -q fish_color_command
        set accent (string replace -r '\s.*' '' -- $fish_color_command)
    end
    test -n "$accent"; or set accent normal

    # Каталог без тильды: домашний показываем словом, иначе последние
    # две части пути — так строка остаётся короткой и без служебных знаков
    set -l cwd (string replace -r '^~/?' '' -- (prompt_pwd -d 2))
    test -n "$cwd"; or set cwd home

    set_color 4a4a4a
    echo -n '▍'
    set_color $accent --bold
    echo -n $cwd
    set_color normal

    # Ветка git — только имя и звёздочка, если есть незакоммиченное
    set -l branch (command git symbolic-ref --short HEAD 2>/dev/null; or command git rev-parse --short HEAD 2>/dev/null)
    if test -n "$branch"
        set_color 6a6a6a
        echo -n '  '(string sub -l 24 -- $branch)
        command git diff-index --quiet HEAD -- 2>/dev/null; or echo -n '*'
        set_color normal
    end

    # Фоновые задачи
    set -l running (count (jobs -p))
    if test $running -gt 0
        set_color 6a6a6a
        echo -n "  ⏵$running"
        set_color normal
    end

    # Разделитель: краснеет, если прошлая команда упала
    if test $last_status -ne 0
        set_color ff5555
        echo -n '  ⟢ '
    else
        set_color $accent
        echo -n '  ⟢ '
    end
    set_color normal
end
