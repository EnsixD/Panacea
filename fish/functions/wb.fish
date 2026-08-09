function wb --wraps='pkill waybar; begin; waybar >/dev/null 2>&1 &; end; disown' --description 'alias wb=pkill waybar; begin; waybar >/dev/null 2>&1 &; end; disown'
    pkill waybar; begin; waybar >/dev/null 2>&1 &; end; disown $argv
end
