#!/usr/bin/env python3

print('Hello from backup-iphone.py!')

import blinkt
blinkt.set_clear_on_exit(False)

import os, time, subprocess
from datetime import datetime
from pathlib import Path

MOUNT_DIR = Path.home() / 'usr' / 'mnt'           # I will mount iPhone's filesystem here
BACKUP_DIR_BASE = Path.home() / 'iphone-backups'  # I will backup the phone to here
LOG_FILE = Path('~/log.txt')

# Follow the directions in the README for how to install these
# binaries from source so that they live in your home directory.
IFUSE_BIN = Path.home() / 'usr' / 'bin' / 'ifuse'
IDEVICEPAIR_BIN = Path.home() / 'usr' / 'bin' / 'idevicepair'

# The README describes how to install these 3 tools:
LSUSB_BIN = '/usr/bin/lsusb'
RSYNC_BIN = '/usr/bin/rsync'
FUSERMOUNT_BIN = '/bin/fusermount'

import logging
logger = logging.getLogger('my_logger')
logger.setLevel(logging.DEBUG)

for h in [logging.StreamHandler(), logging.FileHandler(LOG_FILE, encoding='utf-8')]:
    h.setLevel(logging.DEBUG)
    h.setFormatter(logging.Formatter('%(asctime)-15s  %(name)-8s  %(levelname)-8s  %(message)s'))
    logger.addHandler(h)

##############################################

def main():
    logger.info(f'{datetime.now()}: Welcome to backup-iphone.sh!')

    if not BACKUP_DIR_BASE.is_dir():
        logger.info(f'No backup dir exists, creating {BACKUP_DIR_BASE} ...')
        BACKUP_DIR_BASE.mkdir()

    leds = LEDs()
    leds.test()

    logger.info('Plugged in?')
    leds.run_task_with_lights(task = lambda: run_repeatedly(plug_in, is_plugged_in), led = 0)

    # Note: takes 10 sec upon plug-in for iOS to prompt for "Trust".
    logger.info('Pairing...')
    leds.run_task_with_lights(task = lambda: run_repeatedly(pair, is_paired), led = 1)

    logger.info('Mounting...')
    leds.run_task_with_lights(task = lambda: run_repeatedly(mount, is_mounted), led = 2)

    logger.info('Backing up...')
    leds.run_task_with_lights(task = lambda: backup(), led = 3)

    logger.info('Unmounting...')
    leds.run_task_with_lights(task = lambda: run_repeatedly(unmount, is_unmounted), led = 4)

    logger.info('Unpairing...')
    leds.run_task_with_lights(task = lambda: run_repeatedly(unpair, is_unpaired), led = 5)

    logger.info(f'{datetime.now()}: Bye from backup-iphone.sh!')


#############################################

def run(arg_list):
    logger.info('Running:')
    logger.info(arg_list)
    p = subprocess.run(
        arg_list,
        capture_output=True,
        universal_newlines=True
        )
    logger.info(f'returncode: "{p.returncode}"')
    logger.info(f'stdout: "{p.stdout}"')
    logger.info(f'stderr: "{p.stderr}"')

    return p

def run_repeatedly(f, check, imax=100, twait=2):
    '''
    Gonna run f() until check() returns true,
    up to imax times, pausing twait secs after each failure.
    '''

    if check():
        logger.info(f'Check={check.__name__} succeeded without even running f={f.__name__} once!')
        return

    i=0
    while i <= imax:
        i += 1
        logger.info(f'Running f={f.__name__}, attempt {i}/{imax}...')
        f()
        logger.info(f'Checking {check.__name__}...')
        if check():
            logger.info('Success!')
            return
        else:
            if i == imax:
                raise RuntimeError(f'{f.__name__} failed {imax} times! Bailing.')
            else:
                logger.info(f'Failed. Sleeping for {twait} secs...')
                time.sleep(twait)
    raise RuntimeError("Exceeded imax! Shouldn't get here!")

def plug_in():
    logger.info('Please plug in your phone!')

def is_plugged_in():
    p = run([LSUSB_BIN])
    return 'iPad' in p.stdout or 'iPhone' in p.stdout

def pair():
    logger.info('Pairing...')
    run([IDEVICEPAIR_BIN,'pair'])

def is_paired():
    return len(paired_devices()) > 0

def paired_devices():
    p = run([IDEVICEPAIR_BIN,'list'])
    devs = [d.strip() for d in p.stdout.split() if len(d.strip())>0]
    return devs

def backup():
    sn = phone_serial_number()
    logger.info(f'Found phone serial number: {sn}')
    backup_dir = os.path.join(BACKUP_DIR_BASE, sn)
    if not os.path.isdir(backup_dir):
        logger.info(f'No backup path exists, creating {backup_dir} ...')
        os.mkdir(backup_dir)
    run([RSYNC_BIN, '-v', '-a', MOUNT_DIR, backup_dir])

def mount():
    run([IFUSE_BIN, MOUNT_DIR])

def is_mounted():
    return any(f'{MOUNT_DIR} ' in m for m in open('/proc/mounts','r').readlines())

def unmount():
    run([FUSERMOUNT_BIN, '-u', MOUNT_DIR])

def is_unmounted():
    return not is_mounted()

def unpair():
    run([IDEVICEPAIR_BIN,'unpair'])

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
                logger.info(f'LED: {l}, color: {c}')
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
