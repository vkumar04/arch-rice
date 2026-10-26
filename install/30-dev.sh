#!/usr/bin/env bash
# 30-dev.sh — dev toolchain. Every language runtime comes from mise
# (dotfiles/mise/.config/mise/config.toml): Node LTS, pnpm, bun, Erlang, Elixir,
# Python, uv. Plus Docker, CLI tools and Claude Code. (fish, starship, eza,
# zoxide, btop and Zed come from Caelestia.)
set -euo pipefail
info() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }

info "Installing CLI + dev packages"
sudo pacman -S --needed --noconfirm \
  github-cli git-delta lazygit \
  ripgrep fd fzf bat jq yq tree unzip p7zip \
  mise \
  ncurses openssl libxslt inotify-tools \
  docker docker-compose docker-buildx lazydocker \
  zellij \
  pgcli \
  tailscale openssh

# ---- Docker -----------------------------------------------------------------
sudo systemctl enable --now docker
sudo usermod -aG docker "$USER"

# ---- Tailscale (reach the Mac and other machines by name) ----------------------
sudo systemctl enable --now tailscaled
# --operator lets you run `tailscale` without sudo; --ssh lets your other devices SSH in here
if ! tailscale status >/dev/null 2>&1; then
  info "Tailscale: open the printed URL to log in"
  sudo tailscale up --operator="$USER" --ssh
fi

# ---- approved extras (AUR fallback via paru) ----------------------------------
paru -S --needed --noconfirm lazysql spotify-player

# ---- Mullvad VPN (AUR: daemon + `mullvad` CLI + GUI) ---------------------------
# Note: while Mullvad is connected its firewall blocks the tailnet, so `ssh <mac>`
# over Tailscale won't work until you disconnect. See README › VPNs.
paru -S --needed --noconfirm mullvad-vpn-bin
sudo systemctl enable --now mullvad-daemon
mullvad auto-connect set off >/dev/null 2>&1 || true
echo "Mullvad: run 'mullvad account login <number>' then 'mullvad connect'."

# ---- runtimes via mise -------------------------------------------------------
info "Installing runtimes with mise (Erlang compiles from source — grab a coffee)"
eval "$(mise activate bash)"
mise trust --all >/dev/null 2>&1 || true
mise install
mise reshim

info "Elixir: Hex, Rebar, Phoenix generator"
mise exec -- mix local.hex --force
mise exec -- mix local.rebar --force
mise exec -- mix archive.install hex phx_new --force

# ---- Claude Code ------------------------------------------------------------
if ! command -v claude >/dev/null; then
  info "Installing Claude Code"
  curl -fsSL https://claude.ai/install.sh | bash
fi

# ---- git + SSH ----------------------------------------------------------------
if ! git config --global user.email >/dev/null; then
  read -rp "Git email: " email
  git config --global user.email "$email"
fi
if [[ ! -f ~/.ssh/id_ed25519 ]]; then
  info "Generating SSH key"
  ssh-keygen -t ed25519 -C "$USER@$(hostnamectl hostname)" -f ~/.ssh/id_ed25519 -N ""
fi
mkdir -p ~/code

echo "Next: 'gh auth login' (choose SSH), then 'claude' to sign in."
echo "Log out and back in for docker group membership to apply."
