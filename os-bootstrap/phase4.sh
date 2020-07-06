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


### Set version variables

kissversion="1.1"


### Set download variables

urlinstallfiles="http://10.1.1.21/misc/kiss/${kissversion}/files"


### Update Kiss

#echo -ne '\n' | kiss update

echo | kiss update

### Build/Install xorg base

#echo -ne '\n' | kiss b xorg-server xinit xinput libinput
#echo -ne '\n' | kiss i xorg-server xinit xinput libinput

for pkg in xorg-server xinit xinput libinput; do
  echo | kiss build $pkg
  kiss install $pkg
done


### Build/Install xorg drivers

if [ "$IsVM" != "true" ]

then

    #echo -ne '\n' | kiss b xf86-video-amdgpu xf86-video-intel xf86-video-nouveau xf86-video-vesa xf86-input-libinput
    #echo -ne '\n' | kiss i xf86-video-amdgpu xf86-video-intel xf86-video-nouveau xf86-video-vesa xf86-input-libinput

    for pkg in xf86-video-amdgpu xf86-video-intel xf86-video-nouveau xf86-video-vesa xf86-input-libinput; do
      echo | kiss build $pkg
      kiss install $pkg
    done

else

    #echo -ne '\n' | kiss b xf86-video-vesa xf86-input-libinput
    #echo -ne '\n' | kiss i xf86-video-vesa xf86-input-libinput

    for pkg in xf86-video-vesa xf86-input-libinput; do
      echo | kiss build $pkg
      kiss install $pkg
    done

fi


### Build/Install xorg utils

#echo -ne '\n' | kiss b xset xsetroot xclip fontconfig xrandr
#echo -ne '\n' | kiss i xset xsetroot xclip fontconfig xrandr

for pkg in xset xsetroot xclip fontconfig xrandr; do
  echo | kiss build $pkg
  kiss install $pkg
done


### Build/Install xorg fonts

#echo -ne '\n' | kiss b liberation-fonts terminus-font
#echo -ne '\n' | kiss i liberation-fonts terminus-font

for pkg in liberation-fonts terminus-font; do
  echo | kiss build $pkg
  kiss install $pkg
done


### Build/Install xorg drivers

if [ $IsVM != "true" ]
then

    #echo -ne '\n' | kiss b alsa-lib alsa-utils mesa libdrm intel-vaapi-driver mpv gstreamer gst-plugins gst-plugins-base
    #echo -ne '\n' | kiss i alsa-lib alsa-utils mesa libdrm intel-vaapi-driver mpv gstreamer gst-plugins gst-plugins-base

    for pkg in alsa-lib alsa-utils mesa libdrm intel-vaapi-driver mpv gstreamer gst-plugins gst-plugins-base; do
      echo | kiss build $pkg
      kiss install $pkg
    done

fi


### Build/Install bash

#echo -ne '\n' | kiss b bash
#echo -ne '\n' | kiss i bash

echo | kiss b bash
kiss i bash

### Build/Install window manager

#echo -ne '\n' | kiss b dwm dmenu st slock
#echo -ne '\n' | kiss i dwm dmenu st slock

for pkg in dwm dmenu slock rxvt-unicode; do
  echo | kiss build $pkg
  kiss install $pkg
done


### Build/Install community misc

#echo -ne '\n' | kiss b htop neofetch imagemagick sxiv ranger w3m xfsprogs
#echo -ne '\n' | kiss i htop neofetch imagemagick sxiv ranger w3m xfsprogs

for pkg in htop pfetch imagemagick sxiv ranger w3m xfsprogs; do
  echo | kiss build $pkg
  kiss install $pkg
done


### Install firefox-bin

#echo -ne '\n' | kiss b firefox-bin
#echo -ne '\n' | kiss i firefox-bin

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

