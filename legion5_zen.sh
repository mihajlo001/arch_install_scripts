#!/usr/bin/env bash

sgdisk -Z /dev/nvme0n1

sgdisk -n 1:0:+1G -c 1:"boot" -t 1:ef00 /dev/nvme0n1
sgdisk -n 2:0:+16G -c 2:"swap" -t 2:8200 /dev/nvme0n1
sgdisk -n 3:0:+40G -c 3:"root" -t 3:8300 /dev/nvme0n1
sgdisk -N 4 -c 4:"home" -t 4:8300 /dev/nvme0n1

echo "Please enter EFI paritition: (example /dev/sda1 or /dev/nvme0n1p1)"
read EFI
/dev/nvme0n1p1

echo "Please enter SWAP paritition: (example /dev/sda2)"
read SWAP
/dev/nvme0n1p2

echo "Please enter Root(/) paritition: (example /dev/sda3)"
read ROOT
/dev/nvme0n1p3 

echo "Please enter Home paritition: (example /dev/sda4)"
read HOME
/dev/nvme0n1p4 

echo "Please enter root password"
read RPASSWORD

echo "Please enter your username"
read USER 

echo "Please enter your password"
read PASSWORD 



echo "Please choose Your Desktop Environment"
echo "1. GNOME"
echo "2. KDE"
echo "3. XFCE"
echo "4. NoDesktop"
read DESKTOP








# make filesystems
echo -e "\nCreating Filesystems...\n"

mkfs.vfat -F32 -n "EFISYSTEM" "${EFI}"
mkswap "${SWAP}"
swapon "${SWAP}"
mkfs.ext4 -L "ROOT" "${ROOT}"
mkfs.ext4 -L "HOME" "${HOME}"

# mount target
mount -t ext4 "${ROOT}" /mnt
mkdir /mnt/boot
mkdir /mnt/home
mount -t vfat "${EFI}" /mnt/boot/
mount -t ext4 "${HOME}" /mnt/home/

echo "--------------------------------------"
echo "-- INSTALLING Arch Linux BASE on Main Drive       --"
echo "--------------------------------------"
pacstrap /mnt base base-devel --noconfirm --needed

# kernel
pacstrap /mnt linux-zen linux-zen-headers linux-firmware --noconfirm --needed

echo "--------------------------------------"
echo "-- Setup Dependencies               --"
echo "--------------------------------------"

pacstrap /mnt networkmanager nano intel-ucode git --noconfirm --needed

# fstab
genfstab -U /mnt >> /mnt/etc/fstab

echo "--------------------------------------"
echo "-- Bootloader Installation  --"
echo "--------------------------------------"
bootctl install --path /mnt/boot
echo "default arch.conf" >> /mnt/boot/loader/loader.conf

echo "title Arch Zen Linux" >> /mnt/boot/loader/entries/arch.conf
echo "linux /vmlinuz-linux-zen" >> /mnt/boot/loader/entries/arch.conf
echo "initrd /intel-ucode.img" >> /mnt/boot/loader/entries/arch.conf
echo "initrd /initramfs-linux-zen.img" >> /mnt/boot/loader/entries/arch.conf

echo "options root=PARTUUID=$(blkid -s PARTUUID -o value $ROOT) rw" >> /mnt/boot/loader/entries/arch.conf


cat <<REALEND > /mnt/next.sh
echo root:$RPASSWORD | chpasswd
useradd -m $USER
usermod -aG wheel,storage,power $USER
echo $USER:$PASSWORD | chpasswd
sed -i 's/^# %wheel ALL=(ALL:ALL) NOPASSWD: ALL/%wheel ALL=(ALL:ALL) NOPASSWD: ALL/' /etc/sudoers

echo "-------------------------------------------------"
echo "Setup Language to US and set locale"
echo "-------------------------------------------------"
sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" >> /etc/locale.conf

ln -sf /usr/share/zoneinfo/Europe/Belgrade /etc/localtime
hwclock --systohc

echo "galvatron" > /etc/hostname
cat <<EOF > /etc/hosts
127.0.0.1	localhost
::1			localhost
127.0.1.1	galvatron
EOF

echo "-------------------------------------------------"
echo "Enabling multilib"
echo "-------------------------------------------------"
sed -i "/\[multilib\]/,/Include/"'s/^#//' /etc/pacman.conf

pacman -Sy

echo "-------------------------------------------------"
echo "Display and Audio Drivers"
echo "-------------------------------------------------"

pacman -S xorg-server nvidia-dkms nvidia-utils lib32-nvidia-utils nvidia-settings nvidia-prime mesa lib32-mesa vulkan-intel lib32-vulkan-intel --noconfirm --needed
# intel-media-driver

systemctl enable NetworkManager

#DESKTOP ENVIRONMENT
if [[ $DESKTOP == '1' ]]
then 
    pacman -S gnome gdm --noconfirm --needed
    systemctl enable gdm
elif [[ $DESKTOP == '2' ]]
then
    pacman -S plasma sddm konsole dolphin firefox kate steam vlc qbittorrent libreoffice-still koko p7zip ark ntfs-3g bluez bluez-utils wine-staging lutris --noconfirm --needed
    systemctl enable sddm
elif [[ $DESKTOP == '3' ]]
then
    pacman -S xfce4 xfce4-goodies lightdm lightdm-gtk-greeter --noconfirm --needed
    systemctl enable lightdm
else
    echo "You have choosen to Install Desktop Yourself"
fi

echo "-------------------------------------------------"
echo "Install Complete, You can reboot now"
echo "-------------------------------------------------"

REALEND


arch-chroot /mnt sh next.sh
