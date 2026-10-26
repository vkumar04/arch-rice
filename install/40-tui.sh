#!/usr/bin/env bash
# 40-tui.sh — terminal-first apps. Installed one at a time through paru (official
# repos first, AUR as fallback) so a single missing package never stops the rest.
set -euo pipefail
info() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!!\033[0m %s\n' "$*"; }

pkgs=(
  # files & navigation
  yazi ffmpegthumbnailer poppler imagemagick chafa 7zip   # yazi + previews (foot shows images via sixel)
  zellij                     # tabs/splits/sessions inside foot
  # git & code
  gh-dash                    # GitHub PRs/issues dashboard (also a `gh` extension)
  # containers & infra
  k9s                        # Kubernetes
  # databases
  lazysql                    # Postgres/MySQL/SQLite
  pgcli litecli              # smarter psql / sqlite3
  # system
  bluetui                    # Bluetooth
  wiremix                    # PipeWire mixer
  powertop                   # battery drain per process — useful on a laptop
  dust duf gdu               # disk usage
  bandwhich trippy           # per-process bandwidth / traceroute
  # reading & reference
  glow                       # render Markdown
  tealdeer                   # tldr pages
  # media
  spotify-player             # Spotify client
)

failed=()
for p in "${pkgs[@]}"; do
  paru -S --needed --noconfirm "$p" >/dev/null 2>&1 || failed+=("$p")
done
[[ ${#failed[@]} -eq 0 ]] || warn "Couldn't install: ${failed[*]} (try: paru -S <name>)"

info "Python TUIs via uv (mise)"
for t in posting harlequin isd-tui; do
  mise exec -- uv tool install --upgrade "$t" >/dev/null 2>&1 || warn "uv tool install $t failed"
done

tldr --update >/dev/null 2>&1 || true
info "TUI apps installed"
