#!/bin/bash

: <<'DISCLAIMER'

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
OTHER DEALINGS IN THE SOFTWARE.

This script is licensed under the terms of the MIT license.
Unless otherwise noted, code reproduced herein
was written for this script.

- The Pimoroni Crew -

DISCLAIMER

# script control variables

productname="Blinkt!" # the name of the product to install
scriptname="blinkt" # the name of this script
spacereq=50 # minimum size required on root partition in MB
debugmode="no" # whether the script should use debug routines
debuguser="none" # optional test git user to use in debug mode
debugpoint="none" # optional git repo branch or tag to checkout
forcesudo="no" # whether the script requires to be ran with root privileges
promptreboot="no" # whether the script should always prompt user to reboot
mininstall="no" # whether the script enforces minimum install routine
customcmd="no" # whether to execute commands specified before exit
gpioreq="yes" # whether low-level gpio access is required
i2creq="no" # whether the i2c interface is required
i2sreq="no" # whether the i2s interface is required
spireq="no" # whether the spi interface is required
uartreq="no" # whether uart communication is required
armhfonly="yes" # whether the script is allowed to run on other arch
armv6="yes" # whether armv6 processors are supported
armv7="yes" # whether armv7 processors are supported
armv8="yes" # whether armv8 processors are supported
raspbianonly="no" # whether the script is allowed to run on other OSes
osreleases=( "Raspbian" "Kano" "Mate" "PiTop" "RetroPie" ) # list os-releases supported
oswarning=( "Kali" "OSMC" "Volumio" ) # list experimental os-releases
osdeny=( "Darwin" "Debian" "Linaro" "Ubuntu" ) # list os-releases specifically disallowed
debpackage="blinkt" # the name of the package in apt repo
piplibname="blinkt" # the name of the lib in pip repo
pipoverride="no" # whether the script should give priority to pip repo
pip2support="yes" # whether python2 is supported
pip3support="yes" # whether python3 is supported
topdir="Pimoroni" # the name of the top level directory
localdir="blinkt" # the name of the dir for copy of resources
gitreponame="blinkt" # the name of the git project repo
gitusername="pimoroni" # the name of the git user to fetch repo from
gitrepobranch="master" # repo branch to checkout
gitrepotop="root" # the name of the dir to base repo from
gitrepoclone="no" # whether the git repo is to be cloned locally
gitclonedir="source" # the name of the local dir for repo
repoclean="no" # whether any git repo clone found should be cleaned up
repoinstall="no" # whether the library should be installed from repo
libdir="library" # subdirectory of library in repo
copydir=( "documentation" "examples" ) # subdirectories to copy from repo
copyhead="no" # whether to use the latest repo commit or release tag
pkgremove=() # list of conflicting packages to remove
coredeplist=() # list of core dependencies
pythondep=() # list of python dependencies
pipdeplist=() # list of dependencies to source from pypi
examplesdep=( "numpy" "psutil" "requests" "tweepy" ) # list of python modules required by examples
somemoredep=() # list of additional dependencies
xdisplaydep=() # list of dependencies requiring X server

# template 1712181300

FORCE=$1
ASK_TO_REBOOT=false
CURRENT_SETTING=false
MIN_INSTALL=false
FAILED_PKG=false
REMOVE_PKG=false
UPDATE_DB=false

AUTOSTART=~/.config/lxsession/LXDE-pi/autostart
BOOTCMD=/boot/cmdline.txt
CONFIG=/boot/config.txt
DTBODIR=/boot/overlays
APTSRC=/etc/apt/sources.list
INITABCONF=/etc/inittab
BLACKLIST=/etc/modprobe.d/raspi-blacklist.conf
LOADMOD=/etc/modules

RASPOOL="http://mirrordirector.raspbian.org/raspbian/pool"
RPIPOOL="http://archive.raspberrypi.org/debian/pool"
DEBPOOL="http://ftp.debian.org/debian/pool"
GETPOOL="https://get.pimoroni.com"

SMBUS2="python-smbus_3.1.1+svn-2_armhf.deb"
SMBUS3="python3-smbus_3.1.1+svn-2_armhf.deb"
SMBUS35="python3-smbus1_1.1+35dbg-1_armhf.deb"

SPIDEV2="python-spidev_2.0~git20150907_armhf.deb"
SPIDEV3="python3-spidev_2.0~git20150907_armhf.deb"

RPIGPIO1="raspi-gpio_0.20170105_armhf.deb"
RPIGPIO2="python-rpi.gpio_0.6.3~jessie-1_armhf.deb"
RPIGPIO3="python3-rpi.gpio_0.6.3~jessie-1_armhf.deb"

export PIP_FORMAT=legacy

# function define

confirm() {
    if [ "$FORCE" == '-y' ]; then
        true
    else
        read -r -p "$1 [y/N] " response < /dev/tty
        if [[ $response =~ ^(yes|y|Y)$ ]]; then
            true
        else
            false
        fi
    fi
}

prompt() {
        read -r -p "$1 [y/N] " response < /dev/tty
        if [[ $response =~ ^(yes|y|Y)$ ]]; then
            true
        else
            false
        fi
}

success() {
    echo -e "$(tput setaf 2)$1$(tput sgr0)"
}

inform() {
    echo -e "$(tput setaf 6)$1$(tput sgr0)"
}

warning() {
    echo -e "$(tput setaf 1)$1$(tput sgr0)"
}

newline() {
    echo ""
}

progress() {
    count=0
    until [ $count -eq 7 ]; do
        echo -n "..." && sleep 1
        ((count++))
    done;
    if ps -C $1 > /dev/null; then
        echo -en "\r\e[K" && progress $1
    fi
}

sudocheck() {
    if [ $(id -u) -ne 0 ]; then
        echo -e "Install must be run as root. Try 'sudo ./$scriptname'\n"
        exit 1
    fi
}

sysclean() {
    sudo apt-get clean && sudo apt-get autoclean
    sudo apt-get -y autoremove &> /dev/null
}

sysupdate() {
    if ! $UPDATE_DB; then
        echo "Updating apt indexes..." && progress apt-get &
        sudo apt-get update 1> /dev/null || { warning "Apt failed to update indexes!" && exit 1; }
        sleep 3 && UPDATE_DB=true
    fi
}

sysupgrade() {
    sudo apt-get upgrade
    sudo apt-get clean && sudo apt-get autoclean
    sudo apt-get -y autoremove &> /dev/null
}

sysreboot() {
    warning "Some changes made to your system require"
    warning "your computer to reboot to take effect."
    echo
    if prompt "Would you like to reboot now?"; then
        sync && sudo reboot
    fi
}

arch_check() {
    IS_ARMHF=false
    IS_ARMv6=false

    if uname -m | grep -q "armv.l"; then
        IS_ARMHF=true
        if uname -m | grep -q "armv6l"; then
            IS_ARMv6=true
        fi
    fi
}

os_check() {
    IS_MACOSX=false
    IS_RASPBIAN=false
    IS_SUPPORTED=false
    IS_EXPERIMENTAL=false
    OS_NAME="Unknown"

    if uname -s | grep -q "Darwin"; then
        OS_NAME="Darwin" && IS_MACOSX=true
    elif cat /etc/os-release | grep -q "Kali"; then
        OS_NAME="Kali"
    elif [ -d ~/.kano-settings ] || [ -d ~/.kanoprofile ]; then
        OS_NAME="Kano"
    elif whoami | grep -q "linaro"; then
        OS_NAME="Linaro"
    elif [ -d ~/.config/ubuntu-mate ];then
        OS_NAME="Mate"
    elif [ -d ~/.pt-os-dashboard ] || [ -d ~/.pt-dashboard ] || [ -f ~/.pt-dashboard-config ]; then
        OS_NAME="PiTop"
    elif command -v emulationstation > /dev/null; then
        OS_NAME="RetroPie"
    elif cat /etc/os-release | grep -q "OSMC"; then
        OS_NAME="OSMC"
    elif cat /etc/os-release | grep -q "volumio"; then
        OS_NAME="Volumio"
    elif cat /etc/os-release | grep -q "Raspbian"; then
        OS_NAME="Raspbian" && IS_RASPBIAN=true
    elif cat /etc/os-release | grep -q "Debian"; then
        OS_NAME="Debian"
    elif cat /etc/os-release | grep -q "Ubuntu"; then
        OS_NAME="Ubuntu"
    fi

    if [[ " ${osreleases[@]} " =~ " ${OS_NAME} " ]]; then
        IS_SUPPORTED=true
    fi
    if [[ " ${oswarning[@]} " =~ " ${OS_NAME} " ]]; then
        IS_EXPERIMENTAL=true
    fi
}

raspbian_check() {
    IS_SUPPORTED=false
    IS_EXPERIMENTAL=false

    if [ -f /etc/os-release ]; then
        if cat /etc/os-release | grep -q "/sid"; then
            IS_SUPPORTED=false && IS_EXPERIMENTAL=true
        elif cat /etc/os-release | grep -q "stretch"; then
            IS_SUPPORTED=true && IS_EXPERIMENTAL=false
        elif cat /etc/os-release | grep -q "jessie"; then
            IS_SUPPORTED=true && IS_EXPERIMENTAL=false
        elif cat /etc/os-release | grep -q "wheezy"; then
            IS_SUPPORTED=true && IS_EXPERIMENTAL=false
        else
            IS_SUPPORTED=false && IS_EXPERIMENTAL=false
        fi
    fi
}

home_dir() {
    if [ $EUID -ne 0 ]; then
        if $IS_MACOSX; then
            USER_HOME=$(dscl . -read /Users/$USER NFSHomeDirectory | cut -d: -f2)
        else
            USER_HOME=$(getent passwd $USER | cut -d: -f6)
        fi
    else
        warning "Running as root, please log in as a regular user with sudo rights!"
        echo && exit 1
    fi
}

space_chk() {
    if command -v stat > /dev/null && ! $IS_MACOSX; then
        if [ $spacereq -gt $(($(stat -f -c "%a*%S" /)/10**6)) ];then
            echo
            warning  "There is not enough space left to proceed with  installation"
            if confirm "Would you like to attempt to expand your filesystem?"; then
                curl -sS $GETPOOL/expandfs | sudo bash && exit 1
            else
                echo && exit 1
            fi
        fi
    fi
}

timestamp() {
    date +%Y%m%d-%H%M
}

check_network() {
    sudo ping -q -w 10 -c 1 8.8.8.8 | grep "received, 0" &> /dev/null && return 0 || return 1
}

launch_url() {
    check_network || (error_box "You don't appear to be connected to the internet, please check your connection and try again!" && exit 1)
    if command -v xdg-open > /dev/null; then
        xdg-open "$1" && return 0
    else
        error_box "There was an error attempting to launch your browser!"
    fi
}

get_install() {
    check_network || (error_box "You don't appear to be connected to the internet, please check your connection and try again!" && exit 1)
    if [ "$1" != diagnostic ];then
        sysupdate && UPDATE_DB=true
    fi
    if ! command -v curl > /dev/null; then
        apt_pkg_install "curl"
    fi
    curl -sS https://get.pimoroni.com/$1 | bash -s - "-y" $2
    read -p "Press Enter to continue..." < /dev/tty
}

apt_pkg_req() {
    APT_CHK=$(dpkg-query -W -f='${Status}\n' "$1" 2> /dev/null | grep "install ok installed")

    if [ "" == "$APT_CHK" ]; then
        echo "$1 is required"
        true
    else
        echo "$1 is already installed"
        false
    fi
}

apt_pkg_install() {
    echo "Installing $1..."
    sudo apt-get --yes install "$1" 1> /dev/null || { inform "Apt failed to install $1!\nFalling back on pypi..." && return 1; }
}

apt_deb_chk() {
    BEFORE=$(dpkg-query -W "$1" 2> /dev/null)
    sudo apt-get --yes install "$1" &> /dev/null || return 1
    AFTER=$(dpkg-query -W "$1" 2> /dev/null)
    if [ "$BEFORE" == "$AFTER" ]; then
        echo "$1 is already the newest version"
    else
        echo "$1 was successfully upgraded"
    fi
}

apt_deb_install() {
    echo "Installing $1..."
    if [[ "$1" != *".deb"* ]]; then
        sudo apt-get --yes install "$1" &> /dev/null || inform "Apt failed to install $1!\nFalling back on pypi..."
        dpkg-query -W -f='${Status}\n' "$1" 2> /dev/null | grep "install ok installed"
    else
        DEBDIR=`mktemp -d /tmp/pimoroni.XXXXXX`
        cd $DEBDIR
        wget "$GETPOOL/resources/$1" &> /dev/null
        sudo dpkg -i "$DEBDIR/$1" | grep "Installing $1"
    fi
}

pip_cmd_chk() {
    if command -v pip2 > /dev/null; then
        PIP2_BIN="pip2"
    elif command -v pip-2.7 > /dev/null; then
        PIP2_BIN="pip-2.7"
    elif command -v pip-2.6 > /dev/null; then
        PIP2_BIN="pip-2.6"
    else
        PIP2_BIN="pip"
    fi
    if command -v pip3 > /dev/null; then
        PIP3_BIN="pip3"
    elif command -v pip-3.3 > /dev/null; then
        PIP3_BIN="pip-3.3"
    elif command -v pip-3.2 > /dev/null; then
        PIP3_BIN="pip-3.2"
    fi
}

pip2_lib_req() {
    PIP2_CHK=$($PIP2_BIN list 2> /dev/null | grep -i "$1")

    if [ -z "$PIP2_CHK" ]; then
        true
    else
        false
    fi
}

pip3_lib_req() {
    PIP3_CHK=$($PIP3_BIN list 2> /dev/null | grep -i "$1")

    if [ -z "$PIP3_CHK" ]; then
        true
    else
        false
    fi
}

usb_max_power() {
    if grep -q "^max_usb_current=1$" $CONFIG; then
        echo -e "\nMax USB current setting already active"
    else
        echo -e "\nAdjusting USB current setting in $CONFIG"
        echo "max_usb_current=1" | sudo tee -a $CONFIG &> /dev/null
    fi
}

add_dtoverlay() {
    if grep -q "^dtoverlay=$1" $CONFIG; then
        echo -e "\n$1 overlay already active"
    elif grep -q "^#dtoverlay=$1" $CONFIG; then
        sudo sed -i "/^#dtoverlay=$1$/ s|#||" $CONFIG
        echo -e "\nAdding $1 overlay to $CONFIG"
        ASK_TO_REBOOT=true
    else
        echo "dtoverlay=$1" | sudo tee -a $CONFIG &> /dev/null
        echo -e "\nAdding $1 overlay to $CONFIG"
        ASK_TO_REBOOT=true
    fi
}

remove_dtoverlay() {
    sudo sed -i "/^dtoverlay=$1$/ s|^|#|" $CONFIG
    ASK_TO_REBOOT=true
}

enable_pi_audio() {
    if grep -q "#dtparam=audio=on" $CONFIG; then
        sudo sed -i "/^#dtparam=audio=on$/ s|#||" $CONFIG
        echo -e "\nsnd_bcm2835 loaded (on-board audio enabled)"
        ASK_TO_REBOOT=true
    fi
}

disable_pi_audio() {
    if grep -q "^dtparam=audio=on" $CONFIG; then
        sudo sed -i "/^dtparam=audio=on$/ s|^|#|" $CONFIG
        echo -e "\nsnd_bcm2835 unloaded (on-board audio disabled)"
        ASK_TO_REBOOT=true
    fi
}

test_audio() {
    echo
    if confirm "Do you wish to test your system now?"; then
        echo -e "\nTesting..."
        speaker-test -l5 -c2 -t wav
    fi
}

disable_pulseaudio() {
    sudo mv /etc/xdg/autostart/pulseaudio.desktop /etc/xdg/autostart/pulseaudio.disabled &> /dev/null
    pulseaudio -k &> /dev/null
}

kill_volumealsa() {
    sed -i "s|type=volumealsa|type=space|" $HOME/.config/lxpanel/LXDE/panels/panel &> /dev/null
    sed -i "s|type=volumealsa|type=space|" $HOME/.config/lxpanel/LXDE-pi/panels/panel &> /dev/null
}

basic_asound() {
        sudo echo -e "pcm.\041default {\n type hw\n card 1\n}" > $HOME/.asoundrc
        sudo echo -e "ctl.\041default {\n type hw\n card 1\n}" >> $HOME/.asoundrc
        sudo mv $HOME/.asoundrc /etc/asound.conf
}

config_set() {
    if [ -n $defaultconf ]; then
        sudo sed -i "s|$1=.*$|$1=$2|" $defaultconf
    else
        sudo sed -i "s|$1=.*$|$1=$2|" $3
    fi
}

servd_trig() {
    if command -v service > /dev/null; then
        sudo service $1 $2
    fi
}

get_init_sys() {
    if command -v systemctl > /dev/null && systemctl | grep -q '\-\.mount'; then
        SYSTEMD=1
    elif [ -f /etc/init.d/cron ] && [ ! -h /etc/init.d/cron ]; then
        SYSTEMD=0
    else
        echo "Unrecognised init system" && exit 1
    fi
}

i2c_vc_dtparam() {
    if [ -e $CONFIG ] && grep -q "^dtparam=i2c_vc=on$" $CONFIG; then
        echo -e "\ni2c0 bus already active"
    else
        echo -e "\nEnabling i2c0 bus in $CONFIG"
        echo "dtparam=i2c_vc=on" | sudo tee -a $CONFIG && echo
    fi
}

: <<'MAINSTART'

Perform all variables declarations as well as function definition
above this section for clarity, thanks!

MAINSTART

# intro message

if [ $debugmode != "no" ]; then
    if [ $debuguser != "none" ]; then
        gitusername="$debuguser"
    fi
    if [ $debugpoint != "none" ]; then
        gitrepobranch="$debugpoint"
    fi
    inform "\nDEBUG MODE ENABLED"
    echo -e "git user $gitusername and $gitrepobranch branch/tag will be used\n"
else
    echo -e "\nThis script will install everything needed to use\n$productname"
    if [ "$FORCE" != '-y' ]; then
        inform "\nAlways be careful when running scripts and commands copied"
        inform "from the internet. Ensure they are from a trusted source.\n"
        echo -e "If you want to see what this script does before running it,"
        echo -e "you should run: 'curl $GETPOOL/$scriptname'\n"
    fi
fi

# checks and init

arch_check
os_check
space_chk
home_dir

if [ $debugmode != "no" ]; then
    echo "USER_HOME is $USER_HOME"
    echo "OS_NAME is $OS_NAME"
    echo "IS_SUPPORTED is $IS_SUPPORTED"
    echo "IS_EXPERIMENTAL is $IS_EXPERIMENTAL"
    echo
fi

if ! $IS_ARMHF; then
    warning "This hardware is not supported, sorry!"
    warning "Config files have been left untouched\n"
    exit 1
fi

if $IS_ARMv8 && [ $armv8 == "no" ]; then
    warning "Sorry, your CPU is not supported by this installer\n"
    exit 1
elif $IS_ARMv7 && [ $armv7 == "no" ]; then
    warning "Sorry, your CPU is not supported by this installer\n"
    exit 1
elif $IS_ARMv6 && [ $armv6 == "no" ]; then
    warning "Sorry, your CPU is not supported by this installer\n"
    exit 1
fi

if [ $raspbianonly == "yes" ] && ! $IS_RASPBIAN;then
    warning "This script is intended for Raspbian on a Raspberry Pi!\n"
    exit 1
fi

if $IS_RASPBIAN; then
    raspbian_check
    if ! $IS_SUPPORTED && ! $IS_EXPERIMENTAL; then
        warning "\n--- Warning ---\n"
        echo "The $productname installer"
        echo "does not work on this version of Raspbian."
        echo "Check https://github.com/$gitusername/$gitreponame"
        echo "for additional information and support" && echo
        exit 1
    fi
fi

if ! $IS_SUPPORTED && ! $IS_EXPERIMENTAL; then
    warning "Your operating system is not supported, sorry!\n"
    exit 1
fi

if $IS_EXPERIMENTAL; then
    warning "\nSupport for your operating system is experimental. Please visit"
    warning "forums.pimoroni.com if you experience issues with this product.\n"
fi

if [ $forcesudo == "yes" ]; then
    sudocheck
fi

if [ $uartreq == "yes" ]; then
    echo "Note: $productname requires UART communication"
    warning "The serial console will be disabled if you proceed!"
fi
if [ $spireq == "yes" ]; then
    echo -e "Note: $productname requires SPI communication"
fi
if [ $i2creq == "yes" ]; then
    echo -e "Note: $productname requires I2C communication"
fi
if [ $i2sreq == "yes" ]; then
    echo -e "Note: $productname uses the I2S interface"
    if [ $OS_NAME != "Volumio" ]; then
        warning "The on-board audio chip will be disabled if you proceed!"
    fi
fi

newline
if confirm "Do you wish to continue?"; then

# basic environment preparation

    echo -e "\nChecking environment..."

    if [ "$FORCE" != '-y' ]; then
        if ! check_network; then
            warning "We can't connect to the Internet, check your network!" && exit 1
        fi
        sysupdate && newline
    fi

    if apt_pkg_req "apt-utils" &> /dev/null; then
        apt_pkg_install "apt-utils"
    fi
    if ! command -v curl > /dev/null; then
        apt_pkg_install "curl"
    fi
    if ! command -v wget > /dev/null; then
        apt_pkg_install "wget"
    fi

    if [ "$pip2support" == "yes" ]; then
        if ! [ -f "$(which python2)" ]; then
            if confirm "Python 2 is not installed. Would like to install it?"; then
                progress apt-get &
                apt_pkg_install "python-pip"
            else
                pip2support="na"
            fi
        elif apt_pkg_req "python-pip" &> /dev/null; then
            progress apt-get &
            apt_pkg_install "python-pip"
        fi
    fi
    if [ "$pip3support" == "yes" ]; then
        if ! [ -f "$(which python3)" ]; then
            if prompt "Python 3 is not installed. Would like to install it?"; then
                progress apt-get &
                apt_pkg_install "python3-pip"
            else
                pip3support="na"
            fi
        elif apt_pkg_req "python3-pip" &> /dev/null; then
            progress apt-get &
            apt_pkg_install "python3-pip"
        fi
    fi
    pip_cmd_chk

# hardware setup

    echo -e "\nChecking hardware requirements..."

    if [ $uartreq == "yes" ]; then
        echo -e "\nThe serial console must be disabled for $productname to work"
        curl -sS $GETPOOL/uarton | sudo bash -s - "-y" && ASK_TO_REBOOT=true
    fi

    if [ $gpioreq == "yes" ]; then
        echo -e "\nChecking for packages required for GPIO control..."
        if ! apt_pkg_install "raspi-gpio" &> /dev/null; then
            echo "package raspi-gpio can't be found, fetching from alternative location..."
            DEBDIR=`mktemp -d /tmp/pimoroni.XXXXXX` && cd $DEBDIR
            wget $RPIPOOL/main/r/raspi-gpio/$RPIGPIO1 &> /dev/null
            sudo dpkg -i $DEBDIR/$RPIGPIO1 && FAILED_PKG=false
        fi
        if [ "$pip2support" == "yes" ] && ! apt_pkg_install "python-rpi.gpio" &> /dev/null; then
            if [ -n $(python --version 2>&1 | grep -q "2.7") ]; then
                echo "package python-rpi.gpio can't be found, fetching from alternative location..."
                DEBDIR=`mktemp -d /tmp/pimoroni.XXXXXX` && cd $DEBDIR
                wget $RPIPOOL/main/r/rpi.gpio/$RPIGPIO2 &> /dev/null
                sudo dpkg -i $DEBDIR/$RPIGPIO2 && FAILED_PKG=false
            else
                sudo $PIP2_BIN install RPi.GPIO && FAILED_PKG=false
            fi
        fi
        if [ "$pip3support" == "yes" ] && ! apt_pkg_install "python3-rpi.gpio" &> /dev/null; then
            if [ -n $(python3 --version 2>&1 | grep -q "3.4") ]; then
                echo "package python3-rpi.gpio can't be found, fetching from alternative location..."
                DEBDIR=`mktemp -d /tmp/pimoroni.XXXXXX` && cd $DEBDIR
                wget $RPIPOOL/main/r/rpi.gpio/$RPIGPIO3 &> /dev/null
                sudo dpkg -i $DEBDIR/$RPIGPIO3 && FAILED_PKG=false
            else
                sudo $PIP3_BIN install RPi.GPIO && FAILED_PKG=false
            fi
        fi
        if [ "$pip2support" == "yes" ] && [ -f "$(which python2)" ]; then
            if ! $PIP2_BIN list | grep "RPi.GPIO" &> /dev/null; then
                warning "Unable to install RPi.GPIO for python 2!" && FAILED_PKG=true
            else
                RPIGPIO2="install ok installed"
            fi
        fi
        if [ "$pip3support" == "yes" ] && [ -f "$(which python3)" ]; then
            if ! $PIP3_BIN list | grep "RPi.GPIO" &> /dev/null; then
                warning "Unable to install RPi.GPIO for python 3!" && FAILED_PKG=true
            else
                RPIGPIO3="install ok installed"
            fi
        fi
        if [ "$RPIGPIO2" == "install ok installed" ] || [ "$RPIGPIO3" == "install ok installed" ]; then
            if ! $FAILED_PKG; then
                echo -e "RPi.GPIO installed and up-to-date"
            fi
        fi
    fi

    if [ $spireq == "yes" ]; then
        newline
        if ls /dev/spi* &> /dev/null; then
            inform "SPI already enabled"
        else
            echo "SPI must be enabled for $productname to work"
            if command -v raspi-config > /dev/null && sudo raspi-config nonint get_spi | grep -q "1"; then
                sudo raspi-config nonint do_spi 0
                inform "SPI is now enabled"
            else
                curl -sS $GETPOOL/spi | sudo bash -s - "-y" && ASK_TO_REBOOT=true
            fi
        fi
        echo -e "\nChecking packages required by SPI interface..."
        if [ "$pip2support" == "yes" ] && ! apt_pkg_install "python-spidev" &> /dev/null; then
            if [ -n $(python --version 2>&1 | grep -q "2.7") ]; then
                echo "package python-spidev can't be found, fetching from alternative location..."
                DEBDIR=`mktemp -d /tmp/pimoroni.XXXXXX` && cd $DEBDIR
                wget $RPIPOOL/main/s/spidev/$SPIDEV2 &> /dev/null
                sudo dpkg -i $DEBDIR/$SPIDEV2 && FAILED_PKG=false
            else
                sudo $PIP2_BIN install spidev && FAILED_PKG=false
            fi
        fi
        if [ "$pip3support" == "yes" ] && ! apt_pkg_install "python3-spidev" &> /dev/null; then
            if [ -n $(python3 --version 2>&1 | grep -q "3.4") ]; then
                echo "package python3-spidev can't be found, fetching from alternative location..."
                DEBDIR=`mktemp -d /tmp/pimoroni.XXXXXX` && cd $DEBDIR
                wget $RPIPOOL/main/s/spidev/$SPIDEV3 &> /dev/null
                sudo dpkg -i $DEBDIR/$SPIDEV3 && FAILED_PKG=false
            else
                sudo $PIP3_BIN install spidev && FAILED_PKG=false
            fi
        fi
        if [ "$pip2support" == "yes" ] && [ -f "$(which python2)" ]; then
            if ! $PIP2_BIN list | grep "spidev" &> /dev/null; then
                warning "Unable to install spidev for python 2!" && FAILED_PKG=true
            else
                SPIDEV2="install ok installed"
            fi
        fi
        if [ "$pip3support" == "yes" ] && [ -f "$(which python3)" ]; then
            if ! $PIP3_BIN list | grep "spidev" &> /dev/null; then
                warning "Unable to install spidev for python 3!" && FAILED_PKG=true
            else
                SPIDEV3="install ok installed"
            fi
        fi
        if [ "$SPIDEV2" == "install ok installed" ] || [ "$SPIDEV3" == "install ok installed" ]; then
            if ! $FAILED_PKG; then
                echo -e "spidev installed and up-to-date"
            fi
        fi
    fi

    if [ $i2creq == "yes" ]; then
        newline
        if ls /dev/i2c* &> /dev/null; then
            inform "I2C already enabled"
        else
            echo "I2C must be enabled for $productname to work"
            if command -v raspi-config > /dev/null && sudo raspi-config nonint get_i2c | grep -q "1"; then
                sudo raspi-config nonint do_i2c 0
                inform "I2C is now enabled"
            else
                curl -sS $GETPOOL/i2c | sudo bash -s - "-y" && ASK_TO_REBOOT=true
            fi
        fi
        echo -e "\nChecking packages required by I2C interface..."
        if [ "$pip2support" == "yes" ] && ! apt_pkg_install "python-smbus" &> /dev/null; then
            if [ -n $(python --version 2>&1 | grep -q "2.7") ]; then
                echo "package python-smbus can't be found, fetching from alternative location..."
                DEBDIR=`mktemp -d /tmp/pimoroni.XXXXXX` && cd $DEBDIR
                wget $RPIPOOL/main/i/i2c-tools/$SMBUS2 &> /dev/null
                sudo dpkg -i $DEBDIR/$SMBUS2 && FAILED_PKG=false
            fi
        fi
        if [ "$pip3support" == "yes" ] && ! apt_pkg_install "python3-smbus" &> /dev/null; then
            if [ -n $(python3 --version 2>&1 | grep -q "3.4") ]; then
                echo "package python3-smbus can't be found, fetching from alternative location..."
                DEBDIR=`mktemp -d /tmp/pimoroni.XXXXXX` && cd $DEBDIR
                wget $RPIPOOL/main/i/i2c-tools/$SMBUS3 &> /dev/null
                sudo dpkg -i $DEBDIR/$SMBUS3 && FAILED_PKG=false
            elif [ -n $(python3 --version 2>&1 | grep -q "3.5") ]; then
                if apt_pkg_req "python3-smbus1" &> /dev/null; then
                    echo "package python3-smbus can't be found, fetching from alternative location..."
                    DEBDIR=`mktemp -d /tmp/pimoroni.XXXXXX` && cd $DEBDIR
                    wget $GETPOOL/resources/$SMBUS35 &> /dev/null
                    sudo dpkg -i $DEBDIR/$SMBUS35 && FAILED_PKG=false
                fi
            fi
        fi
        if [ "$pip2support" == "yes" ] && [ -f "$(which python2)" ]; then
            if ! $PIP2_BIN list | grep "smbus" &> /dev/null; then
                warning "Unable to install smbus for python 2!" && FAILED_PKG=true
            else
                SMBUS2="install ok installed"
            fi
        fi
        if [ "$pip3support" == "yes" ] && [ -f "$(which python3)" ]; then
            if ! $PIP3_BIN list | grep "smbus" &> /dev/null; then
                warning "Unable to install smbus for python 3!" && FAILED_PKG=true
            else
                SMBUS3="install ok installed"
            fi
        fi
        if [ "$SMBUS2" == "install ok installed" ] || [ "$SMBUS3" == "install ok installed" ]; then
            if ! $FAILED_PKG; then
                echo -e "smbus installed and up-to-date"
            fi
        fi
    fi

    if [ $i2sreq == "yes" ]; then
        if [ -f /etc/asound.conf ]; then
            sudo rm -f /etc/asound.conf.backup &> /dev/null
            sudo mv /etc/asound.conf /etc/asound.conf.backup
            inform "existing config backed up to /etc/asound.conf.backup"
        fi
        if [ -f $HOME/.asoundrc ]; then
            sudo rm -f $HOME/.asoundrc.backup &> /dev/null
            sudo mv $HOME/.asoundrc $HOME/.asoundrc.backup
            inform "existing config backed up to ~/.asound.conf.backup"
        fi
    fi

# minimum install routine

    if [ $mininstall != "yes" ] && [ $gitrepoclone != "yes" ]; then
        newline
        echo "$productname comes with examples and documentation that you may wish to install."
        echo "Performing a full install will ensure those resources are installed,"
        echo "along with all required dependencies. It may however take a while!"
        newline
        if ! confirm "Do you wish to perform a full install?"; then
            MIN_INSTALL=true
        fi
    else
        MIN_INSTALL=true
    fi

    if [ $localdir != "na" ]; then
        installdir="$USER_HOME/$topdir/$localdir"
    else
        installdir="$USER_HOME/$topdir"
    fi

    if ! $MIN_INSTALL || [ $gitrepoclone == "yes" ]; then
        [ -d $installdir ] || mkdir -p $installdir
    fi

    if [ $debugmode != "no" ]; then
        echo "INSTALLDIR is $installdir"
    fi

# apt repo install

    echo -e "\nChecking for dependencies..."

    if $REMOVE_PKG; then
        for pkgrm in ${pkgremove[@]}; do
            warning "Installed package conflicts with requirements"
            sudo apt-get remove "$pkgrm"
        done
    fi

    for pkgdep in ${coredeplist[@]}; do
        if apt_pkg_req "$pkgdep"; then
            apt_pkg_install "$pkgdep"
        fi
    done

    for pkgdep in ${pythondep[@]}; do
        if [ -f "$(which python2)" ] && [ $pip2support == "yes" ]; then
            if apt_pkg_req "python-$pkgdep"; then
                apt_pkg_install "python-$pkgdep"
            fi
        fi
        if [ -f "$(which python3)" ] && [ $pip3support == "yes" ]; then
            if apt_pkg_req "python3-$pkgdep"; then
                apt_pkg_install "python3-$pkgdep"
            fi
        fi
    done

    if [ $pipoverride != "yes" ] && [ $debpackage != "na" ]; then
        newline
        if [ $pip2support != "yes" ] && [ $pip3support != "yes" ]; then
            apt_deb_install "$debpackage"
        fi
        if [ -f "$(which python2)" ] && [ $pip2support == "yes" ]; then
            apt_deb_install "python-$debpackage"
            if ! apt_pkg_req "python-$debpackage" &> /dev/null; then
                sudo $PIP2_BIN uninstall -y "$piplibname" &> /dev/null
            fi
        fi
        if [ -f "$(which python3)" ] && [ $pip3support == "yes" ]; then
            apt_deb_install "python3-$debpackage"
            if ! apt_pkg_req "python3-$debpackage" &> /dev/null; then
                sudo $PIP3_BIN uninstall -y "$piplibname" &> /dev/null
            fi
        fi
        if apt_pkg_req "python-$debpackage" &> /dev/null || apt_pkg_req "python3-$debpackage" &> /dev/null; then
            debpackage="na"
        fi
    else
        debpackage="na"
    fi

# pypi repo install

    if [ -f "$(which python2)" ] && [ $pip2support == "yes" ] && apt_pkg_req "python-$debpackage" &> /dev/null; then
        if [ $piplibname != "na" ] && [ $debpackage == "na" ]; then
            newline && echo "Installing $productname library for Python 2..." && newline
            if ! sudo -H $PIP2_BIN install "$piplibname"; then
                warning "Python 2 library install failed!"
                echo "If problems persist, visit forums.pimoroni.com for support"
                exit 1
            fi
        fi
    fi

    if [ -f "$(which python3)" ] && [ $pip3support == "yes" ] && apt_pkg_req "python3-$debpackage" &> /dev/null; then
        if [ $piplibname != "na" ] && [ $debpackage == "na" ]; then
            newline && echo "Installing $productname library for Python 3..." && newline
            if ! sudo -H $PIP3_BIN install "$piplibname"; then
                warning "Python 3 library install failed!"
                echo "If problems persist, visit forums.pimoroni.com for support"
                exit 1
            fi
        fi
    fi

# git repo install

    if [ $gitrepoclone == "yes" ]; then
        if ! command -v git > /dev/null; then
            apt_pkg_install git
        fi
        if [ $gitclonedir == "source" ]; then
            gitclonedir=$gitreponame
        fi
        if [ $repoclean == "yes" ]; then
            rm -Rf $installdir/$gitclonedir
        fi
        if [ -d $installdir/$gitclonedir ]; then
            newline && echo "Github repo already present. Updating..."
            cd $installdir/$gitclonedir && git pull
        else
            newline && echo "Cloning Github repo locally..."
            cd $installdir
            if [ $debugmode != "no" ]; then
                echo "git user name is $gitusername"
                echo "git repo name is $gitreponame"
            fi
            if [ $gitrepobranch != "master" ]; then
                git clone https://github.com/$gitusername/$gitreponame $gitclonedir -b $gitrepobranch
            else
                git clone --depth=1 https://github.com/$gitusername/$gitreponame $gitclonedir
            fi
        fi
    fi

    if [ $repoinstall == "yes" ]; then
        newline && echo "Installing library..." && newline
        cd $installdir/$gitreponame/$libdir
        if [ -f "$(which python2)" ] && [ $pip2support == "yes" ]; then
            sudo python2 ./setup.py install
        fi
        if [ -f "$(which python3)" ] && [ $pip3support == "yes" ]; then
            sudo python3 ./setup.py install
        fi
        newline
    fi

# additional install

    if ! $MIN_INSTALL; then
        echo -e "\nChecking for additional software..."
        for moredep in ${examplesdep[@]}; do
            if [ -f "$(which python2)" ] && apt_pkg_req "python-$moredep"; then
                if ! apt_pkg_install "python-$moredep"; then
                    sudo -H $PIP2_BIN install "$moredep"
                    if pip2_lib_req "$moredep"; then
                        FAILED_PKG=true
                    fi
                fi
            fi
            if [ -f "$(which python3)" ] && apt_pkg_req "python3-$moredep"; then
                if ! apt_pkg_install "python3-$moredep"; then
                    sudo -H $PIP3_BIN install "$moredep"
                    if pip3_lib_req "$moredep"; then
                        FAILED_PKG=true
                    fi
                fi
            fi
        done
        for pipdep in ${pipdeplist[@]}; do
            if [ -f "$(which python2)" ] && pip2_lib_req "$pipdep"; then
                sudo -H $PIP2_BIN install "$pipdep"
            fi
            if [ -f "$(which python3)" ] && pip3_lib_req "$pipdep"; then
                sudo -H $PIP3_BIN install "$pipdep"
            fi
        done
        for moredep in ${somemoredep[@]}; do
            if apt_pkg_req "$moredep"; then
                apt_pkg_install "$moredep"
            fi
        done
        if [ -n "$DISPLAY" ]; then
            for x11dep in ${xdisplaydep[@]}; do
                if apt_pkg_req "$x11dep"; then
                    apt_pkg_install "$x11dep"
                fi
            done
        fi
    fi

# resources install

    if ! $MIN_INSTALL && [ -n "$copydir" ]; then
        if ! command -v git > /dev/null; then
            apt_pkg_install git
        fi
        echo -e "\nDownloading examples and documentation..."
        TMPDIR=`mktemp -d /tmp/pimoroni.XXXXXX`
        cd $TMPDIR
        if [ $copyhead != "yes" ]; then
            GITTAG=$(git ls-remote -t https://github.com/$gitusername/$gitreponame v\?.?.? | tail -n 1 | rev | cut -c -6 | rev)
        fi
        if [ -n "$GITTAG" ]; then
            git clone https://github.com/$gitusername/$gitreponame -b $GITTAG &> /dev/null
        else
            git clone --depth=1 https://github.com/$gitusername/$gitreponame &> /dev/null
        fi
        cd $installdir
        for repodir in ${copydir[@]}; do
            if [ -d $repodir ] && [ $repodir != "documentation" ]; then
                newline
                if [ -d $installdir/$repodir-backup ]; then
                    rm -R $installdir/$repodir-old &> /dev/null
                    mv $installdir/$repodir-backup $installdir/$repodir-old &> /dev/null
                fi
                mv $installdir/$repodir $installdir/$repodir-backup &> /dev/null
                if [ $gitrepotop != "root" ]; then
                    cp -R $TMPDIR/$gitreponame/$gitrepotop/$repodir $installdir/$repodir &> /dev/null
                else
                    cp -R $TMPDIR/$gitreponame/$repodir $installdir/$repodir &> /dev/null
                fi
                inform "The $repodir directory already exists on your system!"
                echo -e "We've backed them up as $repodir-backup, just in case you've changed anything!\n"
            else
                rm -R $installdir/$repodir &> /dev/null
                if [ $gitrepotop != "root" ]; then
                    cp -R $TMPDIR/$gitreponame/$gitrepotop/$repodir $installdir/$repodir &> /dev/null
                else
                    cp -R $TMPDIR/$gitreponame/$repodir $installdir/$repodir &> /dev/null
                fi
            fi
        done
        echo "Resources for your $productname were copied to"
        inform "$installdir"
        rm -rf $TMPDIR
    fi

# script custom routines

    if [ $customcmd == "no" ]; then
        if [ -n "$pkgremove" ]; then
            echo -e "\nFinalising Install...\n"
            sysclean && newline
        fi
        echo -e "\nAll done. Enjoy your $productname!\n"
    else # custom block starts here
        echo -e "\nFinalising Install...\n"
        # place all custom commands in this scope
    fi

    if $FAILED_PKG; then
        warning "\nSome packages could not be installed, review the output for details!\n"
    fi
    if $IS_EXPERIMENTAL; then
        warning "\nSupport for your operating system is experimental. Please visit"
        warning "forums.pimoroni.com if you experience issues with this product.\n"
    fi

    if [ "$FORCE" != '-y' ]; then
        if [ $promptreboot == "yes" ] || $ASK_TO_REBOOT; then
            sysreboot && newline
        fi
    fi
else
    echo -e "\nAborting...\n"
fi

exit 0
