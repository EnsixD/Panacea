function tailscale-down --wraps='sudo tailscale down && sudo systemctl stop tailscaled.service' --description 'alias tailscale-down=sudo tailscale down && sudo systemctl stop tailscaled.service'
    sudo tailscale down && sudo systemctl stop tailscaled.service $argv
end
