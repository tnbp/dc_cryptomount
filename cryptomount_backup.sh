#!/bin/bash

echo "Enabling backup drives..."
/opt/datacubic_relaycontrol.py -c 1

if [[ "$?" -ne 0 ]]; then
        echo "Could not enable backup drives--exiting!"
        exit 1
fi

echo "Success! Allowing 10 seconds for devices to get ready..."

sleep 10

# BEGIN PLAGIARISM

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

echo -n $PASSWORD | cryptsetup open /dev/disk/by-partlabel/CRYPTO_BACKUP_A CRYPTO_BACKUP_A -d -
if [ -h /dev/mapper/CRYPTO_BACKUP_A ]; then
        echo "Successfully unlocked CRYPTO_BACKUP_A!"
else
        echo "Could not unlock CRYPTO_BACKUP_A!"
fi
echo -n $PASSWORD | cryptsetup open /dev/disk/by-partlabel/CRYPTO_BACKUP_B CRYPTO_BACKUP_B -d -
if [ -h /dev/mapper/CRYPTO_BACKUP_B ]; then
        echo "Successfully unlocked CRYPTO_BACKUP_B!"
else
        echo "Could not unlock CRYPTO_BACKUP_B!"
fi

mount -L CRYPTO_BACKUP_A || echo "Could not mount CRYPTO_BACKUP_A!"
mount -L CRYPTO_BACKUP_B || echo "Could not mount CRYPTO_BACKUP_B!"

BACKUP_ERROR=0

if [ $(lsblk | grep /mnt/.backup_a | wc -l) -eq "0" ]; then
        echo "ERROR: Asked to mount CRYPTO_BACKUP_A, but it is not mounted!"
        BACKUP_ERROR=1
fi
if [ $(lsblk | grep /mnt/.backup_b | wc -l) -eq "0" ]; then
        echo "ERROR: Asked to mount CRYPTO_BACKUP_B, but it is not mounted!"
        BACKUP_ERROR=1
fi

if [ "$BACKUP_ERROR" -ne 1 ]; then
        echo "Merging CRYPTO_BACKUP_* ..."
        mergerfs -o use_ino,cache.files=off,dropcacheonclose=true,allow_other,category.create=mfs /mnt/.backup_\* /mnt/backup
        if [ $(mount | grep /mnt/backup | wc -l) -eq "0" ]; then
                echo "ERROR: Could not merge CRYPTO_BACKUP_*!"
        else
                echo "Merged CRYPTO_BACKUP_* to /mnt/backup."
        fi
else
        echo "CRYPTO_BACKUP_* volumes do not seem ready--not merging!"
fi
