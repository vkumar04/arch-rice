# arch-fw13pro

Clean Arch Linux install for the **Framework Laptop 13 Pro** (Intel Core Ultra Series 3), set up as a dev machine running a **pure [Caelestia](https://github.com/caelestia-dots/caelestia)** desktop.

- **Disk:** LUKS2 full-disk encryption → btrfs (`@`, `@home`, `@snapshots`, `@var_log`, `@pkg`), zram swap, snapper + snap-pac (automatic snapshot before/after every pacman transaction)
- **Boot:** systemd-boot + unified kernel images, `linux` with `linux-lts` fallback
- **Desktop:** stock Caelestia (Hyprland + Caelestia shell), installed with `caelestia install`. Nothing in `~/.config/hypr` is modified. Color scheme: **Catppuccin Mocha**
- **Dev:** every runtime via **mise** (Node LTS, pnpm, bun, Erlang, Elixir, Python, uv), Docker, lazygit, lazydocker, Tailscale, Mullvad VPN, Zed, Claude Code

## Install

1. **BIOS** (F2 at boot): Administer Secure Boot → Enforce Secure Boot → **Disabled**. (Re-enable later with `sbctl`.)
2. Flash the Arch ISO to a USB stick, boot it (F12 for the boot menu).
3. Connect to Wi‑Fi and run the base installer:
   ```sh
   iwctl station wlan0 connect "<SSID>"
   pacman -Sy --noconfirm git
   git clone https://github.com/vkumar04/arch-fw13pro && cd arch-fw13pro
   ./install/00-base.sh          # wipes /dev/nvme0n1 — asks you to type it to confirm
   umount -R /mnt && reboot
   ```
   Override defaults with env vars: `DISK=… USERNAME=… HOSTNAME_=… TIMEZONE=… ./install/00-base.sh`
4. Unlock the disk at boot, log in on the console, then:
   ```sh
   cd ~/arch-fw13pro && ./bootstrap.sh
   ```
   Runs `10-framework` → links config → `20-caelestia` → `30-dev`. Erlang compiles from source the first time (~10 min). Reboot when it's done.
5. After first login: `gh auth login` (pick SSH), `claude` to sign in, `sudo fwupdmgr update` for firmware.
6. Tailscale: bootstrap prints a login URL. Then `ssh you@<mac-name>` works from anywhere (turn on **Remote Login** in the Mac's System Settings → General → Sharing, or enable Tailscale SSH on the Mac).

## What this repo changes vs. stock Caelestia

Only Caelestia's own override files, which its installer and `caelestia update` never touch:

| File | Change |
|---|---|
| `~/.config/caelestia/hypr-user.lua` | Laptop display at scale 1.6 (Caelestia defaults to 1, too small on this panel) |
| `~/.config/caelestia/hypr-vars.lua` | Editor = Zed (`zeditor`) |
| `~/.config/caelestia/user-config.fish` | `mise activate fish`, `lg`/`ld` abbreviations |

Plus: Zed component enabled, scheme set to Catppuccin Mocha, greetd + tuigreet as the login manager (Caelestia ships none and recommends this one).

## Using it

- Keybinds: [Caelestia's list](https://github.com/caelestia-dots/caelestia#default-keybinds). Tap `Super` for the launcher; `Super+T` terminal, `Super+C` Zed, `Super+W` browser, `Super+Q` close.
- Change scheme: launcher, or `caelestia scheme set -n <name> -f <flavour>` (`caelestia scheme list -n`)
- Update everything: `caelestia update`
- Pin runtimes per project: `mise use node@22 pnpm@9` · global defaults in `~/.config/mise/config.toml`

## VPNs

Tailscale and Mullvad are both installed, but **Mullvad's firewall blocks tailnet traffic while it's connected**, so `ssh <mac>` fails until you `mullvad disconnect`. If you want both at once, the clean fix is Tailscale's Mullvad add-on (Mullvad exit nodes inside Tailscale) instead of the Mullvad app.

## Layout

```
install/00-base.sh       live ISO: partition, encrypt, btrfs, pacstrap, bootloader
install/01-chroot.sh     called by 00: locale, UKIs, systemd-boot, snapper, user
install/10-framework.sh  power-profiles-daemon, fwupd, fprintd (sudo + lock), Intel media, inotify limits
install/20-caelestia.sh  paru, caelestia-cli, `caelestia install`, greetd, scheme
install/30-dev.sh        CLI tools, Docker, lazygit/lazydocker, Tailscale, Mullvad, mise runtimes, Claude Code
bootstrap.sh             10 → stow → 20 → 30
dotfiles/                stow packages: caelestia (override files only), git, mise
```

## Recovery

- Every `pacman`/`paru` run makes a snapper pre/post pair: `sudo snapper list`, `sudo snapper undochange <pre>..<post>`.
- If `linux` won't boot, pick **arch-linux-lts** in the systemd-boot menu (hold Space at power-on).
