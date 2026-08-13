if status is-interactive
    # Commands to run in interactive sessions can go here
end

set -gx BROWSER firefox


# opencode and local bin
fish_add_path $HOME/.opencode/bin
fish_add_path $HOME/.local/bin

set -g fish_greeting ""

# eza вместо ls: цвета, иконки, дерево. Флаги подобраны под остров —
# без рамок, группировка папок сверху.
#
# -a везде: в домашнем каталоге почти всё интересное начинается с точки —
# .config, .local, .ssh. Прятать их по умолчанию значит прятать ровно то,
# ради чего в этот каталог и заходят. Точку и две точки (-a, а не -A) не
# показываем: они не файлы, а навигация, и только зашумляют список.
if type -q eza
    alias ls   'eza --icons --group-directories-first -a'
    alias ll   'eza --icons --group-directories-first -la --git'
    alias la   'eza --icons --group-directories-first -la --git'
    alias lt   'eza --icons --group-directories-first --tree --level=2 -a'
    # если понадобится список без скрытых — вот он
    alias lv   'eza --icons --group-directories-first'
end

# zoxide подменяет cd: он помнит, куда вы ходили, и прыгает по обрывку пути.
# init отдаёт функцию cd, поэтому обычный cd продолжает работать как раньше.
if type -q zoxide
    zoxide init --cmd cd fish | source
end

# bat вместо cat: подсветка синтаксиса и номера строк. --paging=never, чтобы
# в скриптах и пайпах вёл себя как обычный cat.
if type -q bat
    alias cat 'bat --paging=never'
    set -gx BAT_THEME ansi
end

# Строка приглашения живёт в functions/fish_prompt.fish.
# Определение здесь перекрывало файл, и правки в него не действовали.



# Обновление системы и установка пакетов целыми словами. abbr разворачивается
# в команду прямо в строке — видно, что именно сейчас уйдёт под sudo, и это
# важнее экономии на нажатиях, когда речь о -Syu.
abbr -a upd 'sudo pacman -Syu'
abbr -a ins 'sudo pacman -S'

# Pacman base
abbr -a i 'sudo pacman -S'       # Installa
abbr -a syu 'sudo pacman -Syu'     # Aggiorna sistema
abbr -a r 'sudo pacman -Rns'      # Rimuove con dipendenze inutilizzate
abbr -a pacc 'pacman -Ss'           # Cerca nei repo
abbr -a pace 'pacman -Qe'         # Elenca pacchetti installati esplicitamente

# Se usi un AUR helper (es. yay o paru)
abbr -a y 'yay'                     # Scorciatoia universale per AUR
abbr -a yi 'yay -S'
abbr -a ysyu 'yay -Syu'

# Git
abbr -a gs 'git status'
abbr -a ga 'git add'
abbr -a gc 'git commit -m'
abbr -a gp 'git push'

# Очистить экран одной буквой. Именно alias, а не abbr: abbr разворачивается
# в строку и требует Enter дважды на то, что должно срабатывать мгновенно.
alias c clear

# fastfetch намеренно не зовётся при запуске терминала: он нужен, когда его
# спрашивают, а не каждым новым окном. Настройки его лежат в
# ~/.config/fastfetch/config.jsonc и подхватываются обычным вызовом `fastfetch`.
# Короткая форма, чтобы не набирать имя целиком:
abbr -a ff 'fastfetch'


# Added by Antigravity CLI installer
set -gx PATH "/home/ensi/.local/bin" $PATH
