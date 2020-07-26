#!/bin/sh -e

### Set version variables

export scriptversion="1.2"
export kissversion="1.1"

### Set download variables

export urlinstallfiles="http://10.1.1.21/misc/kiss/${kissversion}/source"


### Virtual Machine check

Make=$(cat /sys/class/dmi/id/sys_vendor 2> /dev/null) 

if [ "$Make" = "QEMU" ]

then

   echo "Machine is a VM - $Make"

   export IsVM="true"

elif [ "$Make" = "VMware" ]

then

   echo "Machine is a VM - $Make"

   export IsVM="true"

else

   echo "Machine is not a VM - $Make"

   export IsVM="false"

fi


### Update Kiss

echo | kiss update


### Build/Install xorg base

for pkg in xorg-server xinit xinput libinput; do
  echo | kiss build $pkg
  kiss install $pkg
done


### Build/Install xorg drivers

if [ "$IsVM" != "true" ]

then

    for pkg in xf86-video-amdgpu xf86-video-intel xf86-video-nouveau xf86-video-vesa xf86-input-libinput; do
      echo | kiss build $pkg
      kiss install $pkg
    done

else

    for pkg in xf86-video-vesa xf86-input-libinput; do
      echo | kiss build $pkg
      kiss install $pkg
    done

fi


### Build/Install xorg utils

for pkg in xset xsetroot xclip fontconfig xrandr; do
  echo | kiss build $pkg
  kiss install $pkg
done


### Build/Install xorg fonts

for pkg in liberation-fonts terminus-font; do
  echo | kiss build $pkg
  kiss install $pkg
done


### Build/Install xorg drivers

if [ $IsVM != "true" ]
then

    for pkg in alsa-lib alsa-utils mesa libdrm intel-vaapi-driver mpv gstreamer gst-plugins gst-plugins-base; do
      echo | kiss build $pkg
      kiss install $pkg
    done

fi


### Build/Install bash

echo | kiss b bash
kiss i bash


### Build/Install window manager

for pkg in dwm dmenu slock rxvt-unicode; do
  echo | kiss build $pkg
  kiss install $pkg
done


### Build/Install community misc

for pkg in htop pfetch imagemagick sxiv ranger w3m xfsprogs; do
  echo | kiss build $pkg
  kiss install $pkg
done


### Install firefox-bin

for pkg in firefox-bin; do
  echo | kiss build $pkg
  kiss install $pkg
done


### Download/extract dotfiles

wget -P /tmp $urlinstallfiles/dotfiles.tar.gz

tar -xvzf /tmp/dotfiles.tar.gz -C /


### Add default user

adduser -k /etc/skel -s /bin/bash user


### Add default user to groups

addgroup user video
addgroup user audio
addgroup user input
addgroup user wheel
