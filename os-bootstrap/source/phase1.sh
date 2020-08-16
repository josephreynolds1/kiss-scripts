#!/bin/sh -e

### Variables #################################################################

### Set version variables

export scriptversion="1.2"
export kissversion="1.1"

source ./scriptvars.sh


if [ -z "$hostname" ]; then

    export hostname="kiss"

fi


if [ -z "$domain" ]; then

    export domain="localdomain"

fi


if [ -z "$rootpw" ]; then

    export rootpw="kiss"

fi


### Set time variable for logging

time=$(date '+%Y-%m-%d-%H:%M')
export time

### Set color variables

export lcol='\033[1;33m'
export lcol2='\033[1;36m'
export lclr='\033[m'

### Set compile flag variables

#export commonflags="-O3 -pipe -march=native"
#export cpucount="nproc"

export CFLAGS="${commonflags}"
export CXXFLAGS="${commonflags}"
export MAKEFLAGS="-j${cpucount}"


### Functions #################################################################

log() {

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
    else
        echo "$1 is inacessible"
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

    log "Machine is a VM" "$Make"

    IsVM="true"

elif [ "$Make" = "VMware" ]

then

    log "Machine is a VM" "$Make"

    IsVM="true"

else

    log "Machine is not a VM" "$Make"

    IsVM="false"

fi


### Main script body ##########################################################

### Build/install gnugpg

for pkg in gnupg1; do
    log "Building" "$pkg"
    echo | kiss build $pkg
    log "Installing" "$pkg"
    echo | kiss install $pkg
done

### Add/configure kiss repo key

log "Configuring kiss repo GPG key"

gpg --keyserver keys.gnupg.net --recv-key 46D62DD9F1DE636E
echo trusted-key 0x46d62dd9f1de636e >>/root/.gnupg/gpg.conf

cd /var/db/kiss/repo
git config merge.verifySignatures true


### Update kiss

log "Updating Kiss"

echo | kiss update

log "Updating Kiss"

echo | kiss update


### Recompile installed apps

log "Rebuilding base apps"

#echo | kiss build "$(ls /var/db/kiss/installed)"

cd /var/db/kiss/installed && echo | kiss build *


### Build/Install base apps


for pkg in e2fsprogs xfsprogs dosfstools util-linux eudev dhcpcd libelf ncurses perl tzdata acpid openssh sudo; do
    log "Building" "$pkg"
    echo | kiss build $pkg
    log "Installing" "$pkg"
    echo | kiss install $pkg
done


if [ "$IsVM" != "true" ]

then

    for pkg in wpa_supplicant; do
        log "Building" "$pkg"
        echo | kiss build $pkg
        log "Installing" "$pkg"
        echo | kiss install $pkg
    done

fi


### Extract and remove downloaded kernel archive

log "Extracting" "linux-${kernelversion}.tar.xz"

tar xvf "/usr/src/kernel/linux-${kernelversion}.tar.xz" --directory /usr/src/kernel/ || die "$?" "Failed to extract kernel archive to /usr/src/kernel"

log "Removing" "linux-${kernelversion}.tar.xz"

rm -rf "/usr/src/kernel/linux-${kernelversion}.tar.xz" || war "$?" "Failed to remove /usr/src/kernel/linux-${kernelversion}.tar.xz"


### Create firmware directories

if [ "$IsVM" != "true" ]

then

    log "Creating linux firmware source directory" "/usr/src/firmware"

    mkdir -p /usr/src/firmware

    log "Creating linux firmware directory" "/usr/lib/firmware"

    mkdir -p /usr/lib/firmware

    cd /usr/src/firmware


    ### Download firmware archive

    log "Cloning linux firmware git repository"

    git clone "$urlfirmware"


    ### Extract and remove downloaded firmware archive

    #tar xvf "linux-firmware-${firmwareversion}.tar.gz" --directory /usr/src/firmware/

    #rm -rf "linux-firmware-${firmwareversion}.tar.gz"

    log "Copying linux firmware files" "/usr/lib/firmware"

    cp -R /usr/src/firmware/* /usr/lib/firmware/ || war "$?" "Failed to copy firmware files to /usr/lib/firmware"

fi


### Download kernel GCC 10 fix patch

#wget "$urlinstallfiles/patch1.patch"


### Copy kernel config to kernel source directory

log "Copy kernel config to kernel source directory"

cp "/usr/src/kernel/config" "/usr/src/kernel/linux-${kernelversion}/.config" || die "$?" "Failed to copy default kernel config to /usr/src/kernel/linux-${kernelversion}"


### Change to kernel source directory

cd "/usr/src/kernel/linux-${kernelversion}"


### Prepare linux kernel configuration

log "Prepare linux kernel configuration"

make olddefconfig || die "$?" "Failed kernel config preperation"


### Apply kernel patch

#patch -p1 < patch1.patch


### Compile the kernel

log "Compiling the kernel"

make -j "$(nproc)"

### Install kernel modules

log "Install kernel modules"

make INSTALL_MOD_STRIP=1 modules_install || die "$?" "Failed to install kernel modules"


### Install kernel to /boot

log "Installing kernel" "/boot"

make install || die "$?" "Failed kernel install"


### Rename kernel files

log "Renaming vmlinux to vmlinuz-${kernelversion}"

mv /boot/vmlinuz "/boot/vmlinuz-${kernelversion}" || die "$?" "Failed to rename kernel image"

log "Renaming System.map to System.map-${kernelversion}"

mv /boot/System.map "/boot/System.map-${kernelversion}" || die "$?" "Failed to rename System.map"


### Build/Install efibootmgr

for pkg in grub efibootmgr; do
    log "Building" "$pkg"
    echo | kiss build $pkg
    log "Installing" "$pkg"
    echo | kiss install $pkg
done

log "Creating directory" "/boot/efi"

mkdir /boot/efi || die "$?" "Failed to create /boot/efi directory"

### Mount efi partition to /boot/efi

log "Mounting efi boot partition /dev/${diskchoice}1 to /boot/efi"

mount -t vfat "/dev/${diskchoice}1" /boot/efi || die "$?" "Failed to mount boot partition /dev/${diskchoice}1 on /boot/efi"


### Install grub for efi

log "Installing grub for efi" "/boot/efi"

grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=Kiss || die "$?" "Grub bootloader install failed"


### Generate grub config

log "Generating grub configuration" "/boot/grub/grub.cfg"

grub-mkconfig -o /boot/grub/grub.cfg || die "$?" "Failed generate grub.cfg"


### Build/install baseinit

for pkg in baseinit; do
    log "Building" "$pkg"
    echo | kiss build $pkg
    log "Installing" "$pkg"
    echo | kiss install $pkg
done

### Configure timezone to EST

log "Setting timezone" "$timezone"

rm -rf /etc/localtime
ln -s /usr/share/zoneinfo/America/New_York /etc/localtime

### Set hostname

log "Setting hostname:" "${hostname}.${domain}"

echo "${hostname}.${domain}" > /etc/hostname || war "$?" "Failed to set hostname"

log "Updating /etc/hosts file with hostname/domain" "${hostname}.${domain}"

/bin/cat <<EOM >"/etc/hosts"
127.0.0.1  ${hostname}.localdomain  ${hostname}
::1        ${hostname}.localdomain  ${hostname}  ip6-localhost

EOM

### Enable default services

log "Enabling default services"

ln -s /etc/sv/dhcpcd /var/service
ln -s /etc/sv/acpid /var/service
ln -s /etc/sv/syslogd /var/service
ln -s /etc/sv/sshd /var/service
ln -s /etc/sv/udevd /var/service


### Configure KISS community repository

log "Adding Kiss community repository"

mkdir /usr/src/repo

cd /usr/src/repo

git clone https://github.com/kisslinux/community.git

rm /etc/profile.d/kiss_path.sh

touch /etc/profile.d/kiss_path.sh

echo 'export KISS_PATH=/var/db/kiss/repo/core:/var/db/kiss/repo/extra:/var/db/kiss/repo/xorg:/usr/src/repo/community:/usr/src/repo/community/community' > /etc/profile.d/kiss_path.sh

chmod +x /etc/profile.d/kiss_path.sh

### Set compiler options /etc/profile

log "Adding compiler options to /etc/profile"

/bin/cat <<EOM >> "/etc/profile"

export CFLAGS="${commonflags}"
export CXXFLAGS="${commonflags}"
export MAKEFLAGS="-j${cpucount}"
EOM


### Set root password

log "Setting root password"

echo "root:${rootpw}" | chpasswd

