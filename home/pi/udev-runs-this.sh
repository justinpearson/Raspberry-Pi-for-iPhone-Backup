#!/bin/bash

echo "udev-runs-this.sh: START" >> "/home/pi/log.txt" 2>&1

sleep 3

echo "$(date +%Y-%m-%d-%H-%M-%S) \$0=$0 pwd=$(pwd) whoami=$(whoami) START"    >> "/home/pi/log.txt" 2>&1
echo "About to start backup-iphone.sh | at now."                              >> "/home/pi/log.txt" 2>&1

echo "/bin/su -c '/home/pi/backup-iphone.sh >> /home/pi/log.txt 2>&1' pi" | at now

echo "$(date +%Y-%m-%d-%H-%M-%S) \$0=$0 pwd=$(pwd) whoami=$(whoami) END"      >> "/home/pi/log.txt" 2>&1

echo "udev-runs-this.sh: END" >> "/home/pi/log.txt" 2>&1
