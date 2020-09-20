#!/bin/bash

echo "$(date) : Welcome to backup-iphone.sh"

export SHELL=/bin/bash
export PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin:$HOME/usr/bin
export LD_LIBRARY_PATH=$HOME/usr/lib

echo "$(date +%Y-%m-%d-%H-%M-%S) \$0=$0 pwd=$(pwd) whoami=$(whoami) START"

# -u: stdout & stderr are unbuffered. Else our tail -f isn't real-time.
python3 -u $HOME/backup-iphone.py >> $HOME/log.txt 2>&1

echo "$(date +%Y-%m-%d-%H-%M-%S) \$0=$0 pwd=$(pwd) whoami=$(whoami) END"
