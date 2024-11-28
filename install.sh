
# Formatting partitions
mkfs.btrfs $ROOT
mkfs.fat -F 32 $BOOT
mkfs.swap $SWAP


# Mounting and installing base system
mount $ROOT /mnt
mkdir /mnt/boot
mount $BOOT /mnt/boot
pacstrap -K /mnt base base-devel linux linux-firmware

