#!/usr/bin/env bash
# 20-caelestia.sh — the stock Caelestia desktop, installed the official way
# (caelestia-cli → `caelestia install`). Nothing in ~/.config/hypr is touched;
# personal changes live only in Caelestia's own override files (see dotfiles/caelestia).
set -euo pipefail
info() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }

SCHEME="${SCHEME:-catppuccin}"
FLAVOUR="${FLAVOUR:-mocha}"

# ---- AUR helper (paru) ------------------------------------------------------
if ! command -v paru >/dev/null; then
  info "Building paru"
  sudo pacman -S --needed --noconfirm base-devel git
  tmp="$(mktemp -d)"
  git clone --depth 1 https://aur.archlinux.org/paru-bin.git "$tmp/paru-bin"
  (cd "$tmp/paru-bin" && makepkg -si --noconfirm)
  rm -rf "$tmp"
fi

# ---- Caelestia ----------------------------------------------------------------
info "Installing caelestia-cli"
paru -S --needed --noconfirm caelestia-cli

# All default components, plus Zed (themed by Caelestia). VS Code/Codium stay off.
info "Running caelestia install"
caelestia install --aur-helper paru --enable-components zed --noconfirm

# ---- login manager (Caelestia ships none; greetd + tuigreet is what it recommends)
info "Configuring greetd (tuigreet → Hyprland)"
sudo pacman -S --needed --noconfirm greetd greetd-tuigreet
sudo tee /etc/greetd/config.toml >/dev/null <<'EOF'
[terminal]
vt = 1

[default_session]
command = "tuigreet --time --remember --asterisks --cmd Hyprland"
user = "greeter"
EOF
sudo systemctl enable greetd

# ---- color scheme -----------------------------------------------------------------
info "Setting color scheme: $SCHEME $FLAVOUR"
caelestia scheme set -n "$SCHEME" -f "$FLAVOUR" || echo "Set it later from the launcher or: caelestia scheme set -n $SCHEME -f $FLAVOUR"
