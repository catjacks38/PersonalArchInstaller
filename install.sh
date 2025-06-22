#!/bin/bash

# Gets initial settings from user
read -rp "What disk is being installed to? " DISK
read -rp "Hostname? " HOSTNAME
read -rp "Non-root username? " NONROOT_USER
read -rp "Password for $NONROOT_USER? " NONROOT_PASSWD
read -rp "Password for root? " ROOT_PASSWD
read -rp "Additional packages to install (seperated by spaces)? " ADDITIONAL_PACKAGES


# TODO: Implement method for installing nvidia drivers (and blacklisting nouveau onces)
# Add pacman hook
# Remove kms module from HOOKS /etc/mkinitcpio.conf
# TL;DR read Arch wiki on how to do this properly
# Resources:
# https://www.reddit.com/r/archlinux/comments/187iw3h/enabling_nvidia_drm/


# Partitions the disk
wipefs --all --force $DISK
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

# Copies user files over
cp -r config /mnt/home/temp_config
cp zshrc /mnt/home/.zshrc
cp start_hyprland /mnt/bin/start_hyprland

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

# Enables sudoers to use sudo WITHOUT a password (this is temporary and will be changed when the installer has completed)
sed -i 's/# %wheel ALL=(ALL:ALL) NOPASSWD: ALL/%wheel ALL=(ALL:ALL) NOPASSWD: ALL/g' /etc/sudoers

grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=$HOSTNAME
grub-mkconfig -o /boot/grub/grub.cfg

# Move dotfiles
mv /home/temp_config /home/$NONROOT_USER/.config
chown -R catjacks38:catjacks38 /home/$NONROOT_USER/.config

# Enable systemd services
systemctl enable dhcpcd
systemctl enable iwd
systemctl enable grub-btrfsd

# Enable multilib
# [CURRENTLY BORKED]
# sed -i 's/#[multilib]/[multilib]/g' /etc/pacman.conf
# sed -i 's/#Include = \/etc\/pacman.d\/mirrorlist/Include = \/etc\/pacman.d\/mirrorlist/g' /etc/pacman.conf

# TODO: Fully implement the nonroot user configuration
echo "
git clone https://aur.archlinux.org/yay.git
cd yay
makepkg -si --noconfirm
cd ..
rm -rf yay
yay -S --noconfirm timeshift-autosnap satisfactory-mod-manager
sh -c '$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)'
git clone --depth=1 https://github.com/romkatv/powerlevel10k.git '${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k'
" | su $NONROOT_USER

# Changes shell for NONROOT_USER
chsh -s /usr/bin/zsh $NONROOT_USER

# Requires sudoers to use a password when running sudo
sed -i 's/%wheel ALL=(ALL:ALL) NOPASSWD: ALL/# %wheel ALL=(ALL:ALL) NOPASSWD: ALL/g' /etc/sudoers
sed -i 's/# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/g' /etc/sudoers
" | arch-chroot /mnt
echo Installation Complete
