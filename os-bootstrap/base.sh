#!/bin/sh -e

### Set version variables

export scriptversion="1.2"


# Emit a warning to tty
function printWarning()
{
    echo -en '\e[1m\e[93m[WARNING]\e[0m '
    echo $*
}

# Emit an error to tty
function printError()
{
    echo -en '\e[1m\e[91m[ERROR]\e[0m '
    echo $*
}

# Emit info to tty
function printInfo()
{
    echo -en '\e[1m\e[94m[INFO]\e[0m '
    echo $*
}

# Failed to do a thing. Exit fatally.
function scriptFail()
{
    printError $*
    exit 1
}



requiredTools()
{
    for tool in "$@" ; do

       if which "${tool}" >/dev/null 2>&1; then
            echo "${tool} : OK"
       else
            echo "${tool} : Missing"
            return 1
       fi
    
    done
}


urlTest()
{
    echo "testing $1"

    if curl -fsS $1 >/dev/null; then
        printf "$1 is accessible"
    else
        printf "$1 is inaccessible"
    fi

}

downloadSource()
{

    wget -P "$1" "$2" || scriptFail "Failed to download: $2"

}


### Call common.sh to set variables

source ./common.sh


echo
echo "#########################################"
echo "Checking for required tools"
echo

requiredTools wget curl sha256sum gpg sfdisk mkfs.fat mkfs.xfs mkswap tar gzip

echo
echo "#########################################"
echo "Downloading source files"
echo
echo "Cleaning downloads directory"
echo

rm -rf ${dirdownload}/*

echo
echo "Stable kernel version from Kernel.org: ${kernelversion}"
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

#sh ./phase1.sh