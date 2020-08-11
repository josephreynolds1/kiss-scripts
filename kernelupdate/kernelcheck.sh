#!/bin/sh -e

scriptversion="1.0"

### Set time variable for logging

time=$(date '+%Y-%m-%d-%H:%M')
export time

### Set color variables

export lcol='\033[1;33m'
export lcol2='\033[1;36m'
export lclr='\033[m'

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


### Get current kernel version

installedkernel=$(uname -r)

echo ""

if [ -f /boot/kernelprevious ]
then

    kernelprevious=$(cat /boot/kernelprevious)

    log "Kernelprevious file set value:" "$kernelprevious"

else

    log "Kernelprevious file not found"

fi

if [ -f /boot/kernelcurrent ]
then

    kernelcurrent=$(cat /boot/kernelcurrent)

    log "Kernelcurrent file set value:" "$kernelcurrent"

else

    log "Kernelcurrent file not found"

fi



echo ""
log "Installed Linux kernel:" "$installedkernel"


### Get latest kernel.org stable version

latestkernel=$(wget -q --output-document - https://www.kernel.org/ | grep -A 1 "latest_link")

latestkernel=${latestkernel##*.tar.xz\">}

latestkernel=${latestkernel%</a>}

echo ""
log "Stable version from Kernel.org:" "$latestkernel"

if [ "$latestkernel" = "$installedkernel" ]

then

    echo ""
    log "Kernel is already latest version"
    echo ""

else

    echo ""
    log "Newer kernel available!"
    log "Run KernelUpdate.sh to update the Linux kernel"
    echo ""

fi
