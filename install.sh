#!/bin/bash

# Get initial settings from user
read -rp "What disk is being installed to? " DISK
read -rp "Hostname? " HOSTNAME
read -rp "Non-root username? " NONROOT_USER
read -rp "Password for $NONROOT_USER? " NONROOT_PASSWD
read -rp "Password for root? " ROOT_PASSWD
read -rp "Additional packages to install (seperated by spaces)? " ADDITIONAL_PACKAGES

# Partitions the disk
echo "
o
y
n


+300M
ef00
n


+4G
8200
n




w
y
" | gdisk $DISK

# Formats the partitions
BOOT="$((fdisk -l $DISK | grep -o '^/dev/\S*') | awk 'NR==1 {print $0}')"
SWAP="$((fdisk -l $DISK | grep -o '^/dev/\S*') | awk 'NR==2 {print $0}')"
ROOT="$((fdisk -l $DISK | grep -o '^/dev/\S*') | awk 'NR==3 {print $0}')"

mkfs.btrfs -f $ROOT
mkfs.fat -F 32 $BOOT
mkswap $SWAP

# Mounts and installs the base system
mount $ROOT /mnt
mkdir /mnt/boot
mount $BOOT /mnt/boot
swapon $SWAP
pacstrap -K /mnt - < required_pkgs.txt
pacstrap -K /mnt $ADDITIONAL_PACKAGES
genfstab -U /mnt >> /mnt/etc/fstab

# Chroots into the system to finalize the installation
echo "
# Sets the time and locale stuff
ln -sf /usr/share/zoneinfo/US/Eastern /etc/localtime
hwclock --systohc
sed -i 's/#en_US\./en_US\./g' /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

# Sets up the hostname
echo $HOSTNAME > /etc/hostname
echo 127.0.0.1 localhost >> /etc/hosts
echo ::1 localhost >> /etc/hosts
echo 127.0.1.1 $HOSTNAME >> /etc/hosts

# Sets up the users
passwd
$ROOT_PASSWD
$ROOT_PASSWD
useradd -mG wheel $NONROOT_USER
passwd $NONROOT_USER
$NONROOT_PASSWD
$NONROOT_PASSWD
sed -i 's/# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/g' /etc/sudoers
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=$HOSTNAME
grub-mkconfig -o /boot/grub/grub.cfg
" | arch-chroot /mnt
cp -rv config /mnt/home/$NONROOT_USER/.config
echo Installation Complete
