#!/bin/bash 

# osascript -e 'tell application "Terminal"' -e 'set the bounds of the front window to {24, 96, 524, 396}' -e 'end tell'
# 1. horiz dist from left side of screen to upper-left corner of window
# 2. vert dist from top of screen to upper-left corner of window
# 3. horiz dist from LHS of screen to lower-right corner of window
# 4. vert dist from RHS of screen to lower-right corner of window


osascript -e 'tell app "Terminal" to do script "ssh -t rpi42 watch -d -t lsusb"'
osascript -e 'tell application "Terminal"' -e 'set the bounds of the front window to {1, 1, 500, 500}' -e 'end tell'
osascript -e 'tell app "Terminal" to do script "ssh -t rpi42 dmesg -w"'
osascript -e 'tell application "Terminal"' -e 'set the bounds of the front window to {500, 1, 1000, 500}' -e 'end tell'
osascript -e 'tell app "Terminal" to do script "ssh -t rpi42 tail -f /var/log/syslog"'
osascript -e 'tell application "Terminal"' -e 'set the bounds of the front window to {1000, 1, 1500, 500}' -e 'end tell'
osascript -e 'tell app "Terminal" to do script "ssh -t rpi42 journalctl -f"'
osascript -e 'tell application "Terminal"' -e 'set the bounds of the front window to {1, 550, 500, 1000}' -e 'end tell'
osascript -e 'tell app "Terminal" to do script "ssh -t rpi42 udevadm monitor -kup"'
osascript -e 'tell application "Terminal"' -e 'set the bounds of the front window to {500, 550, 1000, 1000}' -e 'end tell'
osascript -e 'tell app "Terminal" to do script "ssh -t rpi42 watch -d -t /home/pi/usr/bin/idevicepair list "'
osascript -e 'tell application "Terminal"' -e 'set the bounds of the front window to {1000, 550, 1500, 750}' -e 'end tell'
osascript -e 'tell app "Terminal" to do script "ssh -t rpi42 tail -f /home/pi/log.txt "'
osascript -e 'tell application "Terminal"' -e 'set the bounds of the front window to {1000, 750, 1500, 1000}' -e 'end tell'