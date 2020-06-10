#!/bin/bash

isMounted () { 
        findmnt -rno SOURCE,TARGET "$1" >/dev/null;
}

STATUS=0

if [ -f /mnt/backup/backup_test ]; then
        echo "Umounting /mnt/backup ..."
        umount /mnt/backup
        STATUS="$?"
fi

if [ "$STATUS" -ne 0 ]; then
        echo "Could not umount /mnt/backup -- exiting!"
        exit 1
fi

if isMounted "/mnt/.backup_a"; then
        echo "Umounting /mnt/.backup_a ..."
        umount /mnt/.backup_a
        STATUS="$?"
fi

if [ "$STATUS" -ne 0 ]; then
        echo "Could not umount /mnt/.backup_a -- exiting!"
        exit 1
fi

if isMounted "/mnt/.backup_b"; then
        echo "Umounting /mnt/.backup_b ..."
        umount /mnt/.backup_b
        STATUS="$?"
fi

if [ "$STATUS" -ne 0 ]; then
        echo "Could not umount /mnt/.backup_b -- exiting!"
        exit 1
fi

if [ -h /dev/mapper/CRYPTO_BACKUP_A ]; then
        echo "Closing crypto volume CRYPTO_BACKUP_A ..."
        cryptsetup close CRYPTO_BACKUP_A
        STATUS="$?"
fi

if [ "$STATUS" -ne 0 ]; then
        echo "Could not close crypto volume CRYPTO_BACKUP_A -- exiting!"
        exit 1
fi

echo "Successfully crypto-umounted CRYPTO_BACKUP_A!"

if [ -h /dev/mapper/CRYPTO_BACKUP_B ]; then
        echo "Closing crypto volume CRYPTO_BACKUP_B ..."
        cryptsetup close CRYPTO_BACKUP_B
        STATUS="$?"
fi

if [ "$STATUS" -ne 0 ]; then
        echo "Could not close crypto volume CRYPTO_BACKUP_B -- exiting!"
        exit 1
fi

echo "Successfully crypto-umounted CRYPTO_BACKUP_B!"

echo "Detaching..."
udisksctl power-off -b /dev/disk/by-partlabel/CRYPTO_BACKUP_A
udisksctl power-off -b /dev/disk/by-partlabel/CRYPTO_BACKUP_B

echo "Syncing..."
sync

echo "Turning off the power..."
/opt/datacubic_relaycontrol.py -c 0
