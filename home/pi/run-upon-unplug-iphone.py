#!/usr/bin/python3

# Blink the LEDs once to indicate the phone has been unplugged.

from blinkt import set_all, show, clear
from time import sleep
set_all(255,255,255)
show()
sleep(1)
clear()
show()

