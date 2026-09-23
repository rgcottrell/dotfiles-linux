source /usr/share/cachyos-fish-config/cachyos-config.fish

# Disable the CachyOS fastfetch startup banner.
function fish_greeting
end

set -gx SSH_AUTH_SOCK $XDG_RUNTIME_DIR/ssh-agent.socket
