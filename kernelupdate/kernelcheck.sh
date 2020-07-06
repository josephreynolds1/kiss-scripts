#!/bin/sh -e

### Get current kernel version

installedkernel=$(uname -r)

echo ""

if [ -f /boot/kernelprevious ]
then

    kernelprevious=$(cat /boot/kernelprevious)

    echo "Kernelprevious file set value: $kernelprevious"

else
    
    echo "/boot/kernelprevious file not found"

fi

if [ -f /boot/kernelcurrent ]
then

    kernelcurrent=$(cat /boot/kernelcurrent)

    echo "Kernelcurrent file set value: $kernelcurrent"

else
    
    echo "/boot/kernelcurrent file not found"

fi



echo ""
echo "Installed Linux kernel: $installedkernel"


### Get latest kernel.org stable version

latestkernel=$(wget -q --output-document - https://www.kernel.org/ | grep -A 1 "latest_link")

latestkernel=${latestkernel##*.tar.xz\">}

latestkernel=${latestkernel%</a>}

echo ""
echo "Stable version from Kernel.org: $latestkernel"

if [ "$latestkernel" = "$installedkernel" ]

then

    echo ""
    echo "Kernel is already latest version"
    echo ""

else

    echo ""
    echo "Newer kernel available!"
    echo "Run KernelUpdate.sh to update the Linux kernel"
    echo ""

fi