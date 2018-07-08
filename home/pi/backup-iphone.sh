#!/bin/bash

export SHELL=/bin/bash
export PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin:/home/pi/usr/bin
export LD_LIBRARY_PATH=/home/pi/usr/lib

echo "$(date) : Welcome to backup-iphone.sh"

# Note: takes 10 sec upon plug-in for iOS to prompt for "Trust".

MOUNT_DIR=/home/pi/usr/mnt
BACKUP_DIR=/home/pi/iphone-backups
LOCKFILE=/home/pi/PHONE_BACKUP_IN_PROGRESS

function is_phone_connected() {
    echo "BEGIN $FUNCNAME." >&2    
    /usr/bin/lsusb | grep -qs "05ac:12a8 Apple, Inc. iPhone5/5C/5S/6"
    RETVAL=$?
    echo "EXITING $FUNCNAME with $RETVAL." >&2
    return $RETVAL
}
function is_paired() {
    echo "BEGIN $FUNCNAME." >&2    
    /usr/bin/test "$(/home/pi/usr/bin/idevicepair list)" != ""
    RETVAL=$?
    echo "EXITING $FUNCNAME with $RETVAL." >&2
    return $RETVAL
}
function is_mounted() {
    echo "BEGIN $FUNCNAME." >&2    
    grep -qs "$MOUNT_DIR " /proc/mounts
    RETVAL=$?
    echo "EXITING $FUNCNAME with $RETVAL." >&2
    return $RETVAL
}
function repeatedly_pair() {
    echo "BEGIN $FUNCNAME." >&2
    RETVAL=1
    for i in `seq 1 30`
    do
	echo "Pairing attempt $i..."
	if /home/pi/usr/bin/idevicepair pair ; then
	    echo "Success!"
	    RETVAL=0
	    break
	fi
	sleep 2
    done
    echo "EXITING $FUNCNAME with $RETVAL." >&2
    return $RETVAL
}

if ! [ -f $LOCKFILE ] ; then
    echo "Locking..."
    touch $LOCKFILE
    echo "Here we go!"
    is_phone_connected && \
	repeatedly_pair && \
	/home/pi/usr/bin/ifuse $MOUNT_DIR && \
	echo "$(date +%Y-%m-%d-%H-%M-%S) backup-iphone.sh : I will rsync now." >> /home/pi/log.txt 2>&1 && \
	/usr/bin/rsync -v -a $MOUNT_DIR $BACKUP_DIR
    echo "If mounted, I'll unmount."
    if is_mounted ; then /bin/fusermount -u $MOUNT_DIR ; fi
    echo "If paired, I'll unpair."
    if is_paired ; then /home/pi/usr/bin/idevicepair unpair ; fi
    echo "sleeping to catch any rogue pairings..."
    sleep 60
    echo "checking for rogue pairings..."
    if is_paired ; then /home/pi/usr/bin/idevicepair unpair ; fi
    echo "Unlocking."
    rm $LOCKFILE
else
    echo "Lockfile $LOCKFILE exists, so not doing anything."
fi


echo "$(date) : goodbye from backup-iphone.sh"
