#!/bin/sh -e

### Set version variables

export scriptversion="1.2"
export kissversion="1.1"

### User set variables

#export hostname="" # set hostname if blank will be set to kiss
#export domain="" # optional set domain name
#export rootpw="" # set root password if blank you will be prompted
#export kernelversion=""
#export firmwareversion="20200421"

source ./scriptvars.sh

if [ -z "$hostname" ]; then

    export hostname="kiss"

fi


if [ -z "$domain" ]; then

    export domain=""

fi


if [ -z "$rootpw" ]; then

    export rootpw="kiss"

fi




### Get latest kernel.org stable version

if [ -z "$kernelversion" ]; then

    #echo "kernelversion is not set getting latest kernel version from kernel.org"

    kernelversion=$(wget -q --output-document - https://www.kernel.org/ | grep -A 1 "latest_link")

    kernelversion=${kernelversion##*.tar.xz\">}

    export kernelversion=${kernelversion%</a>}

else

    echo "$kernelversion is set"

fi

### Set time variable for logging

time=$(date '+%Y-%m-%d-%H:%M')
export time

### Set color variables

export lcol='\033[1;33m'
export lcol2='\033[1;36m'
export lclr='\033[m'

### Set compile flag variables

export commonflags="-O3 -pipe -march=native"
export cpucount="nproc"

export CFLAGS="${commonflags}"
export CXXFLAGS="${commonflags}"
export MAKEFLAGS="-j${cpucount}"

### Set download variables

export urlinstallfiles="http://10.1.1.21/misc/kiss/${kissversion}/source"


### Functions

log() {
    # Print a message prettily.
    #
    # All messages are printed to stderr to allow the user to hide build
    # output which is the only thing printed to stdout.
    #
    # The l<word> variables contain escape sequence which are defined
    # when '$KISS_COLOR' is equal to '1'.
    printf '%b%s %b%s%b %s\n' \
        "$lcol" "${3:-->}" "${lclr}${2:+$lcol2}" "$1" "$lclr" "$2" >&2
}

war() {
    log "$1" "$2" "${3:-WARNING}"
}

die() {
    log "$1" "$2" "${3:-ERROR}"
    exit 1
}


# Check for required tools
requiredTools()
{
    for tool in "$@" ; do

        if which "${tool}" >/dev/null 2>&1; then
            echo "${tool} : OK"
        else

            war "${tool} : Missing"

            return 1
        fi

    done
}


urlTest()
{
    echo "testing $1"

    if curl -fsS "$1" >/dev/null; then
        echo "$1 is accessible"
        #printf "%s\n $1 is accessible"
    else
        echo "$1 is inacessible"
        #printf "%s\n $1 is inaccessible"
    fi

}


downloadSource()
{

    wget -P "$1" "$2" || scriptFail "Failed to download: $2"

}


contains() {
    string="$1"
    substring="$2"
    if test "${string#*$substring}" != "$string"
    then

        return 0    # $substring is in $string

    else

        return 1    # $substring is not in $string

    fi
}

decompress() {
    case $1 in
        *.bz2)      bzip2 -d  ;;
        *.lzma)     lzma -dc  ;;
        *.lz)       lzip -dc  ;;

        *.tar)      cat       ;;
        *.tgz|*.gz) gzip -d   ;;
        *.xz|*.txz) xz -dcT 0 ;;
        *.zst)      zstd -dc  ;;
    esac < "$1"
}


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

### Build/install gpg

for pkg in gnupg1; do
    echo | kiss build $pkg
    kiss install $pkg
done


### Add/configure kiss repo key

gpg --keyserver keys.gnupg.net --recv-key 46D62DD9F1DE636E
echo trusted-key 0x46d62dd9f1de636e >>/root/.gnupg/gpg.conf

cd /var/db/kiss/repo
git config merge.verifySignatures true


### Update kiss

echo | kiss update
echo | kiss update


### Recompile installed apps

echo | kiss build "$(ls /var/db/kiss/installed)"


### Build/Install base apps

for pkg in e2fsprogs dosfstools util-linux eudev dhcpcd libelf ncurses perl tzdata acpid openssh sudo; do
    echo | kiss build $pkg
    kiss install $pkg
done


if [ "$IsVM" != "true" ]

then

    for pkg in wpa_supplicant; do
        echo | kiss build $pkg
        kiss install $pkg
    done

fi


### Extract and remove downloaded kernel archive

tar xvf "/usr/src/kernel/linux-${kernelversion}.tar.xz" --directory /usr/src/kernel/

rm -rf "/usr/src/kernel/linux-${kernelversion}.tar.xz"


### Create firmware directories

if [ "$IsVM" != "true" ]

then

    mkdir /usr/src/firmware
    mkdir -p /usr/lib/firmware

    cd /usr/src/firmware


    ### Download firmware archive

    git clone "$urlfirmware"


    ### Extract and remove downloaded firmware archive

    tar xvf "linux-firmware-${firmwareversion}.tar.gz" --directory /usr/src/firmware/

    rm -rf "linux-firmware-${firmwareversion}.tar.gz"


    #cp -R ./path/to/driver /usr/lib/firmware

fi


### Change to kernel source directory

cd "/usr/src/kernel/linux-${kernelversion}"


### Download kernel GCC 10 fix patch

#wget "$urlinstallfiles/patch1.patch"


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

mv /boot/vmlinuz "/boot/vmlinuz-${kernelversion}"
mv /boot/System.map "/boot/System.map-${kernelversion}"


### Build/Install efibootmgr

for pkg in grub efibootmgr; do
    echo | kiss build $pkg
    kiss install $pkg
done

mkdir /boot/efi

### Mount efi partition to /boot/efi

mount -t vfat "/dev/${diskchoice}1" /boot/efi || die "$?" "Failed to mount boot partition /dev/${diskchoice}1 on /boot/efi"


### Install grub for efi

grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=Kiss


### Generate grub config

grub-mkconfig -o /boot/grub/grub.cfg


### Build/install baseinit

for pkg in baseinit; do
    echo | kiss build $pkg
    kiss install $pkg
done


### Configure fstab

rm -rf /etc/fstab

wget -P /etc "$urlinstallfiles/fstab"


### Configure default profile

rm -rf /etc/profile

wget -P /etc "$urlinstallfiles/profile"


### Update kiss

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


echo "root:${rootpw}" | chpasswd

### Unmount efi partition
