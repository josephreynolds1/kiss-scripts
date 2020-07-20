#!/bin/sh -e

### Set version variables

export scriptversion="1.1"
export kisschrootversion="1.11.1"
export kissversion="1.1"


### Folder variables

export dirscript=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
export dirdownload="${dirscript}/source/download"


#kernelversion="5.7.1"
export firmwareversion="20200421"

### Get latest kernel.org stable version

kernelversion=$(wget -q --output-document - https://www.kernel.org/ | grep -A 1 "latest_link")

kernelversion=${kernelversion##*.tar.xz\">}

kernelversion=${kernelversion%</a>}


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

export CFLAGS="${commonflags}"
export CXXFLAGS="${commonflags}"
export MAKEFLAGS="-j$(nproc)"