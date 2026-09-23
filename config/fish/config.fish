source /usr/share/cachyos-fish-config/cachyos-config.fish

# Disable the CachyOS fastfetch startup banner.
function fish_greeting
end

set -gx SSH_AUTH_SOCK $XDG_RUNTIME_DIR/ssh-agent.socket

if status is-interactive; and command -q starship
    # Starship owns prompt spacing instead of CachyOS's Pure event hook.
    functions --erase _pure_prompt_new_line
    starship init fish | source
end
