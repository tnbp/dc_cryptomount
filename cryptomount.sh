#!/bin/bash

unset PASSWORD
unset CHARCOUNT

echo -ne "\e[1m[\e[96m?\e[39m\e[0m] Enter password: "

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

echo -n $PASSWORD | cryptsetup open /dev/disk/by-uuid/d9e4a022-952b-4cc9-92de-069d0d2344a3 CRYPTO_SERVERVOL -d -
if [ -h /dev/mapper/CRYPTO_SERVERVOL ]; then
        echo -e "\e[1m[\e[92m+\e[39m]\e[0m Successfully unlocked CRYPTO_SERVERVOL!"
else
        echo -e "\e[1m[\e[91m-\e[39m]\e[0m Could not unlock CRYPTO_SERVERVOL!"
fi
echo -n $PASSWORD | cryptsetup open /dev/disk/by-partlabel/CRYPTO_EXTERNAL_A CRYPTO_EXTERNAL_A -d -
if [ -h /dev/mapper/CRYPTO_EXTERNAL_A ]; then
        echo -e "\e[1m[\e[92m+\e[39m]\e[0m Successfully unlocked CRYPTO_EXTERNAL_A!"
else
        echo -e "\e[1m[\e[91m-\e[39m]\e[0m Could not unlock CRYPTO_EXTERNAL_A!"
fi
echo -n $PASSWORD | cryptsetup open /dev/disk/by-partlabel/CRYPTO_EXTERNAL_B CRYPTO_EXTERNAL_B -d -
if [ -h /dev/mapper/CRYPTO_EXTERNAL_B ]; then
        echo -e "\e[1m[\e[92m+\e[39m]\e[0m Successfully unlocked CRYPTO_EXTERNAL_B!"
else
        echo -e "\e[1m[\e[91m-\e[39m]\e[0m Could not unlock CRYPTO_EXTERNAL_B!"
fi
echo -n $PASSWORD | cryptsetup open /dev/disk/by-partlabel/CRYPTO_EXTERNAL_C CRYPTO_EXTERNAL_C -d -
if [ -h /dev/mapper/CRYPTO_EXTERNAL_C ]; then
        echo -e "\e[1m[\e[92m+\e[39m]\e[0m Successfully unlocked CRYPTO_EXTERNAL_C!"
else
        echo -e "\e[1m[\e[91m-\e[39m]\e[0m Could not unlock CRYPTO_EXTERNAL_C!"
fi
#echo -n $PASSWORD | cryptsetup open /dev/disk/by-partlabel/CRYPTO_BACKUP CRYPTO_BACKUP -d -
#if [ -h /dev/mapper/CRYPTO_BACKUP ]; then
#       echo -e "\e[1m[\e[92m+\e[39m]\e[0m Successfully unlocked CRYPTO_BACKUP!"
#else
#       echo -e "\e[1m[\e[91m-\e[39m]\e[0m Could not unlock CRYPTO_BACKUP!"
#fi
echo -n $PASSWORD | cryptsetup open /dev/disk/by-uuid/63cd5b65-b693-44a2-99e5-34ecb6a31cfd CRYPTO_EXTVOL -d -
if [ -h /dev/mapper/CRYPTO_EXTVOL ]; then
        echo -e "\e[1m[\e[92m+\e[39m]\e[0m Successfully unlocked CRYPTO_EXTVOL!"
else
        echo -e "\e[1m[\e[91m-\e[39m]\e[0m Could not unlock CRYPTO_EXTVOL!"
fi

mount -L CRYPTO_SERVERVOL || echo -e "\e[1m[\e[91m-\e[39m]\e[0m Could not mount CRYPTO_SERVERVOL!"
mount -L CRY_EXTERNAL_A || echo -e "\e[1m[\e[91m-\e[39m]\e[0m Could not mount CRYPTO_EXTERNAL_A!"
mount -L CRY_EXTERNAL_B || echo -e "\e[1m[\e[91m-\e[39m]\e[0m Could not mount CRYPTO_EXTERNAL_B!"
mount -L CRY_EXTERNAL_C || echo -e "\e[1m[\e[91m-\e[39m]\e[0m Could not mount CRYPTO_EXTERNAL_C!"
#mount -L CRYPTO_BACKUP || echo -e "\e[1m[\e[91m-\e[39m]\e[0m Could not mount CRYPTO_BACKUP!"
mount -L CRYPTO_EXTVOL || echo -e "\e[1m[\e[91m-\e[39m]\e[0m Could not mount CRYPTO_EXTVOL!"

EXTERNAL_ERROR=0

if [ $(lsblk | grep /mnt/servervol | wc -l) -eq "0" ]; then
        echo -e "\e[1m[\e[91m-\e[39m]\e[0m Asked to mount CRYPTO_SERVERVOL, but it is not mounted!"
fi
if [ $(lsblk | grep /mnt/.external_a | wc -l) -eq "0" ]; then
        echo -e "\e[1m[\e[91m-\e[39m]\e[0m Asked to mount CRYPTO_EXTERNAL_A, but it is not mounted!"
        EXTERNAL_ERROR=1
fi
if [ $(lsblk | grep /mnt/.external_b | wc -l) -eq "0" ]; then
        echo -e "\e[1m[\e[91m-\e[39m]\e[0m Asked to mount CRYPTO_EXTERNAL_B, but it is not mounted!"
        EXTERNAL_ERROR=1
fi
if [ $(lsblk | grep /mnt/.external_c | wc -l) -eq "0" ]; then
        echo -e "\e[1m[\e[91m-\e[39m]\e[0m Asked to mount CRYPTO_EXTERNAL_C, but it is not mounted!"
        EXTERNAL_ERROR=1
fi
#if [ $(lsblk | grep /mnt/backup | wc -l) -eq "0" ]; then
#       echo -e "\e[1m[\e[91m-\e[39m]\e[0m Asked to mount CRYPTO_BACKUP, but it is not mounted!"
#fi
if [ $(lsblk | grep /mnt/extvol | wc -l) -eq "0" ]; then
        echo -e "\e[1m[\e[91m-\e[39m]\e[0m Asked to mount CRYPTO_EXTVOL, but it is not mounted!"
fi

if [ "$EXTERNAL_ERROR" -ne "1" ]; then
        echo -e "\e[1m[\e[95m*\e[39m]\e[0m Merging CRYPTO_EXTERNAL_* ..."
        mergerfs -o use_ino,cache.files=off,dropcacheonclose=true,allow_other,category.create=mfs /mnt/.external_\* /mnt/external
        if [ $(mount | grep /mnt/external | wc -l) -eq "0" ]; then
                echo -e "\e[1m[\e[91m-\e[39m]\e[0m Could not merge CRYPTO_EXTERNAL_*!"
        else
                echo -e "\e[1m[\e[92m+\e[39m]\e[0m Merged CRYPTO_EXTERNAL_* to /mnt/external."
        fi
else
        echo -e "\e[1m[\e[91m-\e[39m]\e[0m CRYPTO_EXTERNAL_* volumes do not seem ready--not merging!"
        exit 1
fi

#ip link set dev net0 multicast on
echo -e "\e[1m[\e[92m*\e[39m]\e[0m Starting gerbera media server..."
systemctl start gerbera
systemctl is-active --quiet gerbera
if [ $? -eq 0 ]; then
        echo -e "\e[1m[\e[92m+\e[39m]\e[0m gerbera is running!"
else
        echo -e "\e[1m[\e[91m-\e[39m]\e[0m gerbera is not running!"
fi
