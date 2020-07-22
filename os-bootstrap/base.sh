#!/bin/sh -e

### Set version variables

export scriptversion="1.2"
export kisschrootversion="1.11.1"
export kissversion="1.1"


### Folder variables

export dirscript=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
export dirdownload="${dirscript}/source/download"


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
#export urlfirmware="https://git.kernel.org/pub/scm/linux/kernel/git/firmware/linux-firmware.git/snapshot/linux-firmware-${firmwareversion}.tar.gz"
export urlfirmware="https://git.kernel.org/pub/scm/linux/kernel/git/firmware/linux-firmware.git"

### Set compile flags

export commonflags="-O3 -pipe -march=native"
export cpucount="nproc"

export CFLAGS="${commonflags}"
export CXXFLAGS="${commonflags}"
export MAKEFLAGS="-j${cpucount}"


### Functions

# Emit a warning to tty
printWarning()
{
    echo '\e[1m\e[93m[WARNING]\e[0m '
    echo "$@"
}

# Emit an error to tty
printError()
{
    echo '\e[1m\e[91m[ERROR]\e[0m '
    echo "$@"
}

# Emit info to tty
printInfo()
{
    echo '\e[1m\e[94m[INFO]\e[0m '
    echo "$@"
}

# Failed to do a thing. Exit fatally.
scriptFail()
{
    printError "$@"
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

    wget -P "$1" "$2" -q --show-progress || scriptFail "Failed to download: $2"

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

requiredTools wget sha256sum gpg sfdisk mkfs.fat mkfs.xfs mkswap tar gzip

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
echo "Downloading Kiss chroot script"
echo

    downloadSource "$dirdownload" "${urlkisschrootscript}/kiss-chroot"

echo


### Call phase1.sh

echo "Would you like to to phase1.sh (y/n)? "

read -r answer

if [ "$answer" != "${answer#[Nn]}" ] ;then
    exit 0
fi

#sh ./phase1.sh

