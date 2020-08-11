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
    touch "/boot/kernelprevious"

fi

if [ -f /boot/kernelcurrent ]
then

    kernelcurrent=$(cat /boot/kernelcurrent)

    log "Kernelcurrent file set value:" "$kernelcurrent"

else

    log "Kernelcurrent file not found"
    touch "/boot/kernelcurrent"

fi

echo ""
log "Installed Linux kernel:" "$installedkernel"


### Get latest kernel.org stable version

latestkernel=$(wget -q --output-document - https://www.kernel.org/ | grep -A 1 "latest_link")

latestkernel=${latestkernel##*.tar.xz\">}

latestkernel=${latestkernel%</a>}

log "Stable version from Kernel.org:" "$latestkernel"

if [ "$latestkernel" = "$installedkernel" ]

then

    echo ""
    log "Kernel is already latest version"
    echo ""

else

    echo ""
    log "Newer kernel available!"

    urlkernel="https://cdn.kernel.org/pub/linux/kernel/v5.x/linux-${latestkernel}.tar.xz"

    echo ""
    echo "Would you like to update the Linux Kernel to $latestkernel (y/n)? "
    read -r answer

    if [ "$answer" != "${answer#[Yy]}" ] ;then

        log "Updating kernel...."

        ## Download Kernel

        log "Downloading kernel from:" "${urlkernel}"

        wget -P /usr/src/kernel/ "$urlkernel"

        ### Extract and remove downloaded kernel archive

        tar xvf /usr/src/kernel/linux-"${latestkernel}".tar.xz --directory /usr/src/kernel/

        rm -rf /usr/src/kernel/linux-"${latestkernel}".tar.xz

        ### Copy kernel config to source directory

        cp /usr/src/kernel/config /usr/src/kernel/linux-"${latestkernel}"/.config

        cd /usr/src/kernel/linux-"${latestkernel}"

        ### Prepare config file

        make olddefconfig

        ### Compile the kernel

        make -j "$(nproc)"

        make INSTALL_MOD_STRIP=1 modules_install

        make install

        ### Rename kernel image and map file to version

        mv /boot/vmlinuz /boot/vmlinuz-"${latestkernel}"

        mv /boot/System.map /boot/System.map-"${latestkernel}"

        ### Update kernelprevious/current files under /boot

        echo "$installedkernel" > /boot/kernelprevious
        echo "$latestkernel" > /boot/kernelcurrent

        ### Remove previous kernel files

        if [ -f "/boot/System.map-${kernelprevious}" ]
        then

            rm "/boot/System.map-${kernelprevious}"

            log "Deleting...." "System.map-$kernelprevious"

        else

            log "Previous System.map not found:" "System.map-$kernelprevious"

        fi


        if [ -f "/boot/vmlinuz-${kernelprevious}" ]
        then

            rm "/boot/vmlinuz-${kernelprevious}"

            log "Deleting previous kernel image...." "vmlinuz-$kernelprevious"

        else

            log "Previous kernel image not found:" "vmlinuz-$kernelprevious"

        fi


        if [ -d "/usr/src/kernel/linux-${kernelprevious}" ]
        then

            rm -rf "/usr/src/kernel/linux-${kernelprevious}"

            log "Deleting previous kernel source...." "/usr/src/kernel/linux-${kernelprevious}"

        else

            log "Previous kernel source not found:" "/usr/src/kernel/linux-${kernelprevious}"

        fi


        ### Update grub config

        grub-mkconfig -o /boot/grub/grub.cfg

    fi

fi
