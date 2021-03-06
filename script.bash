#!/bin/bash

log() {
  if [[ $2 != "" ]]; then
    printf "\n[ERRO] $1\n"
    cat <<EOF 

The program has stopped due to the above error
If you believe this is a bug, please report it.
If you are having issues please ask for help from Geckoboard support

Press any key to exit
EOF

    # Give the user time to see this message
    read
    exit 127
  else
    printf "\n[INFO] $1\n"
  fi
}

upgrade_system() {
  sudo apt -qq upgrade -y
  sudo apt -qq autoremove -y > /dev/null
}

install_essential_tools() {
  sudo apt install -y chromium-browser unclutter
}

install_color_emoji() {
  NOTOEMOJI_ZIPFILE=noto_color_emoji.zip
  FONT_STORE=$HOME/.local/share/fonts
  NOTOEMOJI_DIR=noto_color_emoji

  curl -o $NOTOEMOJI_ZIPFILE https://noto-website-2.storage.googleapis.com/pkgs/NotoColorEmoji-unhinted.zip
  unzip $NOTOEMOJI_ZIPFILE -d $NOTOEMOJI_DIR

  mkdir -p $FONT_STORE

  mv $NOTOEMOJI_DIR/*.ttf $FONT_STORE/
  rm -r $NOTOEMOJI_DIR || true
  rm $NOTOEMOJI_ZIPFILE || true
}

install_mscore_fonts() {
  sudo apt install -y ttf-mscorefonts-installer
}

check_raspberrypi() {
  if ! `lsb_release -a | grep -q "Raspbian"`; then
    log "this device appears not to be running raspbian os" 1
  fi

  if ! `uname -m | grep -q "armv"` ; then
    log "this device doesn't appear to be a raspberry pi" 1
  fi

  if [[ $DESKTOP_SESSION != "LXDE-pi" ]]; then
    log "this device isn't running a support desktop environment", 1
  fi
}

install_kiosk_script() {
  AUTOSTART_PATH=$HOME/.config/lxsession/LXDE-pi
  AUTOSTART_FILE=$AUTOSTART_PATH/autostart
  GECKOBOARD_KIOSK_FILE=$AUTOSTART_PATH/geckoboard_kiosk_mode

  mkdir -p $AUTOSTART_PATH

cat > $GECKOBOARD_KIOSK_FILE <<EOF
#!/bin/bash

# Turn off screensaver stuff and disable energysaver stuff
xset -dpms
xset s noblank
xset s off

# Remove the mouse cursor after 10 seconds of idleness
# This uses grab to remove focus from the browser in case of link hover
unclutter -idle 10 -grab &

# Ensure that if we have a power cut or bad shutdown that
# the chromium preferences are reset to a "good" state so we
# don't get the restore previous session dialog
sed -i 's/"exited_cleanly":false/"exited_cleanly":true/' $HOME/.config/chromium/Default/Preferences
sed -i 's/"exit_type":"Crashed"/"exit_type":"Normal"/' $HOME/.config/chromium/Default/Preferences

# Disable any installed extentions and the default browser check
chromium-browser \
--disable-extensions \
--start-fullscreen \
--no-default-browser-check \
https://metabase.doctrine.fr/public/dashboard/d2e4e860-cfa8-4e9d-866b-a588575e567f\#refresh=60&theme=night
EOF

  chmod +x $GECKOBOARD_KIOSK_FILE

  if [[ ! -f $AUTOSTART_FILE ]]; then
    # We are clear to clone the current autostart
    echo "[INFO] cloning system lxde autostart"
    cp /etc/xdg/lxsession/LXDE-pi/autostart $AUTOSTART_FILE

    log "adding kiosk mode to autostart"
    echo "@$GECKOBOARD_KIOSK_FILE" >> $AUTOSTART_FILE
  else
    if grep -Fxq "@$GECKOBOARD_KIOSK_FILE" $AUTOSTART_FILE; then
      echo "[SKIP] kiosk mode already setup"
    else
      log "adding kiosk mode to autostart"
      echo "@$GECKOBOARD_KIOSK_FILE" >> $AUTOSTART_FILE
    fi
  fi
}

disable_underscan() {
  # Create a backup file before modifying
  sudo cp /boot/config.txt /boot/config.txt.bkp
  sudo sed -i 's/#disable_overscan=1/disable_overscan=1/' /boot/config.txt
}


# Display logo and intro to user
# ASCII display generated at https://www.ascii-art-generator.org/

cat <<EOF
   _____ ______ _____ _  ______  ____   ____          _____  _____ 
  / ____|  ____/ ____| |/ / __ \|  _ \ / __ \   /\   |  __ \|  __ \ 
 | |  __| |__   |    | ' / |  | | |_| | |  | | /  \  | |__| | |  | | 
 | | |_ |  __|  |    |  <  |  | |  _ <| |  | |/ /\ \ |  _  /| |  | | 
 | |__| | |___  |____| ' \ |__| | |_| | |__| / ____ \| | \ \| |__| | 
  \_____|______\_____|_|\_\____/|____/ \____/_/    \_\_|  \_\_____/ 


We will guide you through setting up your device optimized to display Geckoboard.
Along the way you will have the option to not do some things for which you can just press enter

The questions which will be asked will be just require either y for Yes or n for No
by default the answer will assume No (y/N) declared by the capital N in these cases you can just press enter

We will do the following;
 - Turn off any underscan if necessary
 - Upgrade your raspbian OS with the latest updates
 - Ensure Chromium is installed and the latest version available
 - Install color emoji support
 - Install Microsoft core fonts 
 - Install a script which will disable screensaver/power settings and
   start chromium at Geckoboard on each startup

 This process should only take a few minutes
 If you are ready press any key to start
EOF

read

check_raspberrypi

log "getting latest packages"
sudo apt update -y

printf "do you see black border around the screen [y/N]:"
read blkbrd
if [[ $blkbrd == "y" ]]; then
  log "disabling underscan"
  disable_underscan
fi

printf "do you want to install latest updates (it might take 10+ mins) [y/N]:"
read upgr
if [[ $upgr == "y" ]]; then
  log "updating os packages"
  upgrade_system
fi

log "installing latest chromium browser and tools"
install_essential_tools > /dev/null

log "installing mscore fonts"
install_mscore_fonts > /dev/null

log "installing color emoji support"
install_color_emoji > /dev/null

log "setting up Geckoboard kiosk mode"
install_kiosk_script

cat <<EOF

************ Setup complete ***********

Check out the send to TV support article on how to pair your device with Geckoboard
Now you are ready to reboot the raspberry pi.

When raspberry pi next starts up it should display the TV pin code

http://bit.ly/gbontvdoc

You'll be empowering your team to be the best in no time

When you are ready press any key to reboot. 
EOF

read
sudo reboot
