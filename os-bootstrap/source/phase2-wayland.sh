#!/bin/sh -e

### Variables #################################################################

### Set version variables

export scriptversion="1.0"


### Disable Kiss prompts

export KISS_PROMPT=0


### Source scriptvars

source ./scriptvars.sh


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
    getScriptDuration
    export KISS_PROMPT=1
    exit 1
}


getScriptDuration() {

  scriptend=$(date +%s)
  scriptendfriendly=$(date)

  duration=$((scriptend - scriptstart))

  output=$(printf '%dh:%dm:%ds\n' $((duration/3600)) $((duration%3600/60)) $((duration%60)))

  log "Script start time:" "$scriptstartfriendly"
  log "Script end time:" "$scriptendfriendly"
  log "Script execution duration:" "$output"

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

appValidation()
{
    for app in "$@" ; do

        if  kiss s "${app}" | grep 'installed' > /dev/null 2>&1; then

            log "$app" "Good"

        else

            war "$app" "Missing"

        fi
    done
}


### Main script body ##########################################################

scriptstart=$(date +%s)
scriptstartfriendly=$(date)

log "Kiss Linux bootstrap phase2 version:" "${scriptversion}"
log "Script start time:" "$scriptstartfriendly"


### Update Kiss

log "Performing Kiss update"

    kiss update


### Build/Install wayland and desktop applications

log "Installing Wayland and Base Desktop Applications"

    kiss b sway && kiss i sway || die "$?" "Failed to install package"
    kiss b foot && kiss i foot || die "$?" "Failed to install package"
	kiss b wl-clipboard && kiss i wl-clipboard || die "$?" "Failed to install package"
	kiss b grim && kiss i grim || die "$?" "Failed to install package"
	kiss b slurp && kiss i slurp || die "$?" "Failed to install package"
	kiss b wofi && kiss i wofi || die "$?" "Failed to install package" 

    kiss b alsa-utils && kiss i alsa-utils || die "$?" "Failed to install package"
    kiss b htop && kiss i htop || die "$?" "Failed to install package"
    kiss b fontconfig && kiss i fontconfig || die "$?" "Failed to install package"
    kiss b liberation-fonts && kiss i liberation-fonts || die "$?" "Failed to install package"
    kiss b terminus-font && kiss i terminus-font || die "$?" "Failed to install package"
    kiss b imagemagick && kiss i imagemagick || die "$?" "Failed to install package"
    kiss b firefox && kiss i firefox || die "$?" "Failed to install package"
    kiss b bash && kiss i bash || die "$?" "Failed to install package"
    kiss b pciutils && kiss i pciutils || die "$?" "Failed to install package"
    kiss b usbutils && kiss i usbutils || die "$?" "Failed to install package"
    kiss b vim && kiss i vim || die "$?" "Failed to install package"

### Add default user

mkdir -p /etc/skel || war "$?" "Failed to create /etc/skel directory"

adduser -k /etc/skel user || die "$?" "Failed to add default user"


### Add default user to groups

addgroup user video || war "$?" "Failed to add default user to the following group" "video"
addgroup user audio || war "$?" "Failed to add default user to the following group" "audio"
addgroup user input || war "$?" "Failed to add default user to the following group" "input"
addgroup user wheel || war "$?" "Failed to add default user to the following group" "wheel"


### Enable Kiss prompts

export KISS_PROMPT=1


### Validating phase1 app installation

  log "Validating phase1 app installation"

  appValidation sway foot wl-clipboard grim slurp wofi alsa-utils htop fontconfig liberation-fonts terminus-font imagemagick firefox bash pciutils usbutils vim


### Generate script duration

  getScriptDuration
