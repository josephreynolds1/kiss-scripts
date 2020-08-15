#!/bin/sh -e

clear

### Set version variables

export scriptversion="1.2"
export kissversion="1.1"

### User set variables

export kisschrootversion="2020.7"
export hostname="" # set hostname if blank will be set to kiss
export domain="" # optional set domain name
export rootpw="" # set root password if blank you will be prompted
export timezone="EST"
export filesystem="xfs" # set root filesystem xfs,ext4,btrfs
export diskchoice=""
export dirchroot="/mnt/kiss"
export kernelversion=""
export firmwareversion="20200421"

### Set folder variables

export dirscript=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
export dirsource="${dirscript}/source"
export dirdownload="${dirscript}/source/download"


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

### Set download variables

export kisschrooturl="https://github.com/kisslinux/repo/releases/download/${kisschrootversion}"
export urlkisschrootscript="https://raw.githubusercontent.com/kisslinux/kiss/master/contrib"

export urlinstallscripts="http://10.1.1.21/misc/kiss/${kissversion}"
export urlinstallfiles="http://10.1.1.21/misc/kiss/${kissversion}/source"

export urlkernel="https://cdn.kernel.org/pub/linux/kernel/v5.x/linux-${kernelversion}.tar.xz"

### Set firmware download url

if [ -z "$firmwareversion" ]; then

    export urlfirmware="https://git.kernel.org/pub/scm/linux/kernel/git/firmware/linux-firmware.git"

else

    export urlfirmware="https://git.kernel.org/pub/scm/linux/kernel/git/firmware/linux-firmware.git/snapshot/linux-firmware-${firmwareversion}.tar.gz"

fi


### Set compile flag variables

export commonflags="-O3 -pipe -march=native"

cpucount="$(nproc)"
export cpucount

export CFLAGS="${commonflags}"
export CXXFLAGS="${commonflags}"
export MAKEFLAGS="-j${cpucount}"


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

cleanchroot() {

umount -fV "$dirchroot" || war "$?" "Failed to unmount" "$dirchroot"
swapoff -v "/dev/${diskchoice}2" || war "$?" "Failed to turn off swap space" "/dev/${diskchoice}2"

rm -rf "$dirchroot" | war "$?" "Failed to delete" "$dirchroot"

}


### Main script body

log "Kiss Linux bootstrap version:" "${scriptversion}"
log "Checking for required tools"

echo ""
requiredTools wget sha256sum gpg sfdisk mkfs.fat mkfs.ext4 mkfs.xfs mkswap tar gzip lsblk || die "$?" "${tool} is not installed"


### Set time with ntpdate

if which ntpdate >/dev/null 2>&1; then

    echo ""
    log "ntpdate is installed"
    log "Setting date/time with ntpdate"

    ntpdate 0.pool.ntp.org

else

    echo ""
    war "ntpdate" "is not installed" "$3"
    war "Skipping setting date/time with ntpdate" "$3"
    war "Make sure date and time are correct" "$(date)" "$3"

fi

### Choose disk to install to

disksdev=$(lsblk -d -e 11,1,7 -o NAME,SIZE | awk '{if (NR!=1) {print $1}}' )

if [ -z "$diskchoice" ]; then

    echo ""
    war "Disk is not selected!"

    log "Choose disk for install"
    echo ""

    lsblk -d -p -e 11,1,7 -o NAME,SIZE,RM,RO,TYPE,MOUNTPOINT

    echo ""

    i=1

    for disk in $disksdev; do

        echo "$i: $disk"

        i=$((i + 1))

    done

    echo
    echo "Which disk would you like to install Kiss to? "

    read -r diskchoice

    contains "$disksdev" "$diskchoice"

    result="$?"

else

    echo "Disk is specified ${diskchoice}"

    contains "$disksdev" "$diskchoice"

    result="$?"

fi


sfdiskfile="${diskchoice}.sfdisk"

case "$diskchoice" in
    *nvme*)
       diskchoice="${diskchoice}p"
    ;;
esac

#if [ -z "$diskchoicenvme" ]; then

/bin/cat <<EOM >"$dirsource/$sfdiskfile"
label: gpt
unit: sectors
first-lba: 2048

/dev/${diskchoice}1 : start=2048, size=1048576, type=C12A7328-F81F-11D2-BA4B-00A0C93EC93b
/dev/${diskchoice}2 : start=1050624, size=8388608, type=0657FD6D-A4AB-43C4-84E5-0933C84B4F4F
/dev/${diskchoice}3 : start=9439232, type=4F68BCE3-E8CD-4DB1-96E7-FBCAF984B709
EOM

#else

#/bin/cat <<EOM >"$dirsource/$sfdiskfile"
#label: gpt
#unit: sectors
#first-lba: 2048

#/dev/${diskchoice}1 : start=2048, size=1048576, type=C12A7328-F81F-11D2-BA4B-00A0C93EC93b
#/dev/${diskchoice}2 : start=1050624, size=8388608, type=0657FD6D-A4AB-43C4-84E5-0933C84B4F4F
#/dev/${diskchoice}3 : start=9439232, type=4F68BCE3-E8CD-4DB1-96E7-FBCAF984B709
#EOM

#fi


### Summary

echo ""
log "Hostname:" "${hostname}"
log "Domain:" "${domain}"
log "Kiss Linux Chroot:" "${kisschrootversion}"
log "Linux kernel:" "${kernelversion}"
log "Linux firmware:" "${firmwareversion}"
log "Install disk:" "/dev/${diskchoice}"
log "Root filesystem:" "${filesystem}"
log "Timezone:" "${timezone}"


### Install Kiss choice

echo ""
echo "Proceed with installing Kiss Linux (y/n)? "

read -r answer

if [ "$answer" != "${answer#[Nn]}" ] ;then
    exit 0
fi

echo ""
log "Cleaning source downloads directory"

rm -f "${dirdownload:?}"/*

log "Downloading source files"

echo ""
log "Stable kernel version from Kernel.org:" "${kernelversion}"
log "Downloading kernel version:" "${kernelversion}"
echo ""
downloadSource "$dirdownload" "$urlkernel" || die "$?" "Failed to download" "$urlkernel"

log "Downloading Kiss-chroot version:" "${kisschrootversion}"
echo ""
downloadSource "$dirdownload" "${kisschrooturl}/kiss-chroot-${kisschrootversion}.tar.xz" || die "$?" "Failed to download" "${kisschrooturl}/kiss-chroot-${kisschrootversion}.tar.xz"

log "Downloading Kiss-chroot sha256 hash"
echo ""
downloadSource "$dirdownload" "${kisschrooturl}/kiss-chroot-${kisschrootversion}.tar.xz.sha256" || die "$?" "Failed to download" "${kisschrooturl}/kiss-chroot-${kisschrootversion}.tar.xz.sha256"

log "Downloading kiss-chroot key"
echo ""
downloadSource "$dirdownload" "${kisschrooturl}/kiss-chroot-${kisschrootversion}.tar.xz.asc" || die "$?" "Failed to download" "${kisschrooturl}/kiss-chroot-${kisschrootversion}.tar.xz.asc"

log "Validating Kiss chroot files"
echo ""
sha256sum -c < "$dirdownload/kiss-chroot-${kisschrootversion}.tar.xz.sha256"
gpg --keyserver keys.gnupg.net --recv-key 46D62DD9F1DE636E || die "$?" "Failed to get gnupg key for kiss-chroot-${kisschrootversion}.tar.xz"
gpg --verify "$dirdownload/kiss-chroot-${kisschrootversion}.tar.xz.asc" "$dirdownload/kiss-chroot-${kisschrootversion}.tar.xz" || die "$?" "Failed to verify signature of" "$dirdownload/kiss-chroot-${kisschrootversion}.tar.xz"

echo ""
log "Exporting default profile"

/bin/cat <<EOM >"$dirsource/profile"
# /etc/profile
#
# System wide environment and startup programs.

# Set default path (/usr/sbin:/sbin:/bin included for non-KISS Linux chroots).
export PATH=/usr/local/sbin:/usr/local/bin:/usr/bin:/usr/sbin:/sbin:/bin

# Set default umask.
umask 022

# Load profiles from /etc/profile.d
for file in /etc/profile.d/*.sh; do
    [ -r "$file" ] && . "$file"
done

unset file

# Build Settings
export CFLAGS="${commonflags}"
export CXXFLAGS="${commonflags}"
export MAKEFLAGS="-j${cpucount}"
EOM

#Set variables file for chroot environment

echo ""
log "Set variables file for chroot environment"

/bin/cat <<EOM >"$dirsource/scriptvars.sh"
#!/bin/sh

export hostname="${hostname}"
export domain="${domain}"
export timezone="${timezone}"
export rootpw="${rootpw}"
export filesystem="${filesystem}"
export diskchoice="${diskchoice}"
export kernelversion="${kernelversion}"
export firmwareversion="${firmwareversion}"
EOM


#Set variables file for chroot environment

echo ""
log "Generate fstab configuration"

/bin/cat <<EOM >"$dirsource/fstab"
# Static information about the filesystems.
# See fstab(5) for details.

# <file system> <dir> <type> <options> <dump> <pass>

/dev/${diskchoice}1	/boot/efi	vfat	0 2
/dev/${diskchoice}2	none	swap	sw	0 0
/dev/${diskchoice}3	/	${filesystem}	noatime	0 1

EOM


### Partition/format disk and enter chroot

echo
echo "Would you like to partition/format /dev/$diskchoice (y/n)? "

read -r answer

if [ "$answer" != "${answer#[Nn]}" ] ;then
    exit 0
fi

log "Creating partions on:" "/dev/${diskchoice}"

sfdisk "/dev/${diskchoice}" < "$dirsource/$sfdiskfile" || die "$?" "Failed to partition /dev/${diskchoice}"

log "Formating partions on:" "/dev/${diskchoice}"

mkfs.fat -F32 "/dev/${diskchoice}1" || die "$?" "Failed to format boot partition:" "/dev/${diskchoice}1"
mkswap "/dev/${diskchoice}2" || die "$?" "Failed to create swap partition:" "/dev/${diskchoice}2"
"mkfs.${filesystem}" -f "/dev/${diskchoice}3" || die "$?" "Failed to format root partition with $filesystem:" "/dev/${diskchoice}3"

log "Enabling swap space on:" "/dev/${diskchoice}2"

swapon "/dev/${diskchoice}2" || die "$?" "Failed to enable swap"

mkdir "$dirchroot"
mount "/dev/${diskchoice}3" "$dirchroot" || die "$?" "Failed to mount root partition /dev/${diskchoice}3 on $dirchroot"


echo
echo "Would you like to enter chroot (y/n)? "

read -r answer

if [ "$answer" != "${answer#[Nn]}" ] ;then
    exit 0
fi

log "Extracting root filesystem to ${dirchroot}"

tar xvf "$dirdownload/kiss-chroot-${kisschrootversion}.tar.xz" -C "$dirchroot" --strip-components 1 || die "$?" "Failed to extract kiss-chroot to $dirchroot"

cp "${dirsource}/phase1.sh" "$dirchroot/root/" || die "$?" "Failed to copy phase1.sh to ${dirchroot}/root"
cp "${dirsource}/phase2.sh" "$dirchroot/root/" || die "$?" "Failed to copy phase2.sh to ${dirchroot}/root"
cp "${dirsource}/profile" "$dirchroot/etc/profile" || die "$?" "Failed to copy default profile to ${dirchroot}/etc"
cp "${dirsource}/scriptvars.sh" "$dirchroot/root/" || die "$?" "Failed to copy scriptvars to ${dirchroot}/root"
cp "${dirsource}/fstab" "$dirchroot/etc/" || die "$?" "Failed to copy fstab to ${dirchroot}/etc"

mkdir -p "$dirchroot/usr/src/kernel" || die "$?" "Failed to create kernel source dir ${dirchroot}/usr/src/kernel"
cp "${dirsource}/config" "$dirchroot/usr/src/kernel/" || die "$?" "Failed to copy kernel config to ${dirchroot}/usr/src/kernel"
cp "${dirsource}/download/linux-${kernelversion}.tar.xz" "$dirchroot/usr/src/kernel/" || die "$?" "Failed to copy kernel source to ${dirchroot}/usr/src/kernel"


log "Executing kiss-chroot script"

"$dirchroot/bin/kiss-chroot" "$dirchroot" || die "$?" "Failed execution of kiss-chroot script"

