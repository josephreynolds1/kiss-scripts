#!/bin/sh -e

scriptversion="1.1"

### Set version variables

kisschrootversion="1.11.0"
kissversion="1.1"

### Set download variables

kisschrooturl="https://github.com/kisslinux/repo/releases/download/$kisschrootversion"
urlkisschrootscript="https://raw.githubusercontent.com/kisslinux/kiss/master/contrib/"
urlinstallscripts="http://10.1.1.21/misc/kiss/$kissversion"
urlinstallfiles="http://10.1.1.21/misc/kiss/$kissversion/files"


### Update time/date

ntpdate 0.pool.ntp.org


### Download Kiss chroot filesystem

wget "$kisschrooturl/kiss-chroot.tar.xz"
wget "$kisschrooturl/kiss-chroot.tar.xz.sha256"


### Download/Configure encryption keys

sha256sum -c < kiss-chroot.tar.xz.sha256
wget "$kisschrooturl/kiss-chroot.tar.xz.asc"

gpg --keyserver keys.gnupg.net --recv-key 46D62DD9F1DE636E
gpg --verify kiss-chroot.tar.xz.asc kiss-chroot.tar.xz


### Download Kiss chroot script

wget "$urlkisschrootscript/kiss-chroot"


### Make kiss-chroot script executable

chmod +x kiss-chroot


### Create Partitions

wget "$urlinstallfiles/sda.sfdisk"

sfdisk /dev/sda1 < sda.sdfdisk


### Format partitions

mkfs.fat -F32 /dev/sda1
mkswap /dev/sda2
mkfs.xfs /dev/sda3


### Enable swap space

swapon /dev/sda2


### Mount root partition to /mnt/kiss

mkdir /mnt/kiss
mount /dev/sda3 /mnt/kiss


### Extract root filesystem and chroot into /mnt/kiss

tar xvf kiss-chroot.tar.xz -C /mnt/kiss --strip-components 1

wget -P /mnt/kiss/tmp $urlinstallscripts/phase2.sh
wget -P /mnt/kiss/tmp $urlinstallscripts/phase3.sh
wget -P /mnt/kiss/tmp $urlinstallscripts/phase4.sh

./kiss-chroot /mnt/kiss

