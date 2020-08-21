#!/bin/sh -e

### Variables #################################################################

export KISS_PROMPT=0

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

    kiss update

### Build/Install xorg and desktop applications

log "Installing Xorg and Base Desktop Applications"

    kiss b alsa-utils && kiss i alsa-utils
    kiss b xorg-server && kiss i xorg-server
    kiss b xf86-input-libinput && kiss i xf86-input-libinput
    kiss b xauth && kiss i xauth
    kiss b xclip && kiss i xclip
    kiss b xset && kiss i xset
    kiss b xsetroot && kiss i xsetroot
    kiss b xrandr && kiss i xrandr
    kiss b xinit && kiss i xinit
    kiss b hsetroot && kiss i hsetroot
    kiss b htop && kiss i htop
    kiss b fontconfig && kiss i fontconfig
    kiss b liberation-fonts && kiss i liberation-fonts
    kiss b terminus-font && kiss i terminus-font
    kiss b imagemagick && kiss i imagemagick
    kiss b firefox-bin && kiss i firefox-bin
    kiss b dmenu && kiss i dmenu
    kiss b st && kiss i st
    kiss b slock && kiss i slock
    kiss b sxiv && kiss i sxiv
    kiss b dwm && kiss i dwm
    kiss b bash && kiss i bash


### Build/Install xorg drivers

if [ "$IsVM" != "true" ]

then

    kiss b xf86-video-amdgpu && kiss i xf86-video-amdgpu
    kiss b xf86-video-nouveau && kiss i xf86-video-nouveau
    kiss b xf86-video-vesa && kiss i xf86-video-vesa

else

    kiss b xf86-video-vesa && kiss i xf86-video-vesa

fi

### Add default user

adduser -k /etc/skel user || die "$?" "Failed to add default user"


### Add default user to groups

addgroup user video || war "$?" "Failed to add default user to the following group" "video"
addgroup user audio || war "$?" "Failed to add default user to the following group" "audio"
addgroup user input || war "$?" "Failed to add default user to the following group" "input"
addgroup user wheel || war "$?" "Failed to add default user to the following group" "wheel"


export KISS_PROMPT=1
