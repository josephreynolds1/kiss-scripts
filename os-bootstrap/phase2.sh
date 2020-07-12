#!/bin/sh -e

scriptversion="1.1"

### Virtual Machine check

Make=$(cat /sys/class/dmi/id/sys_vendor 2> /dev/null) 

if [ "$Make" = "QEMU" ]

then

   echo "Machine is a VM - $Make"

   IsVM="true"

elif [ "$Make" = "VMware" ]

then

   echo "Machine is a VM - $Make"

   IsVM="true"

else

   echo "Machine is not a VM - $Make"

   IsVM="false"

fi


### Set compile flags

export CFLAGS="-O3 -pipe -march=native"
export CXXFLAGS="-O3 -pipe -march=native"
export MAKEFLAGS="-j$(nproc)"


### Build/install gpg

#echo -ne '\n' | kiss b gnupg1
#echo -ne '\n' | kiss i gnupg1

for pkg in gnupg1; do
  echo | kiss build $pkg
  kiss install $pkg
done

### Add/configure kiss repo key

gpg --keyserver keys.gnupg.net --recv-key 46D62DD9F1DE636E
echo trusted-key 0x46d62dd9f1de636e >>/root/.gnupg/gpg.conf

cd /var/db/kiss/repo
git config merge.verifySignatures true


### Update kiss

#echo -ne '\n' | kiss update

#echo -ne '\n' | kiss update

echo | kiss update
echo | kiss update


### Recompile installed apps

#cd /var/db/kiss/installed

#echo -ne '\n' | kiss build *

echo | kiss build $(ls /var/db/kiss/installed)


### Build/Install base apps

#echo -ne '\n' | kiss b e2fsprogs dosfstools util-linux eudev dhcpcd libelf ncurses perl tzdata acpid openssh sudo
#echo -ne '\n' | kiss i e2fsprogs dosfstools util-linux eudev dhcpcd libelf ncurses perl tzdata acpid openssh sudo

for pkg in e2fsprogs dosfstools util-linux eudev dhcpcd libelf ncurses perl tzdata acpid openssh sudo; do
  echo | kiss build $pkg
  kiss install $pkg
done


if [ "$IsVM" != "true" ]

then

    #echo -ne '\n' | kiss b wpa_supplicant
    #echo -ne '\n' | kiss i wpa_supplicant


   for pkg in wpa_supplicant; do
   echo | kiss build $pkg
   kiss install $pkg
   done

fi

cd /root

