#!/bin/sh -e

### Variables #################################################################

### Set version variables

export scriptversion="1.2"
export kissversion="1.1"

source ./scriptvars.sh

### Set download variables

export urlinstallfiles="http://10.1.1.21/misc/kiss/${kissversion}/source"

### Set time variable for logging

time=$(date '+%Y-%m-%d-%H:%M')
export time

### Set color variables

export lcol='\033[1;33m'
export lcol2='\033[1;36m'
export lclr='\033[m'


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

### Update Kiss

log "Updating Kiss"

echo | kiss update

### Build/Install xorg base

for pkg in xorg-server xinit xinput libinput; do
    log "Building" "$pkg"
    echo | kiss build $pkg
    log "Installing" "$pkg"
    echo | kiss install $pkg
done


### Build/Install xorg drivers

if [ "$IsVM" != "true" ]

then

    for pkg in xf86-video-amdgpu xf86-video-intel xf86-video-nouveau xf86-video-vesa xf86-input-libinput; do
        log "Building" "$pkg"
        echo | kiss build $pkg
        log "Installing" "$pkg"
        echo | kiss install $pkg
    done

else

    for pkg in xf86-video-vesa xf86-input-libinput; do
        log "Building" "$pkg"
        echo | kiss build $pkg
        log "Installing" "$pkg"
        echo | kiss install $pkg
    done

fi


### Build/Install xorg utils

for pkg in xset xsetroot xclip fontconfig xrandr; do
    log "Building" "$pkg"
    echo | kiss build $pkg
    log "Installing" "$pkg"
    echo | kiss install $pkg
done


### Build/Install xorg fonts

for pkg in liberation-fonts terminus-font; do
    log "Building" "$pkg"
    echo | kiss build $pkg
    log "Installing" "$pkg"
    echo | kiss install $pkg
done


### Build/Install xorg drivers

if [ $IsVM != "true" ]
then

    for pkg in alsa-lib alsa-utils mesa libdrm intel-vaapi-driver mpv gstreamer gst-plugins gst-plugins-base; do
        log "Building" "$pkg"
        echo | kiss build $pkg
        log "Installing" "$pkg"
        echo | kiss install $pkg
    done

fi


### Build/Install bash

for pkg in bash; do
    log "Building" "$pkg"
    echo | kiss build $pkg
    log "Installing" "$pkg"
    echo | kiss install $pkg
done


### Build/Install window manager

for pkg in dwm dmenu slock st rxvt-unicode; do
    log "Building" "$pkg"
    echo | kiss build $pkg
    log "Installing" "$pkg"
    echo | kiss install $pkg
done


### Build/Install community misc

for pkg in htop pfetch imagemagick sxiv ranger w3m; do
    log "Building" "$pkg"
    echo | kiss build $pkg
    log "Installing" "$pkg"
    echo | kiss install $pkg
done


### Install firefox-bin

for pkg in firefox-bin; do
    log "Building" "$pkg"
    echo | kiss build $pkg
    log "Installing" "$pkg"
    echo | kiss install $pkg
done


### Download/extract dotfiles

wget -P /tmp $urlinstallfiles/dotfiles.tar.gz

tar -xvzf /tmp/dotfiles.tar.gz -C /

log "Downloading dotfiles" "${urlinstallfiles}/dotfiles.tar.gz"
echo ""
downloadSource "/tmp" "$urlkernel" || war "$?" "Failed to download dotfiles" "${urlinstallfiles}/dotfiles.tar.gz"

log "Extracting dotfiles" "/tmp/dotfiles.tar.gz"
echo ""
tar -xvzf /tmp/dotfiles.tar.gz -C / || war "$?" "Failed to extract dotfiles" "/tmp/dotfiles.tar.gz"


### Add default user

adduser -k /etc/skel -s /bin/bash user || die "$?" "Failed to add default user"


### Add default user to groups

addgroup user video || war "$?" "Failed to add default user to the following group" "video"
addgroup user audio || war "$?" "Failed to add default user to the following group" "audio"
addgroup user input || war "$?" "Failed to add default user to the following group" "input"
addgroup user wheel || war "$?" "Failed to add default user to the following group" "wheel"
