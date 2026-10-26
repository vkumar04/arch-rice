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
  ripgrep fd fzf bat jq yq tree unzip 7zip \
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
paru -S --needed --noconfirm lazysql

# ---- Mullvad VPN (AUR: daemon + `mullvad` CLI + GUI) ---------------------------
# Note: while Mullvad is connected its firewall blocks the tailnet, so `ssh <mac>`
# over Tailscale won't work until you disconnect. See README › VPNs.
paru -S --needed --noconfirm mullvad-vpn-bin
sudo systemctl enable --now mullvad-daemon
# the daemon needs a moment before its CLI socket answers
for _ in {1..10}; do mullvad auto-connect set off >/dev/null 2>&1 && break; sleep 1; done
echo "Mullvad: run 'mullvad account login <number>' then 'mullvad connect'."

# ---- bash (login shell) gets mise + ~/.local/bin too ----------------------------
# Foot runs fish, but apps launched from the desktop (Zed's env loading, Claude Code's
# tools) use $SHELL, which stays bash.
if ! grep -q 'mise activate bash' ~/.bashrc 2>/dev/null; then
  cat >> ~/.bashrc <<'RC'

# added by arch-fw13pro: dev toolchain for bash (fish is configured by Caelestia)
export PATH="$HOME/.local/bin:$PATH"
command -v mise >/dev/null && eval "$(mise activate bash)"
RC
fi

# ---- runtimes via mise -------------------------------------------------------
info "Installing runtimes with mise (Erlang compiles from source — grab a coffee)"
eval "$(mise activate bash)"
mise install

info "Elixir: Hex, Rebar, Phoenix generator"
mise exec -- mix local.hex --force
mise exec -- mix local.rebar --force
mise exec -- mix archive.install hex phx_new --force

# ---- Claude Code ------------------------------------------------------------
if ! command -v claude >/dev/null; then
  info "Installing Claude Code"
  curl -fsSL https://claude.ai/install.sh | bash
fi

# ---- Delta (Zed Industries' multiplayer agent workspace) -----------------------
# Official Linux tarball + its bundled per-user installer: ~/.local/delta.app,
# CLI at ~/.local/bin/delta, launcher entry and icons. Updates itself from there.
if [[ ! -x ~/.local/delta.app/bin/delta ]]; then
  info "Installing Delta"
  tmp="$(mktemp -d)"
  curl -fsSL https://github.com/zed-industries/delta-nix/releases/latest/download/delta-linux-x86_64.tar.gz \
    | tar xz -C "$tmp"
  bash "$tmp/Delta/install.sh"
  rm -rf "$tmp"
fi

# ---- git + SSH ----------------------------------------------------------------
# email lives in an untracked file (~/.config/git/local) so it never lands in this repo
if ! git config user.email >/dev/null; then
  read -rp "Git email: " email
  git config --file ~/.config/git/local user.email "$email"
fi
if [[ ! -f ~/.ssh/id_ed25519 ]]; then
  info "Generating SSH key"
  ssh-keygen -t ed25519 -C "$USER@$(hostnamectl hostname)" -f ~/.ssh/id_ed25519 -N ""
fi
mkdir -p ~/code

# ---- GitHub CLI login + gh-dash -------------------------------------------------
# gh-dash ships as a gh extension, which needs gh to be signed in first
if gh auth status >/dev/null 2>&1 || gh auth login --git-protocol ssh --web; then
  gh extension install dlvhdr/gh-dash 2>/dev/null || gh extension upgrade gh-dash || true
else
  echo "Skipped GitHub login. Later: gh auth login && gh extension install dlvhdr/gh-dash"
fi

# ---- posting (HTTP API client TUI), installed with uv from mise -------------------
mise exec -- uv tool install --python 3.13 posting || echo "posting failed; later: uv tool install --python 3.13 posting"

echo "Next: run 'claude' to sign in."
echo "Log out and back in for docker group membership to apply."
