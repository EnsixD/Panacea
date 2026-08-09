function dockeroff --wraps='sudo systemctl stop docker docker.socket containerd' --description 'alias dockeroff=sudo systemctl stop docker docker.socket containerd'
    sudo systemctl stop docker docker.socket containerd $argv
end
