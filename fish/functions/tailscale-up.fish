function tailscale-up --wraps='sudo systemctl start tailscaled.service && sudo tailscale up' --description 'alias tailscale-up=sudo systemctl start tailscaled.service && sudo tailscale up'
    sudo systemctl start tailscaled.service && sudo tailscale up $argv
end
