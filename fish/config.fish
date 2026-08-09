if status is-interactive
    # Commands to run in interactive sessions can go here
end

set -gx BROWSER firefox


# opencode and local bin
fish_add_path $HOME/.opencode/bin
fish_add_path $HOME/.local/bin

set -g fish_greeting ""

# Строка приглашения живёт в functions/fish_prompt.fish.
# Определение здесь перекрывало файл, и правки в него не действовали.



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


# Added by Antigravity CLI installer
set -gx PATH "/home/ensi/.local/bin" $PATH
