#!/bin/sh -e

### Set version variables

export scriptversion="1.2"
export kisschrootversion="1.12.0"
export kissversion="1.1"


### Misc Variables

export hostname="" # set hostname if blank will be set to kiss
export domain="" # optional set domain name
export rootpw="" # set root password if blank you will be prompted
export filesystem="xfs" # set root filesystem xfs,ext4,btrfs
export diskchoice=""


### Set folder variables

export dirscript=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
export dirsource="${dirscript}/source"
export dirdownload="${dirscript}/source/download"
export dirchroot="/mnt/kiss"


### Set Kernel/Firmware variables

export kernelversion=""
export firmwareversion="20200421"


### Get latest kernel.org stable version

if [ -z "$kernelversion" ]; then
    
    echo "kernelversion is not set getting latest kernel version from kernel.org"
    
    kernelversion=$(wget -q --output-document - https://www.kernel.org/ | grep -A 1 "latest_link")
    
    kernelversion=${kernelversion##*.tar.xz\">}
    
    export kernelversion=${kernelversion%</a>}
    
else
    
    echo "$kernelversion is set"
    
fi


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
export cpucount="$(nproc)"

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
            echo "${tool} : Missing"
            exit 1
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


### Main script body

echo
echo "#############################################################################"
echo "Kiss Linux bootstrap version: ${scriptversion}"
echo
echo "Versions:"
echo "Kiss Linux: ${kisschrootversion}"
echo "Linux kernel: ${kernelversion}"
echo "Linux firmware: ${firmwareversion}"

echo
echo "#############################################################################"
echo "Checking for required tools"
echo

requiredTools wget sha256sum gpg sfdisk mkfs.fat mkfs.xfs mkswap tar gzip lsblk ntpdate

echo
echo "#############################################################################"
echo "Setting date/time with ntpdate"
echo

ntpdate 0.pool.ntp.org

echo
echo "#############################################################################"
echo "Downloading source files"
echo

echo "Would you like to download the source files (y/n)? "

read -r answer

if [ "$answer" != "${answer#[Nn]}" ] ;then
    exit 0
fi

echo
echo "Cleaning downloads directory"
echo

rm -f "${dirdownload:?}"/*

echo
echo "Stable kernel version from Kernel.org: ${kernelversion}"
echo
echo "Downloading kernel version: ${kernelversion}"
echo

downloadSource "$dirdownload" "$urlkernel"

echo
echo "Downloading Kiss chroot version: ${kisschrootversion}"
echo

downloadSource "$dirdownload" "${kisschrooturl}/kiss-chroot.tar.xz"

echo

downloadSource "$dirdownload" "${kisschrooturl}/kiss-chroot.tar.xz.sha256"

echo 

downloadSource "$dirdownload" "${kisschrooturl}/kiss-chroot.tar.xz.asc"

echo

echo
echo "Downloading Kiss chroot script"
echo

downloadSource "$dirdownload" "${urlkisschrootscript}/kiss-chroot"
chmod +x "$dirdownload/kiss-chroot"

echo
echo "Validating Kiss chroot files"
echo

sha256sum -c < "$dirdownload/kiss-chroot.tar.xz.sha256"
gpg --keyserver keys.gnupg.net --recv-key 46D62DD9F1DE636E
gpg --verify "$dirdownload/kiss-chroot.tar.xz.asc" "$dirdownload/kiss-chroot.tar.xz"

echo
echo

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

### Partition/format disk and enter chroot

disksdev=$(lsblk -d -e 11,1,7 -o NAME,SIZE | awk '{if (NR!=1) {print $1}}' )

if [ -z "$diskchoice" ]; then
    
    echo "Disk is not selected!"
    
    echo
    echo "#############################################################################"
    echo "Choose disk for install"
    echo

    lsblk -d -p -e 11,1,7 -o NAME,SIZE,RM,RO,TYPE,MOUNTPOINT

    echo

    i=1

    for disk in $disksdev; do
        
        echo "$i: $disk"
        
        i=$((i + 1))
        
    done

    echo
    echo "Which disk would you like to install Kiss to? "

    read -r diskchoice

    #echo "$diskchoice"

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
       diskchoicenvme="${diskchoice}p"
    ;;
esac

if [ -z "$diskchoicenvme" ]; then

/bin/cat <<EOM >"$dirsource/$sfdiskfile"
label: gpt
unit: sectors
first-lba: 2048

/dev/${diskchoice}1 : start=2048, size=1048576, type=C12A7328-F81F-11D2-BA4B-00A0C93EC93b
/dev/${diskchoice}2 : start=1050624, size=8388608, type=0657FD6D-A4AB-43C4-84E5-0933C84B4F4F
/dev/${diskchoice}3 : start=9439232, type=4F68BCE3-E8CD-4DB1-96E7-FBCAF984B709
EOM

else

/bin/cat <<EOM >"$dirsource/$sfdiskfile"
label: gpt
unit: sectors
first-lba: 2048

/dev/${diskchoicenvme}1 : start=2048, size=1048576, type=C12A7328-F81F-11D2-BA4B-00A0C93EC93b
/dev/${diskchoicenvme}2 : start=1050624, size=8388608, type=0657FD6D-A4AB-43C4-84E5-0933C84B4F4F
/dev/${diskchoicenvme}3 : start=9439232, type=4F68BCE3-E8CD-4DB1-96E7-FBCAF984B709
EOM

fi

echo
echo "Would you like to partition/format /dev/$diskchoice (y/n)? "

read -r answer

if [ "$answer" != "${answer#[Nn]}" ] ;then
    exit 0
fi

echo
echo "Create Partitions"
echo

sfdisk "/dev/${diskchoice}" < "$dirsource/$sfdiskfile"

echo
echo "Format Partitions"
echo

mkfs.fat -F32 "/dev/${diskchoice}1"
mkswap "/dev/${diskchoice}2"
mkfs.xfs "/dev/${diskchoice}3"

echo
echo "Enable swap space"
echo

swapon "/dev/${diskchoice}2"

echo
echo "Mount root partition to /mnt/kiss"
echo

mkdir "$dirchroot"
mount "/dev/${diskchoice}3" "$dirchroot"

echo
echo "Would you like to enter chroot (y/n)? "

read -r answer

if [ "$answer" != "${answer#[Nn]}" ] ;then
    exit 0
fi

echo
echo "Extract root filesystem and chroot into ${dirchroot}"
echo

tar xvf "$dirdownload/kiss-chroot.tar.xz" -C "$dirchroot" --strip-components 1

cp "${dirsource}/phase1.sh" "$dirchroot/root/"
cp "${dirsource}/phase2.sh" "$dirchroot/root/"
cp "${dirsource}/profile" "$dirchroot/etc/profile"

echo
echo "Executing kiss-chroot script"
echo

"$dirdownload/kiss-chroot" "$dirchroot"
