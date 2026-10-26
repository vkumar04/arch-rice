#!/usr/bin/env bash
# 01-chroot.sh — invoked by 00-base.sh inside arch-chroot. Don't run directly.
set -euo pipefail
: "${HOSTNAME_:?}" "${USERNAME:?}" "${TIMEZONE:?}" "${LOCALE:?}" "${KEYMAP:?}" "${LUKS_UUID:?}" "${USER_PASS:?}"

# ---- time, locale, host -----------------------------------------------------
ln -sf "/usr/share/zoneinfo/$TIMEZONE" /etc/localtime
hwclock --systohc
sed -i "s/^#\(${LOCALE//./\\.} UTF-8\)/\1/" /etc/locale.gen
locale-gen
echo "LANG=$LOCALE" > /etc/locale.conf
echo "KEYMAP=$KEYMAP" > /etc/vconsole.conf
echo "$HOSTNAME_" > /etc/hostname
cat > /etc/hosts <<EOF
127.0.0.1 localhost
::1       localhost
127.0.1.1 $HOSTNAME_.localdomain $HOSTNAME_
EOF

# ---- pacman niceties --------------------------------------------------------
sed -i 's/^#Color/Color/; s/^#ParallelDownloads.*/ParallelDownloads = 10/' /etc/pacman.conf
grep -q '^ILoveCandy' /etc/pacman.conf || sed -i '/^Color/a ILoveCandy' /etc/pacman.conf
# multilib (Steam, Wine, etc.)
sed -i '/^#\[multilib\]/{N;s/#//g}' /etc/pacman.conf

# ---- initramfs: systemd + sd-encrypt, unified kernel images ------------------
sed -i 's/^HOOKS=.*/HOOKS=(base systemd autodetect microcode modconf kms keyboard sd-vconsole block sd-encrypt filesystems fsck)/' /etc/mkinitcpio.conf
sed -i 's/^MODULES=.*/MODULES=(btrfs)/' /etc/mkinitcpio.conf

mkdir -p /etc/kernel /boot/EFI/Linux
echo "rd.luks.name=$LUKS_UUID=cryptroot rd.luks.options=discard root=/dev/mapper/cryptroot rootflags=subvol=@ rw quiet" > /etc/kernel/cmdline

for k in linux linux-lts; do
  cat > "/etc/mkinitcpio.d/$k.preset" <<EOF
ALL_kver="/boot/vmlinuz-$k"
PRESETS=('default')
default_uki="/boot/EFI/Linux/arch-$k.efi"
EOF
done
rm -f /boot/initramfs-*.img
mkinitcpio -P

# ---- bootloader -------------------------------------------------------------
bootctl install
cat > /boot/loader/loader.conf <<EOF
default arch-linux.efi
timeout 2
console-mode max
editor no
EOF
systemctl enable systemd-boot-update.service

# ---- swap on zram -----------------------------------------------------------
cat > /etc/systemd/zram-generator.conf <<EOF
[zram0]
zram-size = min(ram / 2, 16384)
compression-algorithm = zstd
EOF

# ---- snapper (root snapshots, auto pre/post on pacman via snap-pac) ----------
# snapper wants to create /.snapshots itself; we already mount @snapshots there
umount /.snapshots
rmdir /.snapshots
snapper --no-dbus -c root create-config /
btrfs subvolume delete /.snapshots
mkdir /.snapshots
mount -a
chmod 750 /.snapshots
sed -i 's/^TIMELINE_LIMIT_HOURLY=.*/TIMELINE_LIMIT_HOURLY="5"/;
        s/^TIMELINE_LIMIT_DAILY=.*/TIMELINE_LIMIT_DAILY="7"/;
        s/^TIMELINE_LIMIT_WEEKLY=.*/TIMELINE_LIMIT_WEEKLY="2"/;
        s/^TIMELINE_LIMIT_MONTHLY=.*/TIMELINE_LIMIT_MONTHLY="0"/;
        s/^TIMELINE_LIMIT_YEARLY=.*/TIMELINE_LIMIT_YEARLY="0"/' /etc/snapper/configs/root
systemctl enable snapper-timeline.timer snapper-cleanup.timer

# ---- services ---------------------------------------------------------------
cat > /etc/NetworkManager/conf.d/wifi-backend.conf <<EOF
[device]
wifi.backend=iwd
EOF
systemctl enable NetworkManager fstrim.timer reflector.timer systemd-timesyncd

# ---- user -------------------------------------------------------------------
useradd -m -G wheel -s /bin/bash "$USERNAME"
printf '%s:%s\n' "$USERNAME" "$USER_PASS" | chpasswd
passwd -l root
echo '%wheel ALL=(ALL:ALL) ALL' > /etc/sudoers.d/10-wheel
chmod 440 /etc/sudoers.d/10-wheel
