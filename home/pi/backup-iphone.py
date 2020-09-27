#!/usr/bin/env python3

print('Hello from backup-iphone.py!')

import blinkt
blinkt.set_clear_on_exit(False)

import os, time, subprocess
from datetime import datetime

MOUNT_DIR = '/home/pi/usr/mnt'               # Phone's filesystem appears here
BACKUP_DIR_BASE = '/home/pi/iphone-backups'  # We backup the phone to here

##############################################

def main():
    print(f'{datetime.now()}: Welcome to backup-iphone.py!')

    if not os.path.isdir(BACKUP_DIR_BASE):
        print(f'No backup dir exists, creating {BACKUP_DIR_BASE} ...')
        os.mkdir(BACKUP_DIR_BASE)

    leds = LEDs()
    leds.test()

    print('Plugged in?')
    leds.run_task_with_lights(task = lambda: run_repeatedly(plug_in, is_plugged_in), led = 0)

    # Note: takes 10 sec upon plug-in for iOS to prompt for "Trust".
    print('Pairing...')
    leds.run_task_with_lights(task = lambda: run_repeatedly(pair, is_paired), led = 1)

    print('Mounting...')
    leds.run_task_with_lights(task = lambda: run_repeatedly(mount, is_mounted), led = 2)

    print('Backing up...')
    leds.run_task_with_lights(task = lambda: backup(), led = 3)

    print('Unmounting...')
    leds.run_task_with_lights(task = lambda: run_repeatedly(unmount, is_unmounted), led = 4)

    print('Unpairing...')
    leds.run_task_with_lights(task = lambda: run_repeatedly(unpair, is_unpaired), led = 5)

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

def run_repeatedly(f, check, imax=100, twait=2):
    '''
    Gonna run f() until check() returns true,
    up to imax times, pausing twait secs after each failure.
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
    return 'iPad' in p.stdout or 'iPhone' in p.stdout

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

    def run_task_with_lights(self, task, led):
        if led < 0 or led > 7:
            raise RuntimeError(f'Blinkt LED strip has only 8 LEDs, so led={led} should be 0,1,...,7!')

        self._begin_task(led)
        task()
        self._task_completed(led)

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

    def _begin_task(self,i):
        blinkt.set_pixel(i, 0, 0, 255, 0.07)
        blinkt.show()

    def _task_completed(self,i):
        blinkt.set_pixel(i, 0, 255, 0, 0.07)
        blinkt.show()

    def _task_errored(self,i):
        blinkt.set_pixel(i, 255, 0, 0, 0.07)
        blinkt.show()


if __name__ == '__main__':
    main()
