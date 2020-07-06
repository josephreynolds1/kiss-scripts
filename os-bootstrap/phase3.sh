#!/bin/sh -e

scriptversion="1.1"

### Virtual Machine check

Make=$(cat /sys/class/dmi/id/sys_vendor 2> /dev/null) 

if [ "$Make" = "QEMU" ]

then

   echo "Machine is a VM - $Make"

   IsVM="true"

elif [ "$Make" = "VMware" ]

then

   echo "Machine is a VM - $Make"

   IsVM="true"

else

   echo "Machine is not a VM - $Make"

   IsVM="false"

fi


### Set compile flags

export CFLAGS="-O3 -pipe -march=native"
export CXXFLAGS="-O3 -pipe -march=native"
export MAKEFLAGS="-j4"


### Set version variables

kissversion="1.1"
#kernelversion="5.7.1"
firmwareversion="20200421"


### Get latest kernel.org stable version

kernelversion=$(wget --output-document - https://www.kernel.org/ | grep -A 1 "latest_link")

kernelversion=${kernelversion##*.tar.xz\">}

kernelversion=${kernelversion%</a>}

echo "Stable kernel version from Kernel.org: $latestkernel"


### Set download variables

urlkernel="https://cdn.kernel.org/pub/linux/kernel/v5.x/linux-${kernelversion}.tar.xz"
urlfirmware="https://git.kernel.org/pub/scm/linux/kernel/git/firmware/linux-firmware.git/snapshot/linux-firmware-${firmwareversion}.tar.gz"
urlinstallfiles="http://10.1.1.21/misc/kiss/${kissversion}/files"


### Create root kernel source directory

mkdir /usr/src/kernel

cd /usr/src/kernel


### Download kernel

wget $urlkernel


### Extract and remove downloaded kernel archive

tar xvf linux-${kernelversion}.tar.xz --directory /usr/src/kernel/

rm -rf linux-${kernelversion}.tar.xz


### Create firmware directories

if [ "$IsVM" != "true" ]

then

    mkdir /usr/src/firmware
    mkdir -p /usr/lib/firmware

    cd /usr/src/firmware


    ### Download firmware archive

    wget $urlfirmware


    ### Extract and remove downloaded firmware archive

    tar xvf linux-firmware-${firmwareversion}.tar.gz --directory /usr/src/firmware/

    rm -rf linux-firmware-${firmwareversion}.tar.gz


    #cp -R ./path/to/driver /usr/lib/firmware

fi


### Change to kernel source directory

cd /usr/src/kernel/linux-${kernelversion}


### Download kernel GCC 10 fix patch

#wget "$urlinstallfiles/patch1.patch"


### Download kernel config template

wget $urlinstallfiles/config -O .config


### Copy kernel config to kernel source directory

cp .config /usr/src/kernel/config


### Prepare config file

make olddefconfig


### Apply kernel patch

#patch -p1 < patch1.patch


### Compile the kernel

make -j "$(nproc)"


### Install kernel modules

make INSTALL_MOD_STRIP=1 modules_install


### Install kernel to /boot

make install


### Rename kernel files

mv /boot/vmlinuz /boot/vmlinuz-${kernelversion}
mv /boot/System.map /boot/System.map-${kernelversion}


### Build/Install efibootmgr

#echo | kiss b grub efibootmgr
#kiss i grub efibootmgr

for pkg in grub efibootmgr; do
  echo | kiss build $pkg
  kiss install $pkg
done

mkdir /boot/efi


### Mount efi partition to /boot/efi

mount -t vfat /dev/sda1 /boot/efi


### Install grub for efi

grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=Kiss


### Generate grub config

grub-mkconfig -o /boot/grub/grub.cfg


### Build/install baseinit

#echo -ne '\n' | kiss b baseinit
#echo -ne '\n' | kiss i baseinit

for pkg in baseinit; do
  echo | kiss build $pkg
  kiss install $pkg
done


### Configure fstab

rm -rf /etc/fstab

wget -P /etc $urlinstallfiles/fstab


### Configure default profile

rm -rf /etc/profile

wget -P /etc $urlinstallfiles/profile


### Update kiss

#echo -ne '\n' | kiss update
echo | kiss update

### Configure timezone to EST

rm -rf /etc/localtime
ln -s /usr/share/zoneinfo/America/New_York /etc/localtime


### Enable default services

ln -s /etc/sv/dhcpcd /var/service
ln -s /etc/sv/acpid /var/service
ln -s /etc/sv/syslogd /var/service
ln -s /etc/sv/sshd /var/service
ln -s /etc/sv/udevd /var/service


### Configure KISS community repository

mkdir /usr/src/repo

cd /usr/src/repo

git clone https://github.com/kisslinux/community.git

rm /etc/profile.d/kiss_path.sh

touch /etc/profile.d/kiss_path.sh

echo 'export KISS_PATH=/var/db/kiss/repo/core:/var/db/kiss/repo/extra:/var/db/kiss/repo/xorg:/usr/src/repo/community:/usr/src/repo/community/community' > /etc/profile.d/kiss_path.sh

chmod +x /etc/profile.d/kiss_path.sh


### Set root password

passwd root


### Unmount efi partition

umount /boot/efi

