# Sourced by Caelestia's fish config. Dev toolchain + terminal apps only.
fish_add_path -g ~/.local/bin          # uv tools, Claude Code
mise activate fish | source

abbr -a lg lazygit
abbr -a ld lazydocker
abbr -a zj zellij
abbr -a sp spotify_player

# yazi: `y` opens it and cds to wherever you quit
function y
    set -l tmp (mktemp -t yazi-cwd.XXXXXX)
    yazi $argv --cwd-file="$tmp"
    if set -l cwd (command cat -- "$tmp"); and test -n "$cwd"; and test "$cwd" != "$PWD"
        builtin cd -- "$cwd"
    end
    rm -f -- "$tmp"
end
