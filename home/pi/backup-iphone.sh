#!/bin/bash

export SHELL=/bin/bash
export PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin:/home/pi/usr/bin
export LD_LIBRARY_PATH=/home/pi/usr/lib

echo "$(date) : Welcome to backup-iphone.sh"

# Note: takes 10 sec upon plug-in for iOS to prompt for "Trust".

MOUNT_DIR=/home/pi/usr/mnt
BACKUP_DIR=/home/pi/iphone-backups
LOCKFILE=/home/pi/PHONE_BACKUP_IN_PROGRESS

function blinkt_installed() {
    python2 -c 'import blinkt' 2>/dev/null
}
function set_persistent_led() {
    if [ ! blinkt_installed ] ; then echo "no blinkt!" ; return 1 ; fi
    local led_index="$1"
    local led_r="$2"
    local led_g="$3"
    local led_b="$4"
    local cmd="
from blinkt import get_pixel, set_pixel, show, set_clear_on_exit
from pickle import load, dump 
led_file = '/home/pi/leds.pickle'
set_clear_on_exit(False)
old_pixel_values = load(open(led_file,'r'))
map(lambda x: set_pixel(*x), old_pixel_values) 
set_pixel($led_index, $led_r, $led_g, $led_b, 0.07) 
show() 
new_pixel_values = map(lambda i: (i,)+get_pixel(i),range(8))
dump(new_pixel_values,open(led_file,'w'))
"
    python2 -c "$cmd"
}
function led_start_task() {
    set_persistent_led "$1" 255 0 0
}
function led_end_task() {
    set_persistent_led "$1" 0 255 0
}
function led_blue() {
    set_persistent_led "$1" 0 0 255
}
function led_all_off() {
    if [ ! blinkt_installed ] ; then echo "no blinkt!" ; return 1 ; fi
    cp /home/pi/leds_OFF.pickle /home/pi/leds.pickle
    local cmd="from blinkt import show, clear, set_clear_on_exit; set_clear_on_exit(True) ; clear() ; show()"
    python2 -c "$cmd"
}
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
    for i in `seq 1 100`
    do
	echo "Pairing attempt $i..."
	led_blue 2
	if /home/pi/usr/bin/idevicepair pair ; then
	    echo "Success!"
	    RETVAL=0
	    break
	fi
	led_start_task 2
	sleep 2
    done
    echo "EXITING $FUNCNAME with $RETVAL." >&2
    return $RETVAL
}
function iphone_serial_number() {
    local serial_number="$(/home/pi/usr/bin/idevicepair list)"
    if [ -n "$serial_number" ] ; then  # length is nonzero
	echo "$serial_number"
    else
	echo "UNKNOWN_DEVICE_LOL"
    fi
    
}

cp /home/pi/leds_OFF.pickle /home/pi/leds.pickle

led_start_task 0
if ! [ -f $LOCKFILE ] ; then
    led_end_task 0
    echo "Locking..."
    touch $LOCKFILE
    echo "Here we go!"
    led_start_task 1 && is_phone_connected && led_end_task 1 && \
	led_start_task 2 && repeatedly_pair && led_end_task 2 && \
	led_start_task 3 && /home/pi/usr/bin/ifuse $MOUNT_DIR && led_end_task 3 && \
	echo "$(date +%Y-%m-%d-%H-%M-%S) backup-iphone.sh : I will rsync now." >> /home/pi/log.txt 2>&1 && \
	led_start_task 4 && /usr/bin/rsync -v -a $MOUNT_DIR "$BACKUP_DIR/$(iphone_serial_number)" && led_end_task 4
    echo "If mounted, I'll unmount."
    if is_mounted ; then led_start_task 5 ; /bin/fusermount -u $MOUNT_DIR ; led_end_task 5 ; else led_blue 5 ; fi
    echo "If paired, I'll unpair."
    if is_paired ; then led_start_task 6 ; /home/pi/usr/bin/idevicepair unpair ; led_end_task 6 ; else led_blue 6 ; fi
    echo "sleeping to catch any rogue pairings..."
    led_start_task 7
    sleep 60
    echo "checking for rogue pairings..."
    if is_paired ; then led_start_task 7 ; /home/pi/usr/bin/idevicepair unpair ; led_end_task 7 ; else led_blue 7 ; fi
    echo "Unlocking."
    rm $LOCKFILE
else
    led_blue 0
    sleep 1
    echo "Lockfile $LOCKFILE exists, so not doing anything."
fi

sleep 10
led_all_off

echo "$(date) : goodbye from backup-iphone.sh"
