#!/usr/bin/env bash
# 10-framework.sh — Framework Laptop 13 Pro hardware support (Intel Core Ultra Series 3).
# Only what Caelestia doesn't already cover: power profiles, firmware, fingerprint,
# Intel video decode/encode, the NPU, thermal and low-power daemons, sensors. (Audio, Bluetooth, network come from Caelestia.)
set -euo pipefail
info() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }

info "Installing hardware support packages"
sudo pacman -S --needed --noconfirm \
  power-profiles-daemon upower \
  fwupd \
  fprintd \
  iio-sensor-proxy \
  intel-media-driver vulkan-intel \
  libvpl vpl-gpu-rt \
  intel-npu-driver \
  thermald intel-lpmd \
  brightnessctl

# power-profiles-daemon backs Caelestia's power-profile toggle
sudo systemctl enable --now power-profiles-daemon upower

# Intel laptop tuning (what Omarchy enables on Panther Lake):
#   thermald   — Intel thermal management
#   intel-lpmd — Low Power Mode Daemon: keeps light work on the efficiency cores
# libvpl + vpl-gpu-rt above add Quick Sync hardware video *encoding* on the Arc GPU.
sudo systemctl enable --now thermald intel_lpmd

# NPU (Core Ultra X7): userspace driver for /dev/accel/accel0; the render group grants access
sudo usermod -aG render "$USER"

# Larger inotify limits — needed for Vite/Next/Phoenix file watchers on big repos
echo 'fs.inotify.max_user_watches=524288' | sudo tee /etc/sysctl.d/90-inotify.conf >/dev/null
sudo sysctl --system >/dev/null

info "Checking for firmware updates (fwupdmgr — Framework's recommended path)"
sudo fwupdmgr refresh --force || true
sudo fwupdmgr get-updates || true
echo "Apply any listed updates with: sudo fwupdmgr update"

echo
info "Enroll a fingerprint now? (tap the power button sensor repeatedly)"
read -rp "[y/N] " yn
if [[ ${yn,,} == y ]]; then fprintd-enroll || echo "Enroll failed; retry later: fprintd-enroll"; else echo "Later: fprintd-enroll"; fi
