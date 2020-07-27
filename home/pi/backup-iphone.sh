#!/bin/bash

echo "$(date) : Welcome to backup-iphone.sh"

export SHELL=/bin/bash
export PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin:/home/pi/usr/bin
export LD_LIBRARY_PATH=/home/pi/usr/lib

echo "Running backup-iphone.py..."

# -u: stdout & stderr are unbuffered. Else our tail -f isn't real-time.
python3 -u /home/pi/backup-iphone.py >> /home/pi/log.txt 2>&1

echo "$(date) : goodbye from backup-iphone.sh"
