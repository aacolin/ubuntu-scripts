#!/bin/bash

sudo umount -a                  # Unmount all mounted partitions
sudo mount /dev/sda3 /mnt       # Mount the root partition
mkdir -p /mnt/.snapshots
sudo cp -vF /etc/resolv.conf /mnt/etc/resolv.conf   # Copy the resolv.conf file to the new system
sudo btrfs su snapshot /mnt /mnt/@          # Create a snapshot of the root subvolume
sudo rm -rv /mnt/{bin,bin*,boot,cdrom,etc,home,lib,lib*,media,mnt,opt,root,run,sbin,sbin*,snap,srv,sys,tmp,usr,var}
sudo btrfs su create /mnt/@{home,cache,log,tmp,snapshots}   # Create subvolumes for home, cache, log, tmp, and snapshots
sudo cp -av /mnt/@/var/cache/* /mnt/@cache 
rm -frv /mnt/@/var/cache/* || echo "No cache directory"    # Copy the cache directory to the cache subvolume
sudo cp -av /mnt/@/var/log/* /mnt/@log
rm -frv /mnt/@/var/log/* || echo "No log directory"    # Copy the log directory to the log subvolume
sudo umount /mnt                                            # Unmount the root partition
sudo mount -o subvol=@ /dev/sda3 /mnt                       # Mount the root subvolume
sudo mount -o subvol=@home /dev/sda3 /mnt/home              # Mount the home subvolume
sudo mount -o subvol=@cache /dev/sda3 /mnt/var/cache        # Mount the cache subvolume
sudo mount -o subvol=@log /dev/sda3 /mnt/var/log            # Mount the log subvolume
sudo mount -o subvol=@tmp /dev/sda3 /mnt/var/tmp            # Mount the tmp subvolume
sudo mount -o subvol=@snapshots /dev/sda3 /mnt/.snapshots   # Mount the snapshots subvolume
sudo mount /dev/sda1 /mnt/boot/efi
for d in dev proc sys run; do sudo mount --rbind /$d /mnt/$d; done   # Mount the necessary directories
sudo chroot /mnt /bin/bash                                  # Change the root to the new system
sudo grub-mkconfig -o /boot/efi/EFI/ubuntu/grub.cfg
sudo update-grub
echo '#!/bin/bash

function subvol () {
	for su in $(btrfs su list / | grep 'level 5' | awk '{print $9}'); do

	    if test "$su" = "@" ; then mountAt="/" ; fi
	    if test "$su" = "@home" ; then mountAt="/home" ; fi
	    if test "$su" = "@log" ; then mountAt="/var/log" ; fi
	    if test "$su" = "@tmp" ; then mountAt="/tmp" ; fi
	    if test "$su" = "@cache" ; then mountAt="/var/cache" ; fi
	    if test "$su" = "@snapshots" ; then mountAt="/.snapshots" ; fi

	    echo "${getRootFS} $mountAt btrfs ${btrfsOptions},subvol=${su} 0 0"
	done
}

btrfsOptions="ssd,noatime,space_cache=v2,compress=lzo"

getBootFS="$(cat /etc/fstab | grep "vfat" | awk '{print $1}')"
getBootFS="$(cat /etc/fstab | grep "btrfs" | awk '{print $1}')"
getSwapFS="$(cat /etc/fstab | grep "swap" | awk '{print $1}')"

cat <<EOF > /etc/fstab
# /etc/fstab: static file system information.
#
# <file system> <mount point>   <type>  <options>       <dump>  <pass>

# EFI boot partition
${getBootFS} /boot/efi vfat defaults 0 1

# Mount btrfs subvolumes
$(subvol)

# Swap
${getSwapFS} none swap defaults 0 0
EOF

exit 0' > /usr/local/bin/gen-fstab 
cp -v /etc/fstab /etc/fstab.bak     # Backup the fstab file
chmod +x /usr/local/bin/gen-fstab ; gen-fstab       # Generate the new fstab file
echo "System is ready for reboot."
