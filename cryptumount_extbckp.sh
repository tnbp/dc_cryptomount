#!/bin/bash

DRIVES="A B"

isMounted () { 
        findmnt -rno SOURCE,TARGET "$1" >/dev/null;
}

STATUS=0

if isMounted "/mnt/extbckp"; then
        echo "Umounting /mnt/extbckp ..."
        umount /mnt/extbckp
        STATUS="$?"
fi

if [ "$STATUS" -ne 0 ]; then
        echo "Could not umount /mnt/extbckp -- exiting!"
        exit 1
fi

for CUR_DRIVE in $DRIVES; do
        if isMounted "/mnt/.extbckp_$CUR_DRIVE"; then
                echo "Umounting /mnt/.extbckp_$CUR_DRIVE ..."
                umount /mnt/.extbckp_$CUR_DRIVE
                STATUS="$?"
        fi

        if [ "$STATUS" -ne 0 ]; then
                echo "Could not umount /mnt/.backup_a -- exiting!"
                exit 1
        fi


        if [ -h /dev/mapper/CRYPTO_EXTBCKP_$CUR_DRIVE ]; then
                echo "Closing crypto volume CRYPTO_EXTBCKP_$CUR_DRIVE ..."
                cryptsetup close CRYPTO_EXTBCKP_$CUR_DRIVE
                STATUS="$?"
        fi

        if [ "$STATUS" -ne 0 ]; then
                echo "Could not close crypto volume CRYPTO_EXTBCKP_$CUR_DRIVE -- exiting!"
                exit 1
        fi

        echo "Successfully crypto-umounted CRYPTO_BACKUP_$CUR_DRIVE!"
        sleep 2
        echo "Detaching..."
        udisksctl power-off -b /dev/disk/by-partlabel/CRYPTO_EXTBCKP_$CUR_DRIVE
done

echo "Syncing..."
sync
