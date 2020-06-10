#!/bin/bash

# This part is copied from someone else, likely on StackOverflow, but I cannot find the original source...

unset PASSWORD
unset CHARCOUNT

echo -n "Enter password: "

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

# END PLAGIARISM

echo -n $PASSWORD | cryptsetup open /dev/disk/by-uuid/d9e4a022-952b-4cc9-92de-069d0d2344a3 CRYPTO_SERVERVOL -d -
if [ -h /dev/mapper/CRYPTO_SERVERVOL ]; then
        echo "Successfully unlocked CRYPTO_SERVERVOL!"
else
        echo "Could not unlock CRYPTO_SERVERVOL!"
fi
echo -n $PASSWORD | cryptsetup open /dev/disk/by-partlabel/CRYPTO_EXTERNAL_A CRYPTO_EXTERNAL_A -d -
if [ -h /dev/mapper/CRYPTO_EXTERNAL_A ]; then
        echo "Successfully unlocked CRYPTO_EXTERNAL_A!"
else
        echo "Could not unlock CRYPTO_EXTERNAL_A!"
fi
echo -n $PASSWORD | cryptsetup open /dev/disk/by-partlabel/CRYPTO_EXTERNAL_B CRYPTO_EXTERNAL_B -d -
if [ -h /dev/mapper/CRYPTO_EXTERNAL_B ]; then
        echo "Successfully unlocked CRYPTO_EXTERNAL_B!"
else
        echo "Could not unlock CRYPTO_EXTERNAL_B!"
fi
#echo -n $PASSWORD | cryptsetup open /dev/disk/by-partlabel/CRYPTO_BACKUP CRYPTO_BACKUP -d -
#if [ -h /dev/mapper/CRYPTO_BACKUP ]; then
#       echo "Successfully unlocked CRYPTO_BACKUP!"
#else
#       echo "Could not unlock CRYPTO_BACKUP!"
#fi
echo -n $PASSWORD | cryptsetup open /dev/disk/by-uuid/63cd5b65-b693-44a2-99e5-34ecb6a31cfd CRYPTO_EXTVOL -d -
if [ -h /dev/mapper/CRYPTO_EXTVOL ]; then
        echo "Successfully unlocked CRYPTO_EXTVOL!"
else
        echo "Could not unlock CRYPTO_EXTVOL!"
fi

mount -L CRYPTO_SERVERVOL || echo "Could not mount CRYPTO_SERVERVOL!"
mount -L CRY_EXTERNAL_A || echo "Could not mount CRYPTO_EXTERNAL_A!"
mount -L CRY_EXTERNAL_B || echo "Could not mount CRYPTO_EXTERNAL_B!"
#mount -L CRYPTO_BACKUP || echo "Could not mount CRYPTO_BACKUP!"
mount -L CRYPTO_EXTVOL || echo "Could not mount CRYPTO_EXTVOL!"

EXTERNAL_ERROR=0

if [ $(lsblk | grep /mnt/servervol | wc -l) -eq "0" ]; then
        echo "ERROR: Asked to mount CRYPTO_SERVERVOL, but it is not mounted!"
fi
if [ $(lsblk | grep /mnt/.external_a | wc -l) -eq "0" ]; then
        echo "ERROR: Asked to mount CRYPTO_EXTERNAL_A, but it is not mounted!"
        EXTERNAL_ERROR=1
fi
if [ $(lsblk | grep /mnt/.external_b | wc -l) -eq "0" ]; then
        echo "ERROR: Asked to mount CRYPTO_EXTERNAL_B, but it is not mounted!"
        EXTERNAL_ERROR=1
fi
#if [ $(lsblk | grep /mnt/backup | wc -l) -eq "0" ]; then
#       echo "ERROR: Asked to mount CRYPTO_BACKUP, but it is not mounted!"
#fi
if [ $(lsblk | grep /mnt/extvol | wc -l) -eq "0" ]; then
        echo "ERROR: Asked to mount CRYPTO_EXTVOL, but it is not mounted!"
fi

if [ "$EXTERNAL_ERROR" -ne "1" ]; then
        echo "Merging CRYPTO_EXTERNAL_* ..."
        mergerfs -o use_ino,cache.files=off,dropcacheonclose=true,allow_other,category.create=mfs /mnt/.external_\* /mnt/external
        if [ $(mount | grep /mnt/external | wc -l) -eq "0" ]; then
                echo "ERROR: Could not merge CRYPTO_EXTERNAL_*!"
        else
                echo "Merged CRYPTO_EXTERNAL_* to /mnt/external."
        fi
else
        echo "CRYPTO_EXTERNAL_* volumes do not seem ready--not merging!"
        exit 1
fi

#ip link set dev net0 multicast on
systemctl start gerbera
