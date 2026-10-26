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

# Spotify first: Spicetify (Caelestia's Spotify theming) patches files in /opt/spotify,
# which must be writable by you before the component's `spicetify apply` runs.
info "Installing Spotify"
paru -S --needed --noconfirm spotify
sudo chmod a+wr /opt/spotify /opt/spotify/Apps -R

# All default components, plus Zed, Neovim colors, Discord via Equibop and Spotify with
# Spicetify (all themed by Caelestia). VS Code/Codium stay off.
info "Running caelestia install"
caelestia install --aur-helper paru --enable-components zed,nvim,discord,spotify --noconfirm

# ---- apps outside Caelestia ------------------------------------------------------
info "Installing Teams"
paru -S --needed --noconfirm teams-for-linux-bin

# ---- login manager (Caelestia ships none; greetd + tuigreet is what it recommends).
# start-hyprland is Hyprland's watchdog wrapper; launching the bare binary triggers a warning.
info "Configuring greetd (tuigreet → Hyprland)"
sudo pacman -S --needed --noconfirm greetd greetd-tuigreet
sudo tee /etc/greetd/config.toml >/dev/null <<'EOF'
[terminal]
vt = 1

[default_session]
command = "tuigreet --time --remember --asterisks --cmd start-hyprland"
user = "greeter"
EOF
sudo systemctl enable greetd

# ---- color scheme -----------------------------------------------------------------
info "Setting color scheme: $SCHEME $FLAVOUR"
caelestia scheme set -n "$SCHEME" -f "$FLAVOUR" || echo "Set it later from the launcher or: caelestia scheme set -n $SCHEME -f $FLAVOUR"
