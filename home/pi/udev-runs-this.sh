#!/bin/bash

sleep 3

echo "$(date +%Y-%m-%d-%H-%M-%S) /home/pi/udev-runs-this.sh : about to start backup-iphone.sh | at now." >> "/home/pi/log.txt" 2>&1

echo "/bin/su -c '/home/pi/backup-iphone.sh >> /home/pi/log.txt 2>&1' pi" | at now


echo "$(date +%Y-%m-%d-%H-%M-%S) /home/pi/udev-runs-this.sh : exiting udev-runs-this." >> "/home/pi/log.txt" 2>&1
