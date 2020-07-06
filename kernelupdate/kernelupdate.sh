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
    touch "/boot/kernelprevious"

fi

if [ -f /boot/kernelcurrent ]
then

    kernelcurrent=$(cat /boot/kernelcurrent)

    echo "Kernelcurrent file set value: $kernelcurrent"

else
    
    echo "/boot/kernelcurrent file not found"
    touch "/boot/kernelcurrent"

fi

echo ""
echo "Installed Linux kernel: $installedkernel"


### Get latest kernel.org stable version

latestkernel=$(wget -q --output-document - https://www.kernel.org/ | grep -A 1 "latest_link")

latestkernel=${latestkernel##*.tar.xz\">}

latestkernel=${latestkernel%</a>}

echo "Stable version from Kernel.org: $latestkernel"

if [ "$latestkernel" = "$installedkernel" ]

then
    
    echo ""
    echo "Kernel is already latest version"
    echo ""

else

    echo ""
    echo "Newer kernel available!"

    urlkernel="https://cdn.kernel.org/pub/linux/kernel/v5.x/linux-${latestkernel}.tar.xz"

    echo ""
    echo "Would you like to update the Linux Kernel to $latestkernel (y/n)? "
    read -r answer

    if [ "$answer" != "${answer#[Yy]}" ] ;then
        
            echo Updating kernel....

            ## Download Kernel

            echo "Downloading kernel from: ${urlkernel}"

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

                echo "Deleting.... System.map-$kernelprevious"

            else
                
                echo "Previous System.map not found: System.map-$kernelprevious"

            fi


            if [ -f "/boot/vmlinuz-${kernelprevious}" ]
            then

                rm "/boot/vmlinuz-${kernelprevious}"

                echo "Deleting previous kernel image.... vmlinuz-$kernelprevious"

            else
                
                echo "Previous kernel image not found: vmlinuz-$kernelprevious"

            fi


            if [ -d "/usr/src/kernel/linux-${kernelprevious}" ]
            then

                rm -rf "/usr/src/kernel/linux-${kernelprevious}"

                echo "Deleting previous kernel source.... /usr/src/kernel/linux-${kernelprevious}"

            else
                
                echo "Previous kernel source not found: /usr/src/kernel/linux-${kernelprevious}"

            fi
            
 
            ### Update grub config

            grub-mkconfig -o /boot/grub/grub.cfg

    fi

fi