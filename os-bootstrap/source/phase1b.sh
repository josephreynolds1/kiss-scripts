#!/bin/sh -e

### Variables #################################################################

export KISS_PROMPT=0

source ./scriptvars.sh

if [ -z "$hostname" ]; then

    export hostname="kiss"

fi


if [ -z "$domain" ]; then

    export domain="localdomain"

fi


if [ -z "$rootpw" ]; then

    export rootpw="kiss"

fi

### Set color variables

export lcol='\033[1;33m'
export lcol2='\033[1;36m'
export lclr='\033[m'

### Set compile flag variables

export CFLAGS="${commonflags}"
export CXXFLAGS="${commonflags}"
export MAKEFLAGS="-j${cpucount}"


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

kiss b gnupg1 && kiss i gnupg1

gpg --keyserver keys.gnupg.net --recv-key 46D62DD9F1DE636E
echo trusted-key 0x46d62dd9f1de636e >>/root/.gnupg/gpg.conf

cd /var/db/kiss/repo
git config merge.verifySignatures true

kiss update
kiss update

cd /var/db/kiss/installed && kiss build *

  kiss b e2fsprogs && kiss i e2fsprogs
  kiss b dosfstools && kiss i dosfstools
  kiss b xfsprogs && kiss i xfsprogs
  kiss b util-linux && kiss i util-linux
  kiss b eudev && kiss i eudev
  kiss b openssh && kiss i openssh
  kiss b libelf && kiss i dhcpcd
  kiss b libelf && kiss i tzdata
  kiss b libelf && kiss i acpid
  kiss b sudo && kiss i sudo

  if [ "$IsVM" != "true" ]

  then
       kiss b wpa_supplicant &&  kiss i wpa_supplicant
  fi


kiss b libelf && kiss i libelf
kiss b ncurses && kiss i ncurses

if [ "$IsVM" != "true" ]

then

    log "Creating linux firmware directory" "/usr/lib/firmware"

    mkdir -p /usr/lib/firmware

    ### Clone linux-firmware git repository

      log "Cloning linux-firmware git repository"

      cd && git clone "$urlfirmware"

      log "Copying linux firmware files" "/usr/lib/firmware"

      cp -R linux-firmware/* /usr/lib/firmware/ /usr/lib/firmware/ || war "$?" "Failed to copy firmware files to /usr/lib/firmware"

fi

### Copy kernel config to kernel source directory

  log "Copy kernel config to kernel source directory"

  cp "/usr/src/kernel/config" "/usr/src/kernel/linux-${kernelversion}/.config" || die "$?" "Failed to copy default kernel config to /usr/src/kernel/linux-${kernelversion}"


### Change to kernel source directory

  cd "/usr/src/kernel/linux-${kernelversion}"


### Prepare linux kernel configuration

  log "Prepare linux kernel configuration"

  make olddefconfig || die "$?" "Failed kernel config preperation"


### Compile the kernel

  log "Compiling the kernel"

  make -j "$(nproc)"

### Install kernel modules

  log "Install kernel modules"

  make INSTALL_MOD_STRIP=1 modules_install || die "$?" "Failed to install kernel modules"


### Install kernel to /boot

  log "Installing kernel" "/boot"

  make install || die "$?" "Failed kernel install"


### Rename kernel files

  log "Renaming vmlinux to vmlinuz-${kernelversion}"

  mv /boot/vmlinuz "/boot/vmlinuz-${kernelversion}" || die "$?" "Failed to rename kernel image"

  log "Renaming System.map to System.map-${kernelversion}"

  mv /boot/System.map "/boot/System.map-${kernelversion}" || die "$?" "Failed to rename System.map"


  log "Creating directory" "/boot/efi"

  mkdir /boot/efi || die "$?" "Failed to create /boot/efi directory"

### Mount efi partition to /boot/efi

  log "Mounting efi boot partition /dev/${diskchoice}1 to /boot/efi"

  mount -t vfat "/dev/${diskchoice}1" /boot/efi || die "$?" "Failed to mount boot partition /dev/${diskchoice}1 on /boot/efi"

### Install grub for efi

  log "Installing grub for efi" "/boot/efi"

  grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=Kiss || die "$?" "Grub bootloader install failed"

### Generate grub config

  log "Generating grub configuration" "/boot/grub/grub.cfg"

  grub-mkconfig -o /boot/grub/grub.cfg || die "$?" "Failed generate grub.cfg"


kiss b baseinit && kiss i baseinit

ln -s /etc/sv/dhcpcd /var/service
#ln -s /etc/sv/acpid /var/service
ln -s /etc/sv/syslogd /var/service
ln -s /etc/sv/sshd /var/service
ln -s /etc/sv/udevd /var/service

### Configure timezone to EST

  log "Setting timezone" "$timezone"

  rm -rf /etc/localtime
  ln -s /usr/share/zoneinfo/America/New_York /etc/localtime

### Set hostname

  log "Setting hostname:" "${hostname}.${domain}"

  echo "${hostname}.${domain}" > /etc/hostname || war "$?" "Failed to set hostname"

  log "Updating /etc/hosts file with hostname/domain" "${hostname}.${domain}"

  /bin/cat <<EOM >"/etc/hosts"
  127.0.0.1  ${hostname}.S{domain}  ${hostname}
  ::1        ${hostname}.S{domain}  ${hostname}  ip6-localhost

  EOM

### Set compiler options /etc/profile

  log "Adding compiler options to /etc/profile"

  /bin/cat <<EOM >> "/etc/profile"

  export CFLAGS="${commonflags}"
  export CXXFLAGS="${commonflags}"
  export MAKEFLAGS="-j${cpucount}"
  EOM


### Set root password

  log "Setting root password"

  echo "root:${rootpw}" | chpasswd

#exit && cd

