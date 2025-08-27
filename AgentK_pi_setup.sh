#!/bin/bash



LOG_FILE="$HOME/AgentK_pi_setup.log"

log() { echo "$(date +"%Y-%m-%d %T") : $1" | tee -a "$LOG_FILE"; }

# Tail the log in background
if command -v tail >/dev/null 2>&1; then
  tail -f "$LOG_FILE" &
  TAIL_PID=$!
else
  echo "tail not found" >&2
  exit 1
fi

update_and_upgrade() {
  log "Updating and upgrading the system..."
  sudo apt-get update >>"$LOG_FILE" 2>&1 && sudo apt-get upgrade -y >>"$LOG_FILE" 2>&1 || { log "System update failed"; exit 1; }
  log "System update completed."
}

check_dependencies() {
  log "Checking/installing dependencies..."
  REQUIRED_PKG=("git" "figlet" "lolcat" "python3" "vim" "cockpit" "cron" "fail2ban" "wget" "libraspberrypi-bin")
  for PKG in "${REQUIRED_PKG[@]}"; do
    if ! dpkg -l | grep -q "^ii  $PKG\b"; then
      log "Installing $PKG..."
      sudo apt-get install -y "$PKG" >>"$LOG_FILE" 2>&1 || { log "Failed to install $PKG"; exit 1; }
    else
      log "$PKG already installed."
    fi
  done
  sudo systemctl enable --now cron >>"$LOG_FILE" 2>&1 || true
  sudo systemctl enable --now cockpit >>"$LOG_FILE" 2>&1 || true
  log "Dependencies ready."
}

MOUNT_POINT="/media/usb"
USB_PARTITION=""

mount_usb() {
  log "Mounting USB (baseline logic)..."
  lsblk -rpo NAME,TYPE | tee -a "$LOG_FILE"
  USB_PARTITION=$(lsblk -rpo NAME,TYPE | grep "part" | grep -vE "mmcblk|sda2" | awk '{print $1}' | head -n 1)
  if [ -z "$USB_PARTITION" ]; then
    log "No USB partition detected. Insert the USB and re-run."
    exit 1
  fi
  log "Using USB partition: $USB_PARTITION"

  if mount | grep -q "$USB_PARTITION"; then
    log "Partition already mounted; unmounting..."
    sudo umount "$USB_PARTITION" >>"$LOG_FILE" 2>&1 || { log "Failed to unmount $USB_PARTITION"; exit 1; }
  fi

  [ -d "$MOUNT_POINT" ] || sudo mkdir -p "$MOUNT_POINT"

  sudo mount "$USB_PARTITION" "$MOUNT_POINT" -o uid=$(whoami),gid=$(whoami) >>"$LOG_FILE" 2>&1 || {
    log "Mount failed; checking if $MOUNT_POINT is busy..."
    if mount | grep -q " $MOUNT_POINT "; then
      log "Unmounting busy mountpoint then retrying..."
      sudo umount "$MOUNT_POINT" >>"$LOG_FILE" 2>&1 || { log "Failed to unmount busy mountpoint"; exit 1; }
      sudo mount "$USB_PARTITION" "$MOUNT_POINT" -o uid=$(whoami),gid=$(whoami) >>"$LOG_FILE" 2>&1 || { log "Mount failed after retry"; exit 1; }
    else
      log "Mount failed."
      exit 1
    fi
  }
  log "USB partition mounted at $MOUNT_POINT."
}

install_autosol() {
  log "Installing Autosol from USB..."
  AUTOSOL_PACKAGE=$(find "$MOUNT_POINT/Autosol/" -name "*.deb" | head -n 1)
  if [ -f "$AUTOSOL_PACKAGE" ]; then
    sudo apt-get install -y "$AUTOSOL_PACKAGE" >>"$LOG_FILE" 2>&1 || { log "Autosol install failed"; exit 1; }
    log "Autosol installed."
  else
    log "Autosol package not found in $MOUNT_POINT/Autosol."
    exit 1
  fi
}

install_figlet_lolcat() {
  log "Ensuring figlet/lolcat and fonts..."
  sudo apt-get install -y figlet >>"$LOG_FILE" 2>&1
  if [ ! -f /usr/share/figlet/Speed.flf ] || [ ! -f /usr/share/figlet/halfiwi.flf ]; then
    sudo git clone https://github.com/xero/figlet-fonts /usr/share/figlet-fonts >>"$LOG_FILE" 2>&1 || true
    sudo mv /usr/share/figlet-fonts/* /usr/share/figlet 2>/dev/null || true
    sudo rm -rf /usr/share/figlet-fonts
  fi
  if ! command -v lolcat >/dev/null 2>&1; then
    sudo apt-get install -y ruby ruby-dev build-essential >>"$LOG_FILE" 2>&1 || true
    sudo gem install lolcat >>"$LOG_FILE" 2>&1 || true
  fi
  figlet -c -f Speed "Kilo Automation" | lolcat -a --duration=3 -t || true
  log "figlet/lolcat ready."
}

add_banner() {
  log "Adding banner to /etc/bash.bashrc (starting at line 61)..."
  BRC="/etc/bash.bashrc"
  [ -f "$BRC.bak" ] || sudo cp "$BRC" "$BRC.bak" 2>/dev/null || true
  sudo sed -i '/# KA_BANNER_START/,/# KA_BANNER_END/d' "$BRC" 2>/dev/null || true
  LINES=$(wc -l < "$BRC" 2>/dev/null || echo 0)
  if [ "$LINES" -lt 60 ]; then
    for i in $(seq 1 $((60 - LINES))); do echo | sudo tee -a "$BRC" >/dev/null; done
  fi
  sudo tee -a "$BRC" >/dev/null <<'RC'
# KA_BANNER_START
if [ -n "$PS1" ]; then
  figlet -c -f Speed Kilo Automation | lolcat -a --duration=3 -t
  echo "$(tput bold)$(tput setaf 2)"
  echo "				    .~~.   .~~.  "
  echo "				   '. \ ' ' / .' "
  echo "$(tput setaf 1)"
  echo "				    .~ .~~~..~.   "
  echo "				   : .~.'~'.~. :  "
  echo "				  ~ (   ) (   ) ~ "
  echo "				 ( : '~'.~.'~' : )"
  echo "				  ~ .~ (   ) ~. ~ "
  echo "			   	   (  : '~' :  )  "
  echo "			 	    '~ .~~~. ~'   "
  echo "				        '~'      "
  figlet -c -f halfiwi 125_Stone_Cold | lolcat -a --duration=3 -t

  let upSeconds="$(( $(/usr/bin/cut -d. -f1 /proc/uptime) ))"
  let secs=$((upSeconds%60))
  let mins=$((upSeconds/60%60))
  let hours=$((upSeconds/3600%24))
  let days=$((upSeconds/86400))
  UPTIME=$(printf "%d days, %02dh%02dm%02ds" "$days" "$hours" "$mins" "$secs")

  read one five fifteen rest < /proc/loadavg

  echo "$(tput setaf 2)
`date +"%A, %e %B %Y, %r"`
`uname -srmo`

$(tput sgr0)- Uptime.............: ${UPTIME}
$(tput sgr0)- Memory.............: $(free | grep Mem | awk '{print $3/1024}') MB (Used) / $(cat /proc/meminfo | grep MemTotal | awk {'print $2/1024'}) MB (Total)
$(tput sgr0)- Load Averages......: ${one}, ${five}, ${fifteen} (1, 5, 15 min)
$(tput sgr0)- Running Processes..: $(ps ax | wc -l | tr -d " ")
$(tput sgr0)- IP Addresses.......: Local $(hostname -I | /usr/bin/cut -d " " -f 1) Public  $(wget -q -O - http://icanhazip.com/ | tail)
$(tput sgr0)- CPU Tempature......: $(/usr/bin/vcgencmd measure_temp | awk -F "[=']" '{print($2 * 1.8)+32}' | awk '{print $1" °F"}')
$(tput sgr0)"
fi
# KA_BANNER_END
RC
  log "Banner added."
}

configure_fail2ban() {
  log "Configuring Fail2Ban (SSH + Cockpit, journal backend)..."
  sudo tee /etc/fail2ban/jail.local >/dev/null <<'JAIL'
[DEFAULT]
backend = systemd
banaction = iptables-multiport
findtime  = 10m
maxretry  = 3
bantime   = 1h

[sshd]
enabled = true
port    = ssh
logpath = /var/log/auth.log

[cockpit]
enabled  = true
port     = 9090
filter   = cockpit
logpath  = journal
maxretry = 3
bantime  = 1h
JAIL

  sudo tee /etc/fail2ban/filter.d/cockpit.conf >/dev/null <<'FILTER'
[Definition]
journalmatch = _SYSTEMD_UNIT=cockpit.service

failregex = ^.*pam_unix\(.*:auth\): authentication failure;.*rhost=<HOST>.*$
            ^.*Failed to authenticate user .* from <HOST>\.$
            ^.*Refused root login from <HOST>\.$

ignoreregex =
FILTER

  sudo systemctl enable --now fail2ban >>"$LOG_FILE" 2>&1
  sudo systemctl restart fail2ban >>"$LOG_FILE" 2>&1
  log "Fail2Ban configured."
}

unmount_usb() {
  log "Unmounting USB..."
  sudo umount /media/usb >>"$LOG_FILE" 2>&1 || log "Unmount failed (may be busy)."
}

prompt_reboot() {
  log "Reboot now to apply all changes? (y/n)"
  read -r REBOOT
  if [ "$REBOOT" = "y" ]; then
    log "Rebooting..."
    sudo reboot
  else
    log "Reboot skipped."
  fi
}

update_and_upgrade
check_dependencies
mount_usb
install_autosol
install_figlet_lolcat
add_banner
configure_fail2ban
unmount_usb
prompt_reboot

# stop tail
if ps -p "$TAIL_PID" >/dev/null 2>&1; then kill "$TAIL_PID"; fi
log "Setup completed successfully."
