#!/bin/bash

DRIVES="A B"

echo -e "\e[1m[\e[95m*\e[39m]\e[0m Checking if backup drives are available..."

for CUR_DRIVE in $DRIVES; do
        if [ ! -h "/dev/disk/by-partlabel/CRYPTO_EXTBCKP_$CUR_DRIVE" ]; then
                echo -e "\e[1m[\e[91m-\e[39m]\e[0m Could not find drive /dev/disk/by-partlabel/CRYPTO_EXTBCKP_$CUR_DRIVE -- aborting!"
                exit 1
        fi
done

echo -e "\e[1m[\e[95m*\e[39m]\e[0m All drives available! Unlocking..."

unset PASSWORD
unset CHARCOUNT

echo -ne "\e[1m[\e[96m?\e[39m]\e[0m Enter password: "

stty -echo

CHARCOUNT=0
while IFS= read -p "$PROMPT" -r -s -n 1 CHAR
do
    # Enter - accept password
    if [[ $CHAR == $'\0' ]] ; then
        break
    fi
    # Backspace
    if [[ $CHAR == $'\177' ]] ; then
        if [ $CHARCOUNT -gt 0 ] ; then
            CHARCOUNT=$((CHARCOUNT-1))
            PROMPT=$'\b \b'
            PASSWORD="${PASSWORD%?}"
        else
            PROMPT=''
        fi
    else
        CHARCOUNT=$((CHARCOUNT+1))
        PROMPT='*'
        PASSWORD+="$CHAR"
    fi
done

stty echo
echo

for CUR_DRIVE in $DRIVES; do
        echo -n $PASSWORD | cryptsetup open /dev/disk/by-partlabel/CRYPTO_EXTBCKP_$CUR_DRIVE CRYPTO_EXTBCKP_$CUR_DRIVE -d -
        if [ -h /dev/mapper/CRYPTO_EXTBCKP_$CUR_DRIVE ]; then
                echo -e "\e[1m[\e[92m+\e[39m]\e[0m Successfully unlocked CRYPTO_EXTBCKP_$CUR_DRIVE!"
        else
                echo -e "\e[1m[\e[91m-\e[39m]\e[0m Could not unlock CRYPTO_EXTBCKP_$CUR_DRIVE -- exiting!"
                exit 1
        fi
        mount -L CRYPTO_EXTBCKP_$CUR_DRIVE
        if [ $? -ne 0 ]; then
                echo -e "\e[1m[\e[91m-\e[39m]\e[0m Could not mount CRYPTO_EXTBCKP_$CUR_DRIVE -- exiting!"
                exit 1
        fi
        if [ $(lsblk | grep /mnt/.extbckp_$CUR_DRIVE | wc -l) -eq "0" ]; then
                echo -e "\e[1m[\e[91m-\e[39m]\e[0m Asked to mount CRYPTO_EXTBCKP_$CUR_DRIVE, but it is not mounted -- exiting!"
                exit 1
        fi
done

echo -e "\e[1m[\e[95m*\e[39m]\e[0m Merging CRYPTO_EXTBCKP_* ..."
mergerfs -o use_ino,cache.files=off,dropcacheonclose=true,allow_other,category.create=mfs /mnt/.extbckp_\* /mnt/extbckp
if [ $(mount | grep /mnt/extbckp | wc -l) -eq "0" ]; then
        echo -e "\e[1m[\e[91m-\e[39m]\e[0m Could not merge CRYPTO_EXTBCKP_*!"
        exit 1
else
        echo -e "\e[1m[\e[92m+\e[39m]\e[0m Merged CRYPTO_EXTBCKP_* to /mnt/extbckp."
fi
