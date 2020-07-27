#!/usr/bin/env python3

print('Hello from backup-iphone.py!')

import blinkt
blinkt.set_clear_on_exit(False)

import os, time, subprocess
from datetime import datetime

###############################################

# Probably needed since we built idevicepair & friends
# from source in /home/pi/usr/ :

import sys

sys.path.append('/home/pi/usr/bin')

# export SHELL = '/bin/bash'
# export PATH = '/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin:/home/pi/usr/bin'
# export LD_LIBRARY_PATH = '/home/pi/usr/lib'

# Note: takes 10 sec upon plug-in for iOS to prompt for "Trust".

MOUNT_DIR = '/home/pi/usr/mnt'
BACKUP_DIR_BASE = '/home/pi/iphone-backups'
LOCKFILE = '/home/pi/PHONE_BACKUP_IN_PROGRESS'

##############################################

def main():
    print(f'{datetime.now()}: Welcome to backup-iphone.sh!')

    if not os.path.isdir(BACKUP_DIR_BASE):
        print(f'No backup dir exists, creating {BACKUP_DIR_BASE} ...')
        os.mkdir(BACKUP_DIR_BASE)

    leds = LEDs()
    leds.test()
    t = 0 # which task are we on (0-7)

    print('Plugged in?')
    leds.begin_task(t)
    run_repeatedly(
        plug_in,
        is_plugged_in
    )
    leds.task_completed(t)
    t += 1

    print('Pairing...')
    leds.begin_task(t)
    run_repeatedly(
        pair,
        is_paired
    )
    leds.task_completed(t)
    t += 1
    
    print('Mounting...')
    leds.begin_task(t)
    run_repeatedly(
        mount,
        is_mounted
    )
    leds.task_completed(t)
    t += 1
    
    print('Backing up...')
    leds.begin_task(t)
    backup()
    leds.task_completed(t)
    t += 1
    
    print('Unmounting...')
    leds.begin_task(t)
    run_repeatedly(
        unmount,
        is_unmounted
    )
    leds.task_completed(t)
    t += 1
    
    print('Unpairing...')
    leds.begin_task(t)
    run_repeatedly(
        unpair,
        is_unpaired
    )

    leds.task_completed(t)
    t += 1
    
    print(f'{datetime.now()}: Bye from backup-iphone.sh!')


#############################################

def run(arg_list):
    print('Running:')
    print(arg_list)
    p = subprocess.run(
        arg_list,
        capture_output=True,
        universal_newlines=True
        )
    print(f'returncode: "{p.returncode}"')
    print(f'stdout: "{p.stdout}"')
    print(f'stderr: "{p.stderr}"')

    return p

def run_repeatedly(f, check, imax=10, twait=2):
    '''
    Gonna run f()={f.__name__} 
    until check()={check.__name__} returns true, 
    up to imax={imax} times, 
    pausing twait={twait} secs btwn each run.
    '''

    if check():
        print(f'Check={check.__name__} succeeded without even running f={f.__name__} once!')
        return

    i=0
    while i <= imax:
        i += 1
        print(f'Running f={f.__name__}, attempt {i}/{imax}...')
        f()
        print(f'Checking {check.__name__}...')
        if check():
            print('Success!')
            return
        else:
            if i == imax:
                raise RuntimeError(f'{f.__name__} failed {imax} times! Bailing.')
            else:
                print(f'Failed. Sleeping for {twait} secs...')
                time.sleep(twait)
    raise RuntimeError("Exceeded imax! Shouldn't get here!")

def plug_in():
    print('Please plug in your phone!')

def is_plugged_in():
    p = run(['/usr/bin/lsusb'])
    return 'iPhone' in p.stdout

def pair():
    print('Pairing...')
    run(['/home/pi/usr/bin/idevicepair','pair'])

def is_paired():
    return len(paired_devices()) > 0

def paired_devices():
    p = run(['/home/pi/usr/bin/idevicepair','list'])
    devs = [d.strip() for d in p.stdout.split() if len(d.strip())>0]
    return devs

def backup():
    sn = phone_serial_number()
    print(f'Found phone serial number: {sn}')
    backup_dir = os.path.join(BACKUP_DIR_BASE, sn)
    if not os.path.isdir(backup_dir):
        print(f'No backup path exists, creating {backup_dir} ...')
        os.mkdir(backup_dir)
    run(['/usr/bin/rsync', '-v', '-a', MOUNT_DIR, backup_dir])

def mount():
    run(['/home/pi/usr/bin/ifuse', MOUNT_DIR])

def is_mounted():
    return any(MOUNT_DIR+' ' in m for m in open('/proc/mounts','r').readlines())

def unmount():
    run(['/bin/fusermount', '-u', MOUNT_DIR])

def is_unmounted():
    return not is_mounted()

def unpair():
    run(['/home/pi/usr/bin/idevicepair','unpair'])

def is_unpaired():
    return not is_paired()

def phone_serial_number():
    if not is_paired():
        raise RuntimeError("Uh oh - there's no paired devices, so I can't get the phone serial #!")

    devs = paired_devices()

    if len(devs) > 1:
        raise RuntimeError(f'Uh oh - multiple paired devices!: {devs}')

    return devs[0]

########################################

class LEDs:
    '''
    When a task begins, set to BLUE.
    When a task completes, set to GREEN.
    If a task errors, set to RED.
    '''
    def begin_task(self,i):
        blinkt.set_pixel(i, 0, 0, 255, 0.07) 
        blinkt.show() 

    def task_completed(self,i):
        blinkt.set_pixel(i, 0, 255, 0, 0.07) 
        blinkt.show() 

    def task_errored(self,i):
        blinkt.set_pixel(i, 255, 0, 0, 0.07) 
        blinkt.show() 

    def all_off(self):
        blinkt.clear()
        blinkt.show()

    def test(self):
        self.all_off()
        n_leds = 8
        colors = ['red', 'green', 'blue', 'white']
        for l in range(n_leds):
            for c in colors:
                if c == 'red':
                    r = 255
                    g = 0
                    b = 0
                elif c == 'green':
                    r = 0
                    g = 255
                    b = 0
                elif c == 'blue':
                    r = 0
                    g = 0
                    b = 255
                elif c == 'white':
                    r = 255
                    g = 255
                    b = 255
                print(f'LED: {l}, color: {c}')
                blinkt.set_pixel(l, r, g, b, 0.07)
                blinkt.show()
                time.sleep(.01)

        for _ in range(3):
            blinkt.set_all(255,255,255)
            blinkt.show()
            time.sleep(.05)
            blinkt.set_all(0,0,0)
            blinkt.show()
            time.sleep(.05)

        self.all_off()


if __name__ == '__main__':
    main()
