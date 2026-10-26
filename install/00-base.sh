#!/usr/bin/env bash
# 00-base.sh — run from the Arch live ISO on the Framework Laptop 13 Pro.
# Wipes the target disk and installs a minimal encrypted Arch system:
#   GPT: 1 GiB ESP (/boot) + LUKS2 -> btrfs (@, @home, @snapshots, @var_log, @pkg)
#   systemd-boot + unified kernel images (linux + linux-zen fallback; LTS 6.18 lacks Panther Lake Wi-Fi/audio), zram swap.
#
# Usage (from the live ISO, after connecting to the network):
#   pacman -Sy --noconfirm git
#   git clone https://github.com/vkumar04/arch-fw13pro && cd arch-fw13pro
#   ./install/00-base.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ---- settings (override with env vars) --------------------------------------
DISK="${DISK:-/dev/nvme0n1}"
HOSTNAME_="${HOSTNAME_:-fw13pro}"
USERNAME="${USERNAME:-vick}"
TIMEZONE="${TIMEZONE:-America/New_York}"
LOCALE="${LOCALE:-en_US.UTF-8}"
KEYMAP="${KEYMAP:-us}"

info() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31m!!\033[0m %s\n' "$*" >&2; exit 1; }

# ---- preflight --------------------------------------------------------------
[[ $EUID -eq 0 ]] || die "Run as root from the live ISO."
[[ -d /sys/firmware/efi/efivars ]] || die "Not booted in UEFI mode."
[[ -b $DISK ]] || die "Disk $DISK not found. Set DISK=/dev/… and retry."
ping -c1 -W3 archlinux.org >/dev/null 2>&1 || die "No network. Use: iwctl station wlan0 connect <SSID>"

lsblk "$DISK"
echo
echo "This will ERASE EVERYTHING on $DISK."
read -rp "Type the disk path again to confirm: " confirm
[[ $confirm == "$DISK" ]] || die "Confirmation did not match. Aborting."

read -rsp "Disk encryption passphrase: " LUKS_PASS; echo
read -rsp "Confirm passphrase: " LUKS_PASS2; echo
[[ $LUKS_PASS == "$LUKS_PASS2" && -n $LUKS_PASS ]] || die "Passphrases empty or don't match."

read -rsp "Password for user $USERNAME: " USER_PASS; echo
read -rsp "Confirm password: " USER_PASS2; echo
[[ $USER_PASS == "$USER_PASS2" && -n $USER_PASS ]] || die "Passwords empty or don't match."

timedatectl set-ntp true

# ---- partition --------------------------------------------------------------
# nvme partitions use a "p" separator (nvme0n1p1); sata/virtio don't (sda1)
if [[ $DISK =~ [0-9]$ ]]; then PART="${DISK}p"; else PART="$DISK"; fi
ESP="${PART}1"
CRYPT="${PART}2"

info "Partitioning $DISK"
wipefs --all --force "$DISK"
sgdisk --zap-all "$DISK"
sgdisk -n1:0:+1G -t1:ef00 -c1:EFI   "$DISK"
sgdisk -n2:0:0   -t2:8309 -c2:LUKS  "$DISK"
partprobe "$DISK"; sleep 2

# ---- encryption -------------------------------------------------------------
info "Setting up LUKS2 on $CRYPT"
printf '%s' "$LUKS_PASS" | cryptsetup luksFormat --type luks2 --batch-mode --key-file - "$CRYPT"
printf '%s' "$LUKS_PASS" | cryptsetup open --allow-discards --persistent --key-file - "$CRYPT" cryptroot
unset LUKS_PASS LUKS_PASS2

# ---- filesystems ------------------------------------------------------------
info "Creating filesystems"
mkfs.fat -F32 -n EFI "$ESP"
mkfs.btrfs -f -L arch /dev/mapper/cryptroot

mount /dev/mapper/cryptroot /mnt
for sv in @ @home @snapshots @var_log @pkg; do btrfs subvolume create "/mnt/$sv"; done
umount /mnt

OPTS="noatime,compress=zstd:1,space_cache=v2"
mount -o "$OPTS,subvol=@" /dev/mapper/cryptroot /mnt
mkdir -p /mnt/{boot,home,.snapshots,var/log,var/cache/pacman/pkg}
mount -o "$OPTS,subvol=@home"      /dev/mapper/cryptroot /mnt/home
mount -o "$OPTS,subvol=@snapshots" /dev/mapper/cryptroot /mnt/.snapshots
mount -o "$OPTS,subvol=@var_log"   /dev/mapper/cryptroot /mnt/var/log
mount -o "$OPTS,subvol=@pkg"       /dev/mapper/cryptroot /mnt/var/cache/pacman/pkg
mount -o fmask=0077,dmask=0077 "$ESP" /mnt/boot

# ---- base packages ----------------------------------------------------------
info "Ranking mirrors"
reflector --country US --protocol https --latest 20 --sort rate --save /etc/pacman.d/mirrorlist || true

info "Installing base system"
pacstrap -K /mnt \
  base base-devel linux linux-zen linux-firmware sof-firmware intel-ucode \
  btrfs-progs cryptsetup dosfstools \
  networkmanager iwd openssh reflector \
  zram-generator snapper snap-pac \
  sudo bash-completion git neovim man-db man-pages less curl wget rsync stow

genfstab -U /mnt >> /mnt/etc/fstab

# ---- configure inside chroot ------------------------------------------------
LUKS_UUID="$(blkid -s UUID -o value "$CRYPT")"
cp "$SCRIPT_DIR/01-chroot.sh" /mnt/root/01-chroot.sh
arch-chroot /mnt env \
  HOSTNAME_="$HOSTNAME_" USERNAME="$USERNAME" TIMEZONE="$TIMEZONE" \
  LOCALE="$LOCALE" KEYMAP="$KEYMAP" LUKS_UUID="$LUKS_UUID" USER_PASS="$USER_PASS" \
  bash /root/01-chroot.sh
unset USER_PASS USER_PASS2
rm -f /mnt/root/01-chroot.sh

# copy this repo into the new user's home so bootstrap can run after first boot
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
cp -r "$REPO_ROOT" "/mnt/home/$USERNAME/arch-fw13pro"
arch-chroot /mnt chown -R "$USERNAME:$USERNAME" "/home/$USERNAME/arch-fw13pro"

info "Done. Next: umount -R /mnt && reboot"
info "After logging in as $USERNAME: cd ~/arch-fw13pro && ./bootstrap.sh"
