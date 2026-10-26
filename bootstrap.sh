#!/usr/bin/env bash
# bootstrap.sh — run once after first login (as your user, not root).
#   cd ~/arch-fw13pro && ./bootstrap.sh
# Safe to re-run.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
info() { printf '\n\033[1;34m==>\033[0m \033[1m%s\033[0m\n' "$*"; }

[[ $EUID -ne 0 ]] || { echo "Run as your user, not root."; exit 1; }

info "Hardware support (Framework 13 Pro)"
bash "$ROOT/install/10-framework.sh"

# Link our few files before Caelestia installs, so its installer finds them in place.
# These are only Caelestia's sanctioned override files plus git and mise config.
info "Linking personal config"
sudo pacman -S --needed --noconfirm stow
for f in .config/caelestia/hypr-vars.lua .config/caelestia/hypr-user.lua .config/caelestia/user-config.fish \
         .config/git/config .config/mise/config.toml; do
  if [[ -e $HOME/$f && ! -L $HOME/$f ]]; then mv "$HOME/$f" "$HOME/$f.pre-bootstrap"; fi
done
(cd "$ROOT/dotfiles" && stow --no-folding --restow --target="$HOME" caelestia git mise)

info "Caelestia desktop"
bash "$ROOT/install/20-caelestia.sh"

info "Dev toolchain (mise, Docker, Claude Code)"
bash "$ROOT/install/30-dev.sh"

cat <<'EOF'

Done. Reboot and log in through the greeter.

  Super (tap)       launcher
  Super + T         terminal (foot + fish)
  Super + C         Zed
  Super + W         browser
  Super + Q         close window

Full keybind list: https://github.com/caelestia-dots/caelestia#default-keybinds
EOF
