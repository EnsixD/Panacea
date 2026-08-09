function dockeron --wraps='sudo systemctl start docker' --description 'alias dockeron=sudo systemctl start docker'
    sudo systemctl start docker $argv
end
